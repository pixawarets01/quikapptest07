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

# Start build acceleration
log "🚀 Starting Android build with acceleration..."
accelerate_build "android"

# CRITICAL FIX: Ensure Java imports are present in build.gradle.kts
log "🔧 Ensuring Java imports in build.gradle.kts..."
if [ -f "android/app/build.gradle.kts" ]; then
    if ! grep -q 'import java.util.Properties' android/app/build.gradle.kts; then
        log "Adding missing Java imports to build.gradle.kts"
        # Create a temporary file with imports at the top
        {
            echo "import java.util.Properties"
            echo "import java.io.FileInputStream"
            echo ""
            cat android/app/build.gradle.kts
        } > android/app/build.gradle.kts.tmp
        mv android/app/build.gradle.kts.tmp android/app/build.gradle.kts
        log "✅ Java imports added to build.gradle.kts"
    else
        log "✅ Java imports already present in build.gradle.kts"
    fi
else
    log "⚠️ build.gradle.kts not found"
fi

# Generate complete build.gradle.kts based on workflow
log "📝 Generating build.gradle.kts for workflow: ${WORKFLOW_ID:-unknown}"

# Backup original file
cp android/app/build.gradle.kts android/app/build.gradle.kts.original 2>/dev/null || true

# Determine keystore configuration based on workflow
KEYSTORE_CONFIG=""
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    KEYSTORE_CONFIG='
        create("release") {
            val keystorePropertiesFile = rootProject.file("app/src/keystore.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file("src/" + keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }'
else
    KEYSTORE_CONFIG='
        // No keystore configuration for this workflow'
fi

# Determine build type configuration
BUILD_TYPE_CONFIG=""
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    BUILD_TYPE_CONFIG='
        release {
            val keystorePropertiesFile = rootProject.file("app/src/keystore.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
                println("🔐 Using RELEASE signing with keystore")
            } else {
                // Fallback to debug signing if keystore not available
                signingConfig = signingConfigs.getByName("debug")
                println("⚠️ Using DEBUG signing (keystore not found)")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }'
else
    BUILD_TYPE_CONFIG='
        release {
            // Debug signing for free/paid workflows
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }'
fi

# Generate complete build.gradle.kts with optimizations
cat > android/app/build.gradle.kts <<EOF
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "${PKG_NAME:-com.example.quikapptest06}"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        // Enhanced Kotlin compilation optimizations
        freeCompilerArgs += listOf(
            "-Xno-param-assertions",
            "-Xno-call-assertions",
            "-Xno-receiver-assertions",
            "-Xno-optimized-callable-references",
            "-Xuse-ir",
            "-Xskip-prerelease-check"
        )
    }

    defaultConfig {
        // Application ID will be updated by customization script
        applicationId = "${PKG_NAME:-com.example.quikapptest06}"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Optimized architecture targeting
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // Enhanced AGP 8.7.3 optimizations
    buildFeatures {
        buildConfig = true
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
        viewBinding = false
        dataBinding = false
    }

    signingConfigs {$KEYSTORE_CONFIG
    }

    buildTypes {$BUILD_TYPE_CONFIG
    }
    
    // Build optimization settings
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            excludes += listOf("META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/LICENSE.txt", "META-INF/license.txt", "META-INF/NOTICE", "META-INF/NOTICE.txt", "META-INF/notice.txt", "META-INF/ASL2.0", "META-INF/*.kotlin_module")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
EOF

log "✅ Generated optimized build.gradle.kts for ${WORKFLOW_ID:-unknown} workflow"

# Enhanced error handling with recovery
trap 'handle_error $LINENO $?' ERR

handle_error() {
    local line_no=$1
    local exit_code=$2
    local error_msg="Error occurred at line $line_no. Exit code: $exit_code"
    
    log "❌ $error_msg"
    
    # Perform emergency cleanup
    log "🚨 Performing emergency cleanup..."
    
    # Stop all Gradle processes
    log "🛑 Stopping Gradle daemon..."
    # Ensure we're in the project root directory first
    if [ "$(basename "$PWD")" = "android" ]; then
        cd ..
    fi

    if [ -d "android" ]; then
        cd android
        if [ -f gradlew ]; then
            ./gradlew --stop || true
        fi
        cd ..
    else
        log "⚠️ android directory not found, skipping Gradle daemon stop"
    fi
    
    # Clear all caches
    flutter clean 2>/dev/null || true
    rm -rf ~/.gradle/caches/ 2>/dev/null || true
    rm -rf .dart_tool/ 2>/dev/null || true
    rm -rf build/ 2>/dev/null || true
    
    # Force garbage collection
    java -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -Xmx1G -version 2>/dev/null || true
    
    # Generate detailed error report
    log "📊 Generating detailed error report..."
    
    # System diagnostics
    if command -v free >/dev/null 2>&1; then
        AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        log "📊 Memory at failure: ${AVAILABLE_MEM}MB available"
    fi
    
    # shellcheck disable=SC2317
    if command -v df >/dev/null 2>&1; then
        DISK_SPACE=$(df -h . | awk 'NR==2{print $4}')
        log "💾 Disk space at failure: $DISK_SPACE"
    fi
    
    # Send build failed email
    # shellcheck disable=SC2317
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Android" "${CM_BUILD_ID:-unknown}" "$error_msg" || true
    fi
    
    exit "$exit_code"
}

# Send build started email
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_started" "Android" "${CM_BUILD_ID:-unknown}" || true
fi

# Create necessary directories
mkdir -p output/android

# ============================================================================
# 🔍 COMPREHENSIVE VARIABLE VALIDATION AND DEBUG INFORMATION
# ============================================================================

log "🔍 ===== COMPREHENSIVE VARIABLE VALIDATION AND DEBUG ====="

# Function to validate and display variable
validate_var() {
    local var_name=$1
    local var_value=$2
    local is_required=$3
    local description=$4
    
    if [ -n "$var_value" ]; then
        log "✅ $var_name: '$var_value' - $description"
    else
        if [ "$is_required" = "true" ]; then
            log "❌ $var_name: [MISSING - REQUIRED] - $description"
        else
            log "⚠️  $var_name: [EMPTY - OPTIONAL] - $description"
        fi
    fi
}

log "📱 ===== APP METADATA VARIABLES ====="
validate_var "APP_ID" "${APP_ID:-}" "true" "Unique app identifier"
validate_var "APP_NAME" "${APP_NAME:-}" "true" "Application display name"
validate_var "ORG_NAME" "${ORG_NAME:-}" "true" "Organization name"
validate_var "WEB_URL" "${WEB_URL:-}" "true" "Website URL"
validate_var "USER_NAME" "${USER_NAME:-}" "true" "Developer username"
validate_var "EMAIL_ID" "${EMAIL_ID:-}" "true" "Developer email"

log "📦 ===== PACKAGE AND VERSION VARIABLES ====="
validate_var "PKG_NAME" "${PKG_NAME:-}" "true" "Android package name"
validate_var "VERSION_NAME" "${VERSION_NAME:-}" "true" "App version name"
validate_var "VERSION_CODE" "${VERSION_CODE:-}" "true" "App version code"
validate_var "WORKFLOW_ID" "${WORKFLOW_ID:-}" "true" "Build workflow identifier"

log "🎨 ===== BRANDING VARIABLES ====="
validate_var "LOGO_URL" "${LOGO_URL:-}" "true" "App logo image URL"
validate_var "SPLASH_URL" "${SPLASH_URL:-}" "false" "Splash screen image URL"
validate_var "SPLASH_BG_URL" "${SPLASH_BG_URL:-}" "false" "Splash background image URL"
validate_var "SPLASH_BG_COLOR" "${SPLASH_BG_COLOR:-}" "false" "Splash background color"

log "🔧 ===== FEATURE FLAGS ====="
validate_var "PUSH_NOTIFY" "${PUSH_NOTIFY:-}" "false" "Push notifications enabled"
validate_var "IS_CHATBOT" "${IS_CHATBOT:-}" "false" "Chatbot feature enabled"
validate_var "IS_DOMAIN_URL" "${IS_DOMAIN_URL:-}" "false" "Deep linking enabled"
validate_var "IS_SPLASH" "${IS_SPLASH:-}" "false" "Splash screen enabled"
validate_var "IS_PULLDOWN" "${IS_PULLDOWN:-}" "false" "Pull to refresh enabled"
validate_var "IS_BOTTOMMENU" "${IS_BOTTOMMENU:-}" "false" "Bottom menu enabled"
validate_var "IS_LOAD_IND" "${IS_LOAD_IND:-}" "false" "Loading indicator enabled"

log "🔐 ===== PERMISSION FLAGS ====="
validate_var "IS_CAMERA" "${IS_CAMERA:-}" "false" "Camera permission"
validate_var "IS_LOCATION" "${IS_LOCATION:-}" "false" "Location permission"
validate_var "IS_MIC" "${IS_MIC:-}" "false" "Microphone permission"
validate_var "IS_NOTIFICATION" "${IS_NOTIFICATION:-}" "false" "Notification permission"
validate_var "IS_CONTACT" "${IS_CONTACT:-}" "false" "Contacts permission"
validate_var "IS_BIOMETRIC" "${IS_BIOMETRIC:-}" "false" "Biometric permission"
validate_var "IS_CALENDAR" "${IS_CALENDAR:-}" "false" "Calendar permission"
validate_var "IS_STORAGE" "${IS_STORAGE:-}" "false" "Storage permission"

log "🔥 ===== FIREBASE CONFIGURATION ====="
validate_var "FIREBASE_CONFIG_ANDROID" "${FIREBASE_CONFIG_ANDROID:-}" "false" "Firebase Android config URL"

log "🔐 ===== ANDROID KEYSTORE VARIABLES ====="
validate_var "KEY_STORE_URL" "${KEY_STORE_URL:-}" "false" "Keystore file URL"
validate_var "CM_KEYSTORE_PASSWORD" "${CM_KEYSTORE_PASSWORD:-}" "false" "Keystore password"
validate_var "CM_KEY_ALIAS" "${CM_KEY_ALIAS:-}" "false" "Key alias"
validate_var "CM_KEY_PASSWORD" "${CM_KEY_PASSWORD:-}" "false" "Key password"

log "📧 ===== EMAIL NOTIFICATION VARIABLES ====="
validate_var "ENABLE_EMAIL_NOTIFICATIONS" "${ENABLE_EMAIL_NOTIFICATIONS:-}" "false" "Email notifications enabled"
validate_var "EMAIL_SMTP_SERVER" "${EMAIL_SMTP_SERVER:-}" "false" "SMTP server"
validate_var "EMAIL_SMTP_PORT" "${EMAIL_SMTP_PORT:-}" "false" "SMTP port"
validate_var "EMAIL_SMTP_USER" "${EMAIL_SMTP_USER:-}" "false" "SMTP username"
validate_var "EMAIL_SMTP_PASS" "${EMAIL_SMTP_PASS:+[SET]}" "false" "SMTP password"

log "🏗️ ===== BUILD ENVIRONMENT VARIABLES ====="
validate_var "CM_BUILD_ID" "${CM_BUILD_ID:-}" "false" "Codemagic build ID"
validate_var "CM_PROJECT_ID" "${CM_PROJECT_ID:-}" "false" "Codemagic project ID"
validate_var "BUILD_MODE" "${BUILD_MODE:-}" "false" "Build mode (debug/release)"

log "🔍 ===== CRITICAL VARIABLE VALIDATION ====="

# Check for critical missing variables
MISSING_CRITICAL=()

[ -z "${APP_NAME:-}" ] && MISSING_CRITICAL+=("APP_NAME")
[ -z "${PKG_NAME:-}" ] && MISSING_CRITICAL+=("PKG_NAME")
[ -z "${VERSION_NAME:-}" ] && MISSING_CRITICAL+=("VERSION_NAME")
[ -z "${VERSION_CODE:-}" ] && MISSING_CRITICAL+=("VERSION_CODE")
[ -z "${LOGO_URL:-}" ] && MISSING_CRITICAL+=("LOGO_URL")

if [ ${#MISSING_CRITICAL[@]} -gt 0 ]; then
    log "❌ CRITICAL ERROR: Missing required variables:"
    for var in "${MISSING_CRITICAL[@]}"; do
        log "   - $var"
    done
    log "🛑 Build cannot continue without these variables"
    exit 1
else
    log "✅ All critical variables are present"
fi

log "🎯 ===== BUILD CONFIGURATION SUMMARY ====="
log "   App: ${APP_NAME:-Unknown} v${VERSION_NAME:-0.0.0} (${VERSION_CODE:-0})"
log "   Package: ${PKG_NAME:-Unknown}"
log "   Workflow: ${WORKFLOW_ID:-Unknown}"
log "   Firebase: ${PUSH_NOTIFY:-false}"
log "   Keystore: ${KEY_STORE_URL:+Available}"
log "   Email: ${ENABLE_EMAIL_NOTIFICATIONS:-false}"

log "🔍 ===== END VARIABLE VALIDATION ====="

# ============================================================================

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

# Enhanced asset download with parallel processing
log "📥 Starting enhanced asset download..."
if [ -f "lib/scripts/android/branding.sh" ]; then
    chmod +x lib/scripts/android/branding.sh
    if lib/scripts/android/branding.sh; then
        log "✅ Android branding completed with acceleration"
        
        # Validate required assets after branding
        log "🔍 Validating Android assets..."
        required_assets=("assets/images/logo.png" "assets/images/splash.png")
        for asset in "${required_assets[@]}"; do
            if [ -f "$asset" ] && [ -s "$asset" ]; then
                log "✅ $asset exists and has content"
            else
                log "❌ $asset is missing or empty after branding"
                exit 1
            fi
        done
        log "✅ All Android assets validated"
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

# Download custom icons for bottom menu
log "🎨 Downloading custom icons for bottom menu..."
if [ "${IS_BOTTOMMENU:-false}" = "true" ]; then
    if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
        chmod +x lib/scripts/utils/download_custom_icons.sh
        if lib/scripts/utils/download_custom_icons.sh; then
            log "✅ Custom icons download completed"
            
            # Validate custom icons if BOTTOMMENU_ITEMS contains custom icons
            if [ -n "${BOTTOMMENU_ITEMS:-}" ]; then
                log "🔍 Validating custom icons..."
                if [ -d "assets/icons" ] && [ "$(ls -A assets/icons 2>/dev/null)" ]; then
                    log "✅ Custom icons found in assets/icons/"
                    ls -la assets/icons/ | while read -r line; do
                        log "   $line"
                    done
                else
                    log "ℹ️ No custom icons found (using preset icons only)"
                fi
            fi
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

# Run customization with acceleration
log "⚙️ Running Android customization with acceleration..."
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

# Run permissions with acceleration
log "🔒 Running Android permissions with acceleration..."
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

# Run Firebase with acceleration
log "🔥 Running Android Firebase with acceleration..."
if [ "${WORKFLOW_ID:-}" = "android-free" ]; then
    log "ℹ️ android-free workflow detected - skipping Firebase setup (PUSH_NOTIFY=false)"
    log "✅ Firebase setup skipped for android-free workflow"
elif [ "${WORKFLOW_ID:-}" = "android-paid" ]; then
    if [ "${PUSH_NOTIFY:-}" = "true" ]; then
        log "ℹ️ android-paid workflow detected with PUSH_NOTIFY=true - enabling Firebase setup"
        if [ -n "${FIREBASE_CONFIG_ANDROID:-}" ]; then
            log "✅ Firebase config URL provided - proceeding with Firebase setup"
            if [ -f "lib/scripts/android/firebase.sh" ]; then
                chmod +x lib/scripts/android/firebase.sh
                if lib/scripts/android/firebase.sh; then
                    log "✅ Android Firebase configuration completed for android-paid workflow"
                else
                    log "❌ Android Firebase configuration failed"
                    exit 1
                fi
            else
                log "❌ Android Firebase script not found"
                exit 1
            fi
        else
            log "❌ PUSH_NOTIFY=true but no FIREBASE_CONFIG_ANDROID provided"
            log "❌ Firebase setup cannot proceed without configuration URL"
            exit 1
        fi
    else
        log "ℹ️ android-paid workflow detected with PUSH_NOTIFY=false - skipping Firebase setup"
        log "✅ Firebase setup skipped for android-paid workflow (push notifications disabled)"
    fi
elif [ "${WORKFLOW_ID:-}" = "android-publish" ]; then
    if [ "${PUSH_NOTIFY:-}" = "true" ]; then
        log "ℹ️ android-publish workflow detected with PUSH_NOTIFY=true - enabling Firebase setup"
        if [ -n "${FIREBASE_CONFIG_ANDROID:-}" ]; then
            log "✅ Firebase config URL provided - proceeding with Firebase setup"
            if [ -f "lib/scripts/android/firebase.sh" ]; then
                chmod +x lib/scripts/android/firebase.sh
                if lib/scripts/android/firebase.sh; then
                    log "✅ Android Firebase configuration completed for android-publish workflow"
                else
                    log "❌ Android Firebase configuration failed"
                    exit 1
                fi
            else
                log "❌ Android Firebase script not found"
                exit 1
            fi
        else
            log "❌ PUSH_NOTIFY=true but no FIREBASE_CONFIG_ANDROID provided"
            log "❌ Firebase setup cannot proceed without configuration URL"
            exit 1
        fi
    else
        log "ℹ️ android-publish workflow detected with PUSH_NOTIFY=false - skipping Firebase setup"
        log "✅ Firebase setup skipped for android-publish workflow (push notifications disabled)"
    fi
elif [ -f "lib/scripts/android/firebase.sh" ]; then
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

# Run keystore with acceleration
log "🔐 Running Android keystore with acceleration..."
if [ "${WORKFLOW_ID:-}" = "android-free" ] || [ "${WORKFLOW_ID:-}" = "android-paid" ]; then
    log "ℹ️ ${WORKFLOW_ID:-} workflow detected - skipping keystore setup (debug signing enabled)"
    log "✅ Keystore setup skipped for ${WORKFLOW_ID:-} workflow - will use debug signing"
elif [ "${WORKFLOW_ID:-}" = "android-publish" ]; then
    log "ℹ️ android-publish workflow detected - enabling keystore setup (release signing)"
    if [ -n "${KEY_STORE_URL:-}" ] && [ -n "${CM_KEYSTORE_PASSWORD:-}" ] && [ -n "${CM_KEY_ALIAS:-}" ] && [ -n "${CM_KEY_PASSWORD:-}" ]; then
        log "✅ All keystore credentials provided - proceeding with keystore setup"
        if [ -f "lib/scripts/android/keystore.sh" ]; then
            chmod +x lib/scripts/android/keystore.sh
            if lib/scripts/android/keystore.sh; then
                log "✅ Android keystore configuration completed for android-publish workflow"
            else
                log "❌ Android keystore configuration failed"
                exit 1
            fi
        else
            log "❌ Android keystore script not found"
            exit 1
        fi
    else
        log "❌ Incomplete keystore configuration for android-publish workflow"
        log "❌ Required: KEY_STORE_URL, CM_KEYSTORE_PASSWORD, CM_KEY_ALIAS, CM_KEY_PASSWORD"
        log "❌ Missing variables:"
        [ -z "${KEY_STORE_URL:-}" ] && log "   - KEY_STORE_URL"
        [ -z "${CM_KEYSTORE_PASSWORD:-}" ] && log "   - CM_KEYSTORE_PASSWORD"
        [ -z "${CM_KEY_ALIAS:-}" ] && log "   - CM_KEY_ALIAS"
        [ -z "${CM_KEY_PASSWORD:-}" ] && log "   - CM_KEY_PASSWORD"
        exit 1
    fi
elif [ -f "lib/scripts/android/keystore.sh" ]; then
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

# Update package names dynamically (replaces any old package names with PKG_NAME)
log "📦 Running dynamic package name update..."
if [ -f "lib/scripts/android/update_package_name.sh" ]; then
    chmod +x lib/scripts/android/update_package_name.sh
    if lib/scripts/android/update_package_name.sh; then
        log "✅ Package name update completed"
    else
        log "❌ Package name update failed"
        exit 1
    fi
else
    log "⚠️ Package name update script not found, skipping..."
fi

# Force regenerate environment configuration to ensure latest variables
log "🔄 Force regenerating environment configuration..."
generate_env_config

# Clean Flutter build cache first
log "🧹 Cleaning Flutter build cache..."
flutter clean

# Clear Dart analysis cache to ensure fresh compilation
log "🧹 Clearing Dart analysis cache..."
rm -rf .dart_tool/package_config.json 2>/dev/null || true
rm -rf .dart_tool/package_config_subset 2>/dev/null || true

# Get Flutter dependencies
log "📦 Getting Flutter dependencies..."
flutter pub get

# Verify environment configuration is correct
log "🔍 Verifying environment configuration..."
if [ -f "lib/config/env_config.dart" ]; then
    # Check for the problematic $BRANCH pattern
    if grep -q '\$BRANCH' lib/config/env_config.dart; then
        log "❌ CRITICAL: Found problematic \$BRANCH pattern in env_config.dart"
        log "🔧 Force regenerating environment configuration..."
        generate_env_config
        
        # Clear all possible caches
        log "🧹 Aggressive cache clearing..."
        rm -rf .dart_tool/ 2>/dev/null || true
        rm -rf build/ 2>/dev/null || true
        rm -rf ~/.pub-cache/hosted/pub.dartlang.org/ 2>/dev/null || true
        
        # Verify fix worked
        if grep -q '\$BRANCH' lib/config/env_config.dart; then
            log "❌ FAILED: Still contains \$BRANCH after regeneration"
            log "📋 Current problematic content:"
            grep -n "branch" lib/config/env_config.dart || true
            exit 1
        else
            log "✅ Successfully fixed \$BRANCH issue"
        fi
    fi
    
    if grep -q "static const String branch = \"main\"" lib/config/env_config.dart; then
        log "✅ Environment configuration verified - using static values"
    elif grep -q "static const String branch = \"\${BRANCH:-main}\"" lib/config/env_config.dart; then
        log "✅ Environment configuration verified - using dynamic values"
    else
        log "⚠️ Environment configuration may have issues"
        log "📋 Current branch line:"
        grep -n "branch" lib/config/env_config.dart || true
    fi
else
    log "❌ Environment configuration file not found"
    exit 1
fi

# ============================================================================
# 🔍 FINAL STATE DEBUG INFORMATION (AFTER ALL CHANGES)
# ============================================================================

log "🔍 ===== FINAL STATE DEBUG INFORMATION ====="

log "📱 ===== PUBSPEC.YAML VERSION CHECK ====="
if [ -f "pubspec.yaml" ]; then
    VERSION_LINE=$(grep "^version:" pubspec.yaml || echo "version: NOT_FOUND")
    log "✅ pubspec.yaml version: $VERSION_LINE"
else
    log "❌ pubspec.yaml not found"
fi

log "🏗️ ===== BUILD.GRADLE.KTS CONFIGURATION CHECK ====="
if [ -f "android/app/build.gradle.kts" ]; then
    log "✅ build.gradle.kts exists"
    
    # Check namespace
    NAMESPACE_LINE=$(grep "namespace = " android/app/build.gradle.kts || echo "namespace = NOT_FOUND")
    log "📦 Namespace: $NAMESPACE_LINE"
    
    # Check applicationId
    APP_ID_LINE=$(grep "applicationId = " android/app/build.gradle.kts || echo "applicationId = NOT_FOUND")
    log "📦 Application ID: $APP_ID_LINE"
    
    # Check versionCode
    VERSION_CODE_LINE=$(grep "versionCode = " android/app/build.gradle.kts || echo "versionCode = NOT_FOUND")
    log "📊 Version Code: $VERSION_CODE_LINE"
    
    # Check versionName
    VERSION_NAME_LINE=$(grep "versionName = " android/app/build.gradle.kts || echo "versionName = NOT_FOUND")
    log "📊 Version Name: $VERSION_NAME_LINE"
    
    # Check for any bash syntax (should be none)
    if grep -q '\${' android/app/build.gradle.kts; then
        log "❌ CRITICAL: Found bash syntax in build.gradle.kts:"
        grep '\${' android/app/build.gradle.kts | while read -r line; do
            log "   🚨 $line"
        done
        log "🛑 This will cause Gradle compilation errors!"
        exit 1
    else
        log "✅ No bash syntax found in build.gradle.kts"
    fi
    
    # Check signing configuration
    if grep -q "signingConfigs" android/app/build.gradle.kts; then
        log "🔐 Signing configuration: Present"
        if grep -q "keystorePropertiesFile.exists()" android/app/build.gradle.kts; then
            log "🔐 Keystore configuration: Dynamic (checks for keystore.properties)"
        fi
    else
        log "🔐 Signing configuration: Missing"
    fi
else
    log "❌ build.gradle.kts not found"
    exit 1
fi

log "📋 ===== ANDROIDMANIFEST.XML CHECK ====="
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    log "✅ AndroidManifest.xml exists"
    
    # Check package attribute
    PACKAGE_LINE=$(grep "package=" android/app/src/main/AndroidManifest.xml || echo "package=NOT_FOUND")
    log "📦 Package attribute: $PACKAGE_LINE"
    
    # Check permissions
    PERMISSION_COUNT=$(grep -c "uses-permission" android/app/src/main/AndroidManifest.xml || echo "0")
    log "🔐 Permissions count: $PERMISSION_COUNT"
else
    log "❌ AndroidManifest.xml not found"
fi

log "🔥 ===== FIREBASE CONFIGURATION CHECK ====="
if [ -f "android/app/google-services.json" ]; then
    FIREBASE_SIZE=$(stat -f%z android/app/google-services.json 2>/dev/null || stat -c%s android/app/google-services.json 2>/dev/null || echo "0")
    log "✅ Firebase config: Present (${FIREBASE_SIZE} bytes)"
    
    # Check package name in Firebase config
    if command -v jq >/dev/null 2>&1; then
        FIREBASE_PKG=$(jq -r '.client[0].client_info.android_client_info.package_name' android/app/google-services.json 2>/dev/null || echo "UNKNOWN")
        log "📦 Firebase package: $FIREBASE_PKG"
    fi
else
    log "⚠️  Firebase config: Not found (Push notifications disabled)"
fi

log "🔐 ===== KEYSTORE CONFIGURATION CHECK ====="
if [ -f "android/app/src/keystore.jks" ]; then
    KEYSTORE_SIZE=$(stat -f%z android/app/src/keystore.jks 2>/dev/null || stat -c%s android/app/src/keystore.jks 2>/dev/null || echo "0")
    log "✅ Keystore file: Present (${KEYSTORE_SIZE} bytes)"
else
    log "⚠️  Keystore file: Not found (Debug signing will be used)"
fi

if [ -f "android/app/src/keystore.properties" ]; then
    log "✅ Keystore properties: Present"
    log "📋 Keystore properties content:"
    while IFS= read -r line; do
        if [[ "$line" == *"Password"* ]]; then
            log "   $(echo "$line" | sed 's/=.*/=[PROTECTED]/')"
        else
            log "   $line"
        fi
    done < android/app/src/keystore.properties
else
    log "⚠️  Keystore properties: Not found"
fi

log "🎨 ===== ASSETS CHECK ====="
if [ -f "assets/images/logo.png" ]; then
    LOGO_SIZE=$(stat -f%z assets/images/logo.png 2>/dev/null || stat -c%s assets/images/logo.png 2>/dev/null || echo "0")
    log "✅ Logo: Present (${LOGO_SIZE} bytes)"
else
    log "❌ Logo: Missing"
fi

if [ -f "assets/images/splash.png" ]; then
    SPLASH_SIZE=$(stat -f%z assets/images/splash.png 2>/dev/null || stat -c%s assets/images/splash.png 2>/dev/null || echo "0")
    log "✅ Splash: Present (${SPLASH_SIZE} bytes)"
else
    log "⚠️  Splash: Missing"
fi

log "📋 ===== ENV_CONFIG.DART CHECK ====="
if [ -f "lib/config/env_config.dart" ]; then
    log "✅ env_config.dart exists"
    
    # Show first few lines
    log "📋 First 10 lines of env_config.dart:"
    head -10 lib/config/env_config.dart | while IFS= read -r line; do
        log "   $line"
    done
    
    # Check for problematic patterns
    if grep -q '\$' lib/config/env_config.dart; then
        log "⚠️  Found $ symbols in env_config.dart (check for unresolved variables)"
        grep '\$' lib/config/env_config.dart | head -5 | while IFS= read -r line; do
            log "   🔍 $line"
        done
    else
        log "✅ No unresolved variables in env_config.dart"
    fi
else
    log "❌ env_config.dart not found"
fi

log "🎯 ===== FINAL BUILD READINESS CHECK ====="

# Critical files check
CRITICAL_FILES=(
    "pubspec.yaml"
    "android/app/build.gradle.kts"
    "android/app/src/main/AndroidManifest.xml"
    "lib/config/env_config.dart"
    "assets/images/logo.png"
)

MISSING_FILES=()
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    log "❌ CRITICAL: Missing required files:"
    for file in "${MISSING_FILES[@]}"; do
        log "   - $file"
    done
    log "🛑 Build cannot continue without these files"
    exit 1
else
    log "✅ All critical files are present"
fi

log "🚀 ===== BUILD CONFIGURATION FINAL SUMMARY ====="
log "   📱 App: ${APP_NAME:-Unknown} v${VERSION_NAME:-0.0.0} (${VERSION_CODE:-0})"
log "   📦 Package: ${PKG_NAME:-Unknown}"
log "   🏗️  Workflow: ${WORKFLOW_ID:-Unknown}"
log "   🔥 Firebase: $([ -f "android/app/google-services.json" ] && echo "✅ Configured" || echo "❌ Not configured")"
log "   🔐 Keystore: $([ -f "android/app/src/keystore.jks" ] && echo "✅ Available" || echo "❌ Not available")"
log "   📧 Email: ${ENABLE_EMAIL_NOTIFICATIONS:-false}"
log "   🎨 Assets: $([ -f "assets/images/logo.png" ] && echo "✅ Ready" || echo "❌ Missing")"

log "🔍 ===== END FINAL STATE DEBUG ====="

# ============================================================================

# Determine build command based on workflow
log "🏗️ Determining build command for workflow: ${WORKFLOW_ID:-unknown}"

# ============================================================================
# 🔍 PRE-BUILD CONFIGURATION DISPLAY
# ============================================================================

log "🔍 ===== PRE-BUILD CONFIGURATION DISPLAY ====="

# Display build.gradle.kts configuration
if [ -f "android/app/build.gradle.kts" ]; then
    log "📋 Build Gradle Configuration (android/app/build.gradle.kts):"
    grep -A 12 "defaultConfig {" android/app/build.gradle.kts | head -12 | nl -v1 | while IFS= read -r line; do
        log "        $line"
    done
else
    log "❌ Build Gradle Configuration: File not found"
fi

# Display AndroidManifest.xml configuration
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    log "📋 Android Manifest (android/app/src/main/AndroidManifest.xml):"
    head -10 android/app/src/main/AndroidManifest.xml | nl -v1 | while IFS= read -r line; do
        log "        $line"
    done
else
    log "❌ Android Manifest: File not found"
fi

# Display pubspec.yaml configuration
if [ -f "pubspec.yaml" ]; then
    log "📋 Pubspec Configuration (pubspec.yaml):"
    head -15 pubspec.yaml | nl -v1 | while IFS= read -r line; do
        log "        $line"
    done
else
    log "❌ Pubspec Configuration: File not found"
fi

log "🔍 ===== END PRE-BUILD CONFIGURATION DISPLAY ====="

# ============================================================================

# ============================================================================
# 🎯 WORKFLOW-SPECIFIC CONFIGURATION SUMMARY
# ============================================================================

log "🎯 ===== WORKFLOW CONFIGURATION SUMMARY ====="
log "   Workflow ID: ${WORKFLOW_ID:-Unknown}"
log "   App Name: ${APP_NAME:-Unknown}"
log "   Package: ${PKG_NAME:-Unknown}"

case "${WORKFLOW_ID:-}" in
    "android-free")
        log "📱 ===== ANDROID-FREE WORKFLOW CONFIGURATION ====="
        log "   ✅ Push Notifications: DISABLED (PUSH_NOTIFY=false)"
        log "   ✅ Firebase Setup: SKIPPED (no Firebase config)"
        log "   ✅ Keystore Setup: SKIPPED (debug signing enabled)"
        log "   ✅ Build Type: DEBUG SIGNED APK"
        log "   ✅ Features: Basic app functionality only"
        log "   ℹ️  Note: This APK cannot be uploaded to Google Play Store"
        ;;
    "android-paid")
        log "📱 ===== ANDROID-PAID WORKFLOW CONFIGURATION ====="
        if [ "${PUSH_NOTIFY:-}" = "true" ]; then
            log "   🔥 Push Notifications: ENABLED (PUSH_NOTIFY=true)"
            log "   🔥 Firebase Setup: ENABLED (if FIREBASE_CONFIG_ANDROID provided)"
            log "   ✅ Keystore Setup: SKIPPED (debug signing enabled)"
            log "   ✅ Build Type: DEBUG SIGNED APK with Firebase"
            log "   ✅ Features: Firebase + push notifications + basic app functionality"
        else
            log "   🔕 Push Notifications: DISABLED (PUSH_NOTIFY=false)"
            log "   🔥 Firebase Setup: SKIPPED (push notifications disabled)"
            log "   ✅ Keystore Setup: SKIPPED (debug signing enabled)"
            log "   ✅ Build Type: DEBUG SIGNED APK without Firebase"
            log "   ✅ Features: Basic app functionality only"
        fi
        log "   ℹ️  Note: This APK cannot be uploaded to Google Play Store"
        ;;
    "android-publish")
        log "📱 ===== ANDROID-PUBLISH WORKFLOW CONFIGURATION ====="
        if [ "${PUSH_NOTIFY:-}" = "true" ]; then
            log "   🔥 Push Notifications: ENABLED (PUSH_NOTIFY=true)"
            log "   🔥 Firebase Setup: ENABLED (if FIREBASE_CONFIG_ANDROID provided)"
            log "   🔐 Keystore Setup: ENABLED (release signing required)"
            log "   🔐 Build Type: RELEASE SIGNED APK + AAB with Firebase"
            log "   ✅ Features: Firebase + push notifications + release signing"
        else
            log "   🔕 Push Notifications: DISABLED (PUSH_NOTIFY=false)"
            log "   🔥 Firebase Setup: SKIPPED (push notifications disabled)"
            log "   🔐 Keystore Setup: ENABLED (release signing required)"
            log "   🔐 Build Type: RELEASE SIGNED APK + AAB without Firebase"
            log "   ✅ Features: Release signing + basic app functionality"
        fi
        log "   ✅ Note: This build can be uploaded to Google Play Store"
        ;;
    "combined")
        log "📱 ===== COMBINED WORKFLOW CONFIGURATION ====="
        log "   🔥 Push Notifications: ${PUSH_NOTIFY:-false}"
        log "   🔥 Firebase Setup: ENABLED (Android + iOS if PUSH_NOTIFY=true)"
        log "   🔐 Android Keystore: ENABLED (release signing)"
        log "   🍎 iOS Signing: ENABLED (release signing)"
        log "   🔐 Build Type: RELEASE SIGNED APK + AAB"
        log "   ✅ Features: Full production build for both platforms"
        log "   ✅ Note: All builds can be uploaded to app stores"
        ;;
    *)
        log "⚠️  Unknown workflow ID: ${WORKFLOW_ID:-Unknown}"
        log "   Using default configuration"
        ;;
