import 'package:size_engine/size_engine.dart';

import '../app_state.dart';

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String unitLabel(UnitSystem u) => u == UnitSystem.cm ? 'cm' : 'in';

/// Converts cm to the display unit and formats it, e.g. "98 cm" or "38.6 in".
String fmtLength(double cm, UnitSystem u, {bool withUnit = true}) {
  final v = u == UnitSystem.cm ? cm : cmToInches(cm);
  return withUnit ? '${_trim(v)} ${unitLabel(u)}' : _trim(v);
}

String fmtRange(Range r, UnitSystem u) {
  if (r.isPoint) return fmtLength(r.min, u);
  return '${fmtLength(r.min, u, withUnit: false)}–${fmtLength(r.max, u)}';
}

/// Parses what the person typed (in the display unit) into cm.
double? parseLength(String text, UnitSystem u) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  return u == UnitSystem.cm ? v : inchesToCm(v);
}

String inputValue(double? cm, UnitSystem u) =>
    cm == null ? '' : fmtLength(cm, u, withUnit: false);
