#!/bin/bash

# 🔧 Common Utility Functions for iOS Build Scripts
# This file provides shared functions used across all iOS build scripts

# Logging functions with timestamps
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1"
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG: $1"
    fi
}

# Function to validate required environment variables
validate_required_vars() {
    local missing_vars=()
    
    # Check required app configuration
    [ -z "${APP_NAME:-}" ] && missing_vars+=("APP_NAME")
    [ -z "${BUNDLE_ID:-}" ] && missing_vars+=("BUNDLE_ID")
    [ -z "${VERSION_NAME:-}" ] && missing_vars+=("VERSION_NAME")
    [ -z "${VERSION_CODE:-}" ] && missing_vars+=("VERSION_CODE")
    [ -z "${APPLE_TEAM_ID:-}" ] && missing_vars+=("APPLE_TEAM_ID")
    [ -z "${PROFILE_TYPE:-}" ] && missing_vars+=("PROFILE_TYPE")
    
    # Check certificate configuration
    if [[ "${WORKFLOW_ID:-}" != "auto-ios-workflow" ]]; then
        # Check if we have either P12 or CER+KEY configuration
        local has_p12=false
        local has_cer_key=false
        
        if [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" == http* ]]; then
            has_p12=true
        fi
        
        if [[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]] && [[ "${CERT_CER_URL}" == http* ]] && [[ "${CERT_KEY_URL}" == http* ]]; then
            has_cer_key=true
        fi
        
        if [[ "$has_p12" == "false" ]] && [[ "$has_cer_key" == "false" ]]; then
            missing_vars+=("CERT_P12_URL or (CERT_CER_URL + CERT_KEY_URL)")
        fi
        
        [ -z "${PROFILE_URL:-}" ] && missing_vars+=("PROFILE_URL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "   - ${var}"
        done
        return 1
    fi
    
    return 0
}

# Function to validate profile type
validate_profile_type() {
    local profile_type="${PROFILE_TYPE:-app-store}"
    
    case "$profile_type" in
        "app-store"|"ad-hoc"|"enterprise"|"development")
            log_success "Valid profile type: $profile_type"
            return 0
            ;;
        *)
            log_error "Invalid profile type: $profile_type"
            log_error "Supported types: app-store, ad-hoc, enterprise, development"
            return 1
            ;;
    esac
}

# Function to send email notifications
send_email() {
    local email_type="$1"
    local platform="$2"
    local build_id="$3"
    local error_message="${4:-No error message provided}"
    
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ] && [ -f "lib/scripts/utils/send_email.py" ]; then
        log_info "Sending $email_type email for $platform build $build_id"
        if python3 lib/scripts/utils/send_email.py "$email_type" "$platform" "$build_id" "$error_message"; then
            log_success "Email sent successfully"
        else
            log_warn "Failed to send email notification"
        fi
    else
        log_debug "Email notifications disabled or email script not found"
    fi
}

# Function to create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check file size and existence (Linux compatible)
validate_file() {
    local file_path="$1"
    local min_size="${2:-1}"
    
    if [ ! -f "$file_path" ]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    # Use Linux-compatible stat command
    local file_size
    if command_exists stat; then
        # Try Linux stat first, then BSD stat
        file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0")
    else
        # Fallback using ls
        file_size=$(ls -l "$file_path" 2>/dev/null | awk '{print $5}' || echo "0")
    fi
    
    if [ "$file_size" -lt "$min_size" ]; then
        log_error "File too small (${file_size} bytes): $file_path"
        return 1
    fi
    
    log_success "File validated: $file_path (${file_size} bytes)"
    return 0
}

# Function to download file with retry logic
download_file() {
    local url="$1"
    local output_path="$2"
    local max_retries="${3:-3}"
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        log_info "Downloading from $url (attempt $((retry_count + 1))/$max_retries)..."
        
        if curl -L --fail --silent --show-error --output "$output_path" "$url"; then
            log_success "Download completed: $output_path"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warn "Download failed, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Download failed after $max_retries attempts: $url"
    return 1
}

# Function to get system memory (Linux compatible)
get_system_memory() {
    if [ -f "/proc/meminfo" ]; then
        # Linux system
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_gb=$((mem_kb / 1024 / 1024))
        echo "${mem_gb} GB"
    elif command_exists sysctl; then
        # macOS system (for local development)
        sysctl -n hw.memsize 2>/dev/null | awk '{print $0/1024/1024/1024 " GB"}' || echo "Unknown"
    else
        echo "Unknown"
    fi
}

# Function to cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script exited with error code: $exit_code"
        send_email "build_failed" "iOS" "${CM_BUILD_ID:-unknown}" "Script failed with exit code $exit_code"
    fi
}

# Set up exit trap
trap cleanup_on_exit EXIT

# Export functions for use in other scripts
export -f log_info log_success log_warn log_error log_debug
export -f validate_required_vars validate_profile_type send_email
export -f ensure_directory command_exists validate_file download_file get_system_memory 