esac

log "🎯 ===== END WORKFLOW CONFIGURATION SUMMARY ====="

# ============================================================================

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    log "🚀 Building AAB for production..."
    flutter build appbundle --release
    
    log "🚀 Building APK for testing..."
    flutter build apk --release
else
    log "🚀 Building APK for testing..."
    flutter build apk --release
fi

log "✅ Flutter build completed successfully"

# ============================================================================
# 🔍 POST-BUILD VERIFICATION
# ============================================================================

log "🔍 ===== POST-BUILD VERIFICATION ====="

# Verify build outputs
log "📦 ===== BUILD OUTPUTS VERIFICATION ====="

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Check for AAB
    AAB_PATHS=(
        "build/app/outputs/bundle/release/app-release.aab"
        "android/app/build/outputs/bundle/release/app-release.aab"
    )
    
    AAB_FOUND=false
    for aab_path in "${AAB_PATHS[@]}"; do
        if [ -f "$aab_path" ]; then
            AAB_SIZE=$(stat -f%z "$aab_path" 2>/dev/null || stat -c%s "$aab_path" 2>/dev/null || echo "0")
            log "✅ AAB found: $aab_path (${AAB_SIZE} bytes)"
            AAB_FOUND=true
            break
        fi
    done
    
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB not found in expected locations"
        log "🔍 Searching for any AAB files:"
        find build -name "*.aab" 2>/dev/null | while read -r file; do
            log "   Found AAB: $file"
        done
    fi
