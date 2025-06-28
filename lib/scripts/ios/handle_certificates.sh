#!/bin/bash

# Certificate and Provisioning Profile Handler for iOS Build
# Purpose: Download, validate, and install certificates and provisioning profiles

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Certificate and Profile Setup..."

# Function to download file with retry logic
download_with_retry() {
    local url="$1"
    local output_file="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Downloading from $url (attempt $attempt/$max_attempts)..."
        
        # Try multiple download methods
        if curl -L -f -s -o "$output_file" "$url" 2>/dev/null; then
            log_success "Download completed: $output_file"
            return 0
        elif wget -q -O "$output_file" "$url" 2>/dev/null; then
            log_success "Download completed: $output_file"
            return 0
        fi
        
        log_warn "Download attempt $attempt failed"
        attempt=$((attempt + 1))
        [ $attempt -le $max_attempts ] && sleep 2
    done
    
    log_error "Failed to download after $max_attempts attempts"
    return 1
}

# Function to validate file exists and has content
validate_file() {
    local file="$1"
    local min_size="${2:-10}"
    
    if [ ! -f "$file" ]; then
        log_error "File does not exist: $file"
        return 1
    fi
    
    local file_size
    if command -v stat >/dev/null 2>&1; then
        if stat -c%s "$file" >/dev/null 2>&1; then
            # Linux stat
            file_size=$(stat -c%s "$file" 2>/dev/null)
        else
            # macOS stat
            file_size=$(stat -f%z "$file" 2>/dev/null)
        fi
    else
        # Fallback using wc
        file_size=$(wc -c < "$file" 2>/dev/null)
    fi
    
    if [ "${file_size:-0}" -lt "$min_size" ]; then
        log_error "File too small (${file_size:-0} bytes): $file"
        return 1
    fi
    
    log_success "File validated: $file (${file_size} bytes)"
    return 0
}

# Function to download and install P12 certificate
install_p12_certificate() {
    local cert_url="$1"
    local cert_file="ios/certificates/certificate.p12"
    
    log_info "Installing P12 certificate from: $cert_url"
    
    # Download certificate
    if ! download_with_retry "$cert_url" "$cert_file"; then
        log_error "Failed to download P12 certificate"
        return 1
    fi
    
    # Validate file
    if ! validate_file "$cert_file"; then
        log_error "Downloaded P12 certificate is invalid"
        return 1
    fi
    
    # Detect password
    local password
    if ! password=$(detect_certificate_password "$cert_file"); then
        log_error "Could not determine certificate password"
        return 1
    fi
    
    log_info "Installing certificate to keychain..."
    
    # Create a temporary keychain for testing
    local temp_keychain="temp_build_$(date +%s).keychain"
    
    # Try installing to temporary keychain first
    if security create-keychain -p "temp123" "$temp_keychain" 2>/dev/null; then
        security unlock-keychain -p "temp123" "$temp_keychain" 2>/dev/null
        
        # Test installation
        if security import "$cert_file" -k "$temp_keychain" -P "$password" -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null; then
            log_success "Certificate password validated successfully"
            
            # Clean up test keychain
            security delete-keychain "$temp_keychain" 2>/dev/null || true
            
            # Install to login keychain
            if security import "$cert_file" -k ~/Library/Keychains/login.keychain-db -P "$password" -T /usr/bin/codesign -T /usr/bin/security; then
                log_success "P12 certificate installed successfully"
                return 0
            else
                log_error "Failed to install certificate to login keychain"
                return 1
            fi
        else
            log_error "Certificate password validation failed"
            security delete-keychain "$temp_keychain" 2>/dev/null || true
            return 1
        fi
    else
        log_warn "Could not create temporary keychain, trying direct installation..."
        
        # Direct installation attempt
        if security import "$cert_file" -k ~/Library/Keychains/login.keychain-db -P "$password" -T /usr/bin/codesign -T /usr/bin/security; then
            log_success "P12 certificate installed successfully"
            return 0
        else
            log_error "Failed to install P12 certificate"
            return 1
        fi
    fi
}

