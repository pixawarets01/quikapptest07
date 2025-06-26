#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

BUNDLE_ID=${BUNDLE_ID:-}
APP_NAME=${APP_NAME:-}

log "Starting iOS app customization"

# Update bundle ID in Info.plist
if [ -n "$BUNDLE_ID" ]; then
  log "Updating bundle ID to $BUNDLE_ID"
  if [ -f ios/Runner/Info.plist ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" ios/Runner/Info.plist || true
  fi
fi

# Update app name in Info.plist
if [ -n "$APP_NAME" ]; then
  log "Updating app name to $APP_NAME"
  if [ -f ios/Runner/Info.plist ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" ios/Runner/Info.plist || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" ios/Runner/Info.plist || true
  fi
fi

# Generate app icons using the icon generation script
log "Generating app icons..."
if [ -f "lib/scripts/utils/fix_ios_icons.sh" ]; then
  chmod +x lib/scripts/utils/fix_ios_icons.sh
  if lib/scripts/utils/fix_ios_icons.sh; then
    log "✅ App icons fixed successfully"
  else
    log "❌ Failed to fix app icons"
    exit 1
  fi
else
  log "⚠️ Icon fix script not found, skipping icon generation"
fi

log "iOS app customization completed successfully"
exit 0 