fi

# Check for APK
APK_PATHS=(
    "build/app/outputs/flutter-apk/app-release.apk"
    "build/app/outputs/apk/release/app-release.apk"
    "android/app/build/outputs/apk/release/app-release.apk"
)

APK_FOUND=false
for apk_path in "${APK_PATHS[@]}"; do
    if [ -f "$apk_path" ]; then
        APK_SIZE=$(stat -f%z "$apk_path" 2>/dev/null || stat -c%s "$apk_path" 2>/dev/null || echo "0")
        log "✅ APK found: $apk_path (${APK_SIZE} bytes)"
        APK_FOUND=true
        break
    fi
done

if [ "$APK_FOUND" = false ]; then
    log "❌ APK not found in expected locations"
    log "🔍 Searching for any APK files:"
    find build -name "*.apk" 2>/dev/null | while read -r file; do
        log "   Found APK: $file"
    done
fi

# Verify APK package name if found
if [ "$APK_FOUND" = true ] && command -v aapt >/dev/null 2>&1; then
    log "📦 ===== APK PACKAGE VERIFICATION ====="
    for apk_path in "${APK_PATHS[@]}"; do
        if [ -f "$apk_path" ]; then
            APK_PACKAGE=$(aapt dump badging "$apk_path" 2>/dev/null | grep "package:" | sed "s/.*name='\([^']*\)'.*/\1/" || echo "UNKNOWN")
            APK_VERSION_NAME=$(aapt dump badging "$apk_path" 2>/dev/null | grep "versionName" | sed "s/.*versionName='\([^']*\)'.*/\1/" || echo "UNKNOWN")
            APK_VERSION_CODE=$(aapt dump badging "$apk_path" 2>/dev/null | grep "versionCode" | sed "s/.*versionCode='\([^']*\)'.*/\1/" || echo "UNKNOWN")
            
            log "📦 APK Package Name: $APK_PACKAGE"
            log "📊 APK Version Name: $APK_VERSION_NAME"
            log "📊 APK Version Code: $APK_VERSION_CODE"
            
            # Compare with expected values
            if [ "$APK_PACKAGE" = "${PKG_NAME:-}" ]; then
                log "✅ Package name matches expected: $APK_PACKAGE"
            else
                log "❌ Package name mismatch! Expected: ${PKG_NAME:-}, Got: $APK_PACKAGE"
            fi
            
            if [ "$APK_VERSION_NAME" = "${VERSION_NAME:-}" ]; then
                log "✅ Version name matches expected: $APK_VERSION_NAME"
            else
                log "❌ Version name mismatch! Expected: ${VERSION_NAME:-}, Got: $APK_VERSION_NAME"
            fi
            
            if [ "$APK_VERSION_CODE" = "${VERSION_CODE:-}" ]; then
                log "✅ Version code matches expected: $APK_VERSION_CODE"
            else
                log "❌ Version code mismatch! Expected: ${VERSION_CODE:-}, Got: $APK_VERSION_CODE"
            fi
            break
        fi
    done
