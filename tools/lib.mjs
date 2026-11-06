// Shared helpers for the data tools.
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
export const BRANDS_DIR = join(ROOT, 'data', 'brands');
export const SCHEMA_PATH = join(ROOT, 'data', 'schema', 'brand.schema.json');
export const BUNDLE_PATH = join(ROOT, 'app', 'assets', 'data', 'sizecheck_data.json');

export const MEASURES = ['chest', 'waist', 'hip', 'shoulder', 'neck', 'sleeve', 'inseam', 'height', 'foot'];

// Plausible adult body ranges in cm. Anything outside is almost certainly a typo
// or a unit mix-up (inches entered as cm, or the other way round).
export const PLAUSIBLE_CM = {
  chest: [60, 190],
  waist: [50, 180],
  hip: [65, 190],
  shoulder: [30, 65],
  neck: [28, 56],
  sleeve: [40, 95],
  inseam: [50, 105],
  height: [130, 215],
  foot: [20, 34],
};

// Words that must never be used as a brand alias, because they appear in
// almost every shop link and would cause false brand matches.
export const ALIAS_STOP_WORDS = new Set([
  'men', 'mens', 'women', 'womens', 'kids', 'boys', 'girls', 'unisex',
  'shirt', 'shirts', 'tshirt', 'tshirts', 't', 'jeans', 'trousers', 'pants',
  'dress', 'dresses', 'top', 'tops', 'kurta', 'kurtas', 'shoes', 'buy',
  'online', 'india', 'fashion', 'clothing', 'apparel', 'cotton', 'slim',
  'regular', 'fit', 'casual', 'formal', 'p', 'product', 'the', 'and', 'for',
]);

export function loadBrandFiles() {
  return readdirSync(BRANDS_DIR)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((file) => {
      const path = join(BRANDS_DIR, file);
      let json;
      try {
        json = JSON.parse(readFileSync(path, 'utf8'));
      } catch (e) {
        return { file, path, error: `Invalid JSON: ${e.message}` };
      }
      return { file, path, id: basename(file, '.json'), json };
    });
}

export function toRange(value) {
  return Array.isArray(value) ? [value[0], value[1]] : [value, value];
}

export function toCm(n, unit) {
  return unit === 'in' ? n * 2.54 : n;
}

export function round1(n) {
  return Math.round(n * 10) / 10;
}

// "2XL" and "XXL" are the same size; "3XL" and "XXXL" too.
export function canonicalAlphaLabel(label) {
  const l = label.trim().toUpperCase().replace(/\s+/g, '');
  const m = l.match(/^(\d)XL$/);
  if (m) return m[1] === '1' ? 'XL' : `${m[1]}XL`;
  const x = l.match(/^(X+)L$/);
  if (x) return x[1].length === 1 ? 'XL' : `${x[1].length}XL`;
  const s = l.match(/^(X+)S$/);
  if (s) return s[1].length === 1 ? 'XS' : `${s[1].length}XS`;
  return l;
}

export const ALPHA_ORDER = ['3XS', '2XS', 'XS', 'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL'];
