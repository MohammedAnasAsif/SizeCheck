import 'models.dart';

/// All brands SizeCheck knows: the shared dataset plus charts the person
/// added themselves.
class Catalog {
  Catalog({
    required this.version,
    required List<Brand> brands,
    required this.typical,
    List<Brand> userBrands = const [],
  }) : brands = [
         ...userBrands,
         // A user's own chart for a brand replaces nothing; both are shown.
         ...brands,
       ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final String version;
  final List<Brand> brands;

  /// "Typical sizes" brand, built from the median of all brands. Used when
  /// a brand has no chart in SizeCheck.
  final Brand? typical;

  static const typicalId = '_typical';

  factory Catalog.fromBundle(
    Map<String, dynamic> json, {
    List<Brand> userBrands = const [],
  }) {
    final typicalCharts = [
      for (final c in (json['typical'] as List? ?? const []))
        SizeChart.fromJson(c as Map<String, dynamic>),
    ].whereType<SizeChart>().toList();
    return Catalog(
      version: json['version'] as String? ?? 'unknown',
      brands: [
        for (final b in (json['brands'] as List? ?? const []))
          Brand.fromJson(b as Map<String, dynamic>),
      ],
      typical: typicalCharts.isEmpty
          ? null
          : Brand(
              id: typicalId,
              name: 'Typical sizes',
              origin: BrandOrigin.typical,
              charts: typicalCharts,
            ),
      userBrands: userBrands,
    );
  }

  Brand? byId(String id) {
    if (id == typicalId) return typical;
    for (final b in brands) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Brands whose name or alias contains [query], best matches first.
  List<Brand> search(String query) {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    if (q.isEmpty) return brands;
    final compact = q.replaceAll(' ', '');
    int rank(Brand b) {
      final name = b.name.toLowerCase();
      if (name == q) return 0;
      if (name.startsWith(q)) return 1;
      if (b.aliases.any(
        (a) => a.startsWith(q) || a.replaceAll(' ', '').startsWith(compact),
      )) {
        return 2;
      }
      if (name.contains(q) || b.aliases.any((a) => a.contains(q))) return 3;
      return 99;
    }

    final hits = brands.where((b) => rank(b) < 99).toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0
            ? r
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return hits;
  }
}
