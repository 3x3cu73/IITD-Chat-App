import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUserMessage;
  final bool info;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUserMessage,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      alignment: info ? Alignment.topCenter  : isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: info ? Colors.purple[100] : isUserMessage ? Colors.blue[100] : Colors.green[100],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: MarkdownBody(
          data: message,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
          shrinkWrap: true,
          selectable: true,
          softLineBreak: true,
        ),
      ),
    );
  }
}