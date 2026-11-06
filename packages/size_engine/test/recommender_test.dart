import 'package:size_engine/size_engine.dart';
import 'package:test/test.dart';

// Made-up charts for testing; not any real brand's numbers.
SizeChart tops({ChartBasis basis = ChartBasis.body}) => SizeChart.fromJson({
      'category': 'men_tops',
      'basis': basis.name,
      'unit': 'cm',
      'sizes': [
        {'label': 'S', 'chest': [86, 91], 'waist': [71, 76]},
        {'label': 'M', 'chest': [91, 96], 'waist': [76, 81]},
        {'label': 'L', 'chest': [96, 101], 'waist': [81, 86]},
        {'label': 'XL', 'chest': [101, 106], 'waist': [86, 91]},
      ],
    })!;

BodyProfile person(Map<Measure, double> m,
        {FitPreference fit = FitPreference.regular}) =>
    BodyProfile(id: 't', name: 'T', measurements: m, fitPreference: fit);

void main() {
  group('recommend', () {
    test('picks the size whose ranges contain the measurements', () {
      final r = Recommender.recommend(
          profile: person({Measure.chest: 98, Measure.waist: 83}),
          chart: tops());
      expect(r.best!.size.label, 'L');
      expect(r.confidence, Confidence.high);
      expect(r.alternative, isNull);
    });

    test('flags being between two sizes', () {
      final r = Recommender.recommend(
          profile: person({Measure.chest: 96.2, Measure.waist: 81.2}),
          chart: tops());
      expect(r.isBetweenSizes, isTrue);
      expect({r.best!.size.label, r.alternative!.size.label}, {'M', 'L'});
    });

    test('a relaxed preference picks the larger size on a near tie', () {
      final r = Recommender.recommend(
          profile: person({Measure.chest: 96, Measure.waist: 81},
              fit: FitPreference.relaxed),
          chart: tops());
      expect(r.best!.size.label, 'L');
    });

    test('says when the person is bigger than the largest size', () {
      final r = Recommender.recommend(
          profile: person({Measure.chest: 125, Measure.waist: 110}),
          chart: tops());
      expect(r.best!.size.label, 'XL');
      expect(r.outOfRange, OutOfRange.largerThanLargest);
      expect(r.confidence, Confidence.low);
    });

    test('returns no result when nothing overlaps', () {
      final r = Recommender.recommend(
          profile: person({Measure.inseam: 80}), chart: tops());
      expect(r.hasResult, isFalse);
      expect(r.missing.first, Measure.chest);
    });

    test('lists missing measurements and lowers confidence without the main one',
        () {
      final r = Recommender.recommend(
          profile: person({Measure.waist: 78}), chart: tops());
      expect(r.best!.size.label, 'M');
      expect(r.missing, [Measure.chest]);
      expect(r.confidence, Confidence.low);
    });

    test('garment charts are converted to body sizes using ease', () {
      // Garment chest 100 cm in a regular-fit top fits a ~90 cm body.
      final garment = SizeChart.fromJson({
        'category': 'men_tops',
        'basis': 'garment',
        'unit': 'cm',
        'sizes': [
          {'label': 'S', 'chest': 96},
          {'label': 'M', 'chest': 102},
          {'label': 'L', 'chest': 108},
        ],
      })!;
      final r = Recommender.recommend(
          profile: person({Measure.chest: 92}), chart: garment);
      expect(r.best!.size.label, 'M');
    });

    test('estimated measurements cap confidence at medium', () {
      final p = person({});
      p.setMeasurement(Measure.chest, 98, isEstimate: true);
      p.setMeasurement(Measure.waist, 83, isEstimate: true);
      final r = Recommender.recommend(profile: p, chart: tops());
      expect(r.usedEstimates, isTrue);
      expect(r.confidence, Confidence.medium);
    });
  });

  group('chart ranges', () {
    test('single values become ranges meeting halfway', () {
      final c = SizeChart.fromJson({
        'category': 'men_tops',
        'basis': 'body',
        'unit': 'cm',
        'sizes': [
          {'label': 'S', 'chest': 88},
          {'label': 'M', 'chest': 94},
          {'label': 'L', 'chest': 100},
        ],
      })!
          .withExpandedPoints();
      expect(c.sizes[0].ranges[Measure.chest], const Range(85, 91));
      expect(c.sizes[1].ranges[Measure.chest], const Range(91, 97));
      expect(c.sizes[2].ranges[Measure.chest], const Range(97, 103));
    });

    test('inch charts are converted to cm', () {
      final c = SizeChart.fromJson({
        'category': 'men_bottoms',
        'basis': 'body',
        'unit': 'in',
        'sizes': [
          {'label': '30', 'waist': 30},
          {'label': '32', 'waist': 32},
        ],
      })!;
      expect(c.sizes[0].ranges[Measure.waist]!.min, closeTo(76.2, 0.01));
    });
  });

  group('feedback learning', () {
    test('"tight" on the recommended size moves the next pick up', () {
      final p = person({Measure.chest: 95.5, Measure.waist: 80.5});
      final before =
          Recommender.recommend(profile: p, chart: tops(), brandId: 'b');
      expect(before.best!.size.label, 'M');
      p.addFeedback(
        FitFeedback(
          brandId: 'b',
          brandName: 'B',
          category: Category.menTops,
          sizeLabel: 'M',
          outcome: FitOutcome.tight,
          date: DateTime(2026, 11, 6),
        ),
        recommendedLabel: 'M',
      );
      expect(p.offsetFor('b', Category.menTops), 1.5);
      final after =
          Recommender.recommend(profile: p, chart: tops(), brandId: 'b');
      expect(after.best!.size.label, 'L');
      expect(after.offsetApplied, 1.5);
      // Other brands are not affected.
      expect(p.offsetFor('other', Category.menTops), 0);
    });

    test('mild feedback on a size SizeCheck did not suggest is ignored', () {
      final p = person({Measure.chest: 93});
      p.addFeedback(
        FitFeedback(
          brandId: 'b',
          brandName: 'B',
          category: Category.menTops,
          sizeLabel: 'L',
          outcome: FitOutcome.loose,
          date: DateTime(2026, 11, 6),
        ),
        recommendedLabel: 'M',
      );
      expect(p.offsetFor('b', Category.menTops), 0);
      expect(p.history, hasLength(1));
    });

    test('offset is capped', () {
      final p = person({Measure.chest: 93});
      for (var i = 0; i < 10; i++) {
        p.addFeedback(FitFeedback(
          brandId: 'b',
          brandName: 'B',
          category: Category.menTops,
          sizeLabel: 'M',
          outcome: FitOutcome.tooSmall,
          date: DateTime(2026, 11, 6),
        ));
      }
      expect(p.offsetFor('b', Category.menTops), BodyProfile.maxOffset);
    });
  });

  test('estimateFromSize returns the middle of the size', () {
    final m = Recommender.estimateFromSize(tops(), 'm');
    expect(m[Measure.chest], 93.5);
    expect(m[Measure.waist], 78.5);
  });

  test('profile export code round-trips', () {
    final p = person({Measure.chest: 98.5, Measure.foot: 26.2})
      ..name = 'Asha'
      ..audience = Audience.women;
    final code = p.toExportCode();
    final back = BodyProfile.fromExportCode('Here: $code', newId: 'new');
    expect(back, isNotNull);
    expect(back!.id, 'new');
    expect(back.name, 'Asha');
    expect(back.audience, Audience.women);
    expect(back.measurements[Measure.chest], 98.5);
    expect(BodyProfile.fromExportCode('nonsense', newId: 'x'), isNull);
  });
}
