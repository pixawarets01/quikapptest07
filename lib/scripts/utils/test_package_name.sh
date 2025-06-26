#!/bin/bash

echo "🔍 Package Name Configuration Test"
echo "=================================="

# Check environment variables
echo "📋 Environment Variables:"
echo "   PKG_NAME: ${PKG_NAME:-NOT_SET}"
echo "   BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}"
echo ""

# Check Android configuration
echo "🤖 Android Configuration:"
if [ -f "android/app/build.gradle.kts" ]; then
    current_app_id=$(grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
    current_namespace=$(grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
    echo "   applicationId: $current_app_id"
    echo "   namespace: $current_namespace"
    
    if [ -n "${PKG_NAME:-}" ] && [ "$current_app_id" = "$PKG_NAME" ]; then
        echo "   ✅ Android package name matches PKG_NAME"
    elif [ -z "${PKG_NAME:-}" ]; then
        echo "   ❌ PKG_NAME environment variable is not set"
    else
        echo "   ❌ Android package name mismatch"
        echo "      Expected: $PKG_NAME"
        echo "      Found: $current_app_id"
    fi
else
    echo "   ⚠️ android/app/build.gradle.kts not found"
fi
echo ""

# Check iOS configuration
echo "🍎 iOS Configuration:"
if [ -f "ios/Runner/Info.plist" ]; then
    current_bundle_id=$(grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    echo "   CFBundleIdentifier: $current_bundle_id"
    
    if [ -n "${BUNDLE_ID:-}" ] && [ "$current_bundle_id" = "$BUNDLE_ID" ]; then
        echo "   ✅ iOS bundle ID matches BUNDLE_ID"
    elif [ -z "${BUNDLE_ID:-}" ]; then
        echo "   ❌ BUNDLE_ID environment variable is not set"
    else
        echo "   ❌ iOS bundle ID mismatch"
        echo "      Expected: $BUNDLE_ID"
        echo "      Found: $current_bundle_id"
    fi
else
    echo "   ⚠️ ios/Runner/Info.plist not found"
fi
echo ""

# Summary
echo "📊 Summary:"
if [ -n "${PKG_NAME:-}" ] && [ -n "${BUNDLE_ID:-}" ]; then
    echo "   ✅ Environment variables are set correctly"
    echo "      PKG_NAME: $PKG_NAME"
    echo "      BUNDLE_ID: $BUNDLE_ID"
elif [ -z "${PKG_NAME:-}" ] && [ -z "${BUNDLE_ID:-}" ]; then
    echo "   ❌ Both environment variables are missing:"
    echo "      PKG_NAME = [YOUR_ANDROID_PACKAGE_NAME]"
    echo "      BUNDLE_ID = [YOUR_IOS_BUNDLE_ID]"
elif [ -z "${PKG_NAME:-}" ]; then
    echo "   ❌ PKG_NAME environment variable is missing:"
    echo "      PKG_NAME = [YOUR_ANDROID_PACKAGE_NAME]"
elif [ -z "${BUNDLE_ID:-}" ]; then
    echo "   ❌ BUNDLE_ID environment variable is missing:"
    echo "      BUNDLE_ID = [YOUR_IOS_BUNDLE_ID]"
fi

echo ""
echo "🚀 To fix: Set PKG_NAME and BUNDLE_ID environment variables in Codemagic to your desired package names"
echo "   Examples:"
echo "   - PKG_NAME = com.mycompany.myapp"
echo "   - BUNDLE_ID = com.mycompany.myapp" 