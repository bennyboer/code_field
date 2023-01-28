import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class TextFieldLayout {
  /// Key that uniquely identifies a [TextField] widget.
  final GlobalKey textFieldKey;

  late RenderEditable _renderEditable;

  TextFieldLayout(this.textFieldKey) {
    final RenderObject object =
        textFieldKey.currentContext!.findRenderObject()!;
    _renderEditable = _getRenderEditable(object)!;
  }

  double lineHeight() => _renderEditable.preferredLineHeight;

  double lineOffset(int offset) {
    final selection = _renderEditable.getLineAtOffset(
      TextPosition(offset: offset),
    );
    final lineBounds = _renderEditable.getBoxesForSelection(selection).first;

    return lineBounds.bottom;
  }

  RenderEditable? _getRenderEditable(RenderObject object) {
    if (object is RenderEditable) {
      return object;
    }

    RenderEditable? editable;
    object.visitChildren((child) {
      var renderEditable = _getRenderEditable(child);
      if (renderEditable != null) {
        editable = renderEditable;
        return;
      }
    });

    return editable;
  }
}
