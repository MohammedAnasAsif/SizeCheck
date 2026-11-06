import 'dart:math' as math;

import 'measure.dart';
import 'models.dart';
import 'profile.dart';

enum Confidence { high, medium, low }

enum FitStatus { below, within, above }

enum OutOfRange { smallerThanSmallest, largerThanLargest }

/// How one measurement compares with one size.
class MeasureFit {
  const MeasureFit({
    required this.measure,
    required this.value,
    required this.range,
    required this.penalty,
  });

  final Measure measure;

  /// The person's effective value in cm (after fit preference and learning).
  final double value;

  /// The size's range in body cm (garment charts already converted).
  final Range range;
  final double penalty;

  FitStatus get status => value < range.min
      ? FitStatus.below
      : value > range.max
          ? FitStatus.above
          : FitStatus.within;

  /// cm outside the range; 0 when inside.
  double get distance => switch (status) {
        FitStatus.below => range.min - value,
        FitStatus.above => value - range.max,
        FitStatus.within => 0,
      };
}

class SizeScore {
  const SizeScore({
    required this.size,
    required this.index,
    required this.score,
    required this.fits,
  });

  final SizeRow size;
  final int index;

  /// 0 = perfect. About 1 = one tolerance step off on the main measurement.
  final double score;
  final List<MeasureFit> fits;
}

class Recommendation {
  const Recommendation({
    required this.chart,
    required this.scores,
    required this.best,
    required this.alternative,
    required this.confidence,
    required this.missing,
    required this.outOfRange,
    required this.offsetApplied,
    required this.usedEstimates,
  });

  final SizeChart chart;

  /// Every size, in chart order.
  final List<SizeScore> scores;

  /// Null when the profile shares no measurement with the chart.
  final SizeScore? best;

  /// The neighbouring size when the person is between two sizes.
  final SizeScore? alternative;
  final Confidence confidence;

  /// Measurements this chart uses that the profile does not have, most
  /// important first. Adding them improves the result.
  final List<Measure> missing;
  final OutOfRange? outOfRange;

  /// Learned adjustment from past purchases, in cm.
  final double offsetApplied;

  /// True when some measurements used were estimated rather than measured.
  final bool usedEstimates;

  bool get hasResult => best != null;
  bool get isBetweenSizes => alternative != null;
  bool get alternativeIsLarger =>
      alternative != null && alternative!.index > best!.index;
}

class Recommender {
  const Recommender._();

  /// How much bigger a garment is than the body it fits, in cm, for a
  /// regular fit. Used to convert garment charts to body measurements.
  static double ease(CategoryGroup group, Measure m, GarmentFit? fit) {
    final base = switch ((group, m)) {
      (CategoryGroup.bottoms, Measure.waist) => 2.0,
      (CategoryGroup.bottoms, Measure.hip) => 6.0,
      (CategoryGroup.dresses, Measure.chest) => 8.0,
      (CategoryGroup.dresses, Measure.waist) => 6.0,
      (CategoryGroup.dresses, Measure.hip) => 6.0,
      (CategoryGroup.footwear, Measure.foot) => 1.0,
      (CategoryGroup.footwear, _) => 0.0,
      (_, Measure.chest) => 10.0,
      (_, Measure.waist) => 8.0,
      (_, Measure.hip) => 6.0,
      (_, Measure.neck) => 1.5,
      (_, Measure.shoulder) => 1.0,
      _ => 0.0,
    };
    final factor = switch (fit) {
      GarmentFit.slim => 0.6,
      GarmentFit.relaxed => 1.6,
      _ => 1.0,
    };
    return base * factor;
  }

  /// The chart as body-measurement ranges, ready for matching.
  static SizeChart bodyChart(SizeChart chart) {
    final expanded = chart.withExpandedPoints();
    if (chart.basis == ChartBasis.body) return expanded;
    return SizeChart(
      category: chart.category,
      basis: ChartBasis.body,
      fit: chart.fit,
      region: chart.region,
      note: chart.note,
      source: chart.source,
      sizes: [
        for (final s in expanded.sizes)
          SizeRow(
            label: s.label,
            alt: s.alt,
            ranges: {
              for (final e in s.ranges.entries)
                e.key: e.value.shift(-ease(chart.category.group, e.key, chart.fit)),
            },
          ),
      ],
    );
  }

  static double _preferenceShift(FitPreference p, Measure m) {
    if (!(m == Measure.chest || m == Measure.waist || m == Measure.hip)) {
      return 0;
    }
    return switch (p) {
      FitPreference.slim => -1.5,
      FitPreference.regular => 0.0,
      FitPreference.relaxed => 2.5,
    };
  }

  static double _offsetShare(Measure m) => switch (m) {
        Measure.chest || Measure.waist || Measure.hip => 1.0,
        Measure.neck => 0.4,
        Measure.foot => 0.25,
        _ => 0.0,
      };

  static double _penalty(double value, Range r, Measure m) {
    if (r.contains(value)) {
      if (r.width < 0.05) return 0;
      final rel = (value - r.center) / (r.width / 2);
      return 0.15 * rel * rel;
    }
    final d = value < r.min ? r.min - value : value - r.max;
    final steps = d / m.tolerance;
    return 0.15 + steps * steps;
  }

  /// Picks the best size in [chart] for [profile].
  ///
  /// [brandId] turns on the person's learned adjustment for that brand.
  static Recommendation recommend({
    required BodyProfile profile,
    required SizeChart chart,
    String? brandId,
  }) {
    final body = bodyChart(chart);
    final weights = chart.category.weights;
    final offset =
        brandId == null ? 0.0 : profile.offsetFor(brandId, chart.category);

    final chartMeasures = body.measures;
    final missing = [
      for (final e in (weights.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))))
        if (chartMeasures.contains(e.key) &&
            !profile.measurements.containsKey(e.key))
          e.key,
    ];

    final scores = <SizeScore>[];
    var usedEstimates = false;
    for (var i = 0; i < body.sizes.length; i++) {
      final size = body.sizes[i];
      var total = 0.0, weightSum = 0.0;
      final fits = <MeasureFit>[];
      for (final e in size.ranges.entries) {
        final w = weights[e.key];
        final raw = profile.measurements[e.key];
        if (w == null || raw == null) continue;
        if (profile.estimated.contains(e.key)) usedEstimates = true;
        final value = raw +
            _preferenceShift(profile.fitPreference, e.key) +
            offset * _offsetShare(e.key);
        final p = _penalty(value, e.value, e.key);
        fits.add(MeasureFit(
            measure: e.key, value: value, range: e.value, penalty: p));
        total += w * p;
        weightSum += w;
      }
      if (weightSum == 0) continue;
      fits.sort((a, b) =>
          (weights[b.measure] ?? 0).compareTo(weights[a.measure] ?? 0));
      scores.add(SizeScore(
          size: size, index: i, score: total / weightSum, fits: fits));
    }

    if (scores.isEmpty) {
      return Recommendation(
        chart: body,
        scores: const [],
        best: null,
        alternative: null,
        confidence: Confidence.low,
        missing: missing,
        outOfRange: null,
        offsetApplied: offset,
        usedEstimates: false,
      );
    }

    // Lowest score wins. On a near tie, the person's preference decides.
    final ranked = [...scores]..sort((a, b) {
        final diff = a.score - b.score;
        if (diff.abs() > 0.03) return diff.sign.toInt();
        final preferLarger = profile.fitPreference == FitPreference.relaxed;
        return preferLarger
            ? b.index.compareTo(a.index)
            : a.index.compareTo(b.index);
      });
    final best = ranked.first;

    SizeScore? alternative;
    for (final s in ranked.skip(1)) {
      if ((s.index - best.index).abs() == 1 && s.score - best.score <= 0.2) {
        alternative = s;
        break;
      }
    }

    final primary = chart.category.primary;
    MeasureFit? primaryFit;
    for (final f in best.fits) {
      if (f.measure == primary) primaryFit = f;
    }
    final mainFit = primaryFit ?? best.fits.first;

    OutOfRange? outOfRange;
    if (mainFit.distance > mainFit.measure.tolerance) {
      if (best.index == 0 && mainFit.status == FitStatus.below) {
        outOfRange = OutOfRange.smallerThanSmallest;
      } else if (best.index == body.sizes.length - 1 &&
          mainFit.status == FitStatus.above) {
        outOfRange = OutOfRange.largerThanLargest;
      }
    }

    Confidence confidence;
    if (outOfRange != null || missing.contains(primary)) {
      confidence = Confidence.low;
    } else if (best.score <= 0.3 && alternative == null) {
      confidence = Confidence.high;
    } else if (best.score <= 1.0) {
      confidence = Confidence.medium;
    } else {
      confidence = Confidence.low;
    }
    if (usedEstimates && confidence == Confidence.high) {
      confidence = Confidence.medium;
    }

    return Recommendation(
      chart: body,
      scores: scores,
      best: best,
      alternative: alternative,
      confidence: confidence,
      missing: missing,
      outOfRange: outOfRange,
      offsetApplied: offset,
      usedEstimates: usedEstimates,
    );
  }

  /// Estimates body measurements from a size the person knows fits them,
  /// e.g. "M in this brand fits me well". Returns cm values.
  static Map<Measure, double> estimateFromSize(SizeChart chart, String label) {
    final body = bodyChart(chart);
    final want = label.trim().toUpperCase();
    for (final s in body.sizes) {
      final names = [s.label, ...s.alt].map((n) => n.trim().toUpperCase());
      if (names.contains(want)) {
        return {
          for (final e in s.ranges.entries) e.key: round1(e.value.center),
        };
      }
    }
    return const {};
  }

  /// Largest gap between what the person measured and a size, for display.
  static double worstDistance(SizeScore s) =>
      s.fits.fold(0.0, (m, f) => math.max(m, f.distance));
}
