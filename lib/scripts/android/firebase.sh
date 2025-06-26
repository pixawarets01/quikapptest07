#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID:-}

log "Starting Firebase configuration"

# Validate Firebase config URL
if [ -n "$FIREBASE_CONFIG_ANDROID" ]; then
  log "Validating Firebase config URL: $FIREBASE_CONFIG_ANDROID"
  
  # Check if URL is reachable
  if ! curl --output /dev/null --silent --head --fail "$FIREBASE_CONFIG_ANDROID"; then
    handle_error "Firebase config URL is not accessible: $FIREBASE_CONFIG_ANDROID"
  fi
  
  log "Downloading Firebase configuration from $FIREBASE_CONFIG_ANDROID"
  curl -L "$FIREBASE_CONFIG_ANDROID" -o android/app/google-services.json || handle_error "Failed to download Firebase config"
  
  # Validate downloaded file
  if [ ! -f android/app/google-services.json ]; then
    handle_error "google-services.json was not created after download"
  fi
  
  # Check file size (should be > 100 bytes for a valid config)
  FIREBASE_SIZE=$(stat -f%z android/app/google-services.json 2>/dev/null || stat -c%s android/app/google-services.json 2>/dev/null || echo "0")
  if [ "$FIREBASE_SIZE" -lt 100 ]; then
    log "Warning: Firebase config file seems too small ($FIREBASE_SIZE bytes). This might be an error page."
    handle_error "Invalid Firebase configuration file downloaded"
  fi
  
  # Validate JSON format
  if ! python3 -m json.tool android/app/google-services.json > /dev/null 2>&1; then
    handle_error "Invalid JSON format in downloaded Firebase config"
  fi
  
  # Check for required fields
  if ! grep -q "project_info" android/app/google-services.json; then
    handle_error "Invalid Firebase config: missing project_info"
  fi
  
  if ! grep -q "client" android/app/google-services.json; then
    handle_error "Invalid Firebase config: missing client configuration"
  fi
  
  mkdir -p assets
  cp android/app/google-services.json assets/google-services.json || handle_error "Failed to copy google-services.json to assets"
  
  log "✅ Firebase configuration validated and installed successfully"
  log "📋 Config file size: $FIREBASE_SIZE bytes"
else
  log "No Firebase config URL provided; skipping Firebase setup."
fi

log "Firebase configuration completed successfully"
exit 0 