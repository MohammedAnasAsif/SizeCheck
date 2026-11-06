import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';

Future<void> showFeedbackSheet(
  BuildContext context, {
  required Brand brand,
  required SizeChart chart,
  required String recommended,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FeedbackSheet(
        brand: brand, chart: chart, recommended: recommended),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet(
      {required this.brand, required this.chart, required this.recommended});

  final Brand brand;
  final SizeChart chart;
  final String recommended;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  late String _size = widget.recommended;
  FitOutcome? _outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How did it fit?', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('${widget.brand.name} · ${widget.chart.category.label}'),
            const SizedBox(height: 16),
            Text('Size you bought', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in widget.chart.sizes)
                ChoiceChip(
                  label: Text(s.label),
                  selected: s.label == _size,
                  onSelected: (_) => setState(() => _size = s.label),
                ),
            ]),
            const SizedBox(height: 16),
            Text('Fit', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in FitOutcome.values)
                ChoiceChip(
                  label: Text(o.label),
                  selected: o == _outcome,
                  onSelected: (_) => setState(() => _outcome = o),
                ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _outcome == null
                    ? null
                    : () {
                        final state = AppScope.read(context);
                        state.active.addFeedback(
                          FitFeedback(
                            brandId: widget.brand.id,
                            brandName: widget.brand.name,
                            category: widget.chart.category,
                            sizeLabel: _size,
                            outcome: _outcome!,
                            date: DateTime.now(),
                          ),
                          recommendedLabel: widget.recommended,
                        );
                        state.changed();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Thanks. SizeCheck will use this '
                                  'next time for this brand.')),
                        );
                      },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saved only on this device.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
