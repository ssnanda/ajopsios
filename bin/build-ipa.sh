#!/usr/bin/env bash
set -euo pipefail

# AJ Ops — iOS IPA builder (production)
# ----------------------------------------
# Builds a production IPA pointed at https://ncllcagents.com (the AJCore Master site)
# Output: ~/Documents/GitHub/ipa/ajopsios.ipa
#
# Common runs:
#   ./bin/build-ipa.sh
#   ./bin/build-ipa.sh --quick
#   ./bin/build-ipa.sh --bump patch --git-commit --push --github-release
#   ./bin/build-ipa.sh --delete

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
IPA_OUTPUT_DIR="$HOME/Documents/GitHub/ipa"
IPA_BUILD_PATH="$ROOT_DIR/build/ios/ipa/ajopsios.ipa"
IPA_FINAL_PATH="$IPA_OUTPUT_DIR/ajopsios.ipa"
GITHUB_REPO="ssnanda/ajopsios"
TAG_PREFIX="v"
API_BASE_URL="https://ncllcagents.com/wp-json/ajcore/v1"

GITHUB_RELEASE="false"
GIT_COMMIT="false"
GIT_PUSH="false"
SKIP_CLEAN="false"
DELETE_ONLY="false"
BUMP_COMMIT="true"

usage() {
  cat <<'USAGE'
AJ Ops — iOS IPA builder (production: https://ncllcagents.com).

Usage:
  ./bin/build-ipa.sh [options]

Examples:
  ./bin/build-ipa.sh
  ./bin/build-ipa.sh --quick
  ./bin/build-ipa.sh --bump patch --git-commit --push --github-release
  ./bin/build-ipa.sh --delete

Options:
  --version X.Y.Z+B
  --bump patch|minor|major|build
  --no-bump
  --no-bump-commit      Leave the version bump uncommitted (old behavior — not recommended,
                         leaves pubspec.yaml dirty for the whole build)
  --delete              Delete old IPA and exit (no build)
  --repo OWNER/REPO
  --github-release
  --no-github-release
  --git-commit
  --no-git-commit
  --push
  --no-push
  --quick               Skip flutter clean (faster rebuild)
  --help
USAGE
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer=""

  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n]: " answer
    answer="${answer:-y}"
  else
    read -r -p "$prompt [y/N]: " answer
    answer="${answer:-n}"
  fi

  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

get_version() {
  awk '/^version:/ {print $2}' "$PUBSPEC_FILE"
}

validate_version() {
  local version="$1"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
    echo "Error: version must use X.Y.Z+B format, example 1.0.0+1" >&2
    exit 1
  fi
}

parse_version() {
  local version="$1"
  local version_part build_part
  version_part="${version%+*}"
  build_part="${version#*+}"
  echo "$version_part" "$build_part"
}

bump_version() {
  local current="$1"
  local part="$2"
  local version_part build_part major minor patch build

  read -r version_part build_part <<< "$(parse_version "$current")"
  IFS='.' read -r major minor patch <<< "$version_part"

  case "$part" in
    patch) patch=$((patch + 1)); build=$((build + 1)) ;;
    minor) minor=$((minor + 1)); patch=0; build=$((build + 1)) ;;
    major) major=$((major + 1)); minor=0; patch=0; build=$((build + 1)) ;;
    build) build=$((build + 1)) ;;
    *) echo "Error: bump must be patch, minor, major, or build" >&2; exit 1 ;;
  esac

  echo "$major.$minor.$patch+$build"
}

set_version() {
  local version="$1"
  validate_version "$version"
  sed -i '' "s/^version: .*/version: $version/" "$PUBSPEC_FILE"
}

choose_version_from_menu() {
  local current="$1"
  local choice=""

  while true; do
    cat >&2 <<MENU
Current version: $current

Choose release type:
  1) patch  ($(bump_version "$current" patch))
  2) minor  ($(bump_version "$current" minor))
  3) major  ($(bump_version "$current" major))
  4) build  ($(bump_version "$current" build))
  5) custom version
  6) no bump / package current version
MENU

    read -r -p "Enter choice (1-6, default=1): " choice
    choice="${choice:-1}"

    case "$choice" in
      1|patch|p) echo "$(bump_version "$current" patch)"; return 0 ;;
      2|minor|m) echo "$(bump_version "$current" minor)"; return 0 ;;
      3|major|M) echo "$(bump_version "$current" major)"; return 0 ;;
      4|build|b) echo "$(bump_version "$current" build)"; return 0 ;;
      5|custom|c)
        read -r -p "Enter version X.Y.Z+B: " custom_version
        validate_version "$custom_version"
        echo "$custom_version"
        return 0
        ;;
      6|none|no|n|current) echo "$current"; return 0 ;;
      *) echo "Please choose 1, 2, 3, 4, 5, or 6." >&2; echo "" >&2 ;;
    esac
  done
}

