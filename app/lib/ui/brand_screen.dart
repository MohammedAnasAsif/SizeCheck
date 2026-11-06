import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';
import 'add_chart_screen.dart';
import 'result_card.dart';

class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key, required this.brandId, this.initialCategory});

  final String brandId;
  final Category? initialCategory;

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  Category? _category;
  bool _showAll = false;

  List<Category> _ordered(Brand brand, Audience audience) {
    final cats = brand.categories.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    int rank(Category c) => audience == Audience.unisex
        ? 0
        : c.audience == audience
            ? 0
            : c.audience == Audience.unisex
                ? 1
                : 2;
    cats.sort((a, b) => rank(a).compareTo(rank(b)));
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final brand = state.catalog.byId(widget.brandId);
    if (brand == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This brand is no longer available.')),
      );
    }
    final profile = state.active;
    final cats = _ordered(brand, profile.audience);
    final forMe = cats
        .where((c) =>
            profile.audience == Audience.unisex ||
            c.audience == profile.audience ||
            c.audience == Audience.unisex)
        .toList();
    final visible = _showAll || forMe.isEmpty ? cats : forMe;

    var category = _category ?? widget.initialCategory;
    if (category == null || !cats.contains(category)) {
      category = visible.isEmpty ? null : visible.first;
    }
    if (category != null && !visible.contains(category)) {
      _showAll = true;
    }
    final chart = category == null ? null : brand.chartFor(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.name),
        actions: [
          if (brand.isUserAdded)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'add') {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AddChartScreen(
                      initialBrandName: brand.name,
                      existingBrandId: brand.id,
                    ),
                  ));
                } else if (v == 'delete') {
                  state.deleteUserBrand(brand);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'add', child: Text('Add another category')),
                PopupMenuItem(value: 'delete', child: Text('Delete this brand')),
              ],
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text('For ${profile.name}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in (_showAll ? cats : visible))
                    ChoiceChip(
                      label: Text(c.label),
                      selected: c == category,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  if (!_showAll && visible.length < cats.length)
                    ActionChip(
                      avatar: const Icon(Icons.expand_more, size: 18),
                      label: Text('${cats.length - visible.length} more'),
                      onPressed: () => setState(() => _showAll = true),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (chart == null)
                const Text('No size chart for this category yet.')
              else
                ResultCard(
                  key: ValueKey('${brand.id}-${chart.category.id}-${profile.id}'),
                  brand: brand,
                  chart: chart,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
