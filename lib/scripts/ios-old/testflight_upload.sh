#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Required variables for TestFlight
IS_TESTFLIGHT=${IS_TESTFLIGHT:-"false"}
APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-""}
APPLE_TEAM_ID=${APPLE_TEAM_ID:-""}
APNS_KEY_ID=${APNS_KEY_ID:-""}
APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-""}

if [ "$IS_TESTFLIGHT" != "true" ]; then
    log "⏭️ TestFlight upload disabled, skipping..."
    exit 0
fi

log "🚀 Starting TestFlight upload process..."

# Validate required variables
if [ -z "$APP_STORE_CONNECT_KEY_IDENTIFIER" ]; then
    handle_error "APP_STORE_CONNECT_KEY_IDENTIFIER is required for TestFlight upload"
fi

if [ -z "$APPLE_TEAM_ID" ]; then
    handle_error "APPLE_TEAM_ID is required for TestFlight upload"
fi

if [ -z "$APNS_KEY_ID" ]; then
    handle_error "APNS_KEY_ID is required for TestFlight upload"
fi

if [ -z "$APNS_AUTH_KEY_URL" ]; then
    handle_error "APNS_AUTH_KEY_URL is required for TestFlight upload"
fi

# Download App Store Connect API Key
log "📥 Downloading App Store Connect API Key..."
mkdir -p ios/keys
curl -L "$APNS_AUTH_KEY_URL" -o ios/keys/AuthKey_${APNS_KEY_ID}.p8 || handle_error "Failed to download API key"

# Create App Store Connect API configuration
log "⚙️ Configuring App Store Connect API..."
cat > ios/keys/app_store_connect_api_key.json << EOF
{
    "key_id": "$APP_STORE_CONNECT_KEY_IDENTIFIER",
    "issuer_id": "$APPLE_TEAM_ID",
    "key": "$(cat ios/keys/AuthKey_${APNS_KEY_ID}.p8)",
    "in_house": false
}
EOF

# Upload to TestFlight using xcrun
log "📤 Uploading to TestFlight..."
if ! xcrun altool --upload-app -f output/ios/Runner.ipa \
    --apiKey "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
    --apiIssuer "$APPLE_TEAM_ID" \
    --type ios; then
    handle_error "Failed to upload to TestFlight"
fi

log "✅ Successfully uploaded to TestFlight"

# Cleanup
rm -rf ios/keys

exit 0 