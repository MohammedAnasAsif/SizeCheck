import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';
import 'format.dart';
import 'known_size_screen.dart';
import 'measure_info.dart';
import 'profile_menu.dart';

/// "My body": the active profile's measurements.
class BodyTab extends StatelessWidget {
  const BodyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My body'),
        actions: const [ProfileMenuButton(), SizedBox(width: 8)],
      ),
      body: _MeasurementsForm(
        key: ValueKey('${p.id}-${state.units.name}'),
        profile: p,
      ),
    );
  }
}

class _MeasurementsForm extends StatefulWidget {
  const _MeasurementsForm({super.key, required this.profile});

  final BodyProfile profile;

  @override
  State<_MeasurementsForm> createState() => _MeasurementsFormState();
}

class _MeasurementsFormState extends State<_MeasurementsForm> {
  final _controllers = <Measure, TextEditingController>{};
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final units = AppScope.read(context).units;
    for (final m in Measure.values) {
      _controllers[m] = TextEditingController(
        text: inputValue(widget.profile.measurements[m], units),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged(Measure m, String text) {
    final state = AppScope.read(context);
    widget.profile.setMeasurement(m, parseLength(text, state.units));
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), state.changed);
    setState(() {});
  }

  void _showHow(Measure m) {
    final info = measureInfo[m]!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(info.icon, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'How to measure: ${m.label.toLowerCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(info.how, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              for (final t in measuringTips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '•  $t',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(Measure m, AppState state) {
    final p = widget.profile;
    final scheme = Theme.of(context).colorScheme;
    final estimated = p.estimated.contains(m) && p.measurements.containsKey(m);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controllers[m],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: m.label,
                suffixText: unitLabel(state.units),
                prefixIcon: Icon(measureInfo[m]!.icon),
                helperText: estimated ? 'Estimated from a size you know' : null,
                helperStyle: TextStyle(color: scheme.secondary),
              ),
              onChanged: (t) => _onChanged(m, t),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'How to measure',
            onPressed: () => _showHow(m),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = widget.profile;
    final text = Theme.of(context).textTheme;
    final core = Measure.values.where((m) => measureInfo[m]!.core).toList();
    final more = Measure.values.where((m) => !measureInfo[m]!.core).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(
              'Measure once. SizeCheck uses these numbers for every brand. '
              'They stay on this device.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text('No tape? Start from a size you know'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KnownSizeScreen()),
              ),
            ),
            const SizedBox(height: 20),
            Text('How you like clothes to fit', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<FitPreference>(
              segments: const [
                ButtonSegment(value: FitPreference.slim, label: Text('Snug')),
                ButtonSegment(
                  value: FitPreference.regular,
                  label: Text('Regular'),
                ),
                ButtonSegment(
                  value: FitPreference.relaxed,
                  label: Text('Loose'),
                ),
              ],
              selected: {p.fitPreference},
              onSelectionChanged: (s) {
                p.fitPreference = s.first;
                state.changed();
              },
            ),
            const SizedBox(height: 16),
            Text('Show clothes for', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Audience>(
              segments: const [
                ButtonSegment(value: Audience.men, label: Text('Men')),
                ButtonSegment(value: Audience.women, label: Text('Women')),
                ButtonSegment(
                  value: Audience.unisex,
                  label: Text('Everything'),
                ),
              ],
              selected: {p.audience},
              onSelectionChanged: (s) {
                p.audience = s.first;
                state.changed();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Units', style: text.titleSmall),
                const Spacer(),
                SegmentedButton<UnitSystem>(
                  segments: const [
                    ButtonSegment(value: UnitSystem.cm, label: Text('cm')),
                    ButtonSegment(
                      value: UnitSystem.inches,
                      label: Text('inches'),
                    ),
                  ],
                  selected: {state.units},
                  onSelectionChanged: (s) => state.setUnits(s.first),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Main measurements', style: text.titleMedium),
            const SizedBox(height: 12),
            for (final m in core) _field(m, state),
            const SizedBox(height: 12),
            Text(
              'More (improves shirts, jeans and shoes)',
              style: text.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final m in more) _field(m, state),
          ],
        ),
      ),
    );
  }
}
