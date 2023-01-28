import 'package:flutter/widgets.dart';

@immutable
class LineRange {
  /// Line index of the end of the line range (inclusive).
  final int start;

  /// Line index of the end of the line range (exclusive).
  final int end;

  LineRange({
    this.start = 0,
    this.end = 1,
  });

  int count() {
    return end - start;
  }

  @override
  String toString() {
    return 'LineRange[$start; $end[';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
