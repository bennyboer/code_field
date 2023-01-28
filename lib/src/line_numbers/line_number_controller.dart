import 'package:flutter/widgets.dart';

import 'line_range.dart';

class LineNumberController extends TextEditingController {
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;
  List<LineRange> lineRanges = [];

  LineNumberController(
    this.lineNumberBuilder,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    List<InlineSpan> children = [];

    for (int lineIndex = 0; lineIndex < lineRanges.length; lineIndex++) {
      final lineNumber = lineIndex + 1;
      final lineRange = lineRanges[lineIndex];

      _pushLineNumberTextSpan(lineNumber, style, children);
      _pushNewlineTextSpans(lineRange, lineIndex, children);
    }

    return TextSpan(children: children, style: style);
  }

  void _pushLineNumberTextSpan(
      int lineNumber, TextStyle? style, List<InlineSpan> toPushTo) {
    TextSpan textSpan = _buildLineNumberTextSpan(lineNumber, style);
    toPushTo.add(textSpan);
  }

  TextSpan _buildLineNumberTextSpan(int lineNumber, TextStyle? style) {
    var textSpan = TextSpan(text: '$lineNumber', style: style);

    if (lineNumberBuilder != null) {
      textSpan = lineNumberBuilder!(lineNumber, style);
    }

    return textSpan;
  }

  void _pushNewlineTextSpans(
      LineRange lineRange, int lineIndex, List<InlineSpan> toPushTo) {
    int newLineCount = lineRange.count();

    final bool isLastLine = lineIndex == lineRanges.length - 1;
    if (isLastLine) {
      newLineCount -= 1;
    }

    for (int i = 0; i < newLineCount; i++) {
      toPushTo.add(_buildNewlineTextSpan());
    }
  }

  TextSpan _buildNewlineTextSpan() => const TextSpan(text: '\n');
}
