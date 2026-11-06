import 'package:flutter/material.dart';

import 'app_state.dart';
import 'services/share_receiver.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  await ShareReceiver((text) => state.incomingShare.value = text).start();
  runApp(SizeCheckApp(state: state));
}

class SizeCheckApp extends StatelessWidget {
  const SizeCheckApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'SizeCheck',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Home(),
      ),
    );
  }
}
