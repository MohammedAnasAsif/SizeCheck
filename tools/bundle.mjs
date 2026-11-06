// Builds app/assets/data/sizecheck_data.json from data/brands/*.json.
//   node bundle.mjs          write the bundle
//   node bundle.mjs --check  fail if the committed bundle is out of date
//
// All values are converted to centimetres and written as [min, max].
// It also builds "typical" charts: for each category, the median of every
// brand that publishes a body-measurement chart, used when a brand is unknown.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';
import {
  BUNDLE_PATH, MEASURES, ALPHA_ORDER, loadBrandFiles, toRange, toCm, round1,
  canonicalAlphaLabel,
} from './lib.mjs';

const MIN_BRANDS_FOR_TYPICAL = 3;

const brands = loadBrandFiles().map((f) => {
  if (f.error) throw new Error(`${f.file}: ${f.error}`);
  const b = f.json;
  return {
    id: b.id,
    name: b.name,
    origin: b.origin,
    aliases: b.aliases,
    domains: b.domains ?? [],
    charts: b.charts.map((c) => ({
      category: c.category,
      basis: c.basis,
      ...(c.fit ? { fit: c.fit } : {}),
      ...(c.region ? { region: c.region } : {}),
      unit: 'cm',
      ...(c.note ? { note: c.note } : {}),
      sizes: c.sizes.map((s) => {
        const out = { label: s.label };
        if (s.alt?.length) out.alt = s.alt;
        for (const m of MEASURES) {
          if (s[m] === undefined) continue;
          out[m] = toRange(s[m]).map((v) => round1(toCm(v, c.unit)));
        }
        return out;
      }),
      source: c.source,
    })),
  };
});

function median(values) {
  const v = [...values].sort((a, b) => a - b);
  const mid = Math.floor(v.length / 2);
  return v.length % 2 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

function buildTypical() {
  const byCategory = new Map();
  for (const b of brands) {
    for (const c of b.charts) {
      if (c.basis !== 'body') continue;
      if (!byCategory.has(c.category)) byCategory.set(c.category, []);
      byCategory.get(c.category).push({ brand: b.id, chart: c });
    }
  }
  const charts = [];
  for (const [category, entries] of [...byCategory.entries()].sort()) {
    const sizes = [];
    for (const label of ALPHA_ORDER) {
      const out = { label };
      let brandsForLabel = new Set();
      for (const m of MEASURES) {
        const mins = [], maxs = [], who = new Set();
        for (const { brand, chart } of entries) {
          const row = chart.sizes.find((s) => canonicalAlphaLabel(s.label) === label);
          if (row && row[m]) { mins.push(row[m][0]); maxs.push(row[m][1]); who.add(brand); }
        }
        if (who.size >= MIN_BRANDS_FOR_TYPICAL) {
          out[m] = [round1(median(mins)), round1(median(maxs))];
          brandsForLabel = new Set([...brandsForLabel, ...who]);
        }
      }
      if (Object.keys(out).length > 1) sizes.push(out);
    }
    if (sizes.length >= 2) {
      const n = new Set(entries.map((e) => e.brand)).size;
      charts.push({
        category,
        basis: 'body',
        unit: 'cm',
        note: `Median of ${n} brands in SizeCheck. Use only when the brand's own chart is unknown.`,
        sizes,
      });
    }
  }
  return charts;
}

const content = { brands, typical: buildTypical() };
const version = createHash('sha256').update(JSON.stringify(content)).digest('hex').slice(0, 12);
const bundle = { format: 1, version, brand_count: brands.length, ...content };
const text = JSON.stringify(bundle) + '\n';

if (process.argv.includes('--check')) {
  const current = existsSync(BUNDLE_PATH) ? readFileSync(BUNDLE_PATH, 'utf8') : '';
  if (current !== text) {
    console.error('The app data bundle is out of date. Run: cd tools && npm run bundle');
    process.exit(1);
  }
  console.log(`OK: bundle is up to date (version ${version}, ${brands.length} brands).`);
} else {
  mkdirSync(dirname(BUNDLE_PATH), { recursive: true });
  writeFileSync(BUNDLE_PATH, text);
  console.log(`Wrote ${BUNDLE_PATH} (version ${version}, ${brands.length} brands, ` +
    `${content.typical.length} typical charts).`);
}
