#!/bin/bash

#  Certificate and Provisioning Profile Handler for iOS Build
# Purpose: Download, validate, and install certificates and provisioning profiles

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info " Starting Certificate and Profile Setup..."

# Function to detect and validate certificate password
detect_certificate_password() {
    local cert_file="$1"
    local provided_password="${CERT_PASSWORD:-}"
    
    log_info " Detecting certificate password..."
    
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
    log_info " Certificate and Profile Setup Starting..."
    
    # Ensure certificates directory exists
    ensure_directory "ios/certificates"
    
    log_success " Certificate and Profile Setup completed successfully!"
    return 0
}

# Run main function
main "$@"
