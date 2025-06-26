#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Permission flags with dynamic environment variable support
IS_CAMERA=${IS_CAMERA:-"false"}
IS_LOCATION=${IS_LOCATION:-"false"}
IS_MIC=${IS_MIC:-"false"}
IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
IS_CONTACT=${IS_CONTACT:-"false"}
IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
IS_CALENDAR=${IS_CALENDAR:-"false"}
IS_STORAGE=${IS_STORAGE:-"false"}

log "🔐 Starting iOS permissions configuration"
log "📋 Permission flags:"
log "   Camera: $IS_CAMERA"
log "   Location: $IS_LOCATION"
log "   Microphone: $IS_MIC"
log "   Notification: $IS_NOTIFICATION"
log "   Contact: $IS_CONTACT"
log "   Biometric: $IS_BIOMETRIC"
log "   Calendar: $IS_CALENDAR"
log "   Storage: $IS_STORAGE"

PLIST_PATH="ios/Runner/Info.plist"

if [ ! -f "$PLIST_PATH" ]; then
  log "❌ Info.plist not found at $PLIST_PATH, skipping permissions update"
  exit 1
fi

# Create backup
cp "$PLIST_PATH" "$PLIST_PATH.bak"
log "✅ Created backup of Info.plist"

# Function to add permission safely
add_permission() {
    local key="$1"
    local value="$2"
    local description="$3"
    
    log "🔧 Adding $description..."
    if /usr/libexec/PlistBuddy -c "Add :$key string '$value'" "$PLIST_PATH" 2>/dev/null; then
        log "✅ Added $description"
    elif /usr/libexec/PlistBuddy -c "Set :$key '$value'" "$PLIST_PATH" 2>/dev/null; then
        log "✅ Updated $description"
    else
        log "⚠️ Failed to add/update $description"
    fi
}

# Add permissions based on feature flags
if [ "$IS_CAMERA" = "true" ]; then
  add_permission "NSCameraUsageDescription" "This app needs access to camera to capture photos and videos." "camera permission"
fi

if [ "$IS_LOCATION" = "true" ]; then
  add_permission "NSLocationWhenInUseUsageDescription" "This app needs access to location when in use." "location when in use permission"
  add_permission "NSLocationAlwaysAndWhenInUseUsageDescription" "This app needs access to location always and when in use." "location always permission"
  add_permission "NSLocationAlwaysUsageDescription" "This app needs access to location always." "location always usage permission"
fi

if [ "$IS_MIC" = "true" ]; then
  add_permission "NSMicrophoneUsageDescription" "This app needs access to microphone to record audio." "microphone permission"
fi

if [ "$IS_CONTACT" = "true" ]; then
  add_permission "NSContactsUsageDescription" "This app needs access to contacts to manage contact information." "contacts permission"
fi

if [ "$IS_BIOMETRIC" = "true" ]; then
  add_permission "NSFaceIDUsageDescription" "This app uses Face ID for secure authentication." "Face ID permission"
fi

if [ "$IS_CALENDAR" = "true" ]; then
  add_permission "NSCalendarsUsageDescription" "This app needs access to calendar to manage events." "calendar permission"
fi

if [ "$IS_STORAGE" = "true" ]; then
  add_permission "NSPhotoLibraryUsageDescription" "This app needs access to photo library to save and retrieve images." "photo library permission"
  add_permission "NSPhotoLibraryAddUsageDescription" "This app needs access to save photos to your photo library." "photo library add permission"
fi

# Always add network permission for Flutter apps
log "🌐 Adding network permissions..."
if /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST_PATH" 2>/dev/null; then
    log "✅ Added NSAppTransportSecurity dict"
elif /usr/libexec/PlistBuddy -c "Set :NSAppTransportSecurity dict" "$PLIST_PATH" 2>/dev/null; then
    log "✅ Updated NSAppTransportSecurity dict"
fi

if /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$PLIST_PATH" 2>/dev/null; then
    log "✅ Added NSAllowsArbitraryLoads"
elif /usr/libexec/PlistBuddy -c "Set :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$PLIST_PATH" 2>/dev/null; then
    log "✅ Updated NSAllowsArbitraryLoads"
fi

# Verify the changes
log "🔍 Verifying Info.plist changes..."
if plutil -lint "$PLIST_PATH" >/dev/null 2>&1; then
    log "✅ Info.plist is valid"
else
    log "❌ Info.plist validation failed, restoring backup"
    cp "$PLIST_PATH.bak" "$PLIST_PATH"
    exit 1
fi

log "✅ iOS permissions configuration completed successfully"
exit 0 