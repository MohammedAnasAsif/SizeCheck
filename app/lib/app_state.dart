import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:size_engine/size_engine.dart';

import 'services/data_source.dart';
import 'services/storage.dart';

enum UnitSystem { cm, inches }

/// Everything the app shows, kept in memory and saved to the device.
class AppState extends ChangeNotifier {
  AppState._(this._storage, this._data);

  /// For tests and previews: nothing is saved or downloaded.
  factory AppState.inMemory(Map<String, dynamic> bundle) {
    final state = AppState._(null, null);
    state._bundle = bundle;
    state._rebuildCatalog();
    state.profiles.add(BodyProfile(id: newId(), name: 'Me'));
    return state;
  }

  final Storage? _storage;
  final DataSource? _data;

  static const _stateFile = 'sizecheck_state.json';

  Map<String, dynamic> _bundle = const {};
  late Catalog catalog;
  final List<BodyProfile> profiles = [];
  final List<Brand> userBrands = [];
  String? _activeId;
  UnitSystem units = UnitSystem.cm;
  DateTime? lastDataCheck;
  bool checkingForUpdate = false;

  /// A link shared from another app, waiting to be shown.
  final ValueNotifier<String?> incomingShare = ValueNotifier(null);

  static Future<AppState> load() async {
    final storage = await Storage.open();
    final state = AppState._(storage, DataSource(storage));
    final saved = await storage.readJson(_stateFile) ?? const {};
    state._restore(saved);
    state._bundle = await state._data!.load();
    state._rebuildCatalog();
    if (state.profiles.isEmpty) {
      state.profiles.add(BodyProfile(id: newId(), name: 'Me'));
      state._activeId = state.profiles.first.id;
    }
    unawaited(state.checkForUpdate());
    return state;
  }

  static String newId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${r.nextInt(1 << 20).toRadixString(36)}';
  }

  void _restore(Map<String, dynamic> json) {
    for (final p in (json['profiles'] as List? ?? const [])) {
      try {
        profiles.add(BodyProfile.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        // Skip a damaged profile rather than failing to start.
      }
    }
    for (final b in (json['user_brands'] as List? ?? const [])) {
      try {
        userBrands.add(Brand.fromJson(b as Map<String, dynamic>));
      } catch (_) {}
    }
    _activeId = json['active'] as String?;
    units = json['units'] == 'in' ? UnitSystem.inches : UnitSystem.cm;
    lastDataCheck = DateTime.tryParse(json['data_checked'] as String? ?? '');
  }

  void _rebuildCatalog() {
    catalog = Catalog.fromBundle(_bundle, userBrands: userBrands);
  }

  Future<void> _save() async => _storage?.writeJson(_stateFile, {
        'format': 1,
        'profiles': [for (final p in profiles) p.toJson()],
        'user_brands': [for (final b in userBrands) b.toJson()],
        'active': _activeId,
        'units': units == UnitSystem.inches ? 'in' : 'cm',
        if (lastDataCheck != null)
          'data_checked': lastDataCheck!.toIso8601String(),
      });

  /// Call after changing a profile or brand in place.
  void changed() {
    notifyListeners();
    unawaited(_save());
  }

  BodyProfile get active => profiles.firstWhere(
        (p) => p.id == _activeId,
        orElse: () => profiles.first,
      );

  void setActive(BodyProfile p) {
    _activeId = p.id;
    changed();
  }

  BodyProfile addProfile(String name) {
    final p = BodyProfile(id: newId(), name: name);
    profiles.add(p);
    _activeId = p.id;
    changed();
    return p;
  }

  void deleteProfile(BodyProfile p) {
    profiles.removeWhere((x) => x.id == p.id);
    if (profiles.isEmpty) profiles.add(BodyProfile(id: newId(), name: 'Me'));
    if (_activeId == p.id) _activeId = profiles.first.id;
    changed();
  }

  void importProfile(BodyProfile p) {
    profiles.add(p);
    _activeId = p.id;
    changed();
  }

  void setUnits(UnitSystem u) {
    units = u;
    changed();
  }

  Brand saveUserChart({
    required String brandName,
    required SizeChart chart,
    String? existingBrandId,
  }) {
    final idx = existingBrandId == null
        ? -1
        : userBrands.indexWhere((b) => b.id == existingBrandId);
    Brand brand;
    if (idx >= 0) {
      final old = userBrands[idx];
      brand = Brand(
        id: old.id,
        name: old.name,
        origin: BrandOrigin.custom,
        aliases: old.aliases,
        charts: [
          ...old.charts.where((c) => c.category != chart.category),
          chart,
        ],
      );
      userBrands[idx] = brand;
    } else {
      final slug = brandName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      brand = Brand(
        id: 'user-${newId()}',
        name: brandName.trim(),
        origin: BrandOrigin.custom,
        aliases: slug.length >= 3 ? [slug] : const [],
        charts: [chart],
      );
      userBrands.add(brand);
    }
    _rebuildCatalog();
    changed();
    return brand;
  }

  void deleteUserBrand(Brand b) {
    userBrands.removeWhere((x) => x.id == b.id);
    _rebuildCatalog();
    changed();
  }

  String get dataVersion => catalog.version;
  int get builtInBrandCount =>
      catalog.brands.where((b) => !b.isUserAdded).length;

  /// Downloads newer size charts at most once a day (or now if [force]).
  Future<bool> checkForUpdate({bool force = false}) async {
    if (checkingForUpdate || _data == null) return false;
    if (!force &&
        lastDataCheck != null &&
        DateTime.now().difference(lastDataCheck!) < const Duration(hours: 24)) {
      return false;
    }
    checkingForUpdate = true;
    notifyListeners();
    final update = await _data.fetchUpdate(catalog.version);
    checkingForUpdate = false;
    lastDataCheck = DateTime.now();
    if (update != null) {
      _bundle = update;
      _rebuildCatalog();
    }
    changed();
    return update != null;
  }
}

/// Makes [AppState] available to every screen.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without rebuilding when it changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
