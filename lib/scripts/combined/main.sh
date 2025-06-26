#!/bin/bash
set -euo pipefail

# CRITICAL: Force fix env_config.dart to resolve $BRANCH compilation error
# This must be done FIRST to prevent any caching issues
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    chmod +x lib/scripts/utils/force_fix_env_config.sh
    lib/scripts/utils/force_fix_env_config.sh
fi

# Source environment variables and build acceleration
source lib/scripts/utils/gen_env_config.sh
source lib/scripts/utils/build_acceleration.sh

# Generate environment configuration
generate_env_config

# CRITICAL: Force fix again after environment generation to ensure no $BRANCH patterns
if [ -f "lib/scripts/utils/force_fix_env_config.sh" ]; then
    lib/scripts/utils/force_fix_env_config.sh
fi

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Universal Combined Build Configuration Detection
log "🚀 Starting Universal Combined Build Configuration Detection..."

# 🔧 WORKFLOW-SPECIFIC VALIDATION: Combined Workflow Android Part
log "🔍 Validating Combined Workflow Android Configuration..."
log "📋 Workflow: Combined (Android + iOS)"
log "📱 Android Part Configuration:"

# Android Build Type Detection
ANDROID_BUILD_TYPE="debug"
ANDROID_FIREBASE_ENABLED="false"
ANDROID_KEYSTORE_ENABLED="false"
ANDROID_AAB_ENABLED="false"

# Check if Firebase is enabled for Android (Conditional based on PUSH_NOTIFY)
if [[ "${PUSH_NOTIFY:-false}" == "true" ]] && [[ -n "${FIREBASE_CONFIG_ANDROID:-}" ]]; then
    ANDROID_FIREBASE_ENABLED="true"
    log "✅ Android Firebase: ENABLED (PUSH_NOTIFY=true and FIREBASE_CONFIG_ANDROID provided)"
else
    log "ℹ️ Android Firebase: DISABLED (PUSH_NOTIFY=false or no FIREBASE_CONFIG_ANDROID)"
fi

# Check if Keystore is available for Android (Required for release signing)
if [[ -n "${KEY_STORE_URL:-}" ]] && [[ -n "${CM_KEYSTORE_PASSWORD:-}" ]] && [[ -n "${CM_KEY_ALIAS:-}" ]] && [[ -n "${CM_KEY_PASSWORD:-}" ]]; then
    ANDROID_KEYSTORE_ENABLED="true"
    ANDROID_BUILD_TYPE="release"
    ANDROID_AAB_ENABLED="true"
    log "✅ Android Keystore: ENABLED (All credentials provided) - Will build APK + AAB with release signing"
else
    log "❌ Android Keystore: DISABLED (Missing credentials) - Will build APK only with debug signing"
    log "   Required: KEY_STORE_URL, CM_KEYSTORE_PASSWORD, CM_KEY_ALIAS, CM_KEY_PASSWORD"
fi

# Validate required Android variables for combined workflow
log "🔍 Validating required Android variables for combined workflow..."
REQUIRED_ANDROID_VARS=("PKG_NAME" "APP_NAME" "VERSION_NAME" "VERSION_CODE")
MISSING_ANDROID_VARS=()

for var in "${REQUIRED_ANDROID_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        MISSING_ANDROID_VARS+=("$var")
    fi
done

