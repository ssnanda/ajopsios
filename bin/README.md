# bin/

Build + release scripts for **AJ Ops** (`ssnanda/ajopsios`). Same scheme as
`aadnanda-app/bin`.

| script | purpose | output |
|---|---|---|
| `bump-version.sh` | resolve next version → write `pubspec.yaml` → commit `Release AJ Ops X.Y.Z+B` | — |
| `ajopsios-ipa.sh` | build iOS IPA (API `ncllcagents.com`) → optional publish to rolling `ios-latest` + `altstore.json` | `~/Documents/GitHub/ipa/ajopsios.ipa` |
| `ajopsios-apk.sh` | build Android APK/AAB → optional publish to rolling `android-latest` | `~/Documents/GitHub/apk/ajopsios.apk` / `.aab` |

These replace the old **`build-ipa.sh`** and **`release.sh`** (still present —
`git rm bin/build-ipa.sh bin/release.sh` once you're happy with the new ones).
`device-run.sh`, `sim-iphone.sh`, `sim-ipad.sh` are unchanged; rename them to
`ajopsios-sim-*.sh` with `git mv` if you want the prefix everywhere.

## Usage

```bash
./bin/bump-version.sh              # interactive menu, bump + commit
./bin/ajopsios-ipa.sh             # build current version + commit (no push)
./bin/ajopsios-ipa.sh --bump patch
./bin/ajopsios-ipa.sh --bump patch --publish   # + push + roll ios-latest + altstore.json
./bin/ajopsios-apk.sh --aab
./bin/ajopsios-ipa.sh --prune-old              # one-time: delete old v* releases/tags
```

### Default behaviour (no flags)

1. If `--bump`/`--version`/`--no-bump` given, or the working tree is dirty →
   `bump-version.sh` runs (bump `pubspec.yaml`, commit the tree). Clean tree with
   no flags → builds the current version, no bump.
2. Build the IPA / APK.
3. **Stops there** — nothing is pushed, no GitHub release.

`--push` also pushes the branch. `--publish` implies `--push` and additionally:
force-moves the `ios-latest` / `android-latest` tag to HEAD, deletes the old
release, creates a fresh one with the artifact attached, and (iOS) regenerates +
commits `altstore.json`.

## AltStore (iOS auto-update)

Source manifest committed at the repo root, served raw:

```
https://raw.githubusercontent.com/ssnanda/ajopsios/main/altstore.json
```

Add it as a Source in AltStore, install AJ Ops from it, and **Refresh All**
(AltServer running) pulls the newest IPA from the `ios-latest` release.

- AltStore compares `CFBundleShortVersionString` (`1.0.67`) — use
  `bump-version.sh` patch/minor/major, not **build**, or AltStore won't see an update.
- Bundle id: `com.ncllcagents.ajopsios`.
- `--publish` keeps the manifest's `version` / `size` / `downloadURL` in sync.

## Generated files

`.gitignore` now also excludes `ios/Podfile.lock`, `macos/Podfile.lock`, and
`*.ipa/*.apk/*.aab`. Commit the one-time CocoaPods integration diff
(`ios/Podfile`, `*.xcconfig`, `project.pbxproj`, `contents.xcworkspacedata`,
`pubspec.lock`) once — do not untrack those.
