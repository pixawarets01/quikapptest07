#!/bin/bash

# Flutter iOS Build Script
# Purpose: Build the Flutter iOS application and create archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Flutter iOS Build..."

# Function to generate Podfile
generate_podfile() {
    log_info "Generating Podfile for iOS..."
    
    if [ ! -f "ios/Podfile" ]; then
        log_info "Creating basic Podfile..."
        cat > ios/Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Flutter-Generated.xcconfig, then run \"flutter pub get\""
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
EOF
        log_success "Basic Podfile created"
    else
        log_info "Podfile already exists"
    fi
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing Flutter dependencies..."
    
    # Flutter pub get
    flutter pub get
    log_success "Flutter dependencies installed"
    
    # Generate iOS platform files
    log_info "Generating iOS platform files..."
    flutter create --platforms ios .
    
    # Install CocoaPods dependencies
    log_info "Installing CocoaPods dependencies..."
    cd ios
    
    # Clean Pods if exists
    if [ -d "Pods" ]; then
        rm -rf Pods
        log_info "Cleaned existing Pods"
    fi
    
    if [ -f "Podfile.lock" ]; then
        rm -f Podfile.lock
        log_info "Removed existing Podfile.lock"
    fi
    
    # Install pods with optimizations
    if [ "${COCOAPODS_FAST_INSTALL:-true}" = "true" ]; then
        pod install --repo-update --verbose
    else
        pod install --verbose
    fi
    
    cd ..
    log_success "CocoaPods dependencies installed"
}

# Function to build Flutter app
build_flutter_app() {
    log_info "Building Flutter iOS app..."
    
    # Determine build configuration based on profile type
    local build_mode="release"
    local build_config="Release"
    
    case "${PROFILE_TYPE:-app-store}" in
        "development")
            build_mode="debug"
            build_config="Debug"
            ;;
        "ad-hoc"|"enterprise"|"app-store")
            build_mode="release"
            build_config="Release"
            ;;
    esac
    
    log_info "Building in $build_mode mode for $PROFILE_TYPE distribution"
    
    # Build Flutter iOS app
    flutter build ios \
        --$build_mode \
        --no-codesign \
        --dart-define=APP_NAME="${APP_NAME:-}" \
        --dart-define=BUNDLE_ID="${BUNDLE_ID:-}" \
        --dart-define=VERSION_NAME="${VERSION_NAME:-}" \
        --dart-define=VERSION_CODE="${VERSION_CODE:-}" \
        --dart-define=LOGO_URL="${LOGO_URL:-}" \
        --dart-define=SPLASH_URL="${SPLASH_URL:-}" \
        --dart-define=SPLASH_BG_URL="${SPLASH_BG_URL:-}" \
        --dart-define=BOTTOMMENU_ITEMS="${BOTTOMMENU_ITEMS:-}" \
        --dart-define=PUSH_NOTIFY="${PUSH_NOTIFY:-false}" \
        --dart-define=IS_DOMAIN_URL="${IS_DOMAIN_URL:-false}" \
        --dart-define=IS_CHATBOT="${IS_CHATBOT:-false}" \
        --dart-define=IS_SPLASH="${IS_SPLASH:-false}" \
        --dart-define=IS_PULLDOWN="${IS_PULLDOWN:-false}" \
        --dart-define=IS_BOTTOMMENU="${IS_BOTTOMMENU:-false}" \
        --dart-define=IS_LOAD_IND="${IS_LOAD_IND:-false}"
    
    log_success "Flutter iOS app built successfully"
}

# Function to create Xcode archive
create_xcode_archive() {
    log_info "Creating Xcode archive..."
    
    local scheme="Runner"
    local workspace="ios/Runner.xcworkspace"
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local build_config="Release"
    
    # Ensure output directory exists
    ensure_directory "${OUTPUT_DIR:-output/ios}"
    
    # Determine build configuration
    case "${PROFILE_TYPE:-app-store}" in
        "development")
            build_config="Debug"
            ;;
        *)
            build_config="Release"
            ;;
    esac
    
    log_info "Creating archive with configuration: $build_config"
    
    # Create Xcode archive
    xcodebuild archive \
        -workspace "$workspace" \
        -scheme "$scheme" \
        -configuration "$build_config" \
        -archivePath "$archive_path" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID:-}" \
        MARKETING_VERSION="${VERSION_NAME:-1.0.0}" \
        CURRENT_PROJECT_VERSION="${VERSION_CODE:-1}" \
        IPHONEOS_DEPLOYMENT_TARGET="12.0" \
        ENABLE_BITCODE=NO \
        COMPILER_INDEX_STORE_ENABLE=NO
    
    if [ -d "$archive_path" ]; then
        log_success "Xcode archive created successfully: $archive_path"
        
        # Validate archive
        if [ -f "$archive_path/Info.plist" ]; then
            log_success "Archive validation passed"
        else
            log_error "Archive validation failed - Info.plist not found"
            return 1
        fi
    else
        log_error "Failed to create Xcode archive"
        return 1
    fi
}

# Main execution
main() {
    log_info "Flutter iOS Build Starting..."
    
    # Generate Podfile if needed
    generate_podfile
    
    # Install dependencies
    if ! install_dependencies; then
        log_error "Failed to install dependencies"
        return 1
    fi
    
    # Build Flutter app
    if ! build_flutter_app; then
        log_error "Failed to build Flutter app"
        return 1
    fi
    
    # Create Xcode archive
    if ! create_xcode_archive; then
        log_error "Failed to create Xcode archive"
        return 1
    fi
    
    log_success "Flutter iOS Build completed successfully!"
    
    # Summary
    log_info "Build Summary:"
    log_info "  - App: ${APP_NAME:-Unknown}"
    log_info "  - Bundle ID: ${BUNDLE_ID:-Unknown}"
    log_info "  - Version: ${VERSION_NAME:-Unknown} (${VERSION_CODE:-Unknown})"
    log_info "  - Profile Type: ${PROFILE_TYPE:-Unknown}"
    log_info "  - Archive: ${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    
    return 0
}

# Run main function
main "$@"
