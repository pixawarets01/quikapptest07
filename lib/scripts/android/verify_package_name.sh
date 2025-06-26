#!/bin/bash
set -euo pipefail

# APK Package Name Verification Script for QuikApp Platform
# This script verifies that the built APK contains the correct package name

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PKG_VERIFY] $1"; }

# Expected package name from environment
EXPECTED_PACKAGE_NAME="${PKG_NAME:-com.example.quikapptest06}"

log "🔍 Starting APK package name verification..."
log "📦 Expected package name: $EXPECTED_PACKAGE_NAME"

# Define possible APK locations
APK_LOCATIONS=(
    "build/app/outputs/flutter-apk/app-release.apk"
    "build/app/outputs/apk/release/app-release.apk"
    "android/app/build/outputs/apk/release/app-release.apk"
    "output/android/app-release.apk"
)

# Find the APK file
APK_PATH=""
for location in "${APK_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        APK_PATH="$location"
        log "✅ Found APK at: $APK_PATH"
        break
    fi
done

if [ -z "$APK_PATH" ]; then
    log "❌ Error: APK not found in any expected location"
    log "🔍 Searched locations:"
    for location in "${APK_LOCATIONS[@]}"; do
        log "   - $location"
    done
    exit 1
fi

# Get APK file size for logging
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
log "📁 APK size: $APK_SIZE"

# Find the aapt tool path dynamically
log "🔧 Locating aapt tool..."

# Try multiple possible locations for aapt
AAPT_PATH=""
POSSIBLE_AAPT_LOCATIONS=(
    "$ANDROID_SDK_ROOT/build-tools/*/aapt"
    "$ANDROID_HOME/build-tools/*/aapt"
    "/usr/local/android-sdk/build-tools/*/aapt"
    "/opt/android-sdk/build-tools/*/aapt"
)

for pattern in "${POSSIBLE_AAPT_LOCATIONS[@]}"; do
    if [ -n "$pattern" ]; then
        # Use find to locate aapt, sort by version, take the latest
        FOUND_AAPT=$(find $(dirname "$pattern") -name "aapt" 2>/dev/null | sort -V | tail -n 1)
        if [ -n "$FOUND_AAPT" ] && [ -f "$FOUND_AAPT" ]; then
            AAPT_PATH="$FOUND_AAPT"
            break
        fi
    fi
done

# Alternative method: use which command
if [ -z "$AAPT_PATH" ]; then
    WHICH_AAPT=$(which aapt 2>/dev/null || echo "")
    if [ -n "$WHICH_AAPT" ]; then
        AAPT_PATH="$WHICH_AAPT"
    fi
fi

if [ -z "$AAPT_PATH" ]; then
    log "❌ Error: aapt tool not found"
    log "🔍 Searched in:"
    for pattern in "${POSSIBLE_AAPT_LOCATIONS[@]}"; do
        log "   - $pattern"
    done
    log "💡 Ensure Android SDK Build Tools are installed"
    log "💡 Check ANDROID_SDK_ROOT or ANDROID_HOME environment variables"
    exit 1
fi

log "✅ Found aapt at: $AAPT_PATH"

# Extract package information from APK
log "🔍 Extracting package information from APK..."

# Get package info using aapt
PACKAGE_INFO=$("$AAPT_PATH" dump badging "$APK_PATH" 2>/dev/null | grep "package: name" || echo "")

if [ -z "$PACKAGE_INFO" ]; then
    log "❌ Error: Could not extract package information from APK"
    log "💡 APK might be corrupted or aapt version incompatible"
    exit 1
fi

# Extract package name from the output
ACTUAL_PACKAGE_NAME=$(echo "$PACKAGE_INFO" | sed -n "s/.*package: name='\([^']*\)'.*/\1/p")

if [ -z "$ACTUAL_PACKAGE_NAME" ]; then
    log "❌ Error: Could not parse package name from aapt output"
    log "📋 Raw aapt output: $PACKAGE_INFO"
    exit 1
fi

log "📦 APK Package Name: $ACTUAL_PACKAGE_NAME"

# Verify package name matches expected
if [ "$ACTUAL_PACKAGE_NAME" = "$EXPECTED_PACKAGE_NAME" ]; then
    log "✅ Package name verification PASSED"
    log "🎉 APK contains correct package name: $ACTUAL_PACKAGE_NAME"
    
    # Extract additional APK information for logging
    log "📊 Additional APK Information:"
    
    # Get version information
    VERSION_INFO=$("$AAPT_PATH" dump badging "$APK_PATH" 2>/dev/null | grep "versionName\|versionCode" || echo "")
    if [ -n "$VERSION_INFO" ]; then
        VERSION_NAME=$(echo "$VERSION_INFO" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
        VERSION_CODE=$(echo "$VERSION_INFO" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
        if [ -n "$VERSION_NAME" ]; then
            log "   📋 Version Name: $VERSION_NAME"
        fi
        if [ -n "$VERSION_CODE" ]; then
            log "   📋 Version Code: $VERSION_CODE"
        fi
    fi
    
    # Get app name
    APP_LABEL=$("$AAPT_PATH" dump badging "$APK_PATH" 2>/dev/null | grep "application-label:" | sed -n "s/.*application-label:'\([^']*\)'.*/\1/p")
    if [ -n "$APP_LABEL" ]; then
        log "   📋 App Label: $APP_LABEL"
    fi
    
    # Get minimum SDK version
    MIN_SDK=$("$AAPT_PATH" dump badging "$APK_PATH" 2>/dev/null | grep "sdkVersion:" | sed -n "s/.*sdkVersion:'\([^']*\)'.*/\1/p")
    if [ -n "$MIN_SDK" ]; then
        log "   📋 Min SDK Version: $MIN_SDK"
    fi
    
    # Get target SDK version
    TARGET_SDK=$("$AAPT_PATH" dump badging "$APK_PATH" 2>/dev/null | grep "targetSdkVersion:" | sed -n "s/.*targetSdkVersion:'\([^']*\)'.*/\1/p")
    if [ -n "$TARGET_SDK" ]; then
        log "   📋 Target SDK Version: $TARGET_SDK"
    fi
    
    log "✅ Package name verification completed successfully"
    exit 0
else
    log "❌ Package name verification FAILED"
    log "🔍 Expected: $EXPECTED_PACKAGE_NAME"
    log "🔍 Actual:   $ACTUAL_PACKAGE_NAME"
    log "💡 This indicates the package name update process may have failed"
    log "💡 Check the package name update script and build configuration"
    
    # Provide troubleshooting information
    log "🔧 Troubleshooting suggestions:"
    log "   1. Verify PKG_NAME environment variable is set correctly"
    log "   2. Check if package name update script ran successfully"
    log "   3. Verify AndroidManifest.xml and build.gradle.kts have correct package name"
    log "   4. Ensure no cached build artifacts are interfering"
    
    exit 1
fi 