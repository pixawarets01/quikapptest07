#!/bin/bash

# Environment Setup Script for iOS Build
# Purpose: Environment validation, cleanup, and optimization

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting iOS Environment Setup..."

# Function to display environment information
show_environment_info() {
    log_info "Build Environment Information:"
    log_info "  - Flutter: $(flutter --version | head -1 2>/dev/null || echo 'Not available')"
    log_info "  - Xcode: $(xcodebuild -version | head -1 2>/dev/null || echo 'Not available')"
    log_info "  - CocoaPods: $(pod --version 2>/dev/null || echo 'Not available')"
    log_info "  - Ruby: $(ruby --version 2>/dev/null || echo 'Not available')"
    log_info "  - Memory: $(get_system_memory)"
    log_info "  - Profile Type: ${PROFILE_TYPE:-not_set}"
    log_info "  - Workflow ID: ${WORKFLOW_ID:-not_set}"
    log_info "  - Bundle ID: ${BUNDLE_ID:-not_set}"
    log_info "  - App Name: ${APP_NAME:-not_set}"
}

# Function to validate required tools
validate_tools() {
    log_info "Validating required tools..."
    
    local missing_tools=()
    
    if ! command_exists flutter; then
        missing_tools+=("flutter")
    fi
    
    if ! command_exists xcodebuild; then
        missing_tools+=("xcodebuild")
    fi
    
    if ! command_exists pod; then
        missing_tools+=("pod (CocoaPods)")
    fi
    
    if ! command_exists curl; then
        missing_tools+=("curl")
    fi
    
    if ! command_exists openssl; then
        missing_tools+=("openssl")
    fi
    
    if ! command_exists security; then
        missing_tools+=("security")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            log_error "   - ${tool}"
        done
        return 1
    fi
    
    log_success "All required tools are available"
    return 0
}

# Function to clean previous build artifacts
cleanup_build_artifacts() {
    log_info "Cleaning previous build artifacts..."
    
    # Flutter cleanup
    if [ -d ".dart_tool" ]; then
        rm -rf .dart_tool
        log_info "Removed .dart_tool directory"
    fi
    
    # iOS specific cleanup
    if [ -d "ios/Pods" ]; then
        rm -rf ios/Pods
        log_info "Removed ios/Pods directory"
    fi
    
    if [ -f "ios/Podfile.lock" ]; then
        rm -f ios/Podfile.lock
        log_info "Removed ios/Podfile.lock"
    fi
    
    if [ -d "ios/build" ]; then
        rm -rf ios/build
        log_info "Removed ios/build directory"
    fi
    
    # Build output cleanup
    if [ -d "build" ]; then
        rm -rf build
        log_info "Removed build directory"
    fi
    
    # Output directory cleanup
    if [ -d "${OUTPUT_DIR:-output/ios}" ]; then
        rm -rf "${OUTPUT_DIR:-output/ios}"
        log_info "Removed output directory"
    fi
    
    # Gradle cache cleanup (if exists)
    if [ -d "$HOME/.gradle/caches" ]; then
        rm -rf "$HOME/.gradle/caches" 2>/dev/null || true
        log_info "Cleaned Gradle caches"
    fi
    
    # Flutter clean
    flutter clean >/dev/null 2>&1 || true
    log_success "Build artifacts cleanup completed"
}

# Function to validate Firebase configuration
validate_firebase_config() {
    log_info "Validating Firebase configuration..."
    
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "Push notifications ENABLED - Firebase validation required"
        
        if [ -z "${FIREBASE_CONFIG_IOS:-}" ]; then
            log_error "FIREBASE_CONFIG_IOS is required when PUSH_NOTIFY=true"
            return 1
        fi
        
        if [[ "${FIREBASE_CONFIG_IOS}" != http* ]]; then
            log_error "FIREBASE_CONFIG_IOS must be a valid HTTP/HTTPS URL"
            return 1
        fi
        
        log_success "Firebase configuration is valid"
    else
        log_info "Push notifications DISABLED - Skipping Firebase validation"
        if [ -n "${FIREBASE_CONFIG_IOS:-}" ]; then
            log_warn "Firebase configuration provided but PUSH_NOTIFY is false"
            log_warn "Firebase will be disabled during build"
        fi
    fi
    
    return 0
}

