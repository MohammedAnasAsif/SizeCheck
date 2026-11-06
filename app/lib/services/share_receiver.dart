import 'dart:io';

import 'package:flutter/services.dart';

/// Receives links shared to SizeCheck from other Android apps.
class ShareReceiver {
  ShareReceiver(this.onText);

  final void Function(String text) onText;
  static const _channel = MethodChannel('sizecheck/share');

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        onText(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('takeSharedText');
      if (initial != null && initial.isNotEmpty) onText(initial);
    } on PlatformException {
      // Nothing shared.
    } on MissingPluginException {
      // Running in tests.
    }
  }
}