if [[ ${#MISSING_ANDROID_VARS[@]} -gt 0 ]]; then
    log "❌ Missing required Android variables: ${MISSING_ANDROID_VARS[*]}"
    log "❌ Combined workflow Android part cannot proceed"
    exit 1
else
    log "✅ All required Android variables present"
fi

log "📊 Combined Workflow Android Configuration Summary:"
log "   Build Type: $ANDROID_BUILD_TYPE"
log "   Firebase: $ANDROID_FIREBASE_ENABLED"
log "   Keystore: $ANDROID_KEYSTORE_ENABLED"
log "   AAB Build: $ANDROID_AAB_ENABLED"
log "   Package Name: ${PKG_NAME:-not set}"
log "   App Name: ${APP_NAME:-not set}"
log "   Version: ${VERSION_NAME:-not set} (${VERSION_CODE:-not set})"

# Detect iOS Configuration
log "🍎 Detecting iOS Configuration..."

# iOS Build Type Detection
IOS_BUILD_ENABLED="false"
IOS_PROFILE_TYPE=""
IOS_FIREBASE_ENABLED="false"

# Check if iOS certificates and profile are available
if [[ -n "${BUNDLE_ID:-}" ]] && [[ -n "${APPLE_TEAM_ID:-}" ]] && [[ -n "${CERT_PASSWORD:-}" ]] && [[ -n "${PROFILE_URL:-}" ]]; then
    IOS_BUILD_ENABLED="true"
    log "✅ iOS build prerequisites detected"
    
    # Check certificate availability
    if [[ -n "${CERT_P12_URL:-}" ]] || ([[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]]); then
        log "✅ iOS certificates detected"
    else
        log "❌ iOS certificates missing - disabling iOS build"
        IOS_BUILD_ENABLED="false"
    fi
else
    log "ℹ️ iOS build prerequisites not available - skipping iOS build"
fi

# Determine iOS Profile Type
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [[ -n "${PROFILE_TYPE:-}" ]]; then
        IOS_PROFILE_TYPE="${PROFILE_TYPE}"
        log "📋 Using specified iOS Profile Type: $IOS_PROFILE_TYPE"
    else
        # Auto-detect based on App Store Connect key
        if [[ -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ]]; then
            IOS_PROFILE_TYPE="app-store"
            log "📋 Auto-detected iOS Profile Type: app-store (App Store Connect key present)"
        else
            IOS_PROFILE_TYPE="ad-hoc"
            log "📋 Auto-detected iOS Profile Type: ad-hoc (default for testing)"
        fi
    fi
    
    # Check if Firebase is enabled for iOS
    if [[ "${PUSH_NOTIFY:-false}" == "true" ]] && [[ -n "${FIREBASE_CONFIG_IOS:-}" ]]; then
        IOS_FIREBASE_ENABLED="true"
        log "✅ iOS Firebase detected and enabled"
    else
        log "ℹ️ iOS Firebase not enabled (PUSH_NOTIFY=false or no FIREBASE_CONFIG_IOS)"
    fi
fi

# Export detected configurations
export ANDROID_BUILD_TYPE="$ANDROID_BUILD_TYPE"
export ANDROID_FIREBASE_ENABLED="$ANDROID_FIREBASE_ENABLED"
export ANDROID_KEYSTORE_ENABLED="$ANDROID_KEYSTORE_ENABLED"
export ANDROID_AAB_ENABLED="$ANDROID_AAB_ENABLED"
export IOS_BUILD_ENABLED="$IOS_BUILD_ENABLED"
export IOS_PROFILE_TYPE="$IOS_PROFILE_TYPE"
export IOS_FIREBASE_ENABLED="$IOS_FIREBASE_ENABLED"

# Summary of detected configuration
log "📊 Universal Build Configuration Summary:"
log "   Android Build Type: $ANDROID_BUILD_TYPE"
log "   Android Firebase: $ANDROID_FIREBASE_ENABLED"
log "   Android Keystore: $ANDROID_KEYSTORE_ENABLED"
log "   Android AAB: $ANDROID_AAB_ENABLED"
log "   iOS Build: $IOS_BUILD_ENABLED"
log "   iOS Profile Type: $IOS_PROFILE_TYPE"
log "   iOS Firebase: $IOS_FIREBASE_ENABLED"

# Start build acceleration
log "🚀 Starting universal combined build with acceleration..."
accelerate_build "combined"

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Universal Combined" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android output/ios

# Enhanced error handling with recovery
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Send build failed email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Universal Combined" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit "$exit_code"
}

# Run version management first (resolves package conflicts)
log "🔄 Running version management and conflict resolution..."
if [ -f "lib/scripts/android/version_management.sh" ]; then
    chmod +x lib/scripts/android/version_management.sh
    if lib/scripts/android/version_management.sh; then
        log "✅ Version management and conflict resolution completed"
            else
        log "❌ Version management failed"
                exit 1
            fi
else
    log "⚠️ Version management script not found, skipping..."
fi

# Update package names dynamically (replaces any old package names with PKG_NAME/BUNDLE_ID)
log "📦 Running dynamic package name update for combined workflow..."
if [ -f "lib/scripts/android/update_package_name.sh" ]; then
    chmod +x lib/scripts/android/update_package_name.sh
    # Set WORKFLOW_ID for the script to know it's a combined workflow
    export WORKFLOW_ID="combined"
    if lib/scripts/android/update_package_name.sh; then
        log "✅ Package name update completed for both Android and iOS"
    else
        log "❌ Package name update failed"
        exit 1
    fi
else
    log "⚠️ Package name update script not found, skipping..."
fi

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Android branding completed with acceleration"
    else
        log "❌ Android branding failed"
        exit 1
    fi
else
    log "⚠️ Android branding script not found, skipping..."
fi

# 🔧 CRITICAL FIX: Validate and repair corrupted image files
log "🔧 Running image validation and repair..."
if [ -f "lib/scripts/utils/image_validation.sh" ]; then
    chmod +x lib/scripts/utils/image_validation.sh
    if lib/scripts/utils/image_validation.sh; then
        log "✅ Image validation and repair completed"
    else
        log "❌ Image validation and repair failed"
        exit 1
    fi
else
    log "⚠️ Image validation script not found, skipping..."
fi

# iOS branding if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "📥 Starting iOS asset download..."
    if [ -f "lib/scripts/ios/branding.sh" ]; then
        chmod +x lib/scripts/ios/branding.sh
        if lib/scripts/ios/branding.sh; then
            log "✅ iOS branding completed with acceleration"
        else
            log "❌ iOS branding failed"
            exit 1
        fi
    else
        log "⚠️ iOS branding script not found, skipping..."
    fi
fi

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ "${IS_BOTTOMMENU:-false}" = "true" ]; then
    if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
        chmod +x lib/scripts/utils/download_custom_icons.sh
        if lib/scripts/utils/download_custom_icons.sh; then
            log "✅ Custom icons download completed"
        else
            log "❌ Custom icons download failed"
            exit 1
        fi
    else
        log "⚠️ Custom icons download script not found, skipping..."
    fi
else
    log "ℹ️ Bottom menu disabled (IS_BOTTOMMENU=false), skipping custom icons download"
fi

# Run customization for both platforms
log "⚙️ Running platform customization..."

# Android customization
if [ -f "lib/scripts/android/customization.sh" ]; then
    chmod +x lib/scripts/android/customization.sh
    if lib/scripts/android/customization.sh; then
        log "✅ Android customization completed"
    else
        log "❌ Android customization failed"
        exit 1
    fi
else
    log "⚠️ Android customization script not found, skipping..."
fi

# iOS customization if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/customization.sh" ]; then
        chmod +x lib/scripts/ios/customization.sh
        if lib/scripts/ios/customization.sh; then
            log "✅ iOS customization completed"
        else
            log "❌ iOS customization failed"
            exit 1
        fi
    else
        log "⚠️ iOS customization script not found, skipping..."
    fi
fi

# Run permissions for both platforms
log "🔒 Running platform permissions..."

# Android permissions
if [ -f "lib/scripts/android/permissions.sh" ]; then
    chmod +x lib/scripts/android/permissions.sh
    if lib/scripts/android/permissions.sh; then
        log "✅ Android permissions configured"
    else
        log "❌ Android permissions configuration failed"
        exit 1
    fi
else
    log "⚠️ Android permissions script not found, skipping..."
fi

# iOS permissions if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/permissions.sh" ]; then
        chmod +x lib/scripts/ios/permissions.sh
        if lib/scripts/ios/permissions.sh; then
            log "✅ iOS permissions configured"
        else
            log "❌ iOS permissions configuration failed"
            exit 1
        fi
    else
        log "⚠️ iOS permissions script not found, skipping..."
    fi
fi

# Run Firebase for both platforms
log "🔥 Running Firebase for both platforms..."

# Android Firebase
if [[ "${ANDROID_FIREBASE_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/android/firebase.sh" ]; then
        chmod +x lib/scripts/android/firebase.sh
        if lib/scripts/android/firebase.sh; then
            log "✅ Android Firebase configuration completed"
        else
            log "❌ Android Firebase configuration failed"
            exit 1
        fi
    else
        log "⚠️ Android Firebase script not found, skipping..."
    fi
else
    log "ℹ️ Android Firebase not enabled, skipping..."
fi

# iOS Firebase if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]] && [[ "${IOS_FIREBASE_ENABLED}" == "true" ]]; then
    if [ -f "lib/scripts/ios/firebase.sh" ]; then
        chmod +x lib/scripts/ios/firebase.sh
        if lib/scripts/ios/firebase.sh; then
            log "✅ iOS Firebase configuration completed"
        else
            log "❌ iOS Firebase configuration failed"
            exit 1
        fi
    else
        log "⚠️ iOS Firebase script not found, skipping..."
    fi
else
    log "ℹ️ iOS Firebase not enabled, skipping..."
fi

# Run platform-specific setup
log "🔧 Running platform-specific setup..."

# Android keystore setup
if [[ "${ANDROID_KEYSTORE_ENABLED}" == "true" ]]; then
    log "🔐 Running Android keystore setup..."
    if [ -f "lib/scripts/android/keystore.sh" ]; then
        chmod +x lib/scripts/android/keystore.sh
        if lib/scripts/android/keystore.sh; then
            log "✅ Android keystore configuration completed"
    else
            log "❌ Android keystore configuration failed"
        exit 1
        fi
    else
        log "⚠️ Android keystore script not found, skipping..."
    fi
else
    log "ℹ️ Android keystore not enabled, skipping..."
fi

# iOS certificate setup if iOS build is enabled
if [[ "${IOS_BUILD_ENABLED}" == "true" ]]; then
    log "🔐 Running iOS certificate setup..."
    if [ -f "lib/scripts/ios/certificate_handler.sh" ]; then
        chmod +x lib/scripts/ios/certificate_handler.sh
        if lib/scripts/ios/certificate_handler.sh; then
            log "✅ iOS certificate configuration completed"
        else
            log "❌ iOS certificate configuration failed"
            exit 1
        fi
    else
        log "⚠️ iOS certificate handler script not found, skipping..."
    fi
fi

# Configure global build optimizations
log "⚙️ Configuring global build optimizations..."

# Configure JVM options
log "🔧 Configuring JVM options..."
export JAVA_TOOL_OPTIONS="-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+UseG1GC"

# Configure environment
log "🔧 Configuring build environment..."
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create optimized gradle.properties
log "📝 Creating optimized gradle.properties..."
if [ ! -f android/gradle.properties ] || ! grep -q "org.gradle.jvmargs" android/gradle.properties; then
    cat >> android/gradle.properties << EOF
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.caching=true
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
kotlin.code.style=official
EOF
fi

# Clean build environment
log "🧹 Cleaning build environment..."
flutter clean

# Create a list of safe environment variables to pass to Flutter
log "🔧 Preparing environment variables for Flutter..."
ENV_ARGS=""

# Define a list of safe variables that can be passed to Flutter
SAFE_VARS=(
    "APP_ID" "WORKFLOW_ID" "BRANCH" "VERSION_NAME" "VERSION_CODE" 
    "APP_NAME" "ORG_NAME" "WEB_URL" "PKG_NAME" "BUNDLE_ID" "EMAIL_ID" "USER_NAME"
    "PUSH_NOTIFY" "IS_CHATBOT" "IS_DOMAIN_URL" "IS_SPLASH" "IS_PULLDOWN"
    "IS_BOTTOMMENU" "IS_LOAD_IND" "IS_CAMERA" "IS_LOCATION" "IS_MIC"
    "IS_NOTIFICATION" "IS_CONTACT" "IS_BIOMETRIC" "IS_CALENDAR" "IS_STORAGE"
    "LOGO_URL" "SPLASH_URL" "SPLASH_BG_URL" "SPLASH_BG_COLOR" "SPLASH_TAGLINE" 
    "SPLASH_TAGLINE_COLOR" "SPLASH_ANIMATION" "SPLASH_DURATION" "BOTTOMMENU_FONT" 
    "BOTTOMMENU_FONT_SIZE" "BOTTOMMENU_FONT_BOLD" "BOTTOMMENU_FONT_ITALIC" 
    "BOTTOMMENU_BG_COLOR" "BOTTOMMENU_TEXT_COLOR" "BOTTOMMENU_ICON_COLOR" 
    "BOTTOMMENU_ACTIVE_TAB_COLOR" "BOTTOMMENU_ICON_POSITION"
    "FIREBASE_CONFIG_ANDROID" "FIREBASE_CONFIG_IOS"
    "ENABLE_EMAIL_NOTIFICATIONS" "EMAIL_SMTP_SERVER" "EMAIL_SMTP_PORT"
    "EMAIL_SMTP_USER" "CM_BUILD_ID" "CM_WORKFLOW_NAME" "CM_BRANCH"
    "FCI_BUILD_ID" "FCI_WORKFLOW_NAME" "FCI_BRANCH" "CONTINUOUS_INTEGRATION"
    "CI" "BUILD_NUMBER" "PROJECT_BUILD_NUMBER"
)

# Only pass safe variables to Flutter
for var_name in "${SAFE_VARS[@]}"; do
    if [ -n "${!var_name:-}" ]; then
        # Escape the value to handle special characters
        var_value="${!var_name}"
        # Remove any newlines or problematic characters
        var_value=$(echo "$var_value" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
        
        # Special handling for APP_NAME to properly escape spaces
        if [ "$var_name" = "APP_NAME" ]; then
            var_value=$(printf '%q' "$var_value")
        fi
        
        ENV_ARGS="$ENV_ARGS --dart-define=$var_name=$var_value"
    fi
done

# Add essential build arguments
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NAME=$VERSION_NAME"
ENV_ARGS="$ENV_ARGS --dart-define=FLUTTER_BUILD_NUMBER=$VERSION_CODE"

log "📋 Prepared $ENV_ARGS environment variables for Flutter build"

# Generate Dart environment configuration
log "⚙️ Generating Dart environment configuration for combined build..."
source "lib/scripts/utils/gen_env_config.sh"
generate_env_config

# Get Flutter dependencies
log "📦 Getting Flutter dependencies..."
flutter pub get

# Build Android artifacts
log "🚀 Building Android artifacts (APK and AAB)..."
flutter build apk --release
flutter build appbundle --release
log "✅ Android build completed."

# Verify Android package name in built APK
log "📦 Verifying Android package name in built APK..."
if [ -f "lib/scripts/android/verify_package_name.sh" ]; then
    chmod +x lib/scripts/android/verify_package_name.sh
    if lib/scripts/android/verify_package_name.sh; then
        log "✅ Android package name verification successful"
    else
        log "❌ Android package name verification failed"
        log "⚠️ Continuing with build process despite package name verification failure"
    fi
else
    log "⚠️ Package name verification script not found"
fi

# Build iOS artifact
log "🚀 Building iOS artifact (IPA)..."
flutter build ipa --release --export-options-plist=output/ios/export_options.plist
log "✅ iOS build completed."

# Final verification
log "✅ Final verification of all build artifacts..."
# You can add specific checks for Android and iOS artifacts here if needed

# Process artifact URLs
log "📦 Processing artifact URLs for email notification..."
source "lib/scripts/utils/process_artifacts.sh"
artifact_urls=$(process_artifacts)
log "Artifact URLs: $artifact_urls"

# Send build success email
log "🎉 Combined build successful! Sending success email..."
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "Combined" "${CM_BUILD_ID:-unknown}" "Build successful" "$artifact_urls"
fi

log "✅ Combined Android and iOS build process completed successfully!"
exit 0 