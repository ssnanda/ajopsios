#!/usr/bin/env bash
set -e

# AJ Ops — physical device launcher
# ------------------------------------
# Defaults to the LIVE production server (https://ncllcagents.com, the AJCore
# Master site) since a real device in your pocket should talk to the real
# backend, not your laptop's local DDEV site. Use --local if you specifically
# want to point a physical device at local DDEV for debugging.
#
# Common runs:
#   ./bin/2d-device-run.sh
#   ./bin/2d-device-run.sh --local
#   ./bin/2d-device-run.sh --device 00008130-00116C4800A1401C

API_BASE_URL="https://ncllcagents.com/wp-json/ajcore/v1"
DEVICE_ID=""
PID_FILE="/tmp/ajopsios_flutter.pid"

usage() {
  cat <<'USAGE'
AJ Ops — physical device launcher (defaults to production).

Usage:
  ./bin/2d-device-run.sh [options]

Options:
  --local       Use local DDEV (http://ncllc.ddev.site) instead of production
  --device ID   Device UDID (default: auto-detect the one connected physical iOS device)
  --help

Hot reload (while Flutter is running in this terminal):
  r   Hot reload  — fast, keeps state
  R   Hot restart — slower, resets state
  q   Quit
USAGE
}

flutter config --no-enable-swift-package-manager 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)    API_BASE_URL="http://ncllc.ddev.site/wp-json/ajcore/v1"; shift ;;
    --device)   DEVICE_ID="${2:-}"; shift 2 ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DEVICE_ID" ]]; then
  echo "Looking for a connected physical iOS device..."
  # flutter devices marks simulators with "(simulator)" at the end of the line —
  # keep only "(mobile)" lines that are NOT simulators.
  MATCHES="$(flutter devices 2>/dev/null | grep "(mobile)" | grep -v "(simulator)" || true)"
  COUNT="$(echo "$MATCHES" | grep -c . || true)"

  if [[ "$COUNT" -eq 0 ]]; then
    echo "Error: no physical device found. Plug in your iPhone (or pair it wirelessly" >&2
    echo "via Xcode > Window > Devices and Simulators) and make sure it's unlocked and trusted." >&2
    exit 1
  elif [[ "$COUNT" -gt 1 ]]; then
    echo "Multiple physical devices found — pass one explicitly with --device ID:" >&2
    echo "$MATCHES" >&2
    exit 1
  fi

  DEVICE_ID="$(echo "$MATCHES" | sed -E 's/.*• ([A-Za-z0-9-]+) •.*/\1/')"
  DEVICE_NAME="$(echo "$MATCHES" | sed -E 's/^(.*)\(mobile\).*/\1/' | sed 's/[[:space:]]*$//')"
  echo "Found: $DEVICE_NAME ($DEVICE_ID)"
fi

echo "API:    $API_BASE_URL"
echo ""
echo "Hot reload: press 'r' in this terminal | Hot restart: press 'R'"
echo ""
flutter run -d "$DEVICE_ID" \
  --pid-file "$PID_FILE" \
  --dart-define="AJ_API_BASE_URL=$API_BASE_URL"
