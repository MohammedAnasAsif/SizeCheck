import 'measure.dart';

/// How a category is matched: which measurements matter and how much.
enum CategoryGroup { tops, shirts, bottoms, dresses, footwear }

enum Audience { men, women, unisex }

enum Category {
  menTops('men_tops', 'T-shirts & tops', Audience.men, CategoryGroup.tops),
  menShirts('men_shirts', 'Shirts', Audience.men, CategoryGroup.shirts),
  menBottoms(
    'men_bottoms',
    'Jeans & trousers',
    Audience.men,
    CategoryGroup.bottoms,
  ),
  womenTops('women_tops', 'Tops & kurtas', Audience.women, CategoryGroup.tops),
  womenBottoms(
    'women_bottoms',
    'Jeans & trousers',
    Audience.women,
    CategoryGroup.bottoms,
  ),
  womenDresses(
    'women_dresses',
    'Dresses',
    Audience.women,
    CategoryGroup.dresses,
  ),
  unisexTops(
    'unisex_tops',
    'T-shirts & tops',
    Audience.unisex,
    CategoryGroup.tops,
  ),
  unisexBottoms(
    'unisex_bottoms',
    'Jeans & trousers',
    Audience.unisex,
    CategoryGroup.bottoms,
  ),
  menFootwear('men_footwear', 'Footwear', Audience.men, CategoryGroup.footwear),
  womenFootwear(
    'women_footwear',
    'Footwear',
    Audience.women,
    CategoryGroup.footwear,
  );

  const Category(this.id, this.shortLabel, this.audience, this.group);

  final String id;
  final String shortLabel;
  final Audience audience;
  final CategoryGroup group;

  String get label {
    final who = switch (audience) {
      Audience.men => 'Men',
      Audience.women => 'Women',
      Audience.unisex => 'Unisex',
    };
    return '$who · $shortLabel';
  }

  static Category? fromId(String id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Measurements that decide the size, with their weights.
  Map<Measure, double> get weights => switch (group) {
    CategoryGroup.tops => const {
      Measure.chest: 1.0,
      Measure.shoulder: 0.5,
      Measure.waist: 0.35,
      Measure.hip: 0.2,
      Measure.sleeve: 0.15,
      Measure.height: 0.1,
    },
    CategoryGroup.shirts => const {
      Measure.chest: 1.0,
      Measure.neck: 0.7,
      Measure.shoulder: 0.5,
      Measure.waist: 0.35,
      Measure.sleeve: 0.2,
      Measure.height: 0.1,
    },
    CategoryGroup.bottoms => const {
      Measure.waist: 1.0,
      Measure.hip: 0.7,
      Measure.inseam: 0.3,
      Measure.height: 0.1,
    },
    CategoryGroup.dresses => const {
      Measure.chest: 1.0,
      Measure.waist: 0.8,
      Measure.hip: 0.8,
      Measure.shoulder: 0.3,
      Measure.height: 0.1,
    },
    CategoryGroup.footwear => const {Measure.foot: 1.0},
  };

  /// The single most important measurement for this category.
  Measure get primary => switch (group) {
    CategoryGroup.bottoms => Measure.waist,
    CategoryGroup.footwear => Measure.foot,
    _ => Measure.chest,
  };
}

enum ChartBasis {
  /// The chart lists body measurements ("fits chest 96-100 cm").
  body,

  /// The chart lists measurements of the garment itself, which include ease.
  garment;

  static ChartBasis fromName(String? name) =>
      name == 'garment' ? ChartBasis.garment : ChartBasis.body;
}

enum GarmentFit {
  slim,
  regular,
  relaxed;

  static GarmentFit? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// A closed range in cm.
class Range {
  const Range(this.min, this.max);

  factory Range.point(double v) => Range(v, v);

  final double min;
  final double max;

  double get center => (min + max) / 2;
  double get width => max - min;
  bool get isPoint => width < 0.05;
  bool contains(double v) => v >= min && v <= max;

  Range shift(double by) => Range(min + by, max + by);

  List<double> toJson() => [round1(min), round1(max)];

  @override
  bool operator ==(Object other) =>
      other is Range && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() =>
      isPoint ? round1(min).toString() : '${round1(min)}–${round1(max)}';
}

class SizeRow {
  const SizeRow({
    required this.label,
    required this.ranges,
    this.alt = const [],
  });

  final String label;
  final List<String> alt;

  /// Measurement ranges in cm.
  final Map<Measure, Range> ranges;

  String get displayLabel => alt.isEmpty ? label : '$label (${alt.join(', ')})';

  factory SizeRow.fromJson(Map<String, dynamic> json, {String unit = 'cm'}) {
    final ranges = <Measure, Range>{};
    final factor = unit == 'in' ? cmPerInch : 1.0;
    for (final m in Measure.values) {
      final v = json[m.key];
      if (v == null) continue;
      if (v is num) {
        ranges[m] = Range.point(v.toDouble() * factor);
      } else if (v is List && v.length == 2) {
        ranges[m] = Range(
          (v[0] as num).toDouble() * factor,
          (v[1] as num).toDouble() * factor,
        );
      }
    }
    return SizeRow(
      label: json['label'] as String,
      alt: [for (final a in (json['alt'] as List? ?? const [])) a as String],
      ranges: ranges,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    if (alt.isNotEmpty) 'alt': alt,
    for (final e in ranges.entries) e.key.key: e.value.toJson(),
  };
}

class ChartSource {
  const ChartSource({required this.url, required this.verifiedOn});

  final String url;
  final String verifiedOn;