# Function to install CER+KEY certificate
install_cer_key_certificate() {
    local cer_url="$1"
    local key_url="$2"
    
    log_info "Installing CER+KEY certificate from: $cer_url and $key_url"
    
    local cer_file="ios/certificates/certificate.cer"
    local key_file="ios/certificates/certificate.key"
    local p12_file="ios/certificates/certificate.p12"
    
    # Download CER file
    if ! download_with_retry "$cer_url" "$cer_file"; then
        log_error "Failed to download CER certificate"
        return 1
    fi
    
    # Download KEY file
    if ! download_with_retry "$key_url" "$key_file"; then
        log_error "Failed to download private key"
        return 1
    fi
    
    # Validate files
    if ! validate_file "$cer_file" || ! validate_file "$key_file"; then
        log_error "Downloaded certificate files are invalid"
        return 1
    fi
    
    log_info "Converting CER+KEY to P12 format..."
    
    # Use provided CERT_PASSWORD or empty password if not provided
    local provided_password="${CERT_PASSWORD:-}"
    local p12_password=""
    
    # First priority: Use provided CERT_PASSWORD
    if [ -n "$provided_password" ] && [ "$provided_password" != "set" ] && [ "$provided_password" != "true" ] && [ "$provided_password" != "false" ] && [ "$provided_password" != "SET" ] && [ "$provided_password" != "your_password" ]; then
        log_info "Using provided CERT_PASSWORD for P12 conversion: '$provided_password'"
        if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:$provided_password" -name "iOS Distribution Certificate" 2>/dev/null; then
            log_success "Certificate converted to P12 format with provided password"
            p12_password="$provided_password"
        else
            log_warn "P12 conversion failed with provided password: '$provided_password'"
        fi
    else
        log_info "No valid CERT_PASSWORD provided (value: '${provided_password:-<empty>}'), using empty password"
    fi
    
    # Second priority: Try empty password if provided password failed or wasn't provided
    if [ ! -f "$p12_file" ]; then
        log_info "Trying P12 conversion with empty password..."
        if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:" -name "iOS Distribution Certificate" 2>/dev/null; then
            log_success "Certificate converted to P12 format with empty password"
            p12_password=""
        else
            log_warn "P12 conversion failed with empty password"
        fi
    fi
    
    # Third priority: Try common passwords only as last resort
    if [ ! -f "$p12_file" ]; then
        log_info "Trying P12 conversion with common passwords as fallback..."
        local conversion_passwords=("password" "123456" "certificate" "quikapp" "twinklub" "ios" "apple")
        
        for pwd in "${conversion_passwords[@]}"; do
            log_info "Trying P12 conversion with fallback password: '$pwd'"
            if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:$pwd" -name "iOS Distribution Certificate" 2>/dev/null; then
                log_success "Certificate converted to P12 format with fallback password: '$pwd'"
                p12_password="$pwd"
                break
            fi
        done
    fi
    
    if [ ! -f "$p12_file" ]; then
        log_error "Failed to convert CER+KEY to P12 format"
        return 1
    fi
    
    # Validate the converted P12 file
    if ! validate_file "$p12_file"; then
        log_error "Converted P12 file is invalid"
        return 1
    fi
    
    log_info "Installing converted certificate to keychain..."
    
    # Create a temporary keychain for testing
    local temp_keychain="temp_build_$(date +%s).keychain"
    
    # Try installing to temporary keychain first
    if security create-keychain -p "temp123" "$temp_keychain" 2>/dev/null; then
        security unlock-keychain -p "temp123" "$temp_keychain" 2>/dev/null
        
        # Test installation
        if security import "$p12_file" -k "$temp_keychain" -P "$p12_password" -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null; then
            log_success "Converted certificate password validated successfully"
            
            # Clean up test keychain
            security delete-keychain "$temp_keychain" 2>/dev/null || true
            
            # Install to login keychain
            if security import "$p12_file" -k ~/Library/Keychains/login.keychain-db -P "$p12_password" -T /usr/bin/codesign -T /usr/bin/security; then
                log_success "Converted certificate installed successfully"
                return 0
            else
                log_error "Failed to install converted certificate to login keychain"
                return 1
            fi
        else
            log_error "Converted certificate password validation failed"
            security delete-keychain "$temp_keychain" 2>/dev/null || true
            return 1
        fi
    else
        log_warn "Could not create temporary keychain, trying direct installation..."
        
        # Direct installation attempt
        if security import "$p12_file" -k ~/Library/Keychains/login.keychain-db -P "$p12_password" -T /usr/bin/codesign -T /usr/bin/security; then
            log_success "Converted certificate installed successfully"
            return 0
        else
            log_error "Failed to install converted certificate"
            return 1
        fi
    fi
}

