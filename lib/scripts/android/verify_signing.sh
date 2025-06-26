#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "🔐 Verifying Android signing configuration..."

# Check build.gradle.kts
if [ -f android/app/build.gradle.kts ]; then
    log "Checking build.gradle.kts configuration..."
    
    if grep -q "signingConfigs" android/app/build.gradle.kts; then
        log "✅ signingConfigs block found in build.gradle.kts"
    else
        log "❌ signingConfigs block missing in build.gradle.kts"
        exit 1
    fi
    
    if grep -q "keystore.properties" android/app/build.gradle.kts; then
        log "✅ keystore.properties reference found in build.gradle.kts"
    else
        log "❌ keystore.properties reference missing in build.gradle.kts"
        exit 1
    fi
else
    log "❌ build.gradle.kts not found"
    exit 1
fi

# Check keystore files (if keystore URL provided)
if [ -n "${KEY_STORE_URL:-}" ]; then
    log "Keystore URL provided, checking keystore files..."
    
    if [ -f android/app/keystore.properties ]; then
        log "✅ keystore.properties found"
        
        # Verify properties file content
        if grep -q "storeFile=" android/app/keystore.properties && \
           grep -q "storePassword=" android/app/keystore.properties && \
           grep -q "keyAlias=" android/app/keystore.properties && \
           grep -q "keyPassword=" android/app/keystore.properties; then
            log "✅ keystore.properties has all required fields"
        else
            log "❌ keystore.properties is missing required fields"
            exit 1
        fi
    else
        log "❌ keystore.properties not found"
        exit 1
    fi
    
    if [ -f android/app/keystore.jks ]; then
        log "✅ keystore.jks found"
        
        # Check file size
        KEYSTORE_SIZE=$(stat -f%z android/app/keystore.jks 2>/dev/null || stat -c%s android/app/keystore.jks 2>/dev/null || echo "0")
        if [ "$KEYSTORE_SIZE" -gt 1024 ]; then
            log "✅ keystore.jks appears to be valid (${KEYSTORE_SIZE} bytes)"
        else
            log "⚠️  keystore.jks seems small (${KEYSTORE_SIZE} bytes) - might be invalid"
        fi
    else
        log "❌ keystore.jks not found"
        exit 1
    fi
    
    log "🎯 RESULT: Release signing is properly configured"
    log "📱 APK/AAB will be signed for Google Play Store upload"
else
    log "⚠️  No keystore URL provided"
    log "🎯 RESULT: Debug signing will be used"
    log "⚠️  WARNING: Debug-signed builds cannot be uploaded to Google Play Store"
fi

log "Android signing verification completed" 