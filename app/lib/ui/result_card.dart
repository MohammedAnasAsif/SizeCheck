import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'body_tab.dart';
import 'feedback_sheet.dart';
import 'format.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.brand, required this.chart});

  final Brand brand;
  final SizeChart chart;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.active;
    final units = state.units;
    final rec = Recommender.recommend(
      profile: profile,
      chart: chart,
      brandId: brand.id,
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (!rec.hasResult) {
      final needed = rec.missing.take(3).map((m) => m.label.toLowerCase());
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a measurement to get your size',
                style: text.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('This chart uses ${needed.join(', ')}.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const BodyTab())),
                child: const Text('Add measurements'),
              ),
              const SizedBox(height: 20),
              _ChartTable(chart: rec.chart, best: null, units: units),
              _SourceLine(brand: brand, chart: chart),
            ],
          ),
        ),
      );
    }

    final best = rec.best!;
    final (confLabel, confColor) = switch (rec.confidence) {
      Confidence.high => ('Good match', scheme.primary),
      Confidence.medium => ('Likely match', scheme.secondary),
      Confidence.low => ('Rough guess', scheme.error),
    };

    final notes = <String>[];
    if (rec.outOfRange == OutOfRange.largerThanLargest) {
      notes.add(
        'Your measurements are larger than this brand\'s biggest size '
        'in this chart. ${best.size.label} is the closest, but it may be tight.',
      );
    } else if (rec.outOfRange == OutOfRange.smallerThanSmallest) {
      notes.add(
        'Your measurements are smaller than this brand\'s smallest '
        'size in this chart. ${best.size.label} is the closest, but it may be loose.',
      );
    }
    if (rec.isBetweenSizes) {
      final alt = rec.alternative!.size.label;
      notes.add(
        rec.alternativeIsLarger
            ? 'You are between sizes. Pick $alt if you want it looser.'
            : 'You are between sizes. Pick $alt if you want it more fitted.',
      );
    }
    if (rec.offsetApplied != 0) {
      notes.add(
        'Adjusted from what you told SizeCheck about past '
        '${brand.name} purchases.',
      );
    }
    if (rec.usedEstimates) {
      notes.add(
        'Partly based on estimated measurements. Measuring yourself '
        'makes this more accurate.',
      );
    }
    if (rec.missing.isNotEmpty) {
      notes.add(
        'Add your ${rec.missing.take(2).map((m) => m.label.toLowerCase()).join(' and ')} '
        'for a more accurate result.',
      );
    }
    if (brand.origin == BrandOrigin.typical) {
      notes.add(
        'These are typical sizes across brands, not this brand\'s own '
        'chart. Check the product page if you can.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your size', style: text.labelLarge),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    best.size.label,
                    style: text.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                if (best.size.alt.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '(${best.size.alt.join(' / ')})',
                      style: text.titleMedium,
                    ),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: confColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      confLabel,
                      style: text.labelLarge?.copyWith(color: confColor),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${brand.name} · ${chart.category.label}',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final f in best.fits)
              _FitRow(fit: f, size: best.size.label, units: units),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: scheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(n)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (brand.origin != BrandOrigin.typical)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.checkroom),
                label: const Text('Bought it? Tell SizeCheck how it fit'),
                onPressed: () => showFeedbackSheet(
                  context,
                  brand: brand,
                  chart: chart,
                  recommended: best.size.label,
                ),
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Full size chart'),
              children: [
                _ChartTable(chart: rec.chart, best: best.index, units: units),
              ],
            ),
            _SourceLine(brand: brand, chart: chart),
          ],
        ),
      ),
    );
  }
}

class _FitRow extends StatelessWidget {
  const _FitRow({required this.fit, required this.size, required this.units});

  final MeasureFit fit;
  final String size;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, verdict) = switch (fit.status) {
      FitStatus.within => (Icons.check_circle, scheme.primary, 'fits'),
      FitStatus.below => (
        Icons.south,
        scheme.secondary,
        '${fmtLength(fit.distance, units)} under',
      ),
      FitStatus.above => (
        Icons.north,
        scheme.error,
        '${fmtLength(fit.distance, units)} over',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${fit.measure.label} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: fmtLength(fit.value, units)),
                  TextSpan(
                    text:
                        '  ·  $size is ${fmtRange(fit.range, units)} ($verdict)',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartTable extends StatelessWidget {
  const _ChartTable({
    required this.chart,
    required this.best,
    required this.units,
  });

  final SizeChart chart;
  final int? best;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final measures = Measure.values.where(chart.measures.contains).toList();
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columnSpacing: 20,
        columns: [
          const DataColumn(label: Text('Size')),
          for (final m in measures)
            DataColumn(
              label: Text('${m.label.split(' ').first} (${unitLabel(units)})'),
            ),
        ],
        rows: [
          for (var i = 0; i < chart.sizes.length; i++)
            DataRow(
              color: i == best
                  ? WidgetStatePropertyAll(scheme.primaryContainer)
                  : null,
              cells: [
                DataCell(
                  Text(
                    chart.sizes[i].displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                for (final m in measures)
                  DataCell(
                    Text(
                      chart.sizes[i].ranges[m] == null
                          ? '–'
                          : fmtRange(
                              chart.sizes[i].ranges[m]!,
                              units,
                            ).replaceAll(' ${unitLabel(units)}', ''),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.brand, required this.chart});

  final Brand brand;
  final SizeChart chart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall;
    String line;
    if (brand.origin == BrandOrigin.typical) {
      line = chart.note ?? 'Typical sizes across brands.';
    } else if (brand.isUserAdded) {
      line = 'Chart you added yourself.';
    } else if (chart.source != null) {
      line =
          'From ${brand.name}\'s official size chart, checked '
          '${chart.source!.verifiedOn}.';
    } else {
      line = 'From ${brand.name}\'s size chart.';
    }
    if (chart.basis == ChartBasis.garment) {
      line +=
          ' The brand lists garment measurements; SizeCheck converts them '
          'to body sizes.';
    }
    final url = chart.source?.url;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(line, style: text),
          if (url != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('View source'),
            ),
        ],
      ),
    );
  }
}
