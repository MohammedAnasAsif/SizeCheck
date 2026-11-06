import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'brand_screen.dart';
import 'format.dart';

const repoUrl = 'https://github.com/MohammedAnasAsif/SizeCheck';

/// Paste (or type) any brand's size chart and get a size immediately.
class AddChartScreen extends StatefulWidget {
  const AddChartScreen({
    super.key,
    this.initialBrandName = '',
    this.initialCategory,
    this.sourceUrl,
    this.existingBrandId,
  });

  final String initialBrandName;
  final Category? initialCategory;
  final String? sourceUrl;
  final String? existingBrandId;

  @override
  State<AddChartScreen> createState() => _AddChartScreenState();
}

class _AddChartScreenState extends State<AddChartScreen> {
  late final _name = TextEditingController(text: widget.initialBrandName);
  final _paste = TextEditingController();
  late final _source = TextEditingController(text: widget.sourceUrl ?? '');
  late Category _category = widget.initialCategory ?? Category.menTops;
  ChartBasis _basis = ChartBasis.body;
  ParsedChart? _parsed;
  ChartUnit? _unit;
  String? _error;

  static const _template =
      'Size\tChest\tWaist\tHip\n'
      'S\t\t\t\n'
      'M\t\t\t\n'
      'L\t\t\t\n'
      'XL\t\t\t\n';

  @override
  void dispose() {
    _name.dispose();
    _paste.dispose();
    _source.dispose();
    super.dispose();
  }

  void _read() {
    setState(() {
      try {
        _parsed = ChartParser.parse(_paste.text);
        _unit = _parsed!.unit;
        _error = null;
      } on ChartParseException catch (e) {
        _parsed = null;
        _error = e.message;
      }
    });
  }

  /// The parsed rows, reinterpreted if the person corrected the unit.
  List<SizeRow> get _rows {
    final p = _parsed!;
    if (_unit == p.unit) return p.sizes;
    final factor = _unit == ChartUnit.inches ? cmPerInch : 1 / cmPerInch;
    return [
      for (final s in p.sizes)
        SizeRow(
          label: s.label,
          ranges: {
            for (final e in s.ranges.entries)
              e.key: Range(
                round1(e.value.min * factor),
                round1(e.value.max * factor),
              ),
          },
        ),
    ];
  }

  SizeChart _chart() {
    final src = _source.text.trim();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return SizeChart(
      category: _category,
      basis: _basis,
      sizes: _rows,
      source: src.startsWith('http')
          ? ChartSource(url: src, verifiedOn: today)
          : null,
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the brand name.');
      return;
    }
    final state = AppScope.read(context);
    final brand = state.saveUserChart(
      brandName: name,
      chart: _chart(),
      existingBrandId: widget.existingBrandId,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            BrandScreen(brandId: brand.id, initialCategory: _category),
      ),
    );
  }

  Future<void> _share() async {
    final name = _name.text.trim();
    final chart = _chart();
    final json = const JsonEncoder.withIndent('  ')
        .convert({'name': name, 'chart': chart.toJson()});
    final body =
        'Please add this size chart to SizeCheck.\n\n'
        'Brand: $name\n'
        'Category: ${chart.category.label}\n'
        'Chart lists: ${chart.basis == ChartBasis.body ? 'body measurements' : 'garment measurements'}\n'
        'Copied from: ${chart.source?.url ?? '(please add the link to the brand\'s size chart)'}\n\n'
        '```json\n$json\n```\n';
    final uri = Uri.parse('$repoUrl/issues/new').replace(
      queryParameters: {
        'title': 'Add brand: $name (${chart.category.label})',
        'labels': 'brand-data',
        'body': body,
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final parsed = _parsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a size chart')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(
                'Open the product page, find "Size chart" or "Size guide", '
                'select the whole table and copy it. Then paste it below.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: widget.existingBrandId == null,
                decoration: const InputDecoration(labelText: 'Brand name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Category>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Clothing type'),
                items: [
                  for (final c in Category.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: 12),
              Text('The chart shows', style: text.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<ChartBasis>(
                segments: const [
                  ButtonSegment(
                    value: ChartBasis.body,
                    label: Text('Body measurements'),
                  ),
                  ButtonSegment(
                    value: ChartBasis.garment,
                    label: Text('Garment measurements'),
                  ),
                ],
                selected: {_basis},
                onSelectionChanged: (s) => setState(() => _basis = s.first),
              ),
              const SizedBox(height: 4),
              Text(
                'Not sure? Charts titled "body measurements" or "to fit" are '
                'body. Charts that say "garment", "product" or "flat" '
                'measurements are garment.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paste,
                minLines: 6,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Paste the size chart here',
                  alignLabelWithHint: true,
                  helperText:
                      'Or type it: one size per line, values separated '
                      'by tabs or two spaces.',
                  suffixIcon: IconButton(
                    tooltip: 'Insert a blank table to fill in',
                    icon: const Icon(Icons.table_chart_outlined),
                    onPressed: () => setState(() => _paste.text = _template),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Read chart'),
                onPressed: _read,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              if (parsed != null) ...[
                const SizedBox(height: 24),
                Text('Check it looks right', style: text.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parsed.unitWasGuessed
                            ? 'The chart did not say cm or inches. SizeCheck '
                                  'guessed ${_unit == ChartUnit.cm ? 'cm' : 'inches'}.'
                            : 'Numbers are in '
                                  '${_unit == ChartUnit.cm ? 'cm' : 'inches'}.',
                      ),
                    ),
                    SegmentedButton<ChartUnit>(
                      segments: const [
                        ButtonSegment(value: ChartUnit.cm, label: Text('cm')),
                        ButtonSegment(
                          value: ChartUnit.inches,
                          label: Text('in'),
                        ),
                      ],
                      selected: {_unit!},
                      onSelectionChanged: (s) =>
                          setState(() => _unit = s.first),
                    ),
                  ],
                ),
                for (final w in parsed.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(w, style: TextStyle(color: scheme.secondary)),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Size')),
                      for (final m in Measure.values.where(
                        parsed.measures.contains,
                      ))
                        DataColumn(
                          label: Text(
                            '${m.label.split(' ').first} '
                            '(${unitLabel(state.units)})',
                          ),
                        ),
                    ],
                    rows: [
                      for (final s in _rows)
                        DataRow(
                          cells: [
                            DataCell(Text(s.label)),
                            for (final m in Measure.values.where(
                              parsed.measures.contains,
                            ))
                              DataCell(
                                Text(
                                  s.ranges[m] == null
                                      ? '–'
                                      : fmtRange(
                                          s.ranges[m]!,
                                          state.units,
                                        ).replaceAll(
                                          ' ${unitLabel(state.units)}',
                                          '',
                                        ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _source,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Link to the size chart page (optional)',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save and get my size'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.public),
                  label: const Text(
                    'Also share it so everyone gets this brand',
                  ),
                  onPressed: _share,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sharing opens a pre-filled GitHub issue in your browser. '
                  'Nothing is sent unless you submit it there.',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
