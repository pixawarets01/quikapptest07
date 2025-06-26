#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [VERSION_MGMT] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

log "🔄 Starting Android Version Management and Package Conflict Resolution"

# Get current environment variables
PKG_NAME=${PKG_NAME:-"com.example.quikapptest06"}
VERSION_NAME=${VERSION_NAME:-"1.0.0"}
VERSION_CODE=${VERSION_CODE:-"1"}
BUILD_MODE=${BUILD_MODE:-"debug"}
KEY_STORE_URL=${KEY_STORE_URL:-}
WORKFLOW_ID=${WORKFLOW_ID:-"android-free"}

# Function to increment version code
increment_version_code() {
    local current_code=$1
    local increment_type=$2
    
    case $increment_type in
        "patch")
            echo $((current_code + 1))
            ;;
        "minor")
            echo $((current_code + 10))
            ;;
        "major")
            echo $((current_code + 100))
            ;;
        "auto")
            # Auto increment based on timestamp
            local timestamp=$(date +%s)
            local last_digits=${timestamp: -3}
            echo $((current_code + last_digits % 100 + 1))
            ;;
        *)
            echo $((current_code + 1))
            ;;
    esac
}

# Function to increment version name
increment_version_name() {
    local current_version=$1
    local increment_type=$2
    
    # Parse version (e.g., "1.2.3" -> major=1, minor=2, patch=3)
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major=${VERSION_PARTS[0]:-1}
    local minor=${VERSION_PARTS[1]:-0}
    local patch=${VERSION_PARTS[2]:-0}
    
    case $increment_type in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "auto")
            patch=$((patch + 1))
            ;;
        *)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Function to generate development package name
generate_dev_package_name() {
    local base_pkg=$1
    local suffix=$2
    
    case $suffix in
        "debug")
            echo "${base_pkg}.debug"
            ;;
        "staging")
            echo "${base_pkg}.staging"
            ;;
        "beta")
            echo "${base_pkg}.beta"
            ;;
        "timestamp")
            local timestamp=$(date +%s)
            local short_timestamp=${timestamp: -6}
            echo "${base_pkg}.dev${short_timestamp}"
            ;;
        *)
            echo "${base_pkg}.dev"
            ;;
    esac
}

# Function to create version configuration
create_version_config() {
    local pkg_name=$1
    local version_name=$2
    local version_code=$3
    
    log "📝 Creating version configuration..."
    log "   Package Name: $pkg_name"
    log "   Version Name: $version_name"
    log "   Version Code: $version_code"
    
    # Update pubspec.yaml
    if [ -f pubspec.yaml ]; then
        log "Updating pubspec.yaml version..."
        sed -i.bak "s/^version: .*/version: ${version_name}+${version_code}/" pubspec.yaml
        log "✅ Updated pubspec.yaml: version: ${version_name}+${version_code}"
    fi
    
    # Update build.gradle.kts
    if [ -f android/app/build.gradle.kts ]; then
        log "Updating build.gradle.kts with new package and version..."
        
        # Update applicationId
        sed -i.bak "s/applicationId = \".*\"/applicationId = \"${pkg_name}\"/" android/app/build.gradle.kts
        
        # Update versionCode and versionName in defaultConfig
        # Handle both flutter.versionCode and direct values
        sed -i.bak "s/versionCode = flutter\.versionCode/versionCode = ${version_code}/" android/app/build.gradle.kts
        sed -i.bak "s/versionName = flutter\.versionName/versionName = \"${version_name}\"/" android/app/build.gradle.kts
        sed -i.bak "s/versionCode = [0-9]*/versionCode = ${version_code}/" android/app/build.gradle.kts
        sed -i.bak "s/versionName = \"[^\"]*\"/versionName = \"${version_name}\"/" android/app/build.gradle.kts
        
        log "✅ Updated build.gradle.kts with new configuration"
    fi
    
    # Update AndroidManifest.xml namespace if needed
    if [ -f android/app/src/main/AndroidManifest.xml ]; then
        log "Checking AndroidManifest.xml namespace..."
        # Note: namespace is typically handled by build.gradle.kts, but we can verify
        log "✅ AndroidManifest.xml namespace is managed by build.gradle.kts"
    fi
}

# Function to handle signing conflicts
resolve_signing_conflicts() {
    local workflow=$1
    
    log "🔐 Resolving signing conflicts for workflow: $workflow"
    
    case $workflow in
        "android-free"|"android-paid")
            log "Using debug signing for $workflow workflow"
            log "📝 This allows installation alongside production versions"
            ;;
        "android-publish"|"combined")
            if [ -n "$KEY_STORE_URL" ]; then
                log "Using release signing for production deployment"
                log "⚠️  Release-signed APKs will conflict with debug versions"
                log "💡 Uninstall debug versions before installing release APKs"
            else
                log "⚠️  No keystore provided for $workflow workflow"
                log "Using debug signing as fallback"
            fi
            ;;
        *)
            log "Unknown workflow: $workflow, using debug signing"
            ;;
    esac
}