  factory ChartSource.fromJson(Map<String, dynamic> json) => ChartSource(
    url: json['url'] as String,
    verifiedOn: json['verified_on'] as String,
  );

  Map<String, dynamic> toJson() => {'url': url, 'verified_on': verifiedOn};
}

class SizeChart {
  SizeChart({
    required this.category,
    required this.basis,
    required List<SizeRow> sizes,
    this.fit,
    this.region,
    this.note,
    this.source,
  }) : sizes = List.unmodifiable(sizes);

  final Category category;
  final ChartBasis basis;
  final GarmentFit? fit;
  final String? region;
  final String? note;
  final ChartSource? source;

  /// Sizes from smallest to largest, values in cm, as published.
  final List<SizeRow> sizes;

  Set<Measure> get measures => {for (final s in sizes) ...s.ranges.keys};

  /// Returns null if the category is unknown (newer data than this app).
  static SizeChart? fromJson(Map<String, dynamic> json) {
    final category = Category.fromId(json['category'] as String? ?? '');
    if (category == null) return null;
    final unit = json['unit'] as String? ?? 'cm';
    return SizeChart(
      category: category,
      basis: ChartBasis.fromName(json['basis'] as String?),
      fit: GarmentFit.fromName(json['fit'] as String?),
      region: json['region'] as String?,
      note: json['note'] as String?,
      source: json['source'] is Map<String, dynamic>
          ? ChartSource.fromJson(json['source'] as Map<String, dynamic>)
          : null,
      sizes: [
        for (final s in (json['sizes'] as List))
          SizeRow.fromJson(s as Map<String, dynamic>, unit: unit),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category.id,
    'basis': basis.name,
    if (fit != null) 'fit': fit!.name,
    if (region != null) 'region': region,
    'unit': 'cm',
    if (note != null) 'note': note,
    'sizes': [for (final s in sizes) s.toJson()],
    if (source != null) 'source': source!.toJson(),
  };

  /// The chart with single values turned into ranges that meet halfway
  /// between neighbouring sizes, so every size covers a band of bodies.
  SizeChart withExpandedPoints() {
    final expanded = [for (final s in sizes) Map<Measure, Range>.of(s.ranges)];
    for (final m in measures) {
      final idx = [
        for (var i = 0; i < sizes.length; i++)
          if (sizes[i].ranges.containsKey(m)) i,
      ];
      for (var k = 0; k < idx.length; k++) {
        final r = sizes[idx[k]].ranges[m]!;
        if (!r.isPoint) continue;
        final v = r.center;
        final prev = k > 0 ? sizes[idx[k - 1]].ranges[m]!.center : null;
        final next = k < idx.length - 1
            ? sizes[idx[k + 1]].ranges[m]!.center
            : null;
        double lo, hi;
        if (prev != null && next != null) {
          lo = (prev + v) / 2;
          hi = (v + next) / 2;
        } else if (next != null) {
          hi = (v + next) / 2;
          lo = v - (hi - v);
        } else if (prev != null) {
          lo = (prev + v) / 2;
          hi = v + (v - lo);
        } else {
          lo = v - m.tolerance / 2;
          hi = v + m.tolerance / 2;
        }
        // Equal neighbours (e.g. the same inseam for every size) give a
        // zero-width range; fall back to the tolerance.
        if (hi - lo < 0.05) {
          lo = v - m.tolerance / 2;
          hi = v + m.tolerance / 2;
        }
        expanded[idx[k]][m] = Range(lo, hi);
      }
    }
    return SizeChart(
      category: category,
      basis: basis,
      fit: fit,
      region: region,
      note: note,
      source: source,
      sizes: [
        for (var i = 0; i < sizes.length; i++)
          SizeRow(
            label: sizes[i].label,
            alt: sizes[i].alt,
            ranges: expanded[i],
          ),
      ],
    );
  }
}

enum BrandOrigin { indian, international, custom, typical }

class Brand {
  Brand({
    required this.id,
    required this.name,
    required this.origin,
    required this.charts,
    this.aliases = const [],
    this.domains = const [],
  });

  final String id;
  final String name;
  final BrandOrigin origin;
  final List<String> aliases;
  final List<String> domains;
  final List<SizeChart> charts;

  bool get isUserAdded => origin == BrandOrigin.custom;

  Set<Category> get categories => {for (final c in charts) c.category};

  /// Prefers an Indian chart, then a regular fit, for the given category.
  SizeChart? chartFor(Category category) {
    final matches = charts.where((c) => c.category == category).toList();
    if (matches.isEmpty) return null;
    int rank(SizeChart c) =>
        (c.region == 'IN' ? 0 : 2) +
        (c.fit == null || c.fit == GarmentFit.regular ? 0 : 1);
    matches.sort((a, b) => rank(a).compareTo(rank(b)));
    return matches.first;
  }

  factory Brand.fromJson(Map<String, dynamic> json) {
    final origin = switch (json['origin']) {
      'indian' => BrandOrigin.indian,
      'custom' => BrandOrigin.custom,
      'typical' => BrandOrigin.typical,
      _ => BrandOrigin.international,
    };
    return Brand(
      id: json['id'] as String,
      name: json['name'] as String,
      origin: origin,
      aliases: [
        for (final a in (json['aliases'] as List? ?? const [])) a as String,
      ],
      domains: [
        for (final d in (json['domains'] as List? ?? const [])) d as String,
      ],
      charts: [
        for (final c in (json['charts'] as List))
          SizeChart.fromJson(c as Map<String, dynamic>),
      ].whereType<SizeChart>().toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'origin': origin.name,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (domains.isNotEmpty) 'domains': domains,
    'charts': [for (final c in charts) c.toJson()],
  };
}