fi

log "🔍 ===== END POST-BUILD VERIFICATION ====="

# ============================================================================

# Stop Gradle daemon after build
log "🛑 Stopping Gradle daemon..."
if [ -d "android" ]; then
cd android
if [ -f gradlew ]; then
    ./gradlew --stop || true
fi
cd ..
else
    log "⚠️ android directory not found, skipping Gradle daemon stop"
fi

# Copy artifacts to output directory
log "📁 Copying artifacts to output directory..."

# Debug: List all APK and AAB files in build directory
log "🔍 Searching for built artifacts..."
find build -name "*.apk" -o -name "*.aab" 2>/dev/null | while read -r file; do
    log "   Found: $file ($(du -h "$file" | cut -f1))"
done
# Smart artifact detection and copying
APK_FOUND=false
AAB_FOUND=false

# Look for APK files in various possible locations
for apk_path in \
    "build/app/outputs/flutter-apk/app-release.apk" \
    "build/app/outputs/apk/release/app-release.apk" \
    "android/app/build/outputs/apk/release/app-release.apk"; do
    
    if [ -f "$apk_path" ]; then
        cp "$apk_path" output/android/app-release.apk
        APK_SIZE=$(du -h output/android/app-release.apk | cut -f1)
        log "✅ APK copied from $apk_path (Size: $APK_SIZE)"
        APK_FOUND=true
        break
    fi