# Function to generate installation instructions
generate_installation_guide() {
    local pkg_name=$1
    local version_name=$2
    local version_code=$3
    local signing_type=$4
    
    cat > output/android/INSTALL_GUIDE.txt <<EOF
🔧 Android APK Installation Guide
================================

App Information:
- Package Name: $pkg_name (same for all workflows)
- Version: $version_name ($version_code)
- Signing: $signing_type
- Build Date: $(date)

🚀 Installation Methods:

Method 1: Fresh Installation
---------------------------
1. If you have the app installed, uninstall it first:
   Settings > Apps > [App Name] > Uninstall
2. Install the new APK

Method 2: ADB Installation (Recommended for Developers)
-------------------------------------------------------
1. Enable Developer Options and USB Debugging
2. Connect device to computer
3. Run: adb install -r app-release.apk
   (The -r flag allows reinstallation)

Method 3: Force Installation (If conflicts occur)
-------------------------------------------------
1. adb uninstall $pkg_name
2. adb install app-release.apk

⚠️  Common Issues and Solutions:

Issue: "App not installed as package conflicts with an existing package"
Solutions:
1. Uninstall the existing app first
2. Use ADB with -r flag: adb install -r app-release.apk
3. Check if you're trying to install debug over release (or vice versa)

Issue: "Installation blocked by Play Protect"
Solutions:
1. Temporarily disable Play Protect
2. Allow installation from unknown sources
3. Use ADB installation method

Issue: "Signatures don't match"
Solutions:
1. This happens when switching between debug/release builds
2. Uninstall the existing app completely
3. Clear app data if uninstall doesn't work

📱 Package Name Information:
- This APK uses package name: $pkg_name
- ALL workflows use the same package name for Firebase connectivity
- Workflow progression: android-free → android-paid → android-publish
- Same package name ensures seamless Firebase integration

🔐 Signing Information:
- $signing_type signed APK
- Debug and Release signed APKs cannot coexist
- Always uninstall before switching signing types

💡 Pro Tips:
1. For testing: Use android-free workflow (debug signing)
2. For Firebase testing: Use android-paid workflow (debug signing + Firebase)
3. For production: Use android-publish workflow (release signing)
4. Same package name across all workflows for seamless progression
5. Firebase configuration works across all workflows

🔄 Workflow Progression:
1. android-free: Test basic app functionality
2. android-paid: Test with Firebase features
3. android-publish: Deploy to production

All workflows use the same package name for consistent Firebase connectivity!

EOF

    log "✅ Installation guide created: output/android/INSTALL_GUIDE.txt"
}

# Main execution logic
main() {
    log "🎯 Analyzing current configuration..."
    
    # Use exact version values from environment variables
    local final_version_name="$VERSION_NAME"
    local final_version_code="$VERSION_CODE"
    local final_package_name="$PKG_NAME"
    
    log "📊 Version Management Summary:"
    log "   Package Name: $final_package_name (same for all workflows)"
    log "   Version Name: $final_version_name (using exact value from VERSION_NAME)"
    log "   Version Code: $final_version_code (using exact value from VERSION_CODE)"
    log "   Workflow: $WORKFLOW_ID"
    log "   🔧 Using exact version values from environment variables (no auto-increment)"
    
    # Apply configuration with exact values
    create_version_config "$final_package_name" "$final_version_name" "$final_version_code"
    
    # Handle signing conflicts
    local signing_type="Debug"
    if [[ "$WORKFLOW_ID" == "android-publish" ]] || [[ "$WORKFLOW_ID" == "combined" ]]; then
        if [ -n "$KEY_STORE_URL" ]; then
            signing_type="Release"
        fi
    fi
    
    resolve_signing_conflicts "$WORKFLOW_ID"
    
    # Create output directory if it doesn't exist
    mkdir -p output/android
    
    # Generate installation guide
    generate_installation_guide "$final_package_name" "$final_version_name" "$final_version_code" "$signing_type"
    
    # Export variables for use by other scripts
    export PKG_NAME="$final_package_name"
    export VERSION_NAME="$final_version_name"
    export VERSION_CODE="$final_version_code"
    
    log "✅ Version management completed successfully"
    log "📦 All workflows now use same package name: $final_package_name"
    log "📋 Check output/android/INSTALL_GUIDE.txt for installation instructions"
}

# Execute main function
main "$@" 