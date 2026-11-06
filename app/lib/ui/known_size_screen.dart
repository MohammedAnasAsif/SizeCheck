import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';
import 'format.dart';

/// "M in Uniqlo fits me well" -> estimated measurements, no tape needed.
class KnownSizeScreen extends StatefulWidget {
  const KnownSizeScreen({super.key});

  @override
  State<KnownSizeScreen> createState() => _KnownSizeScreenState();
}

class _KnownSizeScreenState extends State<KnownSizeScreen> {
  String _query = '';
  Brand? _brand;
  Category? _category;
  String? _size;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final brands = state.catalog
        .search(_query)
        .where((b) => b.origin != BrandOrigin.typical)
        .take(30)
        .toList();
    final chart = _brand != null && _category != null
        ? _brand!.chartFor(_category!)
        : null;
    final estimate = chart != null && _size != null
        ? Recommender.estimateFromSize(chart, _size!)
        : const <Measure, double>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Start from a size you know')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(
                'Pick a brand where you know which size fits you well. '
                'SizeCheck estimates your measurements from that brand\'s '
                'chart. You can replace them with real measurements later.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('1. Brand', style: text.titleMedium),
              const SizedBox(height: 8),
              if (_brand == null) ...[
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search brands',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                for (final b in brands)
                  ListTile(
                    title: Text(b.name),
                    onTap: () => setState(() {
                      _brand = b;
                      final cats = b.categories.toList()
                        ..sort((x, y) => x.index.compareTo(y.index));
                      final mine = cats.where(
                        (c) =>
                            state.active.audience == Audience.unisex ||
                            c.audience == state.active.audience,
                      );
                      _category = mine.isNotEmpty ? mine.first : cats.first;
                      _size = null;
                    }),
                  ),
              ] else
                InputChip(
                  label: Text(_brand!.name),
                  onDeleted: () => setState(() {
                    _brand = null;
                    _category = null;
                    _size = null;
                  }),
                ),
              if (_brand != null) ...[
                const SizedBox(height: 20),
                Text('2. What kind of clothing', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c
                        in _brand!.categories.toList()
                          ..sort((x, y) => x.index.compareTo(y.index)))
                      ChoiceChip(
                        label: Text(c.label),
                        selected: c == _category,
                        onSelected: (_) => setState(() {
                          _category = c;
                          _size = null;
                        }),
                      ),
                  ],
                ),
              ],
              if (chart != null) ...[
                const SizedBox(height: 20),
                Text('3. The size that fits you well', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in chart.sizes)
                      ChoiceChip(
                        label: Text(s.displayLabel),
                        selected: s.label == _size,
                        onSelected: (_) => setState(() => _size = s.label),
                      ),
                  ],
                ),
              ],
              if (estimate.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated measurements', style: text.titleSmall),
                        const SizedBox(height: 8),
                        for (final e in estimate.entries)
                          Text(
                            '${e.key.label}: about '
                            '${fmtLength(e.value, state.units)}',
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Measurements you already entered yourself are '
                          'kept as they are.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final p = state.active;
                    final messenger = ScaffoldMessenger.of(context);
                    var added = 0;
                    for (final e in estimate.entries) {
                      final measuredByHand =
                          p.measurements.containsKey(e.key) &&
                          !p.estimated.contains(e.key);
                      if (measuredByHand) continue;
                      p.setMeasurement(e.key, e.value, isEstimate: true);
                      added++;
                    }
                    p.audience = _category!.audience == Audience.unisex
                        ? p.audience
                        : _category!.audience;
                    state.changed();
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          added == 0
                              ? 'Your own measurements were kept.'
                              : 'Added $added estimated measurements.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Use these'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