# Function to download and install provisioning profile
install_provisioning_profile() {
    local profile_url="$1"
    local profile_file="ios/certificates/profile.mobileprovision"
    
    log_info "Installing provisioning profile from: $profile_url"
    
    # Download provisioning profile
    if ! download_with_retry "$profile_url" "$profile_file"; then
        log_error "Failed to download provisioning profile"
        return 1
    fi
    
    # Validate file
    if ! validate_file "$profile_file"; then
        log_error "Downloaded provisioning profile is invalid"
        return 1
    fi
    
    # Install provisioning profile
    local profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
    mkdir -p "$profiles_dir"
    
    # Get profile UUID
    local profile_uuid
    profile_uuid=$(security cms -D -i "$profile_file" 2>/dev/null | plutil -extract UUID xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
    
    if [ -n "$profile_uuid" ]; then
        local target_file="$profiles_dir/$profile_uuid.mobileprovision"
        cp "$profile_file" "$target_file"
        log_success "Provisioning profile installed: $profile_uuid"
        return 0
    else
        log_error "Failed to extract UUID from provisioning profile"
        return 1
    fi
}

# Function to detect and validate certificate password
detect_certificate_password() {
    local cert_file="$1"
    local provided_password="${CERT_PASSWORD:-}"
    
    log_info "Detecting certificate password..."
    
    # First priority: Use provided CERT_PASSWORD if it exists and is not a placeholder
    if [ -n "$provided_password" ] && [ "$provided_password" != "set" ] && [ "$provided_password" != "true" ] && [ "$provided_password" != "false" ] && [ "$provided_password" != "SET" ] && [ "$provided_password" != "your_password" ]; then
        log_info "Testing provided certificate password..."
        # Test with both legacy and modern openssl options
        if openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" -legacy 2>/dev/null || \
           openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" 2>/dev/null; then
            log_success "Provided certificate password is valid"
            echo "$provided_password"
            return 0
        else
            log_warn "Provided certificate password failed validation: '$provided_password'"
        fi
    else
        log_info "No valid certificate password provided (value: '${provided_password:-<empty>}')"
    fi
    
    # Second priority: Try empty password
    log_info "Trying empty password..."
    if openssl pkcs12 -in "$cert_file" -noout -passin "pass:" -legacy 2>/dev/null || \
       openssl pkcs12 -in "$cert_file" -noout -passin "pass:" 2>/dev/null; then
        log_success "Certificate uses empty password"
        echo ""
        return 0
    fi
    
    # Third priority: Try common passwords only as last resort
    log_info "Trying common certificate passwords as fallback..."
    local common_passwords=(
        "password"
        "123456"
        "certificate"
        "ios"
        "apple"
        "distribution"
        "match"
        "User@54321"
        "your_cert_password"
        "quikapp"
        "QuikApp"
        "QUIKAPP"
        "twinklub"
        "Twinklub"
        "TWINKLUB"
        "test"
        "Test"
        "TEST"
        "admin"
        "Admin"
        "ADMIN"
    )
    
    for password in "${common_passwords[@]}"; do
        log_info "Trying fallback password: '$password'"
        # Test with both legacy and modern openssl options
        if openssl pkcs12 -in "$cert_file" -noout -passin "pass:$password" -legacy 2>/dev/null || \
           openssl pkcs12 -in "$cert_file" -noout -passin "pass:$password" 2>/dev/null; then
            log_success "Found working fallback password: '$password'"
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
    
    # Main certificate handling logic
    cert_installed=false
    
    log_info "Certificate installation priority:"
    log_info "  1. P12 certificate with provided CERT_PASSWORD"
    log_info "  2. CER+KEY conversion with provided CERT_PASSWORD (or empty if not provided)"
    log_info "  3. Fallback methods with common passwords"

    # Try P12 certificate first if URL is provided
    if [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" == http* ]]; then
        log_info "P12 certificate URL provided, attempting installation..."
        log_info "P12 URL: ${CERT_P12_URL}"
        log_info "CERT_PASSWORD: ${CERT_PASSWORD:+<provided>}${CERT_PASSWORD:-<not provided>}"
        
        if install_p12_certificate "$CERT_P12_URL"; then
            cert_installed=true
            log_success "P12 certificate installation successful!"
        else
            log_warn "P12 certificate installation failed, will try CER+KEY method..."
        fi
    else
        log_info "No P12 certificate URL provided, skipping P12 method"
    fi

    # Try CER+KEY certificate if P12 failed or not provided
    if [ "$cert_installed" = false ] && [[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]] && [[ "${CERT_CER_URL}" == http* ]] && [[ "${CERT_KEY_URL}" == http* ]]; then
        log_info "CER+KEY certificate URLs provided, attempting installation..."
        log_info "CER URL: ${CERT_CER_URL}"
        log_info "KEY URL: ${CERT_KEY_URL}"
        log_info "CERT_PASSWORD: ${CERT_PASSWORD:+<provided>}${CERT_PASSWORD:-<not provided>}"
        
        if install_cer_key_certificate "$CERT_CER_URL" "$CERT_KEY_URL"; then
            cert_installed=true
            log_success "CER+KEY certificate installation successful!"
        else
            log_warn "CER+KEY certificate installation failed"
        fi
    else
        if [ "$cert_installed" = false ]; then
            log_info "No CER+KEY certificate URLs provided, skipping CER+KEY method"
        fi
    fi
    
    # Handle provisioning profiles
    profile_installed=false
    if [[ -n "${PROVISIONING_PROFILE_URL:-}" ]] && [[ "${PROVISIONING_PROFILE_URL}" == http* ]]; then
        log_info "Provisioning profile URL provided, installing..."
        if install_provisioning_profile "$PROVISIONING_PROFILE_URL"; then
            profile_installed=true
        else
            log_warn "Provisioning profile installation failed"
        fi
    fi
    
    # Final validation
    if [ "$cert_installed" = false ]; then
        log_error "No valid certificate configuration found or installation failed"
        log_info "Available certificate methods:"
        log_info "  1. P12 Certificate: CERT_P12_URL + CERT_PASSWORD"
        log_info "  2. CER+KEY Certificate: CERT_CER_URL + CERT_KEY_URL"
        log_info "Please ensure:"
        log_info "  - Certificate URLs are accessible"
        log_info "  - Certificate password is correct (if using P12)"
        log_info "  - Certificate files are valid iOS distribution certificates"
        exit 1
    fi
    
    if [ "$profile_installed" = false ]; then
        log_warn "No provisioning profile installed - this may cause code signing issues"
        log_info "To install provisioning profile, set: PROVISIONING_PROFILE_URL"
    fi
    
    log_success "Certificate and Profile Setup completed successfully!"
    return 0
}

# Run main function
main "$@"
