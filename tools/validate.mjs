// Validates every data/brands/*.json file.
// Usage: node validate.mjs
// Exits with code 1 and prints every problem found if anything is wrong.
import Ajv from 'ajv';
import { readFileSync } from 'node:fs';
import {
  SCHEMA_PATH, MEASURES, PLAUSIBLE_CM, ALIAS_STOP_WORDS,
  loadBrandFiles, toRange, toCm, round1,
} from './lib.mjs';

const ajv = new Ajv({ allErrors: true, strict: false });
const validateSchema = ajv.compile(JSON.parse(readFileSync(SCHEMA_PATH, 'utf8')));

const errors = [];
const warnings = [];
const err = (file, msg) => errors.push(`${file}: ${msg}`);
const warn = (file, msg) => warnings.push(`${file}: ${msg}`);

const files = loadBrandFiles();
const aliasOwner = new Map();
const domainOwner = new Map();
const today = new Date().toISOString().slice(0, 10);

for (const f of files) {
  if (f.error) { err(f.file, f.error); continue; }
  const b = f.json;

  if (!validateSchema(b)) {
    for (const e of validateSchema.errors) {
      err(f.file, `${e.instancePath || '(root)'} ${e.message}`);
    }
    continue;
  }

  if (b.id !== f.id) err(f.file, `id "${b.id}" must match the file name "${f.id}"`);

  for (const alias of b.aliases) {
    if (ALIAS_STOP_WORDS.has(alias)) err(f.file, `alias "${alias}" is too generic`);
    if (alias.length < 3) err(f.file, `alias "${alias}" is too short (min 3 characters)`);
    if (aliasOwner.has(alias) && aliasOwner.get(alias) !== b.id) {
      err(f.file, `alias "${alias}" is already used by ${aliasOwner.get(alias)}`);
    }
    aliasOwner.set(alias, b.id);
  }
  for (const d of b.domains ?? []) {
    if (domainOwner.has(d) && domainOwner.get(d) !== b.id) {
      err(f.file, `domain "${d}" is already used by ${domainOwner.get(d)}`);
    }
    domainOwner.set(d, b.id);
  }

  const chartKeys = new Set();
  b.charts.forEach((c, ci) => {
    const where = `charts[${ci}] (${c.category})`;
    const key = `${c.category}|${c.region ?? ''}|${c.fit ?? ''}`;
    if (chartKeys.has(key)) err(f.file, `${where}: duplicate chart for the same category, region and fit`);
    chartKeys.add(key);

    if (c.source.verified_on > today) err(f.file, `${where}: verified_on is in the future`);

    const labels = new Set();
    for (const s of c.sizes) {
      const l = s.label.trim().toUpperCase();
      if (labels.has(l)) err(f.file, `${where}: size "${s.label}" appears twice`);
      labels.add(l);
    }

    for (const m of MEASURES) {
      const rows = c.sizes.filter((s) => s[m] !== undefined);
      if (rows.length === 0) continue;
      if (rows.length !== c.sizes.length) {
        warn(f.file, `${where}: "${m}" is missing for some sizes`);
      }
      let prevCenter = null;
      for (const s of rows) {
        const [lo, hi] = toRange(s[m]).map((v) => toCm(v, c.unit));
        if (lo > hi) err(f.file, `${where}: size ${s.label} ${m} min is bigger than max`);
        const [pmin, pmax] = PLAUSIBLE_CM[m];
        if (lo < pmin || hi > pmax) {
          err(f.file, `${where}: size ${s.label} ${m} = ${round1(lo)}-${round1(hi)} cm looks wrong ` +
            `(expected ${pmin}-${pmax} cm). Check the unit ("${c.unit}").`);
        }
        const center = (lo + hi) / 2;
        if (prevCenter !== null && center < prevCenter - 1) {
          err(f.file, `${where}: ${m} gets smaller at size ${s.label}; sizes must be listed smallest to largest`);
        }
        prevCenter = center;
      }
    }

    const hasGirth = c.sizes.some((s) => s.chest || s.waist || s.hip || s.foot || s.neck);
    if (!hasGirth) err(f.file, `${where}: needs at least one of chest, waist, hip, neck or foot`);
  });
}

for (const w of warnings) console.warn(`warning  ${w}`);
if (errors.length) {
  for (const e of errors) console.error(`error    ${e}`);
  console.error(`\n${errors.length} problem(s) in ${files.length} brand file(s).`);
  process.exit(1);
}
console.log(`OK: ${files.length} brand file(s) valid.`);
