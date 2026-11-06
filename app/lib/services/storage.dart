import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Saves small JSON files in the app's private folder. Nothing leaves the
/// device.
class Storage {
  Storage(this._dir);

  final Directory _dir;

  static Future<Storage> open() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return Storage(dir);
  }

  File _file(String name) => File('${_dir.path}${Platform.pathSeparator}$name');

  Future<Map<String, dynamic>?> readJson(String name) async {
    try {
      final f = _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Writes to a temporary file first so a crash never leaves half a file.
  Future<void> writeJson(String name, Map<String, dynamic> json) async {
    final f = _file(name);
    final tmp = _file('$name.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  Future<void> writeString(String name, String text) async {
    final f = _file(name);
    final tmp = _file('$name.tmp');
    await tmp.writeAsString(text, flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }
}
