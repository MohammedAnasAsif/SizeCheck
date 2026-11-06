import 'measure.dart';
import 'models.dart';

enum ChartUnit { cm, inches }

class ParsedChart {
  const ParsedChart({
    required this.sizes,
    required this.unit,
    required this.unitWasGuessed,
    required this.warnings,
  });

  /// Sizes with values converted to cm.
  final List<SizeRow> sizes;
  final ChartUnit unit;

  /// True when the text did not say cm or inches and the unit was inferred
  /// from the numbers. The app should ask the person to confirm.
  final bool unitWasGuessed;
  final List<String> warnings;

  Set<Measure> get measures => {for (final s in sizes) ...s.ranges.keys};
}

class ChartParseException implements Exception {
  ChartParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads a size chart that a person copied from a shop's website.
///
/// Handles both layouts shops use:
///
///     Size  Chest   Waist        Size   S      M      L
///     S     86-91   71-76        Chest  86-91  91-96  96-101
///     M     91-96   76-81        Waist  71-76  76-81  81-86
///
/// Cells can be separated by tabs, "|", commas or two or more spaces.
/// Ranges can be written 86-91, 86 – 91 or 86 to 91.
class ChartParser {
  const ChartParser._();

  static final _keywords = <RegExp, Measure>{
    RegExp(r'chest|bust'): Measure.chest,
    RegExp(r'waist'): Measure.waist,
    RegExp(r'\bhips?\b|\bseat\b'): Measure.hip,
    RegExp(r'shoulder'): Measure.shoulder,
    RegExp(r'neck|collar'): Measure.neck,
    RegExp(r'sleeve'): Measure.sleeve,
    RegExp(r'inseam|inside leg|inner leg|leg length'): Measure.inseam,
    RegExp(r'height'): Measure.height,
    RegExp(r'foot|feet|insole'): Measure.foot,
  };

  static const _phrases = {
    r'\bto fit\s+': '',
    r'\b(inside|inner) leg( length)?\b': 'Inseam',
    r'\bleg length\b': 'Inseam',
    r'\bbrand size\b': 'Size',
    r'\bfoot length\b': 'Foot',
    r'\bsleeve length\b': 'Sleeve',
    r'\b(across )?shoulders?( width)?\b': 'Shoulder',
    r'\bneck size\b': 'Neck',
    r'\bcollar size\b': 'Collar',
  };

  static final _sizeWord =RegExp(r'^\s*(size|sizes|brand size|label)\b');
  static final _number = RegExp(r'\d+(?:\.\d+)?');

  static Measure? _measureFor(String cell) {
    final c = cell.toLowerCase();
    if (c.contains('length') &&
        !c.contains('leg') &&
        !c.contains('foot') &&
        !c.contains('sleeve')) {
      // "Length" alone is garment length, which SizeCheck does not use.
      return null;
    }
    for (final e in _keywords.entries) {
      if (e.key.hasMatch(c)) return e.value;
    }
    return null;
  }

  static List<String> _cells(String line) {
    var l = line.replaceAll(RegExp(r'\s*[–—]\s*'), '-');
    // Drop unit notes like "(cm)" and join two-word measurement names, so a
    // header separated by single spaces still splits into the right cells.
    l = l.replaceAll(
        RegExp(r'\s*\((?:cm|cms|in|inch|inches)\)', caseSensitive: false), '');
    for (final e in _phrases.entries) {
      l = l.replaceAll(RegExp(e.key, caseSensitive: false), e.value);
    }
    l = l.replaceAllMapped(RegExp(r'(\d)\s*-\s*(\d)'), (m) => '${m[1]}-${m[2]}');
    l = l.replaceAllMapped(RegExp(r'(\d)\s+to\s+(\d)', caseSensitive: false),
        (m) => '${m[1]}-${m[2]}');
    List<String> parts;
    if (l.contains('\t')) {
      parts = l.split('\t');
    } else if (l.contains('|')) {
      parts = l.split('|');
    } else if (RegExp(r'\S\s{2,}\S').hasMatch(l)) {
      parts = l.split(RegExp(r'\s{2,}'));
    } else if (l.contains(',') && !RegExp(r'\d,\d').hasMatch(l)) {
      parts = l.split(',');
    } else {
      parts = l.split(RegExp(r'\s+'));
    }
    return [
      for (final p in parts)
        if (p.trim().isNotEmpty) p.trim(),
    ];
  }

  /// Parses "86-91", "86", "34.5" into a range in the source unit.
  static Range? _value(String cell) {
    final nums = _number
        .allMatches(cell.replaceAll(',', '.'))
        .map((m) => double.parse(m[0]!))
        .toList();
    if (nums.isEmpty) return null;
    if (nums.length >= 2 && cell.contains('-')) {
      final a = nums[0], b = nums[1];
      return a <= b ? Range(a, b) : Range(b, a);
    }
    return Range.point(nums.first);
  }

  static ChartUnit? _statedUnit(String text) {
    final t = text.toLowerCase();
    final cm = RegExp(r'\bcms?\b|centimet').hasMatch(t);
    final inch = RegExp(r'\binch(es)?\b|\bins?\b|"').hasMatch(t);
    if (cm && !inch) return ChartUnit.cm;
    if (inch && !cm) return ChartUnit.inches;
    return null;
  }

  static ParsedChart parse(String text) {
    final lines = [
      for (final l in text.split(RegExp(r'\r?\n')))
        if (l.trim().isNotEmpty) _cells(l),
    ].where((cells) => cells.isNotEmpty).toList();
    if (lines.length < 2) {
      throw ChartParseException(
          'Paste the whole size chart, including the header row.');
    }

    // Layout A: a header row naming the measurements.
    int headerIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      final found = lines[i].where((c) => _measureFor(c) != null).length;
      if (found >= 1 && lines[i].length >= 2 && _measureFor(lines[i].first) == null) {
        headerIndex = i;
        break;
      }
    }

    // Layout B: measurements down the first column.
    final rowsWithMeasure = [
      for (var i = 0; i < lines.length; i++)
        if (_measureFor(lines[i].first) != null) i,
    ];

    final rawRows = <String, Map<Measure, Range>>{};
    final order = <String>[];
    final warnings = <String>[];

    if (rowsWithMeasure.isNotEmpty &&
        (headerIndex < 0 || rowsWithMeasure.length >= 2)) {
      // Find the row of size labels: the "Size" row, or the row before the
      // first measurement row.
      var labelIndex = lines.indexWhere((l) => _sizeWord.hasMatch(l.first.toLowerCase()));
      if (labelIndex < 0) labelIndex = rowsWithMeasure.first - 1;
      if (labelIndex < 0) {
        throw ChartParseException('Could not find the row with the size names.');
      }
      final labelRow = lines[labelIndex];
      final labels = _sizeWord.hasMatch(labelRow.first.toLowerCase())
          ? labelRow.sublist(1)
          : labelRow;
      for (final l in labels) {
        rawRows[l] = {};
        order.add(l);
      }
      for (final i in rowsWithMeasure) {
        final m = _measureFor(lines[i].first)!;
        final values = lines[i].sublist(1);
        if (values.length != labels.length) {
          warnings.add('The ${m.label.toLowerCase()} row has ${values.length} '
              'values for ${labels.length} sizes; please check it.');
        }
        for (var k = 0; k < labels.length && k < values.length; k++) {
          final r = _value(values[k]);
          if (r != null) rawRows[labels[k]]![m] = r;
        }
      }
    } else if (headerIndex >= 0) {
      final header = lines[headerIndex];
      final columns = <int, Measure>{};
      for (var c = 0; c < header.length; c++) {
        final m = _measureFor(header[c]);
        if (m != null && !columns.containsValue(m)) columns[c] = m;
      }
      var labelCol = header.indexWhere((c) => _sizeWord.hasMatch(c.toLowerCase()));
      if (labelCol < 0) labelCol = 0;
      for (final row in lines.skip(headerIndex + 1)) {
        if (row.length <= labelCol) continue;
        final label = row[labelCol];
        if (_value(label) != null && columns.containsKey(labelCol)) continue;
        final ranges = <Measure, Range>{};
        for (final e in columns.entries) {
          if (e.key < row.length) {
            final r = _value(row[e.key]);
            if (r != null) ranges[e.value] = r;
          }
        }
        if (ranges.isEmpty) continue;
        if (!rawRows.containsKey(label)) order.add(label);
        rawRows[label] = ranges;
      }
    } else {
      throw ChartParseException(
          'Could not find measurement names like Chest, Waist or Hip. '
          'Copy the chart including its header row.');
    }

    order.removeWhere((l) => rawRows[l]!.isEmpty);
    if (order.length < 2) {
      throw ChartParseException('Found fewer than two sizes with numbers.');
    }

    final stated = _statedUnit(text);
    final unit = stated ?? _guessUnit(rawRows.values);
    final factor = unit == ChartUnit.inches ? cmPerInch : 1.0;
    final sizes = [
      for (final l in order)
        SizeRow(
          label: l,
          ranges: {
            for (final e in rawRows[l]!.entries)
              e.key: Range(round1(e.value.min * factor), round1(e.value.max * factor)),
          },
        ),
    ];
    return ParsedChart(
      sizes: sizes,
      unit: unit,
      unitWasGuessed: stated == null,
      warnings: warnings,
    );
  }

  /// Body girths in cm are rarely under 60; in inches they rarely exceed 60.
  static ChartUnit _guessUnit(Iterable<Map<Measure, Range>> rows) {
    final girths = <double>[];
    final feet = <double>[];
    for (final r in rows) {
      for (final e in r.entries) {
        if (e.key == Measure.chest || e.key == Measure.waist || e.key == Measure.hip) {
          girths.add(e.value.center);
        }
        if (e.key == Measure.foot) feet.add(e.value.center);
      }
    }
    if (girths.isNotEmpty) {
      girths.sort();
      return girths[girths.length ~/ 2] < 60 ? ChartUnit.inches : ChartUnit.cm;
    }
    if (feet.isNotEmpty) {
      feet.sort();
      return feet[feet.length ~/ 2] < 15 ? ChartUnit.inches : ChartUnit.cm;
    }
    return ChartUnit.cm;
  }
}
