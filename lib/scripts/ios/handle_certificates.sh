#!/bin/bash

# Certificate and Provisioning Profile Handler for iOS Build
# Purpose: Download, validate, and install certificates and provisioning profiles

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Certificate and Profile Setup..."

# Function to download and install P12 certificate
install_p12_certificate() {
    local cert_url="$1"
    local cert_password="${2:-}"
    
    log_info "Installing P12 certificate from: $cert_url"
    
    local cert_file="ios/certificates/certificate.p12"
    
    # Download certificate
    if ! download_file "$cert_url" "$cert_file"; then
        log_error "Failed to download P12 certificate"
        return 1
    fi
    
    # Validate certificate file
    if ! validate_file "$cert_file" 100; then
        log_error "Invalid P12 certificate file"
        return 1
    fi
    
    # Detect password if not provided
    if [ -z "$cert_password" ]; then
        cert_password=$(detect_certificate_password "$cert_file")
        if [ $? -ne 0 ]; then
            log_error "Failed to detect certificate password"
            return 1
        fi
    fi
    
    # Install certificate to keychain
    log_info "Installing certificate to keychain..."
    security import "$cert_file" -P "$cert_password" -A -t cert -f pkcs12 -k ~/Library/Keychains/login.keychain
    
    if [ $? -eq 0 ]; then
        log_success "P12 certificate installed successfully"
        return 0
    else
        log_error "Failed to install P12 certificate"
        return 1
    fi
}

# Function to download and install CER+KEY certificate
install_cer_key_certificate() {
    local cer_url="$1"
    local key_url="$2"
    
    log_info "Installing CER+KEY certificate from: $cer_url and $key_url"
    
    local cer_file="ios/certificates/certificate.cer"
    local key_file="ios/certificates/certificate.key"
    local p12_file="ios/certificates/certificate.p12"
    
    # Download CER file
    if ! download_file "$cer_url" "$cer_file"; then
        log_error "Failed to download CER certificate"
        return 1
    fi
    
    # Download KEY file
    if ! download_file "$key_url" "$key_file"; then
        log_error "Failed to download KEY certificate"
        return 1
    fi
    
    # Validate files
    if ! validate_file "$cer_file" 100 || ! validate_file "$key_file" 100; then
        log_error "Invalid certificate files"
        return 1
    fi
    
    # Convert CER+KEY to P12
    log_info "Converting CER+KEY to P12 format..."
    local temp_password="temp_password_$(date +%s)"
    
    openssl pkcs12 -export -out "$p12_file" -inkey "$key_file" -in "$cer_file" -password "pass:$temp_password"
    
    if [ $? -eq 0 ] && [ -f "$p12_file" ]; then
        log_success "Certificate converted to P12 format"
        
        # Install P12 certificate
        security import "$p12_file" -P "$temp_password" -A -t cert -f pkcs12 -k ~/Library/Keychains/login.keychain
        
        if [ $? -eq 0 ]; then
            log_success "CER+KEY certificate installed successfully"
            return 0
        else
            log_error "Failed to install converted certificate"
            return 1
        fi
    else
        log_error "Failed to convert CER+KEY to P12"
        return 1
    fi
}

# Function to download and install provisioning profile
install_provisioning_profile() {
    local profile_url="$1"
    
    log_info "Installing provisioning profile from: $profile_url"
    
    local profile_file="ios/certificates/profile.mobileprovision"
    
    # Download provisioning profile
    if ! download_file "$profile_url" "$profile_file"; then
        log_error "Failed to download provisioning profile"
        return 1
    fi
    
    # Validate profile file
    if ! validate_file "$profile_file" 100; then
        log_error "Invalid provisioning profile file"
        return 1
    fi
    
    # Install provisioning profile
    log_info "Installing provisioning profile..."
    local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
    ensure_directory "$profile_dir"
    
    # Get profile UUID
    local profile_uuid
    if command_exists security; then
        profile_uuid=$(security cms -D -i "$profile_file" | plutil -extract UUID xml1 -o - - | grep -A1 UUID | tail -1 | sed 's/<[^>]*>//g' | xargs)
    fi
    
    if [ -n "$profile_uuid" ]; then
        cp "$profile_file" "$profile_dir/$profile_uuid.mobileprovision"
        log_success "Provisioning profile installed: $profile_uuid"
    else
        # Fallback: copy with generic name
        cp "$profile_file" "$profile_dir/profile.mobileprovision"
        log_success "Provisioning profile installed (generic name)"
    fi
    
    return 0
}

# Function to detect and validate certificate password
detect_certificate_password() {
    local cert_file="$1"
    local provided_password="${CERT_PASSWORD:-}"
    
    log_info "Detecting certificate password..."
    
    # Check if provided password is valid (not placeholder)
    if [ -n "$provided_password" ] && [ "$provided_password" != "set" ] && [ "$provided_password" != "true" ] && [ "$provided_password" != "false" ]; then
        log_info "Testing provided certificate password..."
        if openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" -legacy 2>/dev/null; then
            log_success "Provided certificate password is valid"
            echo "$provided_password"
            return 0
        else
            log_warn "Provided certificate password failed validation"
        fi
    else
        log_warn "Certificate password appears to be a placeholder value: '$provided_password'"
    fi
    
    # Try common passwords
    log_info "Trying common certificate passwords..."
    local common_passwords=("" "password" "123456" "certificate" "ios" "apple" "distribution" "match" "User@54321" "your_cert_password")
    
    for password in "${common_passwords[@]}"; do
        if openssl pkcs12 -in "$cert_file" -noout -passin "pass:$password" -legacy 2>/dev/null; then
            log_success "Found working password: '$password'"
            echo "$password"
            return 0
        fi
    done
    
    log_error "No working password found for certificate"
    return 1
}

# Main execution
main() {
    log_info "Certificate and Profile Setup Starting..."
    
    # Skip certificate handling for auto-ios-workflow
    if [[ "${WORKFLOW_ID:-}" == "auto-ios-workflow" ]]; then
        log_info "Auto-ios-workflow detected - skipping manual certificate handling"
        log_success "Certificate setup completed (auto-managed)"
        return 0
    fi
    
    # Ensure certificates directory exists
    ensure_directory "ios/certificates"
    
    # Install certificates
    local cert_installed=false
    
    # Try P12 certificate first
    if [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" == http* ]]; then
        log_info "P12 certificate URL provided, installing..."
        if install_p12_certificate "$CERT_P12_URL" "${CERT_PASSWORD:-}"; then
            cert_installed=true
        fi
    fi
    
    # Try CER+KEY certificate if P12 failed or not provided
    if [[ "$cert_installed" == "false" ]] && [[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]] && [[ "${CERT_CER_URL}" == http* ]] && [[ "${CERT_KEY_URL}" == http* ]]; then
        log_info "CER+KEY certificate URLs provided, installing..."
        if install_cer_key_certificate "$CERT_CER_URL" "$CERT_KEY_URL"; then
            cert_installed=true
        fi
    fi
    
    if [[ "$cert_installed" == "false" ]]; then
        log_error "No valid certificate configuration found or installation failed"
        return 1
    fi
    
    # Install provisioning profile
    if [[ -n "${PROFILE_URL:-}" ]] && [[ "${PROFILE_URL}" == http* ]]; then
        log_info "Provisioning profile URL provided, installing..."
        if ! install_provisioning_profile "$PROFILE_URL"; then
            log_error "Failed to install provisioning profile"
            return 1
        fi
    else
        log_error "No valid provisioning profile URL provided"
        return 1
    fi
    
    log_success "Certificate and Profile Setup completed successfully!"
    return 0
}

# Run main function
main "$@"
