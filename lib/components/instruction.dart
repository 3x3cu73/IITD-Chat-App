import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class Instruction extends StatelessWidget {
  final String text;

  const Instruction({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Markdown(
        data: text,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
      ),
    );
  }
}