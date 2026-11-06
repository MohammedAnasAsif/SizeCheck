/// Body measurements SizeCheck understands. All values are stored in cm.
enum Measure {
  chest('chest', 'Chest / bust', 4.0),
  waist('waist', 'Waist', 3.0),
  hip('hip', 'Hip', 4.0),
  shoulder('shoulder', 'Shoulder width', 2.0),
  neck('neck', 'Neck', 1.5),
  sleeve('sleeve', 'Sleeve length', 3.0),
  inseam('inseam', 'Inseam (inside leg)', 3.0),
  height('height', 'Height', 6.0),
  foot('foot', 'Foot length', 0.6);

  const Measure(this.key, this.label, this.tolerance);

  /// Key used in the JSON data files.
  final String key;

  /// Human-readable name.
  final String label;

  /// How many cm outside a size's range counts as "one step" of misfit.
  final double tolerance;

  /// Measurements that wrap around the body and change with weight.
  bool get isGirth =>
      this == chest || this == waist || this == hip || this == neck;

  static Measure? fromKey(String key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }
}

const double cmPerInch = 2.54;

double inchesToCm(double inches) => inches * cmPerInch;
double cmToInches(double cm) => cm / cmPerInch;

/// Rounds to one decimal place.
double round1(double v) => (v * 10).roundToDouble() / 10;
