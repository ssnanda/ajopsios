#!/usr/bin/env bash
set -euo pipefail

# AJ Ops — version bump + GitHub release
# -----------------------------------------
# Run this AFTER build-ipa.sh has built its artifact.
# It bumps the version in pubspec.yaml, commits, tags, pushes, and creates
# a GitHub Release with the IPA attached.
#
# Common runs:
#   ./bin/release.sh
#   ./bin/release.sh --bump patch
#   ./bin/release.sh --bump minor --push --github-release

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"
IPA_OUTPUT_DIR="$HOME/Documents/GitHub/ipa"
GITHUB_REPO="ssnanda/ajopsios"

BUMP_PART=""
NO_BUMP="false"
VERSION_OVERRIDE=""
GIT_COMMIT="ask"
GIT_PUSH="ask"
GITHUB_RELEASE="ask"

usage() {
  cat <<'USAGE'
AJ Ops — version bump + GitHub release.

Run AFTER building with build-ipa.sh.

Usage:
  ./bin/release.sh [options]

Options:
  --bump patch|minor|major|build   Bump version automatically
  --no-bump                        Keep current version
  --version X.Y.Z+B               Set exact version
  --git-commit                     Commit without prompting
  --no-git-commit
  --push                           Push + tag without prompting
  --no-push
  --github-release                 Create GitHub Release without prompting
  --no-github-release
  --repo OWNER/REPO                GitHub repo (default: ssnanda/ajopsios)
  --help
USAGE
}

get_version()      { awk '/^version:/ {print $2}' "$PUBSPEC_FILE"; }
validate_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || {
    echo "Error: version must be X.Y.Z+B format, e.g. 1.0.0+1" >&2; exit 1
  }
}

bump_version() {
  local current="$1" part="$2" vp bp major minor patch build
  vp="${current%+*}"; bp="${current#*+}"
  IFS='.' read -r major minor patch <<< "$vp"
  case "$part" in
    patch) patch=$((patch+1)); build=$((bp+1)) ;;
    minor) minor=$((minor+1)); patch=0; build=$((bp+1)) ;;
    major) major=$((major+1)); minor=0; patch=0; build=$((bp+1)) ;;
    build) build=$((bp+1)) ;;
    *) echo "Error: bump must be patch, minor, major, or build" >&2; exit 1 ;;
  esac
  echo "$major.$minor.$patch+$build"
}

set_version() {
  validate_version "$1"
  sed -i '' "s/^version: .*/version: $1/" "$PUBSPEC_FILE"
}

choose_version_from_menu() {
  local current="$1" choice=""
  while true; do
    cat >&2 <<MENU
Current version: $current
  1) patch  → $(bump_version "$current" patch)
  2) minor  → $(bump_version "$current" minor)
  3) major  → $(bump_version "$current" major)
  4) build  → $(bump_version "$current" build)
  5) custom
  6) no bump
MENU
    read -r -p "Choice [1-6, default=1]: " choice; choice="${choice:-1}"
    case "$choice" in
      1) echo "$(bump_version "$current" patch)"; return ;;
      2) echo "$(bump_version "$current" minor)"; return ;;
      3) echo "$(bump_version "$current" major)"; return ;;
      4) echo "$(bump_version "$current" build)"; return ;;
      5) read -r -p "Enter X.Y.Z+B: " cv; validate_version "$cv"; echo "$cv"; return ;;
      6) echo "$current"; return ;;
      *) echo "Choose 1-6." >&2 ;;
    esac
  done
}

ask_yes_no() {
  local prompt="$1" default="${2:-n}" answer=""
  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n]: " answer; answer="${answer:-y}"
  else
    read -r -p "$prompt [y/N]: " answer; answer="${answer:-n}"
  fi
  case "$answer" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

require_git() {
  command -v git >/dev/null 2>&1 || { echo "Error: git not found" >&2; exit 1; }
  git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Error: not a git repository" >&2; exit 1
  }
}

