#!/usr/bin/env bash
set -euo pipefail

# AJ Ops — iOS IPA builder + publisher
# ------------------------------------
# Builds a release IPA (API: https://ncllcagents.com) and moves it to
# ~/Documents/GitHub/ipa/ajopsios.ipa.
#
# Version bumping lives in bin/1-bump-version.sh — this script calls it when the
# working tree has uncommitted changes (or you pass --bump/--version/--no-bump).
# By default it builds the IPA, pushes the branch, updates altstore.json, and
# refreshes the rolling ios-latest GitHub release.
#
# Common runs:
#   ./bin/2a-ajopsios-ipa.sh
#   ./bin/2a-ajopsios-ipa.sh --quick
#   ./bin/2a-ajopsios-ipa.sh --local

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/bin"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
IPA_OUTPUT_DIR="$HOME/Documents/GitHub/ipa"
APP_NAME="AJ Ops"
IPA_BUILD_DIR="$ROOT_DIR/build/ios/ipa"
IPA_FINAL_PATH="$IPA_OUTPUT_DIR/ajopsios.ipa"
GITHUB_REPO="ssnanda/ajopsios"
RELEASE_TAG="ios-latest"
RELEASE_TITLE="AJ Ops — iOS (latest)"
API_BASE_URL="https://ncllcagents.com/wp-json/ajcore/v1"

ALTSTORE_MANIFEST="$ROOT_DIR/altstore.json"
ALTSTORE_BRANCH="main"
ALTSTORE_SOURCE_ID="com.ncllcagents.ajops.altstore"
ALTSTORE_SOURCE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$ALTSTORE_BRANCH/altstore.json"
ALTSTORE_ICON_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$ALTSTORE_BRANCH/web/icons/Icon-512.png"
ALTSTORE_MIN_IOS="13.0"

GIT_COMMIT="true"
GIT_PUSH="true"
GITHUB_RELEASE="true"
SKIP_CLEAN="false"
DELETE_ONLY="false"
PRUNE_OLD="false"

usage() {
  cat <<'USAGE'
AJ Ops — iOS IPA builder (production API: https://ncllcagents.com).

Usage:
  ./bin/2a-ajopsios-ipa.sh [options]

Options:
  --version X.Y.Z+B     Force a version (passed to 1-bump-version.sh)
  --bump patch|minor|major|build
  --no-bump             Build the current version, don't bump
  --delete              Delete the local IPA and exit (no build)
  --repo OWNER/REPO     Override GitHub repo (default: ssnanda/ajopsios)
  --local               Build locally without pushing or publishing
  --no-publish          Build and push, but don't refresh ios-latest
  --push                Explicitly enable the default push behavior
  --publish             Explicitly enable the default publish behavior
  --prune-old           Delete leftover per-version v* releases/tags, then exit
  --no-git-commit       Rewrite pubspec.yaml only, don't commit the bump
  --quick               Skip flutter clean (faster rebuild)
  --help

Default: bump when dirty, build IPA, push, update altstore.json, and publish ios-latest.
USAGE
}

get_version() { awk '/^version:/ {print $2}' "$PUBSPEC_FILE"; }

validate_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
    echo "Error: version must use X.Y.Z+B format, example 1.0.0+1" >&2
    exit 1
  fi
}

require_files() {
  [[ -f "$PUBSPEC_FILE" ]] || { echo "Error: missing pubspec.yaml at $PUBSPEC_FILE" >&2; exit 1; }
  [[ -x "$BIN_DIR/1-bump-version.sh" ]] || { echo "Error: missing bin/1-bump-version.sh" >&2; exit 1; }
  command -v flutter >/dev/null 2>&1 || { echo "Error: flutter command is required" >&2; exit 1; }
}

require_git() {
  command -v git >/dev/null 2>&1 || { echo "Error: git command is required" >&2; exit 1; }
  git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Error: $ROOT_DIR is not a git repository" >&2
    exit 1
  }
}

require_gh() {
  command -v gh >/dev/null 2>&1 || {
    echo "Error: GitHub CLI required for --publish. 'brew install gh' or drop --publish." >&2
    exit 1
  }
  gh auth status >/dev/null 2>&1 || { echo "Error: run 'gh auth login'." >&2; exit 1; }
}

