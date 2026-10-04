# bin/

Build + release scripts for **AJ Ops** (`ssnanda/ajopsios`). Same scheme as
`aadnanda-app/bin`.

| script | purpose | output |
|---|---|---|
| `1-bump-version.sh` | resolve next version → write `pubspec.yaml` → commit `Release AJ Ops X.Y.Z+B` | — |
| `2a-ajopsios-ipa.sh` | build + publish iOS IPA to rolling `ios-latest` and update `altstore.json` | `~/Documents/GitHub/ipa/ajopsios.ipa` |
| `2b-sim-iphone.sh` | run the app in the configured iPhone simulator | — |
| `2c-sim-ipad.sh` | run the app in the configured iPad simulator | — |
| `2d-device-run.sh` | run the app on a physical iOS device | — |
| `2e-ajopsios-apk.sh` | build Android APK/AAB → optional publish to rolling `android-latest` | `~/Documents/GitHub/apk/ajopsios.apk` / `.aab` |

## Usage

```bash
./bin/1-bump-version.sh           # interactive menu, bump + commit
./bin/2a-ajopsios-ipa.sh          # bump if dirty, build, push, publish, update AltStore
./bin/2a-ajopsios-ipa.sh --local  # build only; do not push or publish
./bin/2b-sim-iphone.sh
./bin/2c-sim-ipad.sh
./bin/2d-device-run.sh
./bin/2e-ajopsios-apk.sh --aab
```

### Default behaviour (no flags)

1. If `--bump`/`--version`/`--no-bump` given, or the working tree is dirty →
   `bump-version.sh` runs (bump `pubspec.yaml`, commit the tree). Clean tree with
   no flags → builds the current version, no bump.
2. Build the IPA / APK.
3. The iOS script pushes the branch, regenerates `altstore.json`, and refreshes
   the rolling `ios-latest` release by default. Use `--local` to stop after the
   local build. Android publishing remains opt-in with `--publish`.

## AltStore (iOS auto-update)

Source manifest committed at the repo root, served raw:

```
https://raw.githubusercontent.com/ssnanda/ajopsios/main/altstore.json
```

Add it as a Source in AltStore, install AJ Ops from it, and **Refresh All**
(AltServer running) pulls the newest IPA from the `ios-latest` release.

- The generated source includes both `CFBundleShortVersionString` as `version`
  and `CFBundleVersion` as `buildVersion`, plus the IPA's privacy permissions.
- Bundle id: `com.ncllcagents.ajopsios`.
- `--publish` keeps the manifest's `version` / `size` / `downloadURL` in sync.

## Generated files

`.gitignore` now also excludes `ios/Podfile.lock`, `macos/Podfile.lock`, and
`*.ipa/*.apk/*.aab`. Commit the one-time CocoaPods integration diff
(`ios/Podfile`, `*.xcconfig`, `project.pbxproj`, `contents.xcworkspacedata`,
`pubspec.lock`) once — do not untrack those.
