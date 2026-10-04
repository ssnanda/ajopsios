#!/usr/bin/env bash
set -euo pipefail

# AJ Ops — Android APK/AAB builder (+ optional publish)
# ----------------------------------------------------
# Builds a release APK (or AAB) (API: https://ncllcagents.com) and moves it to
# ~/Documents/GitHub/apk/ajopsios.apk (or .aab).
#
# Version bumping lives in bin/1-bump-version.sh — called when the tree is dirty
# or you pass --bump/--version/--no-bump. By default: build + commit, no push.
#   --push      also push the branch
#   --publish   push + refresh the rolling "android-latest" GitHub release
#
# Common runs:
#   ./bin/2e-ajopsios-apk.sh
#   ./bin/2e-ajopsios-apk.sh --aab
#   ./bin/2e-ajopsios-apk.sh --bump patch --publish
#   ./bin/2e-ajopsios-apk.sh --no-bump
#   ./bin/2e-ajopsios-apk.sh --delete

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/bin"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
APK_OUTPUT_DIR="$HOME/Documents/GitHub/apk"
APP_NAME="AJ Ops"
GITHUB_REPO="ssnanda/ajopsios"
RELEASE_TAG="android-latest"
RELEASE_TITLE="AJ Ops — Android (latest)"
API_BASE_URL="https://ncllcagents.com/wp-json/ajcore/v1"

BUILD_TYPE="apk"
GIT_COMMIT="true"
GIT_PUSH="false"
GITHUB_RELEASE="false"
SKIP_CLEAN="false"
DELETE_ONLY="false"
PRUNE_OLD="false"

usage() {
  cat <<'USAGE'
AJ Ops — Android APK/AAB builder (production API: https://ncllcagents.com).

Usage:
  ./bin/2e-ajopsios-apk.sh [options]

Options:
  --aab                 Build an Android App Bundle instead of an APK
  --version X.Y.Z+B     Force a version (passed to 1-bump-version.sh)
  --bump patch|minor|major|build
  --no-bump             Build the current version, don't bump
  --delete              Delete the local APK/AAB and exit (no build)
  --repo OWNER/REPO     Override GitHub repo (default: ssnanda/ajopsios)
  --push                Push the branch to origin after building
  --publish             Push + refresh the rolling android-latest release
  --prune-old           Delete leftover per-version v* releases/tags, then exit
  --no-git-commit       Rewrite pubspec.yaml only, don't commit the bump
  --quick               Skip flutter clean (faster rebuild)
  --help

Default (no flags): bump if the tree is dirty, build, commit — no push, no release.
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

delete_old_artifact() {
  for ext in apk aab; do
    [[ -f "$APK_OUTPUT_DIR/ajopsios.$ext" ]] && {
      echo "Deleting old artifact: $APK_OUTPUT_DIR/ajopsios.$ext"
      rm -f "$APK_OUTPUT_DIR/ajopsios.$ext"
    }
  done
  return 0
}

build_artifact() {
  echo ""
  if [[ "$SKIP_CLEAN" == "true" ]]; then
    echo "Skipping flutter clean (--quick)..."
  else
    echo "Cleaning..."; flutter clean
  fi

  echo ""; echo "Getting dependencies..."; flutter pub get

  local src
  if [[ "$BUILD_TYPE" == "aab" ]]; then
    echo ""; echo "Building AAB (API: $API_BASE_URL)..."
    flutter build appbundle --release --dart-define="AJ_API_BASE_URL=$API_BASE_URL"
    src="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
  else
    echo ""; echo "Building APK (API: $API_BASE_URL)..."
    flutter build apk --release --dart-define="AJ_API_BASE_URL=$API_BASE_URL"
    src="$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  fi

  [[ -f "$src" ]] || { echo "Error: artifact not found at $src" >&2; exit 1; }

  echo ""; echo "Moving artifact to $ARTIFACT_FINAL_PATH..."
  mkdir -p "$APK_OUTPUT_DIR"
  cp -f "$src" "$ARTIFACT_FINAL_PATH"
  [[ -f "$ARTIFACT_FINAL_PATH" ]] || { echo "Error: failed to copy artifact to $ARTIFACT_FINAL_PATH" >&2; exit 1; }
}

publish_latest_artifact() {
  require_gh
  require_git
  cd "$ROOT_DIR"

  local sha notes
  sha="$(git rev-parse --short HEAD)"
  notes="$APP_NAME Android — version $VERSION ($BUILD_TYPE)
Built $(date '+%Y-%m-%d %H:%M %Z') from commit $sha.
This release always holds the latest build; older builds are not kept."

  echo "Moving rolling tag $RELEASE_TAG to $sha..."
  git tag -f "$RELEASE_TAG" >/dev/null
  git push -f origin "$RELEASE_TAG"

  if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    echo "Removing previous $RELEASE_TAG release..."
    gh release delete "$RELEASE_TAG" --repo "$GITHUB_REPO" --yes
  fi

  gh release create "$RELEASE_TAG" "$ARTIFACT_FINAL_PATH" \
    --repo "$GITHUB_REPO" --title "$RELEASE_TITLE" --notes "$notes"
  echo "GitHub: published $VERSION to $RELEASE_TAG"
  echo "  https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/$(basename "$ARTIFACT_FINAL_PATH")"
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
    --aab) BUILD_TYPE="aab"; shift ;;
    --version) VERSION_OVERRIDE="${2:-}"; shift 2 ;;
    --bump) BUMP_PART="${2:-}"; shift 2 ;;
    --no-bump) NO_BUMP="true"; shift ;;
    --delete) DELETE_ONLY="true"; shift ;;
    --prune-old) PRUNE_OLD="true"; shift ;;
    --repo) GITHUB_REPO="${2:-}"; shift 2 ;;
    --push) GIT_PUSH="true"; shift ;;
    --publish) GIT_PUSH="true"; GITHUB_RELEASE="true"; shift ;;
    --no-git-commit) GIT_COMMIT="false"; shift ;;
    --quick) SKIP_CLEAN="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Error: unknown option $1" >&2; usage; exit 1 ;;
  esac
done

ARTIFACT_FINAL_PATH="$APK_OUTPUT_DIR/ajopsios.$BUILD_TYPE"

if [[ "$DELETE_ONLY" == "true" ]]; then delete_old_artifact; exit 0; fi
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
echo "  $APP_NAME — Android Builder"
echo "  API: $API_BASE_URL"
echo "  Type: $BUILD_TYPE"
echo "════════════════════════════════════════"
echo "Version: $VERSION"
echo "════════════════════════════════════════"
echo ""

delete_old_artifact
build_artifact

if [[ "$GIT_PUSH" == "true" ]]; then
  git_push_branch
fi

if [[ "$GITHUB_RELEASE" == "true" ]]; then
  publish_latest_artifact
fi

echo ""
echo "════════════════════════════════════════"
echo "  Done!"
echo "════════════════════════════════════════"
echo "Version:        $VERSION"
echo "Built artifact: $ARTIFACT_FINAL_PATH"
[[ "$GITHUB_RELEASE" == "true" ]] && echo "Release:        https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG"
echo "════════════════════════════════════════"
echo ""
