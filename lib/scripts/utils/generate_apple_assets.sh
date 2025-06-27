#!/bin/bash

# Apple Assets Generator Wrapper Script
# This script provides a convenient interface to the apple_assets.py Python script
# for use in Codemagic CI/CD workflows.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if required variables are set
check_required_vars() {
    local missing_vars=()
    
    if [[ -z "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_KEY_IDENTIFIER")
    fi
    
    if [[ -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_API_KEY_PATH")
    fi
    
    if [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_ISSUER_ID")
    fi
    
    if [[ -z "${BUNDLE_ID:-}" ]]; then
        missing_vars+=("BUNDLE_ID")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            error "  - $var"
        done
        return 1
    fi
    
    return 0
}

# Function to install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    # Check if pip3 is available
    if ! command -v pip3 &> /dev/null; then
        error "pip3 is not available. Please install Python 3 and pip."
        return 1
    fi
    
    # Install required packages
    pip3 install requests pyjwt cryptography || {
        error "Failed to install Python dependencies"
        return 1
    }
    
    success "Python dependencies installed successfully"
}

# Function to validate P8 file
validate_p8_file() {
    local p8_file="$1"
    
    if [[ ! -f "$p8_file" ]]; then
        error "P8 file not found: $p8_file"
        return 1
    fi
    
    # Check if it's a valid P8 file
    if ! grep -q "-----BEGIN PRIVATE KEY-----" "$p8_file"; then
        error "Invalid P8 file format. File should start with '-----BEGIN PRIVATE KEY-----'"
        return 1
    fi
    
    if ! grep -q "-----END PRIVATE KEY-----" "$p8_file"; then
        error "Invalid P8 file format. File should end with '-----END PRIVATE KEY-----'"
        return 1
    fi
    
    success "P8 file validation passed"
}

# Function to download P8 file if it's a URL
maybe_download_p8_file() {
    local p8_path="$1"
    local output_dir="$2"
    local local_p8_path="$output_dir/AuthKey.p8"

    if [[ "$p8_path" =~ ^https?:// ]]; then
        log "Detected URL for APP_STORE_CONNECT_API_KEY_PATH. Downloading..."
        mkdir -p "$output_dir"
        if command -v curl &> /dev/null; then
            curl -fsSL "$p8_path" -o "$local_p8_path"
        elif command -v wget &> /dev/null; then
            wget -q "$p8_path" -O "$local_p8_path"
        else
            error "Neither curl nor wget is available to download the P8 file."
            return 1
        fi
        if [[ ! -s "$local_p8_path" ]]; then
            error "Failed to download P8 file from $p8_path"
            return 1
        fi
        log "Downloaded P8 file to $local_p8_path"
        echo "$local_p8_path"
    else
        echo "$p8_path"
    fi
}

# Function to run apple_assets.py
run_apple_assets() {
    local output_dir="${1:-output/apple_assets}"
    local p8_path="${2:-${APP_STORE_CONNECT_API_KEY_PATH}}"
    local profile_type="${PROFILE_TYPE:-IOS_APP_STORE}"
    local team_id="${APPLE_TEAM_ID:-}"
    
    log "Running Apple Assets Generator..."
    log "  Key ID: ${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    log "  P8 File: ${p8_path}"
    log "  Issuer ID: ${APP_STORE_CONNECT_ISSUER_ID}"
    log "  Bundle ID: ${BUNDLE_ID}"
    log "  Profile Type: ${profile_type}"
    log "  Team ID: ${team_id:-not_set}"
    log "  Output Directory: ${output_dir}"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Build command arguments
    local cmd_args=(
        "python3"
        "lib/scripts/utils/apple_assets.py"
        "--key-id" "${APP_STORE_CONNECT_KEY_IDENTIFIER}"
        "--p8-file" "$p8_path"
        "--issuer-id" "${APP_STORE_CONNECT_ISSUER_ID}"
        "--bundle-id" "${BUNDLE_ID}"
        "--profile-type" "${profile_type}"
        "--output-dir" "${output_dir}"
    )
    
    # Add team_id if provided
    if [[ -n "$team_id" ]]; then
        cmd_args+=("--team-id" "$team_id")
    fi
    
    # Run the command
    if "${cmd_args[@]}"; then
        success "Apple assets generated successfully!"
        return 0
    else
        error "Apple assets generation failed"
        return 1
    fi
}

# Function to set environment variables for build process
set_build_env_vars() {
    local output_dir="${1:-output/apple_assets}"
    
    log "Setting environment variables for build process..."
    
    # Set certificate file paths
    export CERT_P12_URL="${output_dir}/certificate.p12"
    export CERT_CER_URL="${output_dir}/certificate.cer"
    export CERT_KEY_URL="${output_dir}/privatekey.key"
    export PROFILE_URL="${output_dir}/profile.mobileprovision"
    export CERT_PASSWORD="match"
    
    # Verify files exist
    local missing_files=()
    
    if [[ ! -f "$CERT_P12_URL" ]]; then
        missing_files+=("certificate.p12")
    fi
    
    if [[ ! -f "$CERT_CER_URL" ]]; then
        missing_files+=("certificate.cer")
    fi
    
    if [[ ! -f "$CERT_KEY_URL" ]]; then
        missing_files+=("privatekey.key")
    fi
    
    if [[ ! -f "$PROFILE_URL" ]]; then
        missing_files+=("profile.mobileprovision")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        warning "Some certificate files are missing:"
        for file in "${missing_files[@]}"; do
            warning "  - $file"
        done
    else
        success "All certificate files generated successfully"
        log "Certificate files:"
        log "  - P12: ${CERT_P12_URL}"
        log "  - CER: ${CERT_CER_URL}"
        log "  - KEY: ${CERT_KEY_URL}"
        log "  - Profile: ${PROFILE_URL}"
    fi
}

# Main function
main() {
    log "🍎 Apple Assets Generator Wrapper"
    log "=================================="
    
    # Check if we're in the right directory
    if [[ ! -f "lib/scripts/utils/apple_assets.py" ]]; then
        error "apple_assets.py not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check required variables
    if ! check_required_vars; then
        log "Skipping Apple assets generation due to missing variables"
        exit 0
    fi
    
    local output_dir="output/apple_assets"
    
    # Download P8 file if needed
    local effective_p8_path
    effective_p8_path=$(maybe_download_p8_file "${APP_STORE_CONNECT_API_KEY_PATH}" "$output_dir")
    if [[ -z "$effective_p8_path" ]]; then
        error "Failed to obtain P8 file."
        exit 1
    fi
    
    # Validate P8 file
    if ! validate_p8_file "$effective_p8_path"; then
        exit 1
    fi
    
    # Install dependencies
    if ! install_dependencies; then
        exit 1
    fi
    
    # Run apple assets generation
    if run_apple_assets "$output_dir" "$effective_p8_path"; then
        set_build_env_vars "$output_dir"
        success "Apple assets generation completed successfully!"
    else
        error "Apple assets generation failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 