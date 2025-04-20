import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data'; // Ensure Uint8List is recognized

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUserMessage;
  final bool info; // Flag for informational messages (e.g., errors, confirmations)
  final Uint8List? chatImageBytes; // Image to display in the bubble

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUserMessage,
    required this.info,
    this.chatImageBytes, // Make optional for display here
  });

  @override
  Widget build(BuildContext context) {
    // Determine alignment based on message type
    CrossAxisAlignment crossAxisAlignment;
    MainAxisAlignment mainAxisAlignment;
    EdgeInsets margin;
    Color backgroundColor;
    Color textColor;
    BorderRadius borderRadius;

    if (info) {
      // Centered informational message styling
      crossAxisAlignment = CrossAxisAlignment.center;
      mainAxisAlignment = MainAxisAlignment.center;
      margin = const EdgeInsets.symmetric(vertical: 6.0, horizontal: 40.0);
      backgroundColor = Colors.blueGrey.shade100;
      textColor = Colors.blueGrey.shade800;
      borderRadius = BorderRadius.circular(8.0);
    } else if (isUserMessage) {
      // User message styling (right-aligned)
      crossAxisAlignment = CrossAxisAlignment.end;
      mainAxisAlignment = MainAxisAlignment.end;
      margin = const EdgeInsets.only(top: 4, bottom: 4, left: 60, right: 8);
      backgroundColor = Colors.teal.shade300; // User message color
      textColor = Colors.white;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
        bottomLeft: Radius.circular(15),
        bottomRight: Radius.circular(0), // Pointy corner towards user side
      );
    } else {
      // Bot message styling (left-aligned)
      crossAxisAlignment = CrossAxisAlignment.start;
      mainAxisAlignment = MainAxisAlignment.start;
      margin = const EdgeInsets.only(top: 4, bottom: 4, left: 8, right: 60);
      backgroundColor = Colors.grey.shade300; // Bot message color
      textColor = Colors.black87;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
        bottomLeft: Radius.circular(0), // Pointy corner towards bot side
        bottomRight: Radius.circular(15),
      );
    }

    // Base text style
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor);

    return Row( // Use Row for alignment control
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width
          margin: margin,
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
          decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              boxShadow: [
                if (!info) // Less shadow for info messages
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2.0,
                    offset: const Offset(1, 1),
                  )
              ]
          ),
          child: Column(
            crossAxisAlignment: crossAxisAlignment, // Align content within bubble
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display image first if provided
              if (chatImageBytes != null)
                Padding(
                  padding: EdgeInsets.only(bottom: message.isNotEmpty ? 8.0 : 0), // Add padding if text follows
                  child: ClipRRect( // Clip image to rounded corners slightly less than bubble
                    borderRadius: BorderRadius.circular(borderRadius.topLeft.x > 0 ? 10.0 : 0), // Adjust based on bubble radius
                    child: Image.memory(
                      chatImageBytes!,
                      // Width constrained by parent container already
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              // Display text message using Markdown only if message is not empty
              // Use selectable text for easy copying
              if (message.isNotEmpty)
                SelectableRegion(
                  focusNode: FocusNode(), // Needed for selection
                  selectionControls: MaterialTextSelectionControls(), // Use Material controls
                  child: MarkdownBody(
                    data: message,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: textStyle, // Apply base text style
                      // You can customize other markdown elements here if needed
                      // e.g., strong: textStyle?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // selectable: true, // Selectable is handled by SelectableRegion now
                    softLineBreak: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}