require_files() {
  [[ -f "$PUBSPEC_FILE" ]] || { echo "Error: missing pubspec.yaml at $PUBSPEC_FILE" >&2; exit 1; }
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
  command -v gh >/dev/null 2>&1 || { echo "Error: GitHub CLI is required. Install with: brew install gh" >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Error: GitHub CLI is not logged in. Run: gh auth login" >&2; exit 1; }
}

delete_old_ipa() {
  if [[ -f "$IPA_FINAL_PATH" ]]; then
    echo "Deleting old IPA: $IPA_FINAL_PATH"
    rm -f "$IPA_FINAL_PATH"
  fi
}

build_ipa() {
  echo ""
  if [[ "$SKIP_CLEAN" == "true" ]]; then
    echo "Skipping flutter clean (--quick)..."
  else
    echo "Cleaning..."
    flutter clean
  fi

  echo ""
  echo "Getting dependencies..."
  flutter pub get

  echo ""
  echo "Building IPA (API: $API_BASE_URL)..."
  flutter build ipa --release --export-method development \
    --dart-define="AJ_API_BASE_URL=$API_BASE_URL"

  [[ -f "$IPA_BUILD_PATH" ]] || { echo "Error: IPA not found at $IPA_BUILD_PATH" >&2; exit 1; }

  echo ""
  echo "Moving IPA to $IPA_OUTPUT_DIR..."
  mkdir -p "$IPA_OUTPUT_DIR"
  mv -f "$IPA_BUILD_PATH" "$IPA_FINAL_PATH"

  [[ -f "$IPA_FINAL_PATH" ]] || { echo "Error: Failed to move IPA to $IPA_FINAL_PATH" >&2; exit 1; }
}

commit_version_bump() {
  require_git
  cd "$ROOT_DIR"

  if git diff --quiet -- "$PUBSPEC_FILE"; then
    return 0
  fi

  git add "$PUBSPEC_FILE"
  git commit -m "Bump version to $VERSION"
  echo "Git: committed version bump ($VERSION)"
}

git_commit_release_files() {
  require_git
  cd "$ROOT_DIR"

  git add -u

  while IFS= read -r file; do
    case "$file" in
      build/*|*.ipa|*.zip) continue ;;
      *) git add "$file" ;;
    esac
  done < <(git ls-files --others --exclude-standard)

  if git diff --cached --quiet; then
    echo "Git: nothing to commit"
    return 0
  fi

  git commit -m "Release AJ Ops $VERSION"
}

git_create_tag() {
  require_git
  cd "$ROOT_DIR"
  local tag="$TAG_PREFIX$VERSION"

  if git rev-parse "$tag" >/dev/null 2>&1; then
    echo "Git: tag already exists: $tag"
  else
    git tag "$tag"
    echo "Git: created tag $tag"
  fi
}

git_push_release() {
  require_git
  cd "$ROOT_DIR"

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  git push origin "$current_branch"
  git push origin "$TAG_PREFIX$VERSION"
}

publish_github_release() {
  require_gh

  local tag="$TAG_PREFIX$VERSION"
  local title="AJ Ops $VERSION"

  if gh release view "$tag" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    gh release upload "$tag" "$IPA_FINAL_PATH" --repo "$GITHUB_REPO" --clobber
    echo "GitHub: uploaded IPA to existing release $tag"
  else
    gh release create "$tag" "$IPA_FINAL_PATH" \
      --repo "$GITHUB_REPO" \
      --title "$title" \
      --notes "AJ Ops iOS release $VERSION"
    echo "GitHub: created release $tag and uploaded IPA"
  fi
}

VERSION_OVERRIDE=""
BUMP_PART=""
NO_BUMP="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION_OVERRIDE="${2:-}"; shift 2 ;;
    --bump) BUMP_PART="${2:-}"; shift 2 ;;
    --no-bump) NO_BUMP="true"; shift ;;
    --no-bump-commit) BUMP_COMMIT="false"; shift ;;
    --delete) DELETE_ONLY="true"; shift ;;
    --repo) GITHUB_REPO="${2:-}"; shift 2 ;;
    --github-release) GITHUB_RELEASE="true"; shift ;;
    --no-github-release) GITHUB_RELEASE="false"; shift ;;
    --git-commit) GIT_COMMIT="true"; shift ;;
    --no-git-commit) GIT_COMMIT="false"; shift ;;
    --push) GIT_PUSH="true"; shift ;;
    --no-push) GIT_PUSH="false"; shift ;;
    --quick) SKIP_CLEAN="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Error: unknown option $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$DELETE_ONLY" == "true" ]]; then
  delete_old_ipa
  exit 0
fi

require_files

if [[ "$SKIP_CLEAN" == "true" ]]; then
  [[ -z "$VERSION_OVERRIDE" && -z "$BUMP_PART" && "$NO_BUMP" == "false" ]] && BUMP_PART="patch"
fi

CURRENT_VERSION="$(get_version)"
validate_version "$CURRENT_VERSION"

ACTION_COUNT=0
[[ -n "$VERSION_OVERRIDE" ]] && ACTION_COUNT=$((ACTION_COUNT + 1))
[[ -n "$BUMP_PART" ]] && ACTION_COUNT=$((ACTION_COUNT + 1))
[[ "$NO_BUMP" == "true" ]] && ACTION_COUNT=$((ACTION_COUNT + 1))

if (( ACTION_COUNT > 1 )); then
  echo "Error: use only one of --version, --bump, or --no-bump" >&2
  exit 1
fi

if [[ -n "$VERSION_OVERRIDE" ]]; then
  NEXT_VERSION="$VERSION_OVERRIDE"
elif [[ -n "$BUMP_PART" ]]; then
  NEXT_VERSION="$(bump_version "$CURRENT_VERSION" "$BUMP_PART")"
elif [[ "$NO_BUMP" == "true" ]]; then
  NEXT_VERSION="$CURRENT_VERSION"
else
  NEXT_VERSION="$(choose_version_from_menu "$CURRENT_VERSION")"
fi

validate_version "$NEXT_VERSION"

# Guard against stacking a bump on top of an already-uncommitted one: CURRENT_VERSION above was
# read straight off disk, not from the last commit, so a previous run that bumped pubspec.yaml
# but never got committed would otherwise get silently bumped again from here instead of from the
# actual last release.
if [[ "$NEXT_VERSION" != "$CURRENT_VERSION" ]] \
  && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && ! git -C "$ROOT_DIR" diff --quiet -- "$PUBSPEC_FILE" 2>/dev/null; then
  echo "" >&2
  echo "Warning: pubspec.yaml is already uncommitted at $CURRENT_VERSION (left over from a prior run)." >&2
  echo "Bumping to $NEXT_VERSION now would stack this bump on top of that uncommitted one." >&2
  if ! ask_yes_no "Continue anyway?" n; then
    echo "Aborted. Commit or discard the pending pubspec.yaml change first (git diff pubspec.yaml), then re-run." >&2
    exit 1
  fi
fi

if [[ "$NEXT_VERSION" != "$CURRENT_VERSION" ]]; then
  set_version "$NEXT_VERSION"
fi

VERSION="$(get_version)"
validate_version "$VERSION"

echo ""
echo "════════════════════════════════════════"
echo "  AJ Ops — IPA Builder"
echo "  API: $API_BASE_URL"
echo "════════════════════════════════════════"
echo "Current version: $CURRENT_VERSION"
echo "New version:     $VERSION"
echo "════════════════════════════════════════"
echo ""

# Committed BEFORE the (long) build starts, not after — a version bump left dirty for the whole
# flutter build ipa duration is exactly the exposed window that let an unrelated manual commit
# during a build accidentally sweep up an in-progress bump. --no-bump-commit restores old behavior.
if [[ "$NEXT_VERSION" != "$CURRENT_VERSION" && "$BUMP_COMMIT" == "true" ]]; then
  commit_version_bump
fi

# Tag + push ALSO happen before the build now, not after — so the version bump is fully committed
# AND pushed to GitHub regardless of whether the build that follows succeeds or fails. Previously
# this ran after build_ipa(), so a failed/retried build could leave a committed-but-unpushed bump
# sitting only on this machine. The .ipa itself is never git-committed (see git_commit_release_files
# excluding *.ipa) — it's uploaded separately as a GitHub Release asset once the build succeeds.
if [[ "$GIT_PUSH" == "true" || "$GITHUB_RELEASE" == "true" ]]; then
  git_create_tag
  git_push_release
fi

delete_old_ipa
build_ipa

if [[ "$GIT_COMMIT" == "true" ]]; then
  git_commit_release_files
fi

if [[ "$GITHUB_RELEASE" == "true" ]]; then
  publish_github_release
fi

echo ""
echo "════════════════════════════════════════"
echo "  Done!"
echo "════════════════════════════════════════"
echo "Current version: $CURRENT_VERSION"
echo "New version:     $VERSION"
echo "Updated:         $PUBSPEC_FILE"
echo "Built IPA:       $IPA_FINAL_PATH"
echo ""
echo "Next: ./bin/release.sh"
echo "════════════════════════════════════════"
echo ""
