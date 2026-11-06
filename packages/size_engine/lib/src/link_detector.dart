import 'models.dart';

class DetectedProduct {
  const DetectedProduct({
    required this.brand,
    required this.category,
    required this.host,
    required this.viaMarketplace,
  });

  /// Null when the link is recognised but the brand is not in SizeCheck yet.
  final Brand? brand;

  /// A guess from words in the link, like "jeans" or "women".
  final Category? category;
  final String host;
  final bool viaMarketplace;
}

/// Works out the brand (and often the category) from a shop link.
class LinkDetector {
  LinkDetector(List<Brand> brands) : _brands = brands {
    for (final b in brands) {
      for (final a in b.aliases) {
        _aliases.add((tokens: a.split(' '), brand: b));
      }
    }
    // Longer names first, so "us polo assn" beats "polo".
    _aliases.sort((a, b) => b.tokens.length.compareTo(a.tokens.length));
  }

  final List<Brand> _brands;
  final List<({List<String> tokens, Brand brand})> _aliases = [];

  /// Shops that sell many brands; the brand is found in the link's path.
  static const marketplaces = [
    'myntra.com',
    'ajio.com',
    'amazon.in',
    'amazon.com',
    'flipkart.com',
    'tatacliq.com',
    'nykaafashion.com',
    'nykaa.com',
    'meesho.com',
    'snapdeal.com',
    'shoppersstop.com',
    'lifestylestores.com',
    'centrestage.in',
    'trends.ajio.com',
    'jiomart.com',
    'firstcry.com',
    'zalando.com',
    'asos.com',
  ];

  static final _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

  /// Finds the first link in [text] (shared text often has a title before it).
  static Uri? extractUri(String text) {
    final m = _url.firstMatch(text);
    if (m == null) return null;
    return Uri.tryParse(m[0]!);
  }

  static String _cleanHost(String host) {
    var h = host.toLowerCase();
    for (final p in ['www.', 'm.', 'www2.', 'shop.', 'in.', 'store.']) {
      if (h.startsWith(p)) h = h.substring(p.length);
    }
    return h;
  }

  static bool _hostMatches(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  DetectedProduct? detect(String text) {
    final uri = extractUri(text);
    if (uri == null || uri.host.isEmpty) return null;
    final host = _cleanHost(uri.host);
    final pathText = Uri.decodeComponent('${uri.path} ${uri.query}')
        .toLowerCase();
    final tokens = pathText
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final category = guessCategory(tokens);

    for (final b in _brands) {
      for (final d in b.domains) {
        if (_hostMatches(host, d)) {
          return DetectedProduct(
            brand: b,
            category: category,
            host: host,
            viaMarketplace: false,
          );
        }
      }
    }

    final isMarketplace = marketplaces.any((d) => _hostMatches(host, d));
    if (!isMarketplace) {
      return DetectedProduct(
        brand: null,
        category: category,
        host: host,
        viaMarketplace: false,
      );
    }

    // Brand names usually come first in product links (e.g. myntra.com/
    // jeans/levis/levis-men-511-slim-fit-jeans/123/buy), so take the alias
    // that appears earliest; on a tie, the longer alias.
    Brand? found;
    var foundAt = 1 << 30;
    var foundLength = 0;
    for (final a in _aliases) {
      final at = _indexOfSequence(tokens, a.tokens);
      if (at < 0) continue;
      if (at < foundAt || (at == foundAt && a.tokens.length > foundLength)) {
        found = a.brand;
        foundAt = at;
        foundLength = a.tokens.length;
      }
    }
    return DetectedProduct(
      brand: found,
      category: category,
      host: host,
      viaMarketplace: true,
    );
  }

  static int _indexOfSequence(List<String> tokens, List<String> seq) {
    // Also match names written as one word in links, e.g. "vanheusen".
    final joined = seq.join();
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i] == joined) return i;
      if (i + seq.length > tokens.length) continue;
      var ok = true;
      for (var k = 0; k < seq.length; k++) {
        if (tokens[i + k] != seq[k]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  static const _women = {'women', 'womens', 'woman', 'ladies', 'girls', 'her'};
  static const _men = {'men', 'mens', 'man', 'boys', 'him'};

  /// Guesses the clothing category from words in a link.
  static Category? guessCategory(List<String> tokens) {
    final set = tokens.toSet();
    final women = set.any(_women.contains);
    final men = !women && set.any(_men.contains);
    bool has(List<String> words) => words.any(set.contains);

    if (has([
      'shoes',
      'sneakers',
      'footwear',
      'sandals',
      'heels',
      'boots',
      'loafers',
      'flats',
    ])) {
      return women ? Category.womenFootwear : Category.menFootwear;
    }
    if (has(['dress', 'dresses', 'gown', 'jumpsuit']))
      return Category.womenDresses;
    if (has([
      'jeans',
      'trousers',
      'pants',
      'chinos',
      'joggers',
      'shorts',
      'leggings',
      'palazzos',
      'skirt',
      'skirts',
      'trackpants',
    ])) {
      return women
          ? Category.womenBottoms
          : men
          ? Category.menBottoms
          : Category.unisexBottoms;
    }
    if (!women &&
        has(['shirt', 'shirts']) &&
        !has(['tshirt', 'tshirts', 't'])) {
      return Category.menShirts;
    }
    if (has([
      'tshirt',
      'tshirts',
      'tee',
      'tees',
      'top',
      'tops',
      'kurta',
      'kurtas',
      'kurti',
      'kurtis',
      'sweatshirt',
      'sweatshirts',
      'hoodie',
      'hoodies',
      'polo',
      'shirt',
      'shirts',
      'blouse',
      'jacket',
      'jackets',
      'sweater',
    ])) {
      return women
          ? Category.womenTops
          : men
          ? Category.menTops
          : Category.unisexTops;
    }
    return null;
  }
}
