import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:image_picker/image_picker.dart';
import 'components/chat_message.dart';

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  ChatAppState createState() => ChatAppState();


}

class ChatAppState extends State<ChatApp> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool isImage = false;
  Uint8List? chatImageBytes;
  // imageBytes
  // Uint8List? chatImageBytes;
  List<Content> contents = [];
  // chatImageBytes List<dynamic>=[];
  final List<List<dynamic>> _messages = [];
  // final List<Instruction> _instructions = [];
  final apiKey =
      "AIzaSyAypqvoB15Z7vK_fhSwLWMDytHUo4Zf3us"; // Replace with your actual API key
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isLoading = false;

  get text => null;
  scroll(){
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }
  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model:
          'gemini-2.0-flash', // Using gemini-pro for more general chatting. Change to flash if needed.
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 2048,
        //Adjust to your needs.
      ),
    );

    final domainOfChat=Content.text("You are chat bot for IITD students. Designed by Sumit Kumar Saw as a project to show during Interview process of OCS IIT Delhi for post of Tech Executive . ");
    _chat = _model.startChat(history: [domainOfChat]);

    _messages.add(["Chat App fined tuned to Answer any query of student.", false, true]);
    scroll();
  }

  //Image Picker
  Future _pickImage() async {
    var imagePicked = await ImagePicker().pickImage(
      source: ImageSource.gallery);
    // imagePicked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (imagePicked != null) {
      // _textController.text=base64Encode(imageBytes);
      // return base64Encode(imageBytes);

      isImage = true;
      chatImageBytes = await imagePicked.readAsBytes();
      setState(() {

        // _messages.add([messageText, true, false]);
        _messages.add(["Got an Image. Last uploaded Image will be considered in each message.", false, true]);
        _isLoading = true;
        scroll();
      });
    } else {
      return null;
    }
  }



  Future _pickImageCamera() async {
    var imagePicked = await ImagePicker().pickImage(
        source: ImageSource.camera);
    // imagePicked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (imagePicked != null) {
      // _textController.text=base64Encode(imageBytes);
      // return base64Encode(imageBytes);

      isImage = true;
      chatImageBytes = await imagePicked.readAsBytes();
      setState(() {

        // _messages.add([messageText, true, false]);
        _messages.add(["Got an Image. Last uploaded Image will be considered in each message.", false, true]);
        _isLoading = true;
        scroll();
      });
    } else {
      return null;
    }
  }





  //  Sending Message
  final bool initialMessage = true;

  // Iterable<Part> get parts => null;
  Future<void> _sendMessage() async {
    final messageText = _textController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      // _messages.add(ChatMessage(text: messageText, isUser: true));
      _messages.add([messageText, true, false]);
      _isLoading = true;
      scroll();

    });

    _textController.clear();

    try {
      // final img=Content.data(mimeType, bytes);
      if (isImage) {
        // final imgRef = await _chat.sendMessage(Content.data('image/png', chatImageBytes!));
        final imgRef = await _chat.sendMessage(
          Content.multi([
            DataPart('image/png', chatImageBytes!),
            TextPart(messageText),
          ]),
        );

        setState(() {
          // _messages.add([messageText, true, false]);
          _messages.add([imgRef.text!, false, false]);
          _isLoading = false;
          scroll();
        });
        isImage = false;
      } else {
        final response = await _chat.sendMessage(Content.text(messageText));
        if (response.text != null) {
          setState(() {
            // _messages.add(ChatMessage(text: response.text!, isUser: false));
            _messages.add([response.text!, false, false]);
            scroll();
            _isLoading = false;
          });
        } else {
          setState(() {
            _messages.add(["No Response", false, true]);
            scroll();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(["Error: $e", false, true]);
        scroll();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text("IITD Chat App")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                // return ChatMessage(text: _messages[index][0], isUser: _messages[index][1]);
                return MessageBubble(
                  message: _messages[index][0],
                  isUserMessage: _messages[index][1],
                  info: _messages[index][2],
                );
              },
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[200]!),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 24),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.camera),
                  onPressed: _pickImageCamera,
                ),
                Expanded(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        side: BorderSide(
                          color: Colors.blue[200]!,
                          width: 1,
                        ), // Set corner radius
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, 2, 10, 2),
                      child: TextFormField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: "Ask anything ....",
                          border: InputBorder.none,
                        ),
                        onFieldSubmitted: (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 5, // Limit to 5 lines
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: ChatApp()));
}
