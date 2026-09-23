# Android build — Dustline Strike

## Preset

`export_presets.cfg` contains one `Android` preset (debug-friendly):
- package `com.dustlinestrike.game`, name `Dustline Strike`, landscape, GLES3/Compatibility
- `version/code` bump per release, `version/name` = tag
- architectures `arm64-v8a` (+ `armeabi-v7a` optional for old devices; CI builds arm64 only for speed)

## Local debug build (needs SDK + templates)

1. Install Godot 4.7.2 export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`
2. Install Android SDK cmdline-tools + platform-34 + build-tools + JDK 17.
3. `godot --headless --path . --export-debug "Android" build/dustline-debug.apk`

If SDK/JDK/templates are missing, the script tells you exactly what is missing (no silent fail).

## CI build (free runners)

`.github/workflows/android-build.yml`:
1. checkout → setup JDK 17 → setup Android SDK → install Godot 4.7.2 + templates → `godot --headless --import` → validate → export debug APK → upload artifact.
2. Release AAB only on tags `v*` AND when `ANDROID_KEYSTORE_BASE64` + passwords exist as GitHub Secrets. Secrets are never logged.

Cost: all steps use `ubuntu-latest` free minutes + free Godot binaries. No paid runners/GPU. If Free minutes run out, CI still validates (import+tests) without exporting.

## Signing — human approval required

Debug builds need no key. Release needs your keystore:
- Create once: `keytool -genkey -v -keystore dustline-release.keystore -alias dustline -keyalg RSA -keysize 2048 -validity 10000`
- Add as GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Never commit the file.
- A repo-root `release-battlearena.keystore` from another project (if present on your machine) is NOT used automatically — confirm before reuse.