done

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Look for AAB files in various possible locations
    for aab_path in \
        "build/app/outputs/bundle/release/app-release.aab" \
        "android/app/build/outputs/bundle/release/app-release.aab"; do
        
        if [ -f "$aab_path" ]; then
            cp "$aab_path" output/android/app-release.aab
            AAB_SIZE=$(du -h output/android/app-release.aab | cut -f1)
            log "✅ AAB copied from $aab_path (Size: $AAB_SIZE)"
            AAB_FOUND=true
            break
        fi
    done
fi

# Verify required artifacts were found based on workflow
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # For production workflows, AAB is required, APK is optional
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB file not found for production workflow"
        exit 1
    fi
    if [ "$APK_FOUND" = false ]; then
        log "ℹ️ APK not built for production workflow (AAB only)"
    fi
else
    # For testing workflows, APK is required
if [ "$APK_FOUND" = false ]; then
    log "❌ APK file not found in any expected location"
    exit 1
    fi
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = false ]; then
        log "❌ AAB file not found in any expected location"
        exit 1
    fi
fi

# Final verification
log "🔍 Final artifact verification..."
if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    # Verify AAB for production workflows
    if [ "$AAB_FOUND" = true ] && [ -f "output/android/app-release.aab" ]; then
        log "✅ AAB verified in output directory"
    else
        log "❌ AAB verification failed"
        exit 1
    fi
    # APK is optional for production workflows
    if [ "$APK_FOUND" = true ] && [ -f "output/android/app-release.apk" ]; then
        log "✅ APK also available in output directory"
    fi
