import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import 'storage.dart';

/// Loads the brand size charts: the newest downloaded copy if there is one,
/// otherwise the copy built into the app.
class DataSource {
  DataSource(this._storage);

  final Storage _storage;

  static const assetPath = 'assets/data/sizecheck_data.json';
  static const cacheName = 'sizecheck_data.json';
  static const remoteUrl =
      'https://raw.githubusercontent.com/MohammedAnasAsif/SizeCheck/main/app/assets/data/sizecheck_data.json';
  static const supportedFormat = 1;

  static bool _isValid(Map<String, dynamic>? json) =>
      json != null &&
      json['format'] == supportedFormat &&
      json['brands'] is List &&
      json['version'] is String;

  Future<Map<String, dynamic>> load() async {
    final bundled = jsonDecode(
      await rootBundle.loadString(assetPath),
    ) as Map<String, dynamic>;
    final cached = await _storage.readJson(cacheName);
    if (_isValid(cached) &&
        (cached!['brand_count'] as int? ?? 0) >=
            (bundled['brand_count'] as int? ?? 0)) {
      return cached;
    }
    return bundled;
  }

  /// Downloads the latest charts. Returns the new data, or null if nothing
  /// changed or the download failed (the app keeps working offline).
  Future<Map<String, dynamic>?> fetchUpdate(String currentVersion) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(remoteUrl));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final text = await res.transform(utf8.decoder).join();
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (!_isValid(json) || json['version'] == currentVersion) return null;
      await _storage.writeString(cacheName, text);
      return json;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
