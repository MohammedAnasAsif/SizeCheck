import 'package:flutter/material.dart';
import 'package:size_engine/size_engine.dart';

import '../app_state.dart';
import 'add_chart_screen.dart';
import 'brand_screen.dart';
import 'known_size_screen.dart';
import 'profile_menu.dart';

/// Opens the right screen for a shared or pasted shop link.
Future<void> openLink(BuildContext context, String text) async {
  final state = AppScope.read(context);
  final detector = LinkDetector(state.catalog.brands);
  final found = detector.detect(text);
  final messenger = ScaffoldMessenger.of(context);
  if (found == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That does not look like a shop link.')),
    );
    return;
  }
  if (found.brand != null) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrandScreen(
          brandId: found.brand!.id,
          initialCategory: found.category,
        ),
      ),
    );
    return;
  }
  final guessName = found.viaMarketplace ? '' : _nameFromHost(found.host);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              found.viaMarketplace
                  ? 'Which brand is this?'
                  : 'This brand is not in SizeCheck yet',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              found.viaMarketplace
                  ? 'SizeCheck could not tell the brand from this ${found.host} '
                        'link. Search for it, or copy the size chart from the '
                        'product page.'
                  : 'Copy the size chart from the product page and paste it '
                        'in. It takes a few seconds, and you get your size '
                        'straight away.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste its size chart'),
              onPressed: () {
                Navigator.pop(sheet);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddChartScreen(
                      initialBrandName: guessName,
                      initialCategory: found.category,
                      sourceUrl: LinkDetector.extractUri(text)?.toString(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (state.catalog.typical != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_graph),
                label: const Text('Use typical sizes for now'),
                onPressed: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BrandScreen(
                        brandId: Catalog.typicalId,
                        initialCategory: found.category,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

String _nameFromHost(String host) {
  final first = host.split('.').first;
  if (first.isEmpty) return '';
  return first[0].toUpperCase() + first.substring(1);
}

class FindTab extends StatefulWidget {
  const FindTab({super.key, required this.onGoToBody});

  final VoidCallback onGoToBody;

  @override
  State<FindTab> createState() => _FindTabState();
}

class _FindTabState extends State<FindTab> {
  final _link = TextEditingController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _link.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final results = state.catalog.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SizeCheck'),
        actions: const [ProfileMenuButton(), SizedBox(width: 8)],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverList.list(
                  children: [
                    if (!state.active.hasAnyMeasurement) ...[
                      Card(
                        color: scheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start here',
                                style: text.titleMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add your measurements once, or tell SizeCheck '
                                'a size that fits you in any brand.',
                                style: TextStyle(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: widget.onGoToBody,
                                    child: const Text('Add measurements'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const KnownSizeScreen(),
                                      ),
                                    ),
                                    child: const Text(
                                      'I know my size somewhere',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Check a product link', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _link,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              hintText: 'Paste a link from Myntra, Ajio, Zara…',
                              prefixIcon: Icon(Icons.link),
                            ),
                            onSubmitted: (v) => openLink(context, v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => openLink(context, _link.text),
                          child: const Text('Check'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Or pick a brand', style: text.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText:
                            'Search ${state.catalog.brands.length} brands',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => _BrandTile(brand: results[i]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList.list(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: Text(
                          _query.isEmpty
                              ? 'Brand not listed?'
                              : 'Can\'t find "${_query.trim()}"?',
                        ),
                        subtitle: const Text(
                          'Paste its size chart from the product page and get '
                          'your size in seconds.',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddChartScreen(initialBrandName: _query.trim()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.brand});

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = switch (brand.origin) {
      BrandOrigin.indian => 'Indian',
      BrandOrigin.international => 'International',
      BrandOrigin.custom => 'Your chart',
      BrandOrigin.typical => 'Typical',
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(
        backgroundColor: brand.isUserAdded
            ? scheme.tertiaryContainer
            : scheme.primaryContainer,
        child: Text(
          brand.name.isEmpty ? '?' : brand.name[0].toUpperCase(),
          style: TextStyle(
            color: brand.isUserAdded
                ? scheme.onTertiaryContainer
                : scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(brand.name),
      subtitle: Text(
        '$tag · ${brand.categories.length} '
        '${brand.categories.length == 1 ? 'category' : 'categories'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => BrandScreen(brandId: brand.id))),
    );
  }
}
