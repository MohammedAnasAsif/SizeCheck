# Releasing SizeCheck

Releases are built entirely by GitHub Actions ([release.yml](../.github/workflows/release.yml)).

## Make a release

1. Make sure CI is green on `main`.
2. Tag and push (or run **Release** from the Actions tab and enter the tag, e.g. `v0.2.0`):

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

3. In about 15 minutes the [Releases page](https://github.com/MohammedAnasAsif/SizeCheck/releases) has:
   - `SizeCheck-0.2.0-android.apk` (all phones) and per-architecture APKs (`-arm64`, `-arm32`, `-x86_64`)
   - `SizeCheck-0.2.0-android.aab` (for the Play Store; only when signed)
   - `SizeCheck-0.2.0-windows-setup.exe` and `SizeCheck-0.2.0-windows-portable.zip`
   - the size-chart data bundle and SHA-256 checksums

Versions starting with `0.` are marked as pre-releases.

New size charts do not need an app release: the app downloads the latest
`app/assets/data/sizecheck_data.json` from `main` once a day.

## One-time setup: Android signing key

Without a signing key, the APK is signed with a temporary key that changes every build, so people would have to uninstall before each update. Set up a permanent key once:

```bash
keytool -genkeypair -v -keystore sizecheck-release.jks \
  -alias sizecheck -keyalg RSA -keysize 4096 -validity 10000
```

Keep `sizecheck-release.jks` and its passwords somewhere safe (a password manager plus an offline backup). **If the key is lost, installed copies can never be updated again.** Never commit it.

Then add four repository secrets under *Settings → Secrets and variables → Actions*:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 sizecheck-release.jks` (macOS: `base64 -i sizecheck-release.jks`; Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("sizecheck-release.jks"))`) |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `sizecheck` |
| `ANDROID_KEY_PASSWORD` | the key password |

The next tagged release is signed with it automatically.

## Optional later

- **Windows code signing** removes the SmartScreen warning; it needs a code-signing certificate.
- **F-Droid**: the app has no tracking or proprietary libraries, so it qualifies; submit a merge request to [fdroiddata](https://gitlab.com/fdroid/fdroiddata).
- **Play Store**: upload the `.aab` (one-time developer fee).
- **winget**: submit the installer to [winget-pkgs](https://github.com/microsoft/winget-pkgs).