require_gh() {
  command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI required. brew install gh" >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Error: gh not logged in. Run: gh auth login" >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)             BUMP_PART="${2:-}"; shift 2 ;;
    --no-bump)          NO_BUMP="true"; shift ;;
    --version)          VERSION_OVERRIDE="${2:-}"; shift 2 ;;
    --git-commit)       GIT_COMMIT="true"; shift ;;
    --no-git-commit)    GIT_COMMIT="false"; shift ;;
    --push)             GIT_PUSH="true"; shift ;;
    --no-push)          GIT_PUSH="false"; shift ;;
    --github-release)   GITHUB_RELEASE="true"; shift ;;
    --no-github-release) GITHUB_RELEASE="false"; shift ;;
    --repo)             GITHUB_REPO="${2:-}"; shift 2 ;;
    --help|-h)          usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -f "$PUBSPEC_FILE" ]] || { echo "Error: missing $PUBSPEC_FILE" >&2; exit 1; }

CURRENT_VERSION="$(get_version)"
validate_version "$CURRENT_VERSION"

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
[[ "$NEXT_VERSION" != "$CURRENT_VERSION" ]] && set_version "$NEXT_VERSION"
VERSION="$(get_version)"

echo ""
echo "════════════════════════════════════════"
echo "  AJ Ops — Release"
echo "════════════════════════════════════════"
echo "  Version: $CURRENT_VERSION → $VERSION"
echo "════════════════════════════════════════"
echo ""

IPA_PATH="$IPA_OUTPUT_DIR/ajopsios.ipa"
ARTIFACTS=()
[[ -f "$IPA_PATH" ]] && ARTIFACTS+=("$IPA_PATH") && echo "  IPA: $IPA_PATH"
[[ ${#ARTIFACTS[@]} -eq 0 ]] && echo "  (no built artifact found — run build-ipa.sh first)"
echo ""

[[ "$GIT_COMMIT" == "ask" ]] && ask_yes_no "Commit release files to git?" "y" \
  && GIT_COMMIT="true" || GIT_COMMIT="false"

if [[ "$GIT_COMMIT" == "true" ]]; then
  require_git
  cd "$ROOT_DIR"
  git add -u
  while IFS= read -r f; do
    case "$f" in build/*|*.ipa) continue ;; *) git add "$f" ;; esac
  done < <(git ls-files --others --exclude-standard)
  git diff --cached --quiet && echo "Nothing to commit." || \
    git commit -m "Release AJ Ops v$VERSION"
fi

[[ "$GIT_PUSH" == "ask" ]] && ask_yes_no "Push and tag to GitHub?" "y" \
  && GIT_PUSH="true" || GIT_PUSH="false"

if [[ "$GIT_PUSH" == "true" ]]; then
  require_git
  TAG="v$VERSION"
  git rev-parse "$TAG" >/dev/null 2>&1 || git tag "$TAG"
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  git push origin "$BRANCH"
  git push origin "$TAG"
  echo "Tagged and pushed: $TAG"
fi

[[ "$GITHUB_RELEASE" == "ask" ]] && ask_yes_no "Create GitHub Release?" "y" \
  && GITHUB_RELEASE="true" || GITHUB_RELEASE="false"

if [[ "$GITHUB_RELEASE" == "true" ]]; then
  require_gh
  TAG="v$VERSION"
  if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
    [[ ${#ARTIFACTS[@]} -gt 0 ]] && \
      gh release upload "$TAG" "${ARTIFACTS[@]}" --repo "$GITHUB_REPO" --clobber
  else
    gh release create "$TAG" "${ARTIFACTS[@]}" \
      --repo "$GITHUB_REPO" \
      --title "AJ Ops v$VERSION" \
      --notes "Release v$VERSION — AJ Ops"
  fi
  echo "GitHub Release: $TAG"
fi

echo ""
echo "════════════════════════════════════════"
echo "  Done!  v$VERSION"
echo "════════════════════════════════════════"
echo ""
