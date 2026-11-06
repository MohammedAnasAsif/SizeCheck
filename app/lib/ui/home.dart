import 'package:flutter/material.dart';

import '../app_state.dart';
import 'about_tab.dart';
import 'body_tab.dart';
import 'find_tab.dart';
import 'history_tab.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;
  AppState? _state;

  static const _destinations = [
    (Icons.search_outlined, Icons.search, 'Find size'),
    (Icons.straighten_outlined, Icons.straighten, 'My body'),
    (Icons.history_outlined, Icons.history, 'History'),
    (Icons.info_outline, Icons.info, 'About'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.read(context);
    if (!identical(state, _state)) {
      _state?.incomingShare.removeListener(_onShare);
      _state = state;
      state.incomingShare.addListener(_onShare);
      if (!state.active.hasAnyMeasurement && state.profiles.length == 1) {
        _tab = 0;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _onShare());
    }
  }

  @override
  void dispose() {
    _state?.incomingShare.removeListener(_onShare);
    super.dispose();
  }

  void _onShare() {
    final text = _state?.incomingShare.value;
    if (text == null || !mounted) return;
    _state!.incomingShare.value = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _tab = 0);
    openLink(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FindTab(onGoToBody: () => setState(() => _tab = 1)),
      const BodyTab(),
      const HistoryTab(),
      const AboutTab(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(index: _tab, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.checkroom,
                  size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.$1),
                  selectedIcon: Icon(d.$2),
                  label: Text(d.$3),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