working_tree_dirty() { [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; }

git_sync_branch() {
  require_git
  cd "$ROOT_DIR"
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "Git: syncing $branch with origin (pull --rebase)..."
  git pull --rebase origin "$branch" || \
    echo "Warning: pull --rebase failed — continuing with local state." >&2
}

git_push_branch() {
  require_git
  cd "$ROOT_DIR"
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  git push origin "$branch"
  echo "Git: pushed $branch"
}

delete_old_ipa() {
  [[ -f "$IPA_FINAL_PATH" ]] && { echo "Deleting old IPA: $IPA_FINAL_PATH"; rm -f "$IPA_FINAL_PATH"; }
  return 0
}

build_ipa() {
  echo ""
  if [[ "$SKIP_CLEAN" == "true" ]]; then
    echo "Skipping flutter clean (--quick)..."
  else
    echo "Cleaning..."; flutter clean
  fi

  echo ""; echo "Getting dependencies..."; flutter pub get

  echo ""; echo "Building IPA (API: $API_BASE_URL)..."
  rm -rf "$IPA_BUILD_DIR"
  flutter build ipa --release --export-method development \
    --dart-define="AJ_API_BASE_URL=$API_BASE_URL"

  local built_ipa
  built_ipa="$(find "$IPA_BUILD_DIR" -maxdepth 1 -name '*.ipa' -print -quit 2>/dev/null || true)"
  [[ -n "$built_ipa" && -f "$built_ipa" ]] || { echo "Error: no IPA in $IPA_BUILD_DIR" >&2; exit 1; }

  echo ""; echo "Moving IPA to $IPA_FINAL_PATH..."
  mkdir -p "$IPA_OUTPUT_DIR"
  mv -f "$built_ipa" "$IPA_FINAL_PATH"
  [[ -f "$IPA_FINAL_PATH" ]] || { echo "Error: failed to move IPA to $IPA_FINAL_PATH" >&2; exit 1; }
}

app_bundle_id() {
  awk -F '[[:space:]]*=[[:space:]]*|;' \
    '/PRODUCT_BUNDLE_IDENTIFIER/ && !/RunnerTests/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' \
    "$ROOT_DIR/ios/Runner.xcodeproj/project.pbxproj"
}

write_altstore_manifest() {
  require_git
  cd "$ROOT_DIR"

  local short="${VERSION%+*}" build="${VERSION#*+}" size date bundle dl
  size="$(stat -f%z "$IPA_FINAL_PATH")"
  date="$(date +%Y-%m-%d)"
  bundle="$(app_bundle_id)"; bundle="${bundle:-com.ncllcagents.ajopsios}"
  dl="https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/$(basename "$IPA_FINAL_PATH")"

  cat > "$ALTSTORE_MANIFEST" <<JSON
{
  "name": "$APP_NAME",
  "identifier": "$ALTSTORE_SOURCE_ID",
  "sourceURL": "$ALTSTORE_SOURCE_URL",
  "apps": [
    {
      "name": "$APP_NAME",
      "bundleIdentifier": "$bundle",
      "developerName": "NC LLC Agents Inc.",
      "subtitle": "Staff app for NC LLC Agents",
      "localizedDescription": "AJ Ops — internal staff app (mail scan, tasks, live chat, service requests).",
      "iconURL": "$ALTSTORE_ICON_URL",
      "tintColor": "1A3C6E",
      "category": "utilities",
      "screenshotURLs": [],
      "versions": [
        {
          "version": "$short",
          "buildVersion": "$build",
          "date": "$date",
          "localizedDescription": "Build $VERSION",
          "downloadURL": "$dl",
          "size": $size,
          "minOSVersion": "$ALTSTORE_MIN_IOS"
        }
      ]
    }
  ],
  "news": []
}
JSON

  git add "$ALTSTORE_MANIFEST"
  if git diff --cached --quiet; then
    echo "AltStore: manifest unchanged"
  else
    git commit -m "AltStore manifest $VERSION"
    echo "AltStore: manifest updated for $VERSION"
  fi
}

publish_latest_ipa() {
  require_gh
  require_git
  cd "$ROOT_DIR"

  local sha notes
  sha="$(git rev-parse --short HEAD)"
  notes="$APP_NAME iOS — version $VERSION
Built $(date '+%Y-%m-%d %H:%M %Z') from commit $sha.
This release always holds the latest build; older builds are not kept."

  echo "Moving rolling tag $RELEASE_TAG to $sha..."
  git tag -f "$RELEASE_TAG" >/dev/null
  git push -f origin "$RELEASE_TAG"

  if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    echo "Removing previous $RELEASE_TAG release..."
    gh release delete "$RELEASE_TAG" --repo "$GITHUB_REPO" --yes
  fi

  gh release create "$RELEASE_TAG" "$IPA_FINAL_PATH" \
    --repo "$GITHUB_REPO" --title "$RELEASE_TITLE" --notes "$notes" --latest
  echo "GitHub: published $VERSION to $RELEASE_TAG"
  echo "  https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/$(basename "$IPA_FINAL_PATH")"
}

prune_old_releases() {
  require_gh
  require_git
  cd "$ROOT_DIR"
  echo "Pruning old per-version releases/tags (v*)..."
  local t
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in
      v[0-9]*) echo "  release $t"; gh release delete "$t" --repo "$GITHUB_REPO" --yes --cleanup-tag || true ;;
    esac
  done < <(gh release list --repo "$GITHUB_REPO" --limit 200 --json tagName -q '.[].tagName' 2>/dev/null || true)
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    echo "  tag $t"
    git push origin ":refs/tags/$t" 2>/dev/null || true
    git tag -d "$t" 2>/dev/null || true
  done < <(git tag -l 'v[0-9]*')
  echo "Prune complete."
}

