#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PKG_VERIFY] $1"; }

# Verify package names are being set correctly
verify_package_names() {
    log "🔍 Verifying package names across all workflows..."
    
    # Check current environment variables
    log "📋 Current Environment Variables:"
    log "   PKG_NAME: ${PKG_NAME:-NOT_SET}"
    log "   BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}"
    log "   WORKFLOW_ID: ${WORKFLOW_ID:-NOT_SET}"
    log "   APP_NAME: ${APP_NAME:-NOT_SET}"
    
    # Check if PKG_NAME is set correctly
    if [ -z "${PKG_NAME:-}" ]; then
        log "❌ PKG_NAME is not set!"
        log "   This will cause package name issues in Android builds"
        log "   Expected: [YOUR_ANDROID_PACKAGE_NAME] (set by user)"
        return 1
    else
        log "✅ PKG_NAME is set: $PKG_NAME"
    fi
    
    # Check if BUNDLE_ID is set correctly
    if [ -z "${BUNDLE_ID:-}" ]; then
        log "❌ BUNDLE_ID is not set!"
        log "   This will cause bundle ID issues in iOS builds"
        log "   Expected: [YOUR_IOS_BUNDLE_ID] (set by user)"
        return 1
    else
        log "✅ BUNDLE_ID is set: $BUNDLE_ID"
    fi
    
    # Check Android build.gradle.kts
    if [ -f "android/app/build.gradle.kts" ]; then
        log "🔍 Checking Android build.gradle.kts..."
        
        current_app_id=$(grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        current_namespace=$(grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        
        log "   Current applicationId: $current_app_id"
        log "   Current namespace: $current_namespace"
        
        if [ "$current_app_id" = "$PKG_NAME" ]; then
            log "✅ Android applicationId matches PKG_NAME"
        else
            log "❌ Android applicationId mismatch!"
            log "   Expected: $PKG_NAME"
            log "   Found: $current_app_id"
            log "   This will cause the AAB upload error you mentioned"
            return 1
        fi
        
        if [ "$current_namespace" = "$PKG_NAME" ]; then
            log "✅ Android namespace matches PKG_NAME"
        else
            log "❌ Android namespace mismatch!"
            log "   Expected: $PKG_NAME"
            log "   Found: $current_namespace"
            return 1
        fi
    else
        log "⚠️ android/app/build.gradle.kts not found"
    fi
    
    # Check iOS Info.plist
    if [ -f "ios/Runner/Info.plist" ]; then
        log "🔍 Checking iOS Info.plist..."
        
        current_bundle_id=$(grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        
        log "   Current CFBundleIdentifier: $current_bundle_id"
        
        if [ "$current_bundle_id" = "$BUNDLE_ID" ]; then
            log "✅ iOS CFBundleIdentifier matches BUNDLE_ID"
        else
            log "❌ iOS CFBundleIdentifier mismatch!"
            log "   Expected: $BUNDLE_ID"
            log "   Found: $current_bundle_id"
            return 1
        fi
    else
        log "⚠️ ios/Runner/Info.plist not found"
    fi
    
    # Check pubspec.yaml
    if [ -f "pubspec.yaml" ]; then
        log "🔍 Checking pubspec.yaml..."
        
        current_version=$(grep -o '^version: [^+]*' pubspec.yaml | cut -d' ' -f2)
        log "   Current version: $current_version"
        
        expected_version="${VERSION_NAME:-1.0.0}"
        if [ "$current_version" = "$expected_version" ]; then
            log "✅ pubspec.yaml version matches VERSION_NAME"
        else
            log "⚠️ pubspec.yaml version mismatch"
            log "   Expected: $expected_version"
            log "   Found: $current_version"
        fi
    else
        log "⚠️ pubspec.yaml not found"
    fi
    
    log "✅ Package name verification completed successfully"
    return 0
}

# Check Codemagic environment variables
check_codemagic_vars() {
    log "🔍 Checking Codemagic environment variables..."
    
    # List all environment variables that might be related to package names
    log "📋 Relevant Environment Variables:"
    
    for var in PKG_NAME BUNDLE_ID APP_NAME VERSION_NAME VERSION_CODE WORKFLOW_ID; do
        if [ -n "${!var:-}" ]; then
            log "   $var: ${!var}"
        else
            log "   $var: NOT_SET"
        fi
    done
    
    # Check if we're in Codemagic
    if [ -n "${CM_BUILD_ID:-}" ]; then
        log "✅ Running in Codemagic environment"
        log "   Build ID: ${CM_BUILD_ID}"
        log "   Workflow: ${CM_WORKFLOW_NAME:-unknown}"
    else
        log "ℹ️ Running in local environment"
    fi
}

# Generate package name report
generate_report() {
    log "📊 Generating package name report..."
    
    cat > package_name_report.txt <<EOF
Package Name Verification Report
================================

Generated: $(date)
Environment: ${CM_BUILD_ID:-local}

Environment Variables:
- PKG_NAME: ${PKG_NAME:-NOT_SET}
- BUNDLE_ID: ${BUNDLE_ID:-NOT_SET}
- WORKFLOW_ID: ${WORKFLOW_ID:-NOT_SET}
- APP_NAME: ${APP_NAME:-NOT_SET}
- VERSION_NAME: ${VERSION_NAME:-NOT_SET}
- VERSION_CODE: ${VERSION_CODE:-NOT_SET}

Android Configuration:
EOF

    if [ -f "android/app/build.gradle.kts" ]; then
        current_app_id=$(grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        current_namespace=$(grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        echo "- applicationId: $current_app_id" >> package_name_report.txt
        echo "- namespace: $current_namespace" >> package_name_report.txt
    else
        echo "- build.gradle.kts: NOT_FOUND" >> package_name_report.txt
    fi

    cat >> package_name_report.txt <<EOF

iOS Configuration:
EOF

    if [ -f "ios/Runner/Info.plist" ]; then
        current_bundle_id=$(grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo "- CFBundleIdentifier: $current_bundle_id" >> package_name_report.txt
    else
        echo "- Info.plist: NOT_FOUND" >> package_name_report.txt
    fi

    cat >> package_name_report.txt <<EOF

Issues Found:
EOF

    # Check for issues
    if [ -z "${PKG_NAME:-}" ]; then
        echo "- PKG_NAME is not set" >> package_name_report.txt
    fi
    
    if [ -z "${BUNDLE_ID:-}" ]; then
        echo "- BUNDLE_ID is not set" >> package_name_report.txt
    fi
    
    if [ -f "android/app/build.gradle.kts" ]; then
        current_app_id=$(grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        if [ "$current_app_id" != "$PKG_NAME" ]; then
            echo "- Android applicationId mismatch: expected $PKG_NAME, found $current_app_id" >> package_name_report.txt
        fi
    fi
    
    if [ -f "ios/Runner/Info.plist" ]; then
        current_bundle_id=$(grep -A1 -B1 "CFBundleIdentifier" ios/Runner/Info.plist | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [ "$current_bundle_id" != "$BUNDLE_ID" ]; then
            echo "- iOS CFBundleIdentifier mismatch: expected $BUNDLE_ID, found $current_bundle_id" >> package_name_report.txt
        fi
    fi

    log "✅ Package name report generated: package_name_report.txt"
}

# Main execution
main() {
    log "🚀 Starting package name verification..."
    
    # Check if we're in the right directory
    if [ ! -f "pubspec.yaml" ]; then
        log "❌ Not in Flutter project root (pubspec.yaml not found)"
        exit 1
    fi
    
    # Check Codemagic variables
    check_codemagic_vars
    
    # Verify package names
    if verify_package_names; then
        log "✅ All package names are correctly configured"
    else
        log "❌ Package name verification failed"
        log "   Check the issues above and ensure PKG_NAME and BUNDLE_ID are set correctly"
        log "   Expected PKG_NAME: [YOUR_ANDROID_PACKAGE_NAME] (set by user)"
        log "   Expected BUNDLE_ID: [YOUR_IOS_BUNDLE_ID] (set by user)"
    fi
    
    # Generate report
    generate_report
    
    log "📋 Check package_name_report.txt for detailed information"
}

# Execute main function
main "$@" 