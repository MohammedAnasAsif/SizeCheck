import 'dart:convert';

import 'measure.dart';
import 'models.dart';

/// How the person likes clothes to fit.
enum FitPreference {
  slim,
  regular,
  relaxed;

  static FitPreference fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return FitPreference.regular;
  }
}

enum FitOutcome {
  tooSmall,
  tight,
  good,
  loose,
  tooBig;

  static FitOutcome fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return FitOutcome.good;
  }

  String get label => switch (this) {
        FitOutcome.tooSmall => 'Too small',
        FitOutcome.tight => 'A bit tight',
        FitOutcome.good => 'Fits well',
        FitOutcome.loose => 'A bit loose',
        FitOutcome.tooBig => 'Too big',
      };

  /// cm added to the person's effective measurement next time.
  double get adjustment => switch (this) {
        FitOutcome.tooSmall => 3.0,
        FitOutcome.tight => 1.5,
        FitOutcome.good => 0.0,
        FitOutcome.loose => -1.5,
        FitOutcome.tooBig => -3.0,
      };
}

/// What the person bought and how it fit.
class FitFeedback {
  const FitFeedback({
    required this.brandId,
    required this.brandName,
    required this.category,
    required this.sizeLabel,
    required this.outcome,
    required this.date,
  });

  final String brandId;
  final String brandName;
  final Category category;
  final String sizeLabel;
  final FitOutcome outcome;
  final DateTime date;

  static FitFeedback? fromJson(Map<String, dynamic> json) {
    final category = Category.fromId(json['category'] as String? ?? '');
    if (category == null) return null;
    return FitFeedback(
      brandId: json['brand'] as String,
      brandName: json['brand_name'] as String? ?? json['brand'] as String,
      category: category,
      sizeLabel: json['size'] as String,
      outcome: FitOutcome.fromName(json['outcome'] as String?),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(2026),
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brandId,
        'brand_name': brandName,
        'category': category.id,
        'size': sizeLabel,
        'outcome': outcome.name,
        'date': date.toIso8601String(),
      };
}

/// One person's body measurements and fit history. Values are in cm.
class BodyProfile {
  BodyProfile({
    required this.id,
    required this.name,
    this.audience = Audience.unisex,
    Map<Measure, double>? measurements,
    Set<Measure>? estimated,
    this.fitPreference = FitPreference.regular,
    Map<String, double>? brandOffsets,
    List<FitFeedback>? history,
  })  : measurements = measurements ?? {},
        estimated = estimated ?? {},
        brandOffsets = brandOffsets ?? {},
        history = history ?? [];

  final String id;
  String name;

  /// Which clothing sections to show first. Unisex shows everything.
  Audience audience;
  final Map<Measure, double> measurements;

  /// Measurements guessed from a known size rather than measured.
  final Set<Measure> estimated;
  FitPreference fitPreference;

  /// Learned per brand and category group, in cm. Key: "brandId|group".
  final Map<String, double> brandOffsets;
  final List<FitFeedback> history;

  static const double maxOffset = 6.0;

  static String offsetKey(String brandId, Category category) =>
      '$brandId|${category.group.name}';

  double offsetFor(String brandId, Category category) =>
      brandOffsets[offsetKey(brandId, category)] ?? 0.0;

  bool get hasAnyMeasurement => measurements.isNotEmpty;

  void setMeasurement(Measure m, double? cm, {bool isEstimate = false}) {
    if (cm == null || cm <= 0) {
      measurements.remove(m);
      estimated.remove(m);
      return;
    }
    measurements[m] = cm;
    if (isEstimate) {
      estimated.add(m);
    } else {
      estimated.remove(m);
    }
  }

  /// Records how a purchase fit and learns from it for next time.
  ///
  /// [recommendedLabel] is what SizeCheck suggested for this brand and
  /// category at the time, if known. The learned offset only moves when the
  /// size bought is the one SizeCheck would pick, or when the person reports
  /// a clear misfit; buying a deliberately different size and finding it
  /// "a bit loose" says nothing new about this person.
  void addFeedback(FitFeedback feedback, {String? recommendedLabel}) {
    history.insert(0, feedback);
    final key = offsetKey(feedback.brandId, feedback.category);
    final current = brandOffsets[key] ?? 0.0;
    final boughtRecommended = recommendedLabel == null ||
        recommendedLabel.toUpperCase() == feedback.sizeLabel.toUpperCase();
    final strong = feedback.outcome == FitOutcome.tooSmall ||
        feedback.outcome == FitOutcome.tooBig;
    double next = current;
    if (feedback.outcome == FitOutcome.good) {
      if (boughtRecommended) next = current * 0.7;
    } else if (boughtRecommended || strong) {
      next = current + feedback.outcome.adjustment;
    }
    next = next.clamp(-maxOffset, maxOffset).toDouble();
    if (next.abs() < 0.2) {
      brandOffsets.remove(key);
    } else {
      brandOffsets[key] = round1(next);
    }
  }

  factory BodyProfile.fromJson(Map<String, dynamic> json) {
    final measurements = <Measure, double>{};
    final m = json['measurements'] as Map<String, dynamic>? ?? const {};
    for (final e in m.entries) {
      final key = Measure.fromKey(e.key);
      if (key != null && e.value is num) {
        measurements[key] = (e.value as num).toDouble();
      }
    }
    return BodyProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Me',
      audience: switch (json['audience']) {
        'men' => Audience.men,
        'women' => Audience.women,
        _ => Audience.unisex,
      },
      measurements: measurements,
      estimated: {
        for (final k in (json['estimated'] as List? ?? const []))
          if (Measure.fromKey(k as String) != null) Measure.fromKey(k)!,
      },
      fitPreference: FitPreference.fromName(json['fit'] as String?),
      brandOffsets: {
        for (final e
            in (json['offsets'] as Map<String, dynamic>? ?? const {}).entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      history: [
        for (final h in (json['history'] as List? ?? const []))
          FitFeedback.fromJson(h as Map<String, dynamic>),
      ].whereType<FitFeedback>().toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audience': audience.name,
        'measurements': {
          for (final e in measurements.entries) e.key.key: round1(e.value),
        },
        'estimated': [for (final m in estimated) m.key],
        'fit': fitPreference.name,
        'offsets': brandOffsets,
        'history': [for (final h in history) h.toJson()],
      };

  static const String _exportPrefix = 'SIZECHECK1:';

  /// A compact text code to copy a profile to another device.
  String toExportCode() =>
      _exportPrefix + base64Url.encode(utf8.encode(jsonEncode(toJson())));

  /// Reads a code made by [toExportCode]. Returns null if it is not valid.
  /// The imported profile gets [newId] so it never overwrites another one.
  static BodyProfile? fromExportCode(String code, {required String newId}) {
    final trimmed = code.trim();
    final start = trimmed.indexOf(_exportPrefix);
    if (start < 0) return null;
    final payload = trimmed
        .substring(start + _exportPrefix.length)
        .split(RegExp(r'\s'))
        .first;
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
          as Map<String, dynamic>;
      json['id'] = newId;
      return BodyProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