else
    # Verify APK for testing workflows
if [ "$APK_FOUND" = true ] && [ -f "output/android/app-release.apk" ]; then
    log "✅ APK verified in output directory"
else
    log "❌ APK verification failed"
    exit 1
    fi
fi

if [[ "${WORKFLOW_ID:-}" == "android-publish" ]] || [[ "${WORKFLOW_ID:-}" == "combined" ]]; then
    if [ "$AAB_FOUND" = true ] && [ -f "output/android/app-release.aab" ]; then
        log "✅ AAB verified in output directory"
    else
        log "❌ AAB verification failed"
        exit 1
    fi
fi

# Verify signing (if applicable)
log "✅ Build successful, verifying signing..."
if [ -f "lib/scripts/android/verify_signing.sh" ]; then
    chmod +x lib/scripts/android/verify_signing.sh
    if lib/scripts/android/verify_signing.sh "output/android/app-release.apk"; then
        log "✅ Signing verification successful"
    else
        log "⚠️ Signing verification failed, but continuing..."
    fi
else
    log "⚠️ Signing verification script not found"
fi

# Verify package name in built APK
log "📦 Verifying package name in built APK..."
if [ -f "lib/scripts/android/verify_package_name.sh" ]; then
    chmod +x lib/scripts/android/verify_package_name.sh
    if lib/scripts/android/verify_package_name.sh; then
        log "✅ Package name verification successful"
    else
        log "❌ Package name verification failed"
        # Don't exit here, just log the failure for investigation
        log "⚠️ Continuing with build process despite package name verification failure"
    fi
else
    log "⚠️ Package name verification script not found"
fi

# Process artifact URLs
log "📦 Processing artifact URLs for email notification..."
source "lib/scripts/utils/process_artifacts.sh"
artifact_urls=$(process_artifacts)
log "Artifact URLs: $artifact_urls"

# Send build success email
log "🎉 Build successful! Sending success email..."
if [ -f "lib/scripts/utils/send_email.sh" ]; then
    chmod +x lib/scripts/utils/send_email.sh
    lib/scripts/utils/send_email.sh "build_success" "Android" "${CM_BUILD_ID:-unknown}" "Build successful" "$artifact_urls"
fi

log "✅ Android build process completed successfully!"
exit 0 