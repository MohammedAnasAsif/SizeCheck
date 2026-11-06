import 'package:size_engine/size_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ChartParser', () {
    test('reads a tab-separated chart copied from a web page', () {
      final p = ChartParser.parse('Size\tChest (cm)\tWaist (cm)\n'
          'S\t86 - 91\t71-76\n'
          'M\t91 – 96\t76-81\n'
          'L\t96-101\t81-86\n');
      expect(p.sizes.map((s) => s.label), ['S', 'M', 'L']);
      expect(p.unit, ChartUnit.cm);
      expect(p.unitWasGuessed, isFalse);
      expect(p.sizes[1].ranges[Measure.chest], const Range(91, 96));
      expect(p.sizes[2].ranges[Measure.waist], const Range(81, 86));
    });

    test('reads a chart with sizes across the top, in inches', () {
      final p = ChartParser.parse('Size  S  M  L  XL\n'
          'To fit chest (in)  36  38  40  42\n'
          'Waist (in)  30  32  34  36\n'
          'All measurements in inches');
      expect(p.sizes.map((s) => s.label), ['S', 'M', 'L', 'XL']);
      expect(p.unit, ChartUnit.inches);
      expect(p.sizes[0].ranges[Measure.chest]!.min, closeTo(91.4, 0.05));
      expect(p.sizes[3].ranges[Measure.waist]!.min, closeTo(91.4, 0.05));
    });

    test('guesses inches when no unit is given and numbers are small', () {
      final p = ChartParser.parse('Size Chest Waist\n'
          '38 38 32\n'
          '40 40 34\n');
      expect(p.unitWasGuessed, isTrue);
      expect(p.unit, ChartUnit.inches);
      expect(p.sizes.map((s) => s.label), ['38', '40']);
    });

    test('joins two-word headers separated by single spaces', () {
      final p = ChartParser.parse('Size Waist Inside leg\n'
          '30 76 81\n'
          '32 81 81\n');
      expect(p.measures, {Measure.waist, Measure.inseam});
    });

    test('ignores garment length columns', () {
      final p = ChartParser.parse('Size\tChest\tLength\n'
          'S\t96\t68\n'
          'M\t102\t70\n');
      expect(p.measures, {Measure.chest});
    });

    test('explains what is wrong with text that is not a chart', () {
      expect(() => ChartParser.parse('hello'),
          throwsA(isA<ChartParseException>()));
      expect(() => ChartParser.parse('a b c\nd e f'),
          throwsA(isA<ChartParseException>()));
    });
  });

  group('LinkDetector', () {
    final brands = [
      Brand(
        id: 'vanheusen',
        name: 'Van Heusen',
        origin: BrandOrigin.indian,
        aliases: ['van heusen'],
        domains: ['vanheusenindia.com'],
        charts: const [],
      ),
      Brand(
        id: 'uspolo',
        name: 'U.S. Polo Assn.',
        origin: BrandOrigin.international,
        aliases: ['us polo assn', 'u s polo assn'],
        charts: const [],
      ),
      Brand(
        id: 'levis',
        name: "Levi's",
        origin: BrandOrigin.international,
        aliases: ['levis'],
        domains: ['levi.in'],
        charts: const [],
      ),
    ];
    final detector = LinkDetector(brands);

    test('finds the brand from its own website', () {
      final d = detector.detect(
          'Look at this https://www.vanheusenindia.com/men-shirts/abc');
      expect(d!.brand!.id, 'vanheusen');
      expect(d.viaMarketplace, isFalse);
      expect(d.category, Category.menShirts);
    });

    test('finds the brand inside a Myntra link', () {
      final d = detector.detect(
          'https://www.myntra.com/jeans/levis/levis-men-511-slim-fit-jeans/12345/buy');
      expect(d!.brand!.id, 'levis');
      expect(d.viaMarketplace, isTrue);
      expect(d.category, Category.menBottoms);
    });

    test('prefers the longer brand name', () {
      final d = detector.detect(
          'https://www.ajio.com/us-polo-assn-men-tshirt/p/469');
      expect(d!.brand!.id, 'uspolo');
      expect(d.category, Category.menTops);
    });

    test('recognises a shop without knowing the brand', () {
      final d = detector.detect('https://www.myntra.com/dresses/unknownlabel/x/1/buy');
      expect(d!.brand, isNull);
      expect(d.viaMarketplace, isTrue);
      expect(d.category, Category.womenDresses);
    });

    test('returns null for text without a link', () {
      expect(detector.detect('no link here'), isNull);
    });
  });

  group('Catalog', () {
    test('loads a bundle and searches by name and alias', () {
      final c = Catalog.fromBundle({
        'format': 1,
        'version': 'v1',
        'brands': [
          {
            'id': 'vanheusen',
            'name': 'Van Heusen',
            'origin': 'indian',
            'aliases': ['van heusen'],
            'charts': [
              {
                'category': 'men_shirts',
                'basis': 'body',
                'unit': 'cm',
                'sizes': [
                  {'label': '38', 'chest': [96, 96]},
                  {'label': '40', 'chest': [101, 101]},
                ],
              },
              {'category': 'some_future_category', 'basis': 'body', 'sizes': []},
            ],
          },
        ],
        'typical': [],
      });
      expect(c.version, 'v1');
      expect(c.search('van').single.name, 'Van Heusen');
      expect(c.search('vanh').single.id, 'vanheusen');
      expect(c.search('zzz'), isEmpty);
      // Unknown categories from newer data are skipped, not fatal.
      expect(c.byId('vanheusen')!.charts, hasLength(1));
      expect(c.typical, isNull);
    });
  });
}
