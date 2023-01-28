import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../line_numbers/line_number_controller.dart';
import '../line_numbers/line_number_style.dart';
import '../line_numbers/line_range.dart';
import 'code_controller.dart';
import 'text_field_layout.dart';

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType? smartQuotesType;

  /// {@macro flutter.widgets.textField.keyboardType}
  final TextInputType? keyboardType;

  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around or make the field scrollable horizontally
  final bool wrap;

  /// A CodeController instance to apply language highlight, themeing and modifiers
  final CodeController controller;

  /// A LineNumberStyle instance to tweak the line number column styling
  final LineNumberStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  final bool readOnly;

  /// {@macro flutter.widgets.textField.isDense}
  final bool isDense;

  /// {@macro flutter.widgets.textField.selectionControls}
  final TextSelectionControls? selectionControls;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final bool lineNumbers;
  final bool horizontalScroll;

  const CodeField({
    Key? key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    this.lineNumberStyle = const LineNumberStyle(),
    this.enabled,
    this.onTap,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.isDense = false,
    this.smartQuotesType,
    this.keyboardType,
    this.lineNumbers = true,
    this.horizontalScroll = true,
    this.selectionControls,
  }) : super(key: key);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LineNumberController? _lineNumberController;

  final GlobalKey _codeFieldKey = GlobalKey();
  final GlobalKey _lineNumberTextFieldKey = GlobalKey();

  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';

  bool _lineNumbersDirtyFlag = false;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _lineNumberController = LineNumberController(widget.lineNumberBuilder);
    widget.controller.addListener(_onTextChanged);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.onKey = _onKey;
    _focusNode!.attach(context, onKey: _onKey);

    _onTextChanged();
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (widget.readOnly) {
      return KeyEventResult.ignored;
    }

    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _lineNumberController?.dispose();
    _keyboardVisibilitySubscription?.cancel();
    super.dispose();
  }

  void rebuild() {
    setState(() {});
  }

  void _onTextChanged() {
    final lineStrings = widget.controller.text.split('\n');

    // Find longest line
    longestLine = '';
    for (var line in lineStrings) {
      if (line.length > longestLine.length) longestLine = line;
    }

    setState(() {
      if (widget.lineNumbers) {
        _markLineNumbersDirty();
      }
    });
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final leftPad = widget.lineNumberStyle.margin / 2;
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: max(minWidth - leftPad, 0),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: leftPad,
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,

      /// Prevents the horizontal scroll if horizontalScroll is false
      physics:
          widget.horizontalScroll ? null : const NeverScrollableScrollPhysics(),
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateLineNumbersAfterBuildIfNecessary();

    // Default color scheme
    const rootKey = 'root';
    final defaultBg = Colors.grey.shade900;
    final defaultText = Colors.grey.shade200;

    final styles = CodeTheme.of(context)?.styles;
    Color? backgroundCol =
        widget.background ?? styles?[rootKey]?.backgroundColor ?? defaultBg;

    if (widget.decoration != null) {
      backgroundCol = null;
    }

    TextStyle textStyle = widget.textStyle ?? const TextStyle();
    textStyle = textStyle.copyWith(
      color: textStyle.color ?? styles?[rootKey]?.color ?? defaultText,
      fontSize: textStyle.fontSize ?? 16.0,
    );

    TextStyle numberTextStyle =
        widget.lineNumberStyle.textStyle ?? const TextStyle();
    final numberColor =
        (styles?[rootKey]?.color ?? defaultText).withOpacity(0.7);

    // Copy important attributes
    numberTextStyle = numberTextStyle.copyWith(
      color: numberTextStyle.color ?? numberColor,
      fontSize: textStyle.fontSize,
      fontFamily: textStyle.fontFamily,
    );

    final cursorColor =
        widget.cursorColor ?? styles?[rootKey]?.color ?? defaultText;

    TextField? lineNumberCol;
    Container? numberCol;

    if (widget.lineNumbers) {
      lineNumberCol = TextField(
        key: _lineNumberTextFieldKey,
        smartQuotesType: widget.smartQuotesType,
        scrollPadding: widget.padding,
        style: numberTextStyle,
        controller: _lineNumberController,
        enabled: false,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        selectionControls: widget.selectionControls,
        expands: widget.expands,
        scrollController: _numberScroll,
        decoration: InputDecoration(
          disabledBorder: InputBorder.none,
          isDense: widget.isDense,
        ),
        textAlign: widget.lineNumberStyle.textAlign,
      );

      numberCol = Container(
        width: widget.lineNumberStyle.width,
        padding: EdgeInsets.only(
          left: widget.padding.left,
          right: widget.lineNumberStyle.margin / 2,
        ),
        color: widget.lineNumberStyle.background,
        child: lineNumberCol,
      );
    }

    final codeField = TextField(
      key: _codeFieldKey,
      keyboardType: widget.keyboardType,
      smartQuotesType: widget.smartQuotesType,
      focusNode: _focusNode,
      onTap: widget.onTap,
      scrollPadding: widget.padding,
      style: textStyle,
      controller: widget.controller,
      minLines: widget.minLines,
      selectionControls: widget.selectionControls,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: InputDecoration(
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: widget.isDense,
      ),
      cursorColor: cursorColor,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final codeCol = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return widget.wrap
              ? codeField
              : _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return Container(
      decoration: widget.decoration,
      color: backgroundCol,
      padding: !widget.lineNumbers ? const EdgeInsets.only(left: 8) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.lineNumbers && numberCol != null) numberCol,
          Expanded(child: codeCol),
        ],
      ),
    );
  }

  void _markLineNumbersDirty() {
    _lineNumbersDirtyFlag = true;
  }

  void _updateLineNumbersAfterBuildIfNecessary() {
    if (_lineNumbersDirtyFlag) {
      _updateLineNumbersAfterBuild();
      _lineNumbersDirtyFlag = false;
    }
  }

  void _updateLineNumbersAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateLineNumbers());
  }

  void _updateLineNumbers() {
    final TextFieldLayout textFieldLayout = TextFieldLayout(_codeFieldKey);

    final lineStrings = widget.controller.text.split('\n');
    var offset = 0;
    var currentLineIndex = 0;
    final lineHeight = textFieldLayout.lineHeight();
    List<LineRange> lineRanges = [];
    for (var lineIndex = 0; lineIndex < lineStrings.length; lineIndex++) {
      final lineString = lineStrings[lineIndex];

      var lineCount = 1;
      if (lineString.isNotEmpty) {
        final int endOffset = offset + lineString.length;
        final startY = textFieldLayout.lineOffset(offset);
        final endY = textFieldLayout.lineOffset(endOffset);

        lineCount = ((endY - startY) / lineHeight).round() + 1;
      }

      final startLineIndex = currentLineIndex;
      final endLineIndex = currentLineIndex + lineCount;
      final lineRange = LineRange(start: startLineIndex, end: endLineIndex);
      lineRanges.add(lineRange);

      currentLineIndex += lineCount;

      offset += lineString.length + 1;
    }

    bool lineRangesChanged = !listEquals(
      lineRanges,
      _lineNumberController?.lineRanges,
    );
    if (lineRangesChanged) {
      setState(() {
        _lineNumberController?.lineRanges = lineRanges;
      });
    }
  }
}
