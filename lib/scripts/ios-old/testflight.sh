#!/bin/bash

# TestFlight Upload Script for iOS Apps
# Handles automatic uploads to TestFlight using App Store Connect API keys

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="${SCRIPT_DIR}/../utils"

# Import common functions if available
if [ -f "${UTILS_DIR}/safe_run.sh" ]; then
    source "${UTILS_DIR}/safe_run.sh"
fi

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $*" >&2
}

success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*"
}

warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ $*"
}

# Function to validate TestFlight upload requirements
validate_testflight_requirements() {
    log "🔍 Validating TestFlight upload requirements..."
    
    # Check if TestFlight upload is enabled
    if [[ "$(echo "${IS_TESTFLIGHT}" | tr '[:upper:]' '[:lower:]')" != "true" ]]; then
        log "📱 TestFlight upload disabled (IS_TESTFLIGHT=${IS_TESTFLIGHT})"
        return 1
    fi
    
    # Check if profile type is app-store
    if [[ "${PROFILE_TYPE}" != "app-store" ]]; then
        log "📱 TestFlight upload requires app-store profile type (current: ${PROFILE_TYPE})"
        return 1
    fi
    
    # Check required App Store Connect API key variables
    local missing_vars=()
    
    if [[ -z "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_KEY_IDENTIFIER")
    fi
    
    if [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_ISSUER_ID")
    fi
    
    if [[ -z "${APP_STORE_CONNECT_API_KEY:-}" ]]; then
        missing_vars+=("APP_STORE_CONNECT_API_KEY")
    fi
    
    if [[ -z "${BUNDLE_ID:-}" ]]; then
        missing_vars+=("BUNDLE_ID")
    fi
    
    if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
        missing_vars+=("APPLE_TEAM_ID")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required TestFlight upload variables:"
        for var in "${missing_vars[@]}"; do
            error "  - ${var}"
        done
        return 1
    fi
    
    log "✅ All TestFlight upload requirements validated"
    return 0
}

# Function to setup App Store Connect API key
setup_api_key() {
    log "🔑 Setting up App Store Connect API key..."
    
    local API_KEY_FILE="AuthKey_${APP_STORE_CONNECT_KEY_IDENTIFIER}.p8"
    local API_KEY_PATH="${SCRIPT_DIR}/../certificates/${API_KEY_FILE}"
    
    # Create certificates directory if it doesn't exist
    mkdir -p "$(dirname "${API_KEY_PATH}")"
    
    # Check if API key is already a file path
    if [[ -f "${APP_STORE_CONNECT_API_KEY}" ]]; then
        log "📁 API key provided as file path: ${APP_STORE_CONNECT_API_KEY}"
        cp "${APP_STORE_CONNECT_API_KEY}" "${API_KEY_PATH}"
    else
        # Check if it's a base64 encoded string
        if [[ "${APP_STORE_CONNECT_API_KEY}" == *"-----BEGIN PRIVATE KEY-----"* ]]; then
            log "📝 API key provided as PEM format"
            echo "${APP_STORE_CONNECT_API_KEY}" > "${API_KEY_PATH}"
        else
            log "🔓 API key provided as base64 encoded string"
            echo "${APP_STORE_CONNECT_API_KEY}" | base64 --decode > "${API_KEY_PATH}"
        fi
    fi
    
    # Set proper permissions
    chmod 600 "${API_KEY_PATH}"
    
    # Verify the key file
    if [[ ! -f "${API_KEY_PATH}" ]]; then
        error "Failed to create API key file: ${API_KEY_PATH}"
        return 1
    fi
    
    log "✅ API key setup completed: ${API_KEY_PATH}"
    echo "${API_KEY_PATH}"
}

# Function to upload IPA to TestFlight using xcrun altool
upload_to_testflight_altool() {
    local IPA_PATH="$1"
    local API_KEY_PATH="$2"
    
    log "🚀 Uploading IPA to TestFlight using xcrun altool..."
    log "📱 IPA: ${IPA_PATH}"
    log "🔑 API Key: ${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    log "🏢 Team ID: ${APPLE_TEAM_ID}"
    log "📦 Bundle ID: ${BUNDLE_ID}"
    
    # Set environment variables for altool
    export ALTOOL_KEY_ID="${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    export ALTOOL_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
    export ALTOOL_KEY_PATH="${API_KEY_PATH}"
    
    # Upload using xcrun altool
    local upload_output
    upload_output=$(xcrun altool --upload-app \
        --type ios \
        --file "${IPA_PATH}" \
        --apiKey "${APP_STORE_CONNECT_KEY_IDENTIFIER}" \
        --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID}" \
        --verbose 2>&1)
    
    local upload_exit_code=$?
    
    # Log the output
    echo "${upload_output}"
    
    if [[ ${upload_exit_code} -eq 0 ]]; then
        success "✅ IPA uploaded to TestFlight successfully!"
        
        # Extract upload ID if available
        local upload_id
        upload_id=$(echo "${upload_output}" | grep -o "RequestUUID: [a-f0-9-]*" | cut -d' ' -f2)
        if [[ -n "${upload_id}" ]]; then
            log "📋 Upload ID: ${upload_id}"
        fi
        
        return 0
    else
        # Use comprehensive error analysis
        analyze_upload_error "${upload_output}" "${upload_exit_code}"
        return $?
    fi
}

# Function to upload IPA to TestFlight using transporter (newer method)
upload_to_testflight_transporter() {
    local IPA_PATH="$1"
    local API_KEY_PATH="$2"
    
    log "🚀 Uploading IPA to TestFlight using transporter..."
    log "📱 IPA: ${IPA_PATH}"
    log "🔑 API Key: ${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    
    # Check if transporter is available
    if ! command -v transporter >/dev/null 2>&1; then
        log "📦 Transporter not available, falling back to altool"
        return 1
    fi
    
    # Upload using transporter
    local upload_output
    upload_output=$(transporter \
        --apiKey "${APP_STORE_CONNECT_KEY_IDENTIFIER}" \
        --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID}" \
        --apiKeyPath "${API_KEY_PATH}" \
        --upload "${IPA_PATH}" \
        --verbose 2>&1)
    
    local upload_exit_code=$?
    
    # Log the output
    echo "${upload_output}"
    
    if [[ ${upload_exit_code} -eq 0 ]]; then
        success "✅ IPA uploaded to TestFlight successfully using transporter!"
        return 0
    else
        error "❌ Transporter upload failed"
        # Use comprehensive error analysis
        analyze_upload_error "${upload_output}" "${upload_exit_code}"
        return $?
    fi
}

# Function to wait for TestFlight processing
wait_for_testflight_processing() {
    local upload_id="$1"
    
    if [[ -z "$upload_id" ]]; then
        log "📋 No upload ID provided, skipping processing wait"
        return 0
    fi
    
    log "⏳ Waiting for TestFlight processing to complete..."
    log "📋 Upload ID: $upload_id"
    
    # Wait for processing (max 10 minutes)
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))
        
        # Check processing status
        local status_output
        status_output=$(xcrun altool --notarization-info "$upload_id" \
            --apiKey "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
            --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" 2>&1)
        
        if echo "$status_output" | grep -q "success"; then
            success "✅ TestFlight processing completed successfully!"
            return 0
        elif echo "$status_output" | grep -q "invalid"; then
            error "❌ TestFlight processing failed"
            echo "$status_output"
            return 1
        else
            log "⏳ Processing... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
    done
    
    warning "⚠️ TestFlight processing timeout after $max_attempts attempts"
    log "📱 Check App Store Connect for final status"
    return 0
}

# Main function to handle TestFlight upload
upload_to_testflight() {
    local IPA_PATH="$1"
    
    log "🚀 Starting TestFlight upload process..."
    
    # Validate requirements
    if ! validate_testflight_requirements; then
        log "📱 TestFlight upload requirements not met, skipping upload"
        return 0
    fi
    
    # Setup API key
    local API_KEY_PATH
    API_KEY_PATH=$(setup_api_key)
    if [[ $? -ne 0 ]]; then
        error "❌ Failed to setup API key"
        return 1
    fi
    
    # Try transporter first, fallback to altool
    if ! upload_to_testflight_transporter "$IPA_PATH" "$API_KEY_PATH"; then
        log "🔄 Falling back to altool method..."
        if ! upload_to_testflight_altool "$IPA_PATH" "$API_KEY_PATH"; then
            error "❌ Both transporter and altool upload methods failed"
            return 1
        fi
    fi
    
    # Cleanup API key file
    rm -f "$API_KEY_PATH"
    
    success "🎉 TestFlight upload process completed successfully!"
    log "📱 Check App Store Connect for build status and TestFlight distribution"
    
    return 0
}

# Function to check TestFlight upload status
check_testflight_status() {
    log "📊 Checking TestFlight upload status..."
    
    # This function can be used to check the status of uploaded builds
    # Implementation depends on specific requirements
    
    log "📱 Use App Store Connect or TestFlight app to check build status"
}

# Function to analyze upload errors comprehensively
analyze_upload_error() {
    local output="$1"
    local exit_code="$2"
    
    log "🔍 Analyzing upload error (exit code: $exit_code)"
    
    if [[ $exit_code -eq 0 ]]; then
        success "✅ IPA uploaded to TestFlight successfully!"
        return 0
    fi
    
    # Check for specific error patterns
    if echo "$output" | grep -q "already exists"; then
        warning "⚠️ App version already exists in TestFlight"
        log "📱 This is normal if the version was previously uploaded"
        return 0
    elif echo "$output" | grep -q "authentication\|auth"; then
        error "🔐 Authentication failed - check API key credentials"
        log "🔍 Common causes:"
        log "   - Invalid API key ID"
        log "   - Invalid Issuer ID"
        log "   - Incorrect API key format"
        log "   - API key doesn't have App Manager role"
        return 1
    elif echo "$output" | grep -q "not found\|doesn't exist"; then
        error "🔍 App not found - check Bundle ID and Team ID"
        log "🔍 Common causes:"
        log "   - Bundle ID doesn't match App Store Connect app"
        log "   - Team ID doesn't match API key issuer"
        log "   - App not created in App Store Connect"
        return 1
    elif echo "$output" | grep -q "network\|connection\|timeout"; then
        error "🌐 Network error - check internet connection"
        log "🔍 Common causes:"
        log "   - Network connectivity issues"
        log "   - Firewall blocking connections"
        log "   - DNS resolution problems"
        return 1
    elif echo "$output" | grep -q "invalid\|malformed"; then
        error "📦 Invalid IPA file - check build process"
        log "🔍 Common causes:"
        log "   - IPA file corrupted during build"
        log "   - Code signing issues"
        log "   - Missing required files in IPA"
        return 1
    elif echo "$output" | grep -q "permission\|access"; then
        error "🔐 Permission denied - check API key permissions"
        log "🔍 Common causes:"
        log "   - API key doesn't have upload permissions"
        log "   - App not accessible with current API key"
        log "   - Team access restrictions"
        return 1
    elif echo "$output" | grep -q "rate limit\|too many"; then
        error "⏱️ Rate limit exceeded - wait before retrying"
        log "🔍 Common causes:"
        log "   - Too many uploads in short time"
        log "   - API rate limits from Apple"
        return 1
    else
        error "❌ Unknown upload error - check the output above"
        log "🔍 Full error output:"
        echo "$output" | head -20
        return 1
    fi
}

# Export functions for use in other scripts
export -f upload_to_testflight
export -f validate_testflight_requirements
export -f check_testflight_status

# Main execution (if script is run directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log "🚀 TestFlight upload script started"
    
    # Check if IPA path is provided
    if [[ $# -eq 0 ]]; then
        error "❌ Usage: $0 <ipa_file_path>"
        exit 1
    fi
    
    # shellcheck disable=SC2168
    local IPA_PATH="$1"
    
    # Check if IPA file exists
    if [[ ! -f "$IPA_PATH" ]]; then
        error "❌ IPA file not found: $IPA_PATH"
        exit 1
    fi
    
    # Run upload
    upload_to_testflight "$IPA_PATH"
    exit $?
fi 