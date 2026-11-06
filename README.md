# SizeCheck

**One body profile, the right size in every brand.**

SizeCheck is a free, open-source app for Android and Windows. You enter your measurements once (or just tell it a size that fits you in one brand), and it tells you which size to buy in any other brand — so fewer online orders come back because of inconsistent sizing.

- **Works with any brand.** Brands in the shared dataset work out of the box. For any other brand, even a tiny one, copy the size chart from the product page, paste it into SizeCheck and get your size in seconds.
- **Share a link, get a size.** On Android, share a product from Myntra, Ajio, Amazon, Zara, H&M or any shop to SizeCheck. It spots the brand and the clothing type from the link.
- **Learns your fit.** Tell it how something fit ("a bit tight") and it adjusts its advice for that brand.
- **Private by design.** No account, no tracking, no server. Your measurements never leave your device. The app only goes online to download updated size charts from this repository.
- **Honest.** Every recommendation shows how sure it is, which measurement decided it, whether you are between sizes, and where the chart came from.

## Download

Get the latest version from the [Releases page](https://github.com/MohammedAnasAsif/SizeCheck/releases/latest):

| Platform | File |
|---|---|
| Android 7+ | `SizeCheck-x.y.z-android.apk` (works on every phone) or the smaller `-arm64.apk` for most phones from the last few years |
| Windows 10/11 | `SizeCheck-x.y.z-windows-setup.exe` (no admin rights needed), or the portable `.zip` |

On Android, allow "Install unknown apps" for your browser or file manager when asked. Windows may show a SmartScreen warning because the app is not code-signed yet: choose *More info → Run anyway*.

## How it works

1. **Your body profile** stores chest/bust, waist, hip, height, and optionally shoulder, neck, sleeve, inseam and foot length. You can keep profiles for the whole family and move them between devices with a profile code.
2. **Size charts** live in [`data/brands/`](data/brands), one JSON file per brand, copied from each brand's official size chart with a link to the source and the date it was checked.
3. **Matching** (in [`packages/size_engine`](packages/size_engine)) scores every size against your measurements, weighting what matters for the garment (chest for tops, waist and hip for jeans, neck for shirts). Charts that list *garment* measurements are converted to body measurements by subtracting typical ease. It reports the best size, a confidence level, the neighbouring size when you are in between, and which measurements to add for a better answer.
4. **Unknown brand?** Paste its chart, or use *typical sizes*: the median of every brand in the dataset for that category.

## Help grow the size data

Every brand added helps everyone. See [CONTRIBUTING.md](CONTRIBUTING.md) — adding a brand is one JSON file, and CI checks it for you. Brands we want next are listed in [data/BRANDS-WANTED.md](data/BRANDS-WANTED.md).

From inside the app, *Add a size chart → Also share it so everyone gets this brand* opens a pre-filled GitHub issue with the chart.

## Build from source

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) 3.47.9 (the version CI uses), Node.js 22 for the data tools.

```bash
# Check the size data and rebuild the bundle the app ships with
cd tools && npm ci && npm run validate && npm run bundle && cd ..

# Engine tests
cd packages/size_engine && dart pub get && dart test && cd ../..

# Run the app
cd app
flutter pub get
flutter run -d windows        # or an Android device/emulator
flutter build apk --release   # Android
flutter build windows         # Windows
```

## Project layout

```
app/                    Flutter app (Android + Windows)
packages/size_engine/   Matching engine, chart parser, link detection (pure Dart, tested)
data/brands/            One JSON size-chart file per brand (CC BY 4.0)
data/schema/            JSON schema for brand files
tools/                  Validator and bundler for the data
.github/workflows/      CI and release builds
```

Releases are built by GitHub Actions when a version tag is pushed; see [docs/RELEASING.md](docs/RELEASING.md).

## Licence

Code: [Apache-2.0](LICENSE). Size data in `data/`: [CC BY 4.0](data/LICENSE). Brand names and trademarks belong to their owners and are used only to identify which size chart applies. SizeCheck is not affiliated with any brand.