# Function to validate iOS signing configuration
validate_ios_signing() {
    log_info "Validating iOS signing configuration..."
    
    if [[ "${WORKFLOW_ID:-}" == "auto-ios-workflow" ]]; then
        log_info "Auto-ios-workflow detected - skipping manual signing validation"
        return 0
    fi
    
    # Check certificate configuration
    local has_p12=false
    local has_cer_key=false
    
    if [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" == http* ]]; then
        has_p12=true
        log_success "P12 certificate URL provided"
    fi
    
    if [[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]] && [[ "${CERT_CER_URL}" == http* ]] && [[ "${CERT_KEY_URL}" == http* ]]; then
        has_cer_key=true
        log_success "CER and KEY certificate URLs provided"
    fi
    
    if [[ "$has_p12" == "false" ]] && [[ "$has_cer_key" == "false" ]]; then
        log_error "Certificate configuration error:"
        log_error "  Option 1: Provide CERT_P12_URL (with HTTPS URL)"
        log_error "  Option 2: Provide both CERT_CER_URL and CERT_KEY_URL (with HTTPS URLs)"
        return 1
    fi
    
    # Check provisioning profile
    if [ -z "${PROFILE_URL:-}" ] || [[ "${PROFILE_URL}" != http* ]]; then
        log_error "PROFILE_URL is required and must be a valid HTTP/HTTPS URL"
        return 1
    fi
    
    log_success "iOS signing configuration is valid"
    return 0
}

# Function to create required directories
setup_directories() {
    log_info "Setting up required directories..."
    
    ensure_directory "${OUTPUT_DIR:-output/ios}"
    ensure_directory "ios/certificates"
    ensure_directory "build/ios/logs"
    
    log_success "Directory setup completed"
}

# Function to set build environment variables
set_build_environment() {
    log_info "Setting build environment variables..."
    
    # Set default values
    export OUTPUT_DIR="${OUTPUT_DIR:-output/ios}"
    export PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
    export CM_BUILD_DIR="${CM_BUILD_DIR:-$(pwd)}"
    export FORCE_CLEAN_EXPORT_OPTIONS="${FORCE_CLEAN_EXPORT_OPTIONS:-true}"
    export PROFILE_TYPE="${PROFILE_TYPE:-app-store}"
    
    # Xcode optimization settings
    export XCODE_FAST_BUILD="${XCODE_FAST_BUILD:-true}"
    export COCOAPODS_FAST_INSTALL="${COCOAPODS_FAST_INSTALL:-true}"
    export XCODE_OPTIMIZATION="${XCODE_OPTIMIZATION:-true}"
    export XCODE_PARALLEL_BUILD="${XCODE_PARALLEL_BUILD:-true}"
    
    log_info "Build Environment Variables:"
    log_info "   OUTPUT_DIR: ${OUTPUT_DIR}"
    log_info "   PROJECT_ROOT: ${PROJECT_ROOT}"
    log_info "   CM_BUILD_DIR: ${CM_BUILD_DIR}"
    log_info "   PROFILE_TYPE: ${PROFILE_TYPE}"
    log_info "   XCODE_FAST_BUILD: ${XCODE_FAST_BUILD}"
    
    log_success "Build environment configured"
}

# Function to check required build scripts
check_build_scripts() {
    log_info "Checking for required build scripts..."
    
    local script_dir="$(dirname "$0")"
    local required_scripts=(
        "handle_certificates.sh"
        "branding_assets.sh"
        "firebase_setup.sh"
        "build_flutter_app.sh"
        "export_ipa.sh"
        "email_notifications.sh"
    )
    
    local missing_scripts=()
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "${script_dir}/${script}" ]; then
            missing_scripts+=("${script}")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing required build scripts:"
        for script in "${missing_scripts[@]}"; do
            log_error "   - ${script}"
        done
        return 1
    fi
    
    log_success "All required build scripts are present"
    return 0
}

# Main execution
main() {
    log_info "iOS Environment Setup Starting..."
    
    # Show environment information
    show_environment_info
    
    # Validate required environment variables
    if ! validate_required_vars; then
        log_error "Environment variable validation failed"
        return 1
    fi
    
    # Validate profile type
    if ! validate_profile_type; then
        log_error "Profile type validation failed"
        return 1
    fi
    
    # Validate required tools
    if ! validate_tools; then
        log_error "Tool validation failed"
        return 1
    fi
    
    # Clean previous build artifacts
    cleanup_build_artifacts
    
    # Validate Firebase configuration
    if ! validate_firebase_config; then
        log_error "Firebase configuration validation failed"
        return 1
    fi
    
    # Validate iOS signing configuration
    if ! validate_ios_signing; then
        log_error "iOS signing configuration validation failed"
        return 1
    fi
    
    # Set up required directories
    setup_directories
    
    # Set build environment variables
    set_build_environment
    
    # Check for required build scripts
    if ! check_build_scripts; then
        log_error "Build script validation failed"
        return 1
    fi
    
    log_success "iOS Environment Setup completed successfully!"
    return 0
}

# Run main function
main "$@" 