VERSION_OVERRIDE=""
BUMP_PART=""
NO_BUMP="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION_OVERRIDE="${2:-}"; shift 2 ;;
    --bump) BUMP_PART="${2:-}"; shift 2 ;;
    --no-bump) NO_BUMP="true"; shift ;;
    --delete) DELETE_ONLY="true"; shift ;;
    --prune-old) PRUNE_OLD="true"; shift ;;
    --repo) GITHUB_REPO="${2:-}"; shift 2 ;;
    --local) GIT_PUSH="false"; GITHUB_RELEASE="false"; shift ;;
    --no-publish) GITHUB_RELEASE="false"; shift ;;
    --push) GIT_PUSH="true"; shift ;;
    --publish) GIT_PUSH="true"; GITHUB_RELEASE="true"; shift ;;
    --no-git-commit) GIT_COMMIT="false"; shift ;;
    --quick) SKIP_CLEAN="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Error: unknown option $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$DELETE_ONLY" == "true" ]]; then delete_old_ipa; exit 0; fi
if [[ "$PRUNE_OLD" == "true" ]]; then require_git; prune_old_releases; exit 0; fi

require_files
require_git

if [[ "$SKIP_CLEAN" == "true" ]]; then
  [[ -z "$VERSION_OVERRIDE" && -z "$BUMP_PART" && "$NO_BUMP" == "false" ]] && BUMP_PART="patch"
fi

CURRENT_VERSION="$(get_version)"
validate_version "$CURRENT_VERSION"

RUN_BUMP="false"
if [[ -n "$VERSION_OVERRIDE" || -n "$BUMP_PART" || "$NO_BUMP" == "true" ]]; then
  RUN_BUMP="true"
elif working_tree_dirty; then
  echo "Uncommitted changes detected — running 1-bump-version.sh"
  RUN_BUMP="true"
else
  echo "Working tree clean and no --bump/--version — building current version $CURRENT_VERSION"
fi

if [[ "$RUN_BUMP" == "true" ]]; then
  BUMP_ARGS=()
  [[ -n "$VERSION_OVERRIDE" ]] && BUMP_ARGS+=(--version "$VERSION_OVERRIDE")
  [[ -n "$BUMP_PART" ]] && BUMP_ARGS+=(--bump "$BUMP_PART")
  [[ "$NO_BUMP" == "true" ]] && BUMP_ARGS+=(--no-bump)
  [[ "$GIT_COMMIT" == "true" ]] || BUMP_ARGS+=(--no-commit)
  "$BIN_DIR/1-bump-version.sh" ${BUMP_ARGS[@]+"${BUMP_ARGS[@]}"}
fi

VERSION="$(get_version)"
validate_version "$VERSION"

if [[ "$GIT_PUSH" == "true" ]]; then
  git_sync_branch
fi

echo ""
echo "════════════════════════════════════════"
echo "  $APP_NAME — IPA Builder"
echo "  API: $API_BASE_URL"
echo "════════════════════════════════════════"
echo "Version: $VERSION"
echo "════════════════════════════════════════"
echo ""

delete_old_ipa
build_ipa

if [[ "$GITHUB_RELEASE" == "true" && "$GIT_COMMIT" == "true" ]]; then
  write_altstore_manifest
fi

if [[ "$GIT_PUSH" == "true" ]]; then
  git_push_branch
fi

if [[ "$GITHUB_RELEASE" == "true" ]]; then
  publish_latest_ipa
fi

echo ""
echo "════════════════════════════════════════"
echo "  Done!"
echo "════════════════════════════════════════"
echo "Version:    $VERSION"
echo "Built IPA:  $IPA_FINAL_PATH"
if [[ "$GITHUB_RELEASE" == "true" ]]; then
  echo "Release:    https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG"
  echo "AltStore:   $ALTSTORE_SOURCE_URL"
fi
echo "════════════════════════════════════════"
echo ""
