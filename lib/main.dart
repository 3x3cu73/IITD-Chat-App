import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:async'; // For TimeoutException

// Correct import based on your project structure
import 'components/chat_message.dart';

// --- Function Declaration for Gemini ---
final submitIssueFunction = FunctionDeclaration(
  'submit_hostel_issue_report',
  'Submits the collected hostel issue details to the backend API AFTER confirming all details with the user. This function should only be called when all required textual information has been gathered and the user has confirmed readiness to submit.',
  Schema(SchemaType.object,
    properties: {
      'hostel_name': Schema(SchemaType.string, description: 'Name of the hostel building.'),
      'student_name': Schema(SchemaType.string, description: 'Full name of the student reporting.'),
      'time': Schema(SchemaType.string, description: 'Timestamp of report (e.g., "YYYY-MM-DD HH:MM AM/PM" or description like "Just now").'),
      'place': Schema(SchemaType.string, description: 'Specific location of the issue (e.g., "Room C-215 Washroom", "Corridor 2nd Floor near stairs").'),
      'room_no': Schema(SchemaType.string, description: 'Student\'s room number.'),
      'entry_no': Schema(SchemaType.string, description: 'Student\'s entry/ID number.'),
      'issue_title': Schema(SchemaType.string, description: 'Brief title summarizing the issue (e.g., "Leaking Pipe", "Broken Chair", "No Hot Water").'),
      'issue_faced': Schema(SchemaType.string, description: 'Detailed description of the problem the user is facing.'),
      'issue_images_base64': Schema(SchemaType.array,
          description: 'Placeholder for Base64 images. The app handles actual image data. Confirm with user if they *uploaded* images.',
          items: Schema(SchemaType.string)), // Gemini doesn't need the actual base64 here
      'severity': Schema(SchemaType.string, description: 'Severity level (e.g., Low, Medium, High, Critical).'),
    },
    // Rely on the system prompt and fallback validation for required fields
  ),
);

// Tool definition for the model
final apiTool = Tool(functionDeclarations: [submitIssueFunction]);

// --- Chat App Widget ---
class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  ChatAppState createState() => ChatAppState();
}

