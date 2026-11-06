import 'package:flutter_test/flutter_test.dart';
import 'package:size_engine/size_engine.dart';
import 'package:sizecheck/app_state.dart';
import 'package:sizecheck/main.dart';

// Made-up test data, not a real brand.
final bundle = <String, dynamic>{
  'format': 1,
  'version': 'test',
  'brand_count': 1,
  'brands': [
    {
      'id': 'testbrand',
      'name': 'Testbrand',
      'origin': 'indian',
      'aliases': ['testbrand'],
      'domains': ['testbrand.example'],
      'charts': [
        {
          'category': 'men_tops',
          'basis': 'body',
          'unit': 'cm',
          'sizes': [
            {'label': 'S', 'chest': [86, 91]},
            {'label': 'M', 'chest': [91, 96]},
            {'label': 'L', 'chest': [96, 101]},
          ],
          'source': {
            'url': 'https://testbrand.example/size',
            'verified_on': '2026-11-06'
          },
        },
      ],
    },
  ],
  'typical': [],
};

void main() {
  testWidgets('shows the brand list and recommends a size', (tester) async {
    final state = AppState.inMemory(bundle);
    await tester.pumpWidget(SizeCheckApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('SizeCheck'), findsWidgets);
    expect(find.text('Testbrand'), findsOneWidget);

    await tester.tap(find.text('Testbrand'));
    await tester.pumpAndSettle();
    expect(find.text('Add a measurement to get your size'), findsOneWidget);

    state.active.setMeasurement(Measure.chest, 93);
    state.changed();
    await tester.pumpAndSettle();
    expect(find.text('M'), findsWidgets);
    expect(find.text('Good match'), findsOneWidget);
  });
}
