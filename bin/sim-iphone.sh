#!/usr/bin/env bash
set -e

# AJ Ops — iPhone simulator launcher
# -----------------------------------
# Defaults to the local DDEV site for development.
# Use --prod to test against the live production server instead.
#
# Common runs:
#   ./bin/sim-iphone.sh
#   ./bin/sim-iphone.sh --prod

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="BAE45ECD-3952-41E5-AAF0-5AD93C703CBE"
DEVICE_NAME="iPhone"
API_BASE_URL="http://ncllc.ddev.site/wp-json/ajcore/v1"
PID_FILE="/tmp/ajopsios_flutter.pid"

usage() {
  cat <<'USAGE'
AJ Ops — iPhone simulator launcher.

Usage:
  ./bin/sim-iphone.sh [options]

Options:
  --prod        Use production server (https://ops.ncllcagents.com) instead of local DDEV
  --device ID   Simulator UDID (default: configured iPhone)
  --help

Hot reload (while Flutter is running in this terminal):
  r   Hot reload  — fast, keeps state
  R   Hot restart — slower, resets state
  q   Quit

Or from another terminal:
  kill -SIGUSR1 $(cat /tmp/ajopsios_flutter.pid)   # hot reload
  kill -SIGUSR2 $(cat /tmp/ajopsios_flutter.pid)   # hot restart
USAGE
}

# Suppress "does not support Swift Package Manager" warnings from plugins
# that haven't adopted SPM yet (flutter_secure_storage).
flutter config --no-enable-swift-package-manager 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)     API_BASE_URL="https://ops.ncllcagents.com/wp-json/ajcore/v1"; shift ;;
    --device)   DEVICE_ID="${2:-}"; shift 2 ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

echo "API:    $API_BASE_URL"
echo ""
echo "Starting $DEVICE_NAME simulator ($DEVICE_ID)..."

if ! xcrun simctl list devices | grep -q "$DEVICE_ID"; then
  echo "Device $DEVICE_ID not found. Available iPhones:"
  xcrun simctl list devices | grep "iPhone"
  exit 1
fi

DEVICE_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "Booted\|Shutdown" || echo "Unknown")

if [[ "$DEVICE_STATE" == "Booted" ]]; then
  echo "Simulator already running."
else
  echo "Booting simulator..."
  xcrun simctl boot "$DEVICE_ID" 2>&1 || true
  sleep 5
fi

echo "Opening Simulator.app..."
open -a Simulator
sleep 3

MAX_ATTEMPTS=30
ATTEMPT=0
while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  [[ "$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "Booted" || echo "")" == "Booted" ]] && break
  echo "Waiting for boot... ($ATTEMPT/$MAX_ATTEMPTS)"
  sleep 1
  ATTEMPT=$((ATTEMPT+1))
done

[[ $ATTEMPT -eq $MAX_ATTEMPTS ]] && { echo "Simulator failed to boot." >&2; exit 1; }

echo ""
echo "Hot reload: press 'r' in this terminal | Hot restart: press 'R'"
echo ""
cd "$ROOT_DIR"
flutter run -d "$DEVICE_ID" \
  --pid-file "$PID_FILE" \
  --dart-define="AJ_API_BASE_URL=$API_BASE_URL"
