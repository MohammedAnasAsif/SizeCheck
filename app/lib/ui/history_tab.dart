import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';
import 'brand_screen.dart';
import 'profile_menu.dart';

/// What the person bought and how it fit. This is what SizeCheck learns from.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.active;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fit history'),
        actions: const [ProfileMenuButton(), SizedBox(width: 8)],
      ),
      body: p.history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.checkroom, size: 48, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text('Nothing here yet', style: text.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'After you buy something, open the brand in SizeCheck '
                      'and tap "Tell SizeCheck how it fit". SizeCheck then '
                      'adjusts its advice for that brand.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
                  itemCount: p.history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = p.history[i];
                    final color = switch (h.outcome) {
                      FitOutcome.good => scheme.primary,
                      FitOutcome.tight || FitOutcome.loose => scheme.secondary,
                      _ => scheme.error,
                    };
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.14),
                        child: Text(
                          h.sizeLabel,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: h.sizeLabel.length > 3 ? 11 : 14,
                          ),
                        ),
                      ),
                      title: Text('${h.brandName} · ${h.category.label}'),
                      subtitle: Text(
                        '${h.outcome.label} · ${h.date.toLocal().toString().substring(0, 10)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          p.history.removeAt(i);
                          state.changed();
                        },
                      ),
                      onTap: state.catalog.byId(h.brandId) == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BrandScreen(
                                  brandId: h.brandId,
                                  initialCategory: h.category,
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