class ChatAppState extends State<ChatApp> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // Stores image bytes collected *before* submission
  final List<Uint8List> collectedImagesForReport = [];
  // Stores chat history: [String message, bool isUser, bool isInfo, Uint8List? imageBytesForDisplay]
  final List<List<dynamic>> _messages = [];

  // --- API Key ---
  // WARNING: Hardcoding API keys is insecure for production apps.
  // Consider using environment variables or other secure methods.
  final apiKey = "AIzaSyAypqvoB15Z7vK_fhSwLWMDytHUo4Zf3us"; // Your provided API key

  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // *** Define the System Prompt String ***
    const systemPrompt = """
You are a friendly and helpful chatbot assistant designed by Aditya Rai. Your primary purpose is to help hostel residents report issues they are facing in their hostel (like broken furniture, leaks, electrical problems, etc.). Don't ask similar questions again and again and try to extract information from previous message and ask only if related information not provided earlier .

Your tasks are:
1.  **Greet and Inquire:** Start by greeting the user and asking them to describe the issue.
2.  **Gather Information:** Politely ask the user for **ALL** of the following necessary details about the issue. You **MUST** collect every one of these before proceeding. Ask one or two questions at a time for a better user experience.
    *   Hostel Name (e.g., Mandakini Hostel, Ganga Hostel)
    *   Student's Full Name
    *   Student's Room Number (e.g., C-215, A-101)
    *   Student's Entry Number (ID number, e.g., 2023CSB1001)
    *   Specific Place/Location of the issue (e.g., "Washroom sink", "Corridor near room 310", "Common Room TV")
    *   A short Title for the issue (e.g., "Leaking Pipe", "Broken Chair", "WiFi Down")
    *   A detailed Description of the issue faced (What is happening? Since when?)
    *   The Severity (ask the user to rate it: Low, Medium, High, or Critical)
    *   Approximate Time the issue was noticed or reported (e.g., "around 10 AM today", "last night", "just now"). You can ask if using the current time is okay.
3.  **Handle Images:** After gathering some initial details, ask the user if they have photos of the issue. Instruct them to UPLOAD images using the app's camera/gallery buttons. After they seem done with text input, explicitly ask: "Have you finished uploading any images related to this issue?". You do not process image data directly, just confirm if they *used the upload buttons*.
4.  **Confirm Details:** Once you are certain you have gathered **ALL** the required text information listed in step 2, and the user has indicated they are done uploading images (if any), **summarize ALL the collected details** back to the user clearly (use bullet points or a list). Ask for confirmation: "Okay, just to confirm, here are the details I have:\n\n[Summarize ALL details here]\n\nIs this correct and are you ready for me to submit the report?".
5.  **Trigger Submission:** **ONLY AFTER** you have collected **ALL** the required details from step 2 AND the user explicitly confirms the summarized details are correct by saying "yes", "correct", "submit", or similar affirmative response, you **MUST** call the `submit_hostel_issue_report` function. Pass all the collected text details as arguments. Do not call the function before collecting *everything* and getting explicit confirmation. If the user says "no" or points out an error, ask them to provide the correct information.
6.  **Be Conversational:** Ask questions clearly and politely. Be patient. If the user provides multiple pieces of information at once, acknowledge them. Keep track of what information you still need.

**CRITICAL REMINDER:** You absolutely **MUST** collect **ALL NINE** text fields listed in step 2 and get user confirmation on the summary before calling the `submit_hostel_issue_report` function. Do not submit if any information is missing or unconfirmed.
""";

    // *** Initialize the Model with System Instructions ***
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Using the specified model
      apiKey: apiKey, // Use the defined apiKey variable
      generationConfig: GenerationConfig(temperature: 0.7), // Adjust creativity
      tools: [apiTool],
      // Provide system instructions here (Correct way for newer SDKs)
      systemInstruction: Content.system(systemPrompt),
    );

    // *** Start the chat session with empty history (system prompt is handled above) ***
    _chat = _model.startChat(history: []);

    // Add the initial greeting message to the UI
    _addMessage(
        "Hi! I'm here to help you report hostel issues. Please describe the problem you're facing. You can also use the buttons below to add photos.",
        false, // isUser = false
        false, // isInfo = false (normal bot message)
        null   // imageBytes = null
    );
  }

  // --- Core Methods ---

  // Adds a message to the UI list and scrolls down
  void _addMessage(String text, bool isUser, bool isInfo, Uint8List? imageBytes) {
    // Format: [String message, bool isUser, bool isInfo, Uint8List? imageBytesForDisplay]
    final messageData = [text, isUser, isInfo, imageBytes];
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _messages.add(messageData);
      });
      // Scroll to bottom after adding message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      debugPrint("Warning: _addMessage called when widget not mounted.");
    }
  }

  // Handles picking an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading) return; // Prevent picking while processing
    try {
      final pickedImage = await ImagePicker().pickImage(source: source, imageQuality: 80); // Added quality setting
      if (pickedImage != null) {
        final imageBytes = await pickedImage.readAsBytes();
        if (mounted) {
          setState(() {
            collectedImagesForReport.add(imageBytes);
            // Add a visual confirmation/preview in the chat (as an info message)
            _addMessage("Image added to report.", true, true, imageBytes); // Show image in bubble
          });
          // Optionally add a message from the bot confirming receipt (or let user continue typing)
          // _addMessage("Image attached. You can add more or continue describing the issue.", false, true, null);
        }
      }
    } catch (e) {
      debugPrint("Image picking error: $e");
      if (mounted) {
        _addMessage("Error picking image: ${e.toString()}", false, true, null); // Show error to user
      }
    }
  }

  // Sends user text message to Gemini and handles the response
  Future<void> _sendMessage() async {
    final messageText = _textController.text.trim();
    if (messageText.isEmpty || _isLoading) return;

    // Add user message immediately to UI
    _addMessage(messageText, true, false, null);
    _textController.clear();
    if (mounted) setState(() { _isLoading = true; });

    try {
      // Send message to the chat session
      final response = await _chat.sendMessage(Content.text(messageText));

      // Check for function calls first
      final functionCalls = response.functionCalls;
      if (functionCalls.isNotEmpty) {
        // We expect only one function call in this scenario
        final functionCall = functionCalls.first;
        if (functionCall.name == 'submit_hostel_issue_report') {
          await _handleApiSubmission(functionCall);
        } else {
          // Handle unexpected function calls if necessary
          _addMessage("Received an unexpected instruction: ${functionCall.name}. Please continue describing the issue.", false, true, null);
          if (mounted) setState(() { _isLoading = false; });
        }
      }
      // Check for text response if no function call
      else if (response.text != null) {
        // Add bot's text response to UI
        _addMessage(response.text!, false, false, null);
        if (mounted) setState(() { _isLoading = false; });
      }
      // Handle cases where response might be blocked or empty but not an error
      else {
        _addMessage("Hmm, I didn't get a clear response. Could you please try rephrasing?", false, true, null);
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      debugPrint("Error sending message to Gemini: $e");
      if (mounted) {
        // Provide a more user-friendly error message
        String errorMessage = "Sorry, I encountered an error communicating. Please try again.";
        if (e is GenerativeAIException) {
          errorMessage = "Sorry, there was an issue: ${e.message}. Please check the details or try again.";
        }
        _addMessage(errorMessage, false, true, null);
        setState(() { _isLoading = false; });
      }
    }
  }

  // Handles the process when Gemini triggers the 'submit_hostel_issue_report' function
  Future<void> _handleApiSubmission(FunctionCall functionCall) async {
    // Ensure loading state is set (might already be true from _sendMessage)
    if (!_isLoading && mounted) setState(() { _isLoading = true; });
    _addMessage("Okay, got the details. Preparing to submit the report...", false, true, null);

    try {
      final Map<String, dynamic> reportDataFromGemini = functionCall.args;
      debugPrint("Gemini function call arguments received: $reportDataFromGemini");

      // --- Crucial Fallback Validation in Flutter ---
      // Double-check required fields received from Gemini before calling API.
      final requiredKeys = [
        'hostel_name', 'student_name', 'time', 'place', 'room_no',
        'entry_no', 'issue_title', 'issue_faced', 'severity'
      ];
      List<String> missingKeys = [];
      for (var key in requiredKeys) {
        final value = reportDataFromGemini[key];
        if (value == null || (value is String && value.isEmpty)) {
          missingKeys.add(key);
        }
      }

      if (missingKeys.isNotEmpty) {
        // Data is missing! Inform the user and *do not* proceed.
        // Let the AI ask for the missing info again in the next turn.
        debugPrint("Submission stopped: Missing required keys from AI arguments: ${missingKeys.join(', ')}");
        final missingList = missingKeys.map((k) => k.replaceAll('_', ' ').capitalizeFirst()).join(', '); // Prettier list
        _addMessage(
            "Hold on! It looks like I'm still missing some details: **$missingList**. Could you please provide this information?",
            false, // Bot message
            false, // Not just info, it's asking for data
            null
        );
        // **Important:** We don't send a function response back to the AI here,
        // because we want it to continue the conversation to get the missing data.
        // We just stop the submission process on the client side.
        if (mounted) setState(() { _isLoading = false; }); // Allow user input again
        return; // Exit the handler
      }

      // --- If validation passes, proceed with API call ---

      // Convert collected image bytes to Base64 strings
      // Add data URI prefix if your backend expects it (FastAPI often doesn't need it)
      final List<String> imageBase64List = collectedImagesForReport
      // Example *with* data URI prefix (adjust if needed):
          .map((bytes) => "data:image/jpeg;base64,${base64Encode(bytes)}")
      // Example *without* data URI prefix:
      // .map((bytes) => base64Encode(bytes))
          .toList();

      debugPrint("Submitting report to API with ${imageBase64List.length} images.");

      // Call the actual API function (using the null-safe version)
      final apiResult = await _submitHostelIssueReportApi(
        reportDataFromGemini: reportDataFromGemini,
        uploadedImageBase64List: imageBase64List,
      );

      // --- Prepare and send the response back to the Gemini model ---
      final responseToModel = Content.functionResponse(
        functionCall.name,
        // Provide the structured result (or error) from the API call
        apiResult ?? {'error': 'API call failed unexpectedly.', 'message': 'Could not reach the submission server.'},
      );

      // Send the API result back to Gemini
      final finalAiResponse = await _chat.sendMessage(responseToModel);

      // Display the final confirmation/status message from the AI
      if (finalAiResponse.text != null) {
        _addMessage(finalAiResponse.text!, false, false, null);
      } else {
        // Fallback message if AI doesn't provide text after function call
        _addMessage(apiResult?['message'] ?? "Report submission processed. The AI didn't provide a final status.", false, true, null);
      }

      // Clear collected images ONLY if the API submission seems successful
      // Check for specific success indicators from your API response
      if (apiResult != null && (apiResult['report_id'] != null || (apiResult['message']?.toLowerCase().contains('success') ?? false)) ) {
        if (mounted) {
          setState(() {
            collectedImagesForReport.clear();
            debugPrint("Collected images cleared after successful submission.");
          });
        }
      } else {
        // Keep images if submission failed, so user doesn't have to re-upload
        debugPrint("Submission likely failed, keeping collected images.");
      }

    } catch (e, s) { // Catch potential errors during the process
      debugPrint("Error during _handleApiSubmission: $e\nStackTrace: $s");
      _addMessage("An error occurred while processing the submission: ${e.toString()}", false, true, null);
      // Optionally, send an error response back to the model if appropriate
      // final errorResponse = Content.functionResponse(functionCall.name, {'error': e.toString(), 'message': 'An internal error occurred.'});
      // await _chat.sendMessage(errorResponse);
    } finally {
      if (mounted) setState(() { _isLoading = false; }); // Ensure loading indicator stops
    }
  }

  // Makes the HTTP POST request to the backend API (Matching curl, Null-Safe)
  Future<Map<String, dynamic>?> _submitHostelIssueReportApi({
    required Map<String, dynamic> reportDataFromGemini,
    required List<String> uploadedImageBase64List,
  }) async {
    // 1. URL
    final url = Uri.parse('https://vps.sumitsaw.tech/api/bhm/add');

    // 2. Headers (Matching curl)
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json', // UTF-8 is default for http package
    };

    // 3. Body (Matching curl -d structure)
    Map<String, dynamic> requestBody = Map.from(reportDataFromGemini);
    requestBody['issue_images_base64'] = uploadedImageBase64List; // Add images list
    final String encodedBody = jsonEncode(requestBody);

    debugPrint('--- Calling API ---');
    debugPrint('URL: $url');
    debugPrint('Headers: $headers');
    debugPrint('Encoded Body: $encodedBody'); // Log full body for debugging

    try {
      // 4. Make the POST request
      final response = await http.post(url, headers: headers, body: encodedBody)
          .timeout(const Duration(seconds: 45)); // Increased timeout

      debugPrint('API Status Code: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      Map<String, dynamic>? responseBody; // Still nullable initially

      // Try to decode the response body
      try {
        if (response.body.isNotEmpty) {
          responseBody = jsonDecode(response.body);
        } else {
          responseBody = {}; // Initialize as empty map if body is empty
        }
      } catch (decodeError) {
        debugPrint('Failed to decode API JSON response: $decodeError');
        return { // Return immediately with error info
          'error': 'JSON Decode Error',
          'status_code': response.statusCode,
          'message': 'Received an invalid response format from the server.',
          'raw_body': response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body
        };
      }

      // Process the responseBody (guaranteed non-null map if we reach here)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('API Success (Status Code: ${response.statusCode})');
        responseBody ??= {}; // Should not be needed here, but safe
        responseBody['status_code'] = response.statusCode;
        responseBody['message'] = responseBody['message'] ??
            (response.statusCode == 204 ? "Report submitted successfully (No content)." : "Report submitted successfully.");
        return responseBody;
      } else {
        debugPrint('API Error Response (Status Code: ${response.statusCode})');
        responseBody ??= {}; // Should not be needed here, but safe
        responseBody['status_code'] = response.statusCode;
        responseBody['error'] = responseBody['error'] ?? responseBody['detail'] ?? 'API Error';
        responseBody['message'] = responseBody['message'] ?? responseBody['detail'] ?? 'Failed to submit report due to a server error (Code: ${response.statusCode}).';
        return responseBody;
      }

    } on TimeoutException catch (e) {
      debugPrint('API Timeout Exception: $e');
      return {'error': 'Network Timeout', 'status_code': 408, 'message': 'The request to the server timed out. Please try again.'};
    } on http.ClientException catch (e) {
      debugPrint('API ClientException: $e');
      return {'error': 'Network Client Error', 'status_code': 503, 'message': 'Could not connect to the server. Please check your network connection.', 'detail': e.message};
    } catch (e, s) {
      debugPrint('API General Exception: $e\nStackTrace: $s');
      return {'error': 'Network Exception', 'status_code': 500, 'message': 'An unexpected network error occurred.', 'detail': e.toString()};
    }
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // No need to pre-calculate theme color here anymore

    return Scaffold(
      resizeToAvoidBottomInset: true, // Handles keyboard overlap
      appBar: AppBar(
        title: const Text("Hostel Issue Reporter"),
        // Using theme settings now for AppBar style defined in main()
      ),
      body: Column(
        children: [
          // Chat Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              itemBuilder: (context, index) {
                // Extract data safely with type checks
                final messageData = _messages[index];
                final text = messageData[0] is String ? messageData[0] as String : '';
                final isUser = messageData[1] is bool ? messageData[1] as bool : false;
                final isInfo = messageData[2] is bool ? messageData[2] as bool : false;
                final imageBytes = messageData.length > 3 && messageData[3] is Uint8List? ? messageData[3] as Uint8List? : null;

                // Use your custom MessageBubble component
                return MessageBubble(
                  key: ValueKey(index), // Add key for better list performance
                  message: text,
                  isUserMessage: isUser,
                  info: isInfo,
                  chatImageBytes: imageBytes,
                );
              },
            ),
          ),

          // Loading Indicator (shown below messages)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                backgroundColor: Colors.teal,
                minHeight: 3, // Make it slightly thicker
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Adapts to light/dark theme
                boxShadow: [ BoxShadow(offset: const Offset(0,-1), blurRadius: 3.0, color: Colors.black.withOpacity(0.1)) ]
            ),
            child: SafeArea( // Ensures padding for notches, etc., on bottom
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                children: [
                  // Camera Button - Color is inherited from theme
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    tooltip: 'Take Photo',
                  ),
                  // Gallery Button - Color is inherited from theme
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    tooltip: 'Pick from Gallery',
                  ),
                  // Text Input Field
                  Expanded(
                    child: ConstrainedBox( // Limit height growth
                      constraints: const BoxConstraints(maxHeight: 120), // Max height before scrolling
                      child: TextField(
                        controller: _textController,
                        enabled: !_isLoading,
                        decoration: const InputDecoration( // Uses theme input decoration
                          hintText: "Describe the issue...",
                          // Border, fill color, padding etc defined in theme
                        ),
                        onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 5, // Allow multi-line input up to 5 lines
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  // Send Button - Let theme handle color unless loading
                  IconButton(
                    icon: const Icon(Icons.send), // Icon itself doesn't need color here
                    // Override color ONLY when loading.
                    // If color is null, IconButton uses its default/theme color.
                    color: _isLoading ? Colors.grey : null,
                    onPressed: _isLoading ? null : _sendMessage,
                    tooltip: 'Send Message',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// --- Helper Extension ---
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


// --- Main Function ---
void main() {
  // Ensure Flutter bindings are initialized (good practice)
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      title: 'Hostel Issue Reporter',
      theme: ThemeData( // Define a light theme
        brightness: Brightness.light,
        primaryColor: Colors.teal,
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.teal,
            brightness: Brightness.light // Explicitly set brightness
        ).copyWith(
          secondary: Colors.tealAccent, // Accent color
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity, // Adapt density
        scaffoldBackgroundColor: Colors.white, // Background for scaffold
        appBarTheme: const AppBarTheme( // Consistent AppBar style
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 4.0,
            iconTheme: IconThemeData(color: Colors.white), // Icons in AppBar
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)
        ),
        // Define input decoration theme globally for consistency
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            hintStyle: TextStyle(color: Colors.grey[600])
        ),
        // Define button themes if needed
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(foregroundColor: Colors.teal[700]) // Default Icon color for IconButtons
        ),
        // Define text themes for bubbles, etc.
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 15.0, height: 1.4), // Default text style
          // Add other styles as needed
        ),
      ),
      // Optional: Define a basic dark theme
      // darkTheme: ThemeData(
      //     brightness: Brightness.dark,
      //     primaryColor: Colors.teal[700],
      //     colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal, brightness: Brightness.dark).copyWith(secondary: Colors.tealAccent[100]),
      //     visualDensity: VisualDensity.adaptivePlatformDensity,
      //     // ... define dark theme input decoration, AppBarTheme, etc. if needed
      // ),
      // themeMode: ThemeMode.system, // Use system theme setting (light/dark)
      home: const ChatApp() // Start with the ChatApp widget
  ));
}