# Contributing to SizeCheck

Thank you! The most valuable contribution is **size charts**: each brand added makes the app useful to more people.

## Add or update a brand

### The easy way (no coding)

[Open an issue](https://github.com/MohammedAnasAsif/SizeCheck/issues/new?template=add-brand.yml) with the brand name, a link to its official size chart, and the chart copied in. A maintainer turns it into a data file.

Or, in the app: *Add a size chart → Also share it so everyone gets this brand*. That opens a pre-filled issue for you.

### The direct way (pull request)

Create `data/brands/<brand-id>.json`. Example:

```json
{
  "id": "example-brand",
  "name": "Example Brand",
  "origin": "indian",
  "aliases": ["example brand"],
  "domains": ["examplebrand.in"],
  "charts": [
    {
      "category": "men_tops",
      "basis": "body",
      "region": "IN",
      "unit": "in",
      "sizes": [
        { "label": "S", "alt": ["38"], "chest": [36, 38], "waist": [30, 32] },
        { "label": "M", "alt": ["40"], "chest": [38, 40], "waist": [32, 34] },
        { "label": "L", "alt": ["42"], "chest": [40, 42], "waist": [34, 36] }
      ],
      "source": {
        "url": "https://examplebrand.in/pages/size-chart",
        "verified_on": "2026-11-06"
      }
    }
  ]
}
```

Then run the checks:

```bash
cd tools
npm ci
npm run validate   # explains any problem in plain words
npm run bundle     # updates app/assets/data/sizecheck_data.json; commit it too
```

CI runs the same checks on every pull request.

### Rules for size data

1. **Official sources only.** Copy from the brand's own website or the brand's own size guide. Do not use size-chart aggregator sites, and do not estimate. Put the link in `source.url` and the date you checked it in `source.verified_on`.
2. **Keep the brand's numbers and unit.** If the chart is in inches, set `"unit": "in"` and copy the inches. A single number (`"chest": 38`) or a range (`"chest": [36, 38]`) are both fine.
3. **Body or garment?** `"basis": "body"` when the chart says *body measurements*, *to fit*, or tells you to measure yourself. `"basis": "garment"` when it lists measurements of the clothing (*garment*, *product*, *flat*, *actual* measurements). This matters: a garment chest of 104 cm fits a body of about 94 cm.
4. **Sizes from smallest to largest.**
5. **Use the measurement names SizeCheck knows:** `chest` (also bust), `waist`, `hip` (also seat), `shoulder` (shoulder to shoulder across the back), `neck` (collar), `sleeve` (shoulder tip to wrist only; leave out sleeves measured from the centre of the back), `inseam`, `height`, `foot`. Leave out garment length.
6. **Categories:** `men_tops`, `men_shirts` (formal/collar-sized shirts), `men_bottoms`, `women_tops` (includes kurtas), `women_bottoms`, `women_dresses`, `unisex_tops`, `unisex_bottoms`, `men_footwear`, `women_footwear`.
7. **Aliases** are the brand name as it appears in shop links, lowercase, words separated by spaces (`"van heusen"`, `"us polo assn"`). They let SizeCheck recognise the brand in a Myntra or Ajio link.
8. `origin` is `indian` or `international`.

If a brand publishes a different chart for each product, use its standard or most common chart (for example its regular-fit T-shirt) and say so in `note`.

## Code

- `packages/size_engine` is plain Dart with unit tests; run `dart test` there.
- `app` is the Flutter app; run `flutter analyze` and `flutter test` there.
- Keep it simple, private (no tracking, no accounts) and offline-first.

By contributing you agree that your code is licensed under Apache-2.0 and your size data under CC BY 4.0.
