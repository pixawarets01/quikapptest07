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

# Function to check existing certificates in keychain
check_existing_certificates() {
    local keychain_name="ios-build.keychain"
    log_info "Checking existing certificates in keychain..."
    
    # List all code signing identities from dedicated keychain first
    local identities
    identities=$(security find-identity -v -p codesigning "$keychain_name" 2>/dev/null)
    
    if [ -z "$identities" ]; then
        # Fallback to checking all keychains
        identities=$(security find-identity -v -p codesigning 2>/dev/null)
    fi
    
    if [ -n "$identities" ]; then
        log_info "Found existing code signing identities:"
        echo "$identities" | while read line; do
            log_info "  $line"
        done
        
        # Check for iOS distribution certificates specifically
        local ios_certs
        ios_certs=$(echo "$identities" | grep -E "iPhone Distribution|iOS Distribution|Apple Distribution")
        
        if [ -n "$ios_certs" ]; then
            log_success "Found existing iOS distribution certificates!"
            echo "$ios_certs" | while read line; do
                log_success "  $line"
            done
            return 0
        else
            log_info "No iOS distribution certificates found"
            return 1
        fi
    else
        log_info "No code signing identities found in keychain"
        return 1
    fi
}

# Function to install P12 certificate
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
    
    # Get provided password
    local provided_password="${CERT_PASSWORD:-}"
    local keychain_name="ios-build.keychain"
    local keychain_password="${KEYCHAIN_PASSWORD:-build123}"
    
    log_info "Setting up dedicated keychain for certificate installation..."
    
    # Delete existing keychain if it exists
    security delete-keychain "$keychain_name" 2>/dev/null || true
    
    # Create new keychain
    if ! security create-keychain -p "$keychain_password" "$keychain_name"; then
        log_error "Failed to create keychain"
        return 1
    fi
    
    # Configure keychain settings
    security set-keychain-settings -lut 21600 "$keychain_name"
    security unlock-keychain -p "$keychain_password" "$keychain_name"
    
    # Try installation with provided password first
    if [ -n "$provided_password" ] && [ "$provided_password" != "set" ] && [ "$provided_password" != "true" ] && [ "$provided_password" != "false" ] && [ "$provided_password" != "SET" ] && [ "$provided_password" != "your_password" ]; then
        log_info "Attempting installation with provided password: '$provided_password'"
        
        if security import "$cert_file" -k "$keychain_name" -P "$provided_password" -T /usr/bin/codesign; then
            log_success "P12 certificate imported successfully with provided password"
            
            # Set key partition list for access
            if security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name"; then
                log_success "Key partition list set successfully"
            else
                log_warn "Failed to set key partition list, but continuing..."
            fi
            
            # Set as default keychain
            security list-keychains -s "$keychain_name"
            security default-keychain -s "$keychain_name"
            
            log_success "P12 certificate installed successfully with provided password"
            return 0
        else
            log_warn "Installation failed with provided password: '$provided_password'"
        fi
    else
        log_info "No valid certificate password provided, trying empty password"
    fi
    
    # Try with empty password
    log_info "Attempting installation with empty password..."
    if security import "$cert_file" -k "$keychain_name" -P "" -T /usr/bin/codesign; then
        log_success "P12 certificate imported successfully with empty password"
        
        # Set key partition list for access
        security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name" 2>/dev/null || true
        
        # Set as default keychain
        security list-keychains -s "$keychain_name"
        security default-keychain -s "$keychain_name"
        
        log_success "P12 certificate installed successfully with empty password"
        return 0
    fi
    
    # Try common passwords as fallback
    log_info "Attempting installation with common passwords..."
    local common_passwords=("password" "123456" "certificate" "ios" "apple" "distribution" "match" "User@54321")
    
    for password in "${common_passwords[@]}"; do
        log_info "Trying password: '$password'"
        
        if security import "$cert_file" -k "$keychain_name" -P "$password" -T /usr/bin/codesign; then
            log_success "P12 certificate imported successfully with password: '$password'"
            
            # Set key partition list for access
            security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name" 2>/dev/null || true
            
            # Set as default keychain
            security list-keychains -s "$keychain_name"
            security default-keychain -s "$keychain_name"
            
            log_success "P12 certificate installed successfully with password: '$password'"
            return 0
        fi
    done
    
    log_error "Failed to install P12 certificate with all attempted passwords"
    return 1
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
        if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:$provided_password" -name "iOS Distribution Certificate" -legacy 2>/dev/null; then
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
        if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:" -name "iOS Distribution Certificate" -legacy 2>/dev/null; then
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
            if openssl pkcs12 -export -in "$cer_file" -inkey "$key_file" -out "$p12_file" -password "pass:$pwd" -name "iOS Distribution Certificate" -legacy 2>/dev/null; then
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
    
    # Use the same dedicated keychain approach
    local keychain_name="ios-build.keychain"
    local keychain_password="${KEYCHAIN_PASSWORD:-build123}"
    
    # Try installation with the password used for conversion
    log_info "Attempting installation with conversion password: '${p12_password:-<empty>}'"
    
    # Create keychain if it doesn't exist (should already exist from P12 attempt)
    security create-keychain -p "$keychain_password" "$keychain_name" 2>/dev/null || true
    security set-keychain-settings -lut 21600 "$keychain_name"
    security unlock-keychain -p "$keychain_password" "$keychain_name"
    
    if security import "$p12_file" -k "$keychain_name" -P "$p12_password" -T /usr/bin/codesign; then
        log_success "Converted certificate imported successfully"
        
        # Set key partition list for access
        if security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_name"; then
            log_success "Key partition list set successfully"
        else
            log_warn "Failed to set key partition list, but continuing..."
        fi
        
        # Set as default keychain
        security list-keychains -s "$keychain_name"
        security default-keychain -s "$keychain_name"
        
        log_success "Converted certificate installed successfully"
        return 0
    else
        log_error "Failed to install converted certificate"
        return 1
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
        log_info "Testing provided certificate password: '$provided_password'"
        # Test with both legacy and modern openssl options
        if openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" -legacy 2>/dev/null; then
            log_success "Provided certificate password is valid (legacy mode)"
            echo "$provided_password"
            return 0
        elif openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" 2>/dev/null; then
            log_success "Provided certificate password is valid (modern mode)"
            echo "$provided_password"
            return 0
        else
            log_warn "Provided certificate password failed validation: '$provided_password'"
            log_info "Testing if certificate might be corrupted or have different format..."
            # Try to get more info about the certificate
            openssl pkcs12 -in "$cert_file" -noout -passin "pass:$provided_password" 2>&1 | head -3 | while read line; do
                log_info "OpenSSL output: $line"
            done
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

# Function to extract certificate information
extract_certificate_info() {
    local cert_file="$1"
    local cert_type="$2"  # "p12" or "installed"
    local keychain_name="ios-build.keychain"
    
    log_info "Extracting certificate information from $cert_type certificate..."
    
    # Wait a moment for keychain to update
    sleep 2
    
    # Extract certificate details using security command
    local cert_identity
    local attempts=0
    local max_attempts=5
    
    while [ $attempts -lt $max_attempts ]; do
        # Check both dedicated keychain and all keychains
        cert_identity=$(security find-identity -v -p codesigning "$keychain_name" 2>/dev/null | grep -E "iPhone Distribution|iOS Distribution|Apple Distribution" | head -1)
        
        if [ -z "$cert_identity" ]; then
            # Fallback to checking all keychains
            cert_identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "iPhone Distribution|iOS Distribution|Apple Distribution" | head -1)
        fi
        
        if [ -n "$cert_identity" ]; then
            break
        fi
        
        attempts=$((attempts + 1))
        log_info "Waiting for certificate to appear in keychain (attempt $attempts/$max_attempts)..."
        sleep 2
    done
    
    if [ -n "$cert_identity" ]; then
        local cert_hash=$(echo "$cert_identity" | awk '{print $2}')
        local cert_name=$(echo "$cert_identity" | sed 's/.*") //' | sed 's/"$//')
        
        log_success "Certificate found in keychain:"
        log_info "  Identity: $cert_name"
        log_info "  SHA-1: $cert_hash"
        
        # Get more certificate details
        local cert_details
        cert_details=$(security find-certificate -c "$cert_name" -p "$keychain_name" 2>/dev/null | openssl x509 -text -noout 2>/dev/null)
        
        if [ -z "$cert_details" ]; then
            # Fallback to default keychain
            cert_details=$(security find-certificate -c "$cert_name" -p 2>/dev/null | openssl x509 -text -noout 2>/dev/null)
        fi
        
        if [ -n "$cert_details" ]; then
            local subject=$(echo "$cert_details" | grep "Subject:" | sed 's/.*Subject: //')
            local issuer=$(echo "$cert_details" | grep "Issuer:" | sed 's/.*Issuer: //')
            local validity=$(echo "$cert_details" | grep -A1 "Validity" | tail -1 | sed 's/.*Not After : //')
            
            log_info "  Subject: ${subject:-<unknown>}"
            log_info "  Issuer: ${issuer:-<unknown>}"
            log_info "  Valid Until: ${validity:-<unknown>}"
        fi
        
        # Export certificate details to environment
        export CERT_IDENTITY="$cert_name"
        export CERT_HASH="$cert_hash"
        
        # Validate certificate type
        if echo "$cert_name" | grep -qE "iPhone Distribution|iOS Distribution|Apple Distribution"; then
            log_success "Valid iOS distribution certificate found"
            return 0
        else
            log_error "Certificate is not a valid iOS distribution certificate"
            log_error "Found: $cert_name"
            log_info "Expected certificate types:"
            log_info "  - iPhone Distribution"
            log_info "  - iOS Distribution" 
            log_info "  - Apple Distribution"
            return 1
        fi
    else
        log_error "No valid iOS distribution certificate found in keychain after $max_attempts attempts"
        log_info "Available certificates in dedicated keychain:"
        security find-identity -v -p codesigning "$keychain_name" 2>/dev/null | while read line; do
            log_info "  $line"
        done
        log_info "Available certificates in all keychains:"
        security find-identity -v -p codesigning 2>/dev/null | while read line; do
            log_info "  $line"
        done
        return 1
    fi
}

# Function to display supported profile types
display_supported_profile_types() {
    log_info "Supported iOS Profile Types:"
    log_info "  📱 app-store: For App Store distribution"
    log_info "     - No device restrictions"
    log_info "     - For production releases"
    log_info "     - Requires App Store Connect"
    log_info ""
    log_info "  🔧 development: For development and testing"
    log_info "     - Limited to registered devices"
    log_info "     - Allows debugging"
    log_info "     - For internal testing"
    log_info ""
    log_info "  📋 ad-hoc: For ad-hoc distribution"
    log_info "     - Limited to specific registered devices"
    log_info "     - For beta testing"
    log_info "     - No App Store required"
    log_info ""
    log_info "  🏢 enterprise: For enterprise distribution"
    log_info "     - No device restrictions"
    log_info "     - For internal company distribution"
    log_info "     - Requires Apple Developer Enterprise Program"
}

# Function to validate provisioning profile
validate_provisioning_profile() {
    local profile_file="$1"
    local expected_profile_type="${PROFILE_TYPE:-app-store}"
    
    log_info "Validating provisioning profile..."
    log_info "Expected profile type: $expected_profile_type"
    
    # Extract provisioning profile information
    local profile_plist
    profile_plist=$(security cms -D -i "$profile_file" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$profile_plist" ]; then
        log_error "Failed to decode provisioning profile"
        return 1
    fi
    
    # Extract profile details
    local profile_name profile_uuid profile_type bundle_id team_id expiry_date
    
    profile_name=$(echo "$profile_plist" | plutil -extract Name xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
    profile_uuid=$(echo "$profile_plist" | plutil -extract UUID xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
    bundle_id=$(echo "$profile_plist" | plutil -extract Entitlements.application-identifier xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
    team_id=$(echo "$profile_plist" | plutil -extract TeamIdentifier.0 xml1 -o - - 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | head -1)
    expiry_date=$(echo "$profile_plist" | plutil -extract ExpirationDate xml1 -o - - 2>/dev/null | sed -n 's/.*<date>\(.*\)<\/date>.*/\1/p' | head -1)
    
    # Determine profile type based on content
    local detected_type="unknown"
    if echo "$profile_plist" | grep -q "get-task-allow.*true"; then
        detected_type="development"
    elif echo "$profile_plist" | grep -q "ProvisionedDevices"; then
        detected_type="ad-hoc"
    elif echo "$profile_plist" | grep -q "ProvisionsAllDevices.*true"; then
        detected_type="enterprise"
    else
        detected_type="app-store"
    fi
    
    log_info "Provisioning Profile Details:"
    log_info "  Name: ${profile_name:-<unknown>}"
    log_info "  UUID: ${profile_uuid:-<unknown>}"
    log_info "  Bundle ID: ${bundle_id:-<unknown>}"
    log_info "  Team ID: ${team_id:-<unknown>}"
    log_info "  Detected Type: $detected_type"
    log_info "  Expiry Date: ${expiry_date:-<unknown>}"
    
    # Validate profile type matches expected
    if [ "$detected_type" != "$expected_profile_type" ]; then
        log_error "Profile type mismatch!"
        log_error "  Expected: $expected_profile_type"
        log_error "  Detected: $detected_type"
        log_info "Supported profile types:"
        display_supported_profile_types
        return 1
    fi
    
    # Validate bundle ID matches project
    local expected_bundle_id="${BUNDLE_ID:-}"
    if [ -n "$expected_bundle_id" ] && [ -n "$bundle_id" ]; then
        # Extract app ID from bundle identifier (remove team prefix)
        local app_id=$(echo "$bundle_id" | sed "s/^${team_id}\.//" 2>/dev/null)
        if [ "$app_id" != "$expected_bundle_id" ]; then
            log_warn "Bundle ID mismatch:"
            log_warn "  Expected: $expected_bundle_id"
            log_warn "  Profile: $app_id"
            log_warn "This may cause code signing issues"
        else
            log_success "Bundle ID matches: $expected_bundle_id"
        fi
    fi
    
    # Check expiry date
    if [ -n "$expiry_date" ]; then
        local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
        if [ "$expiry_date" \< "$current_date" ]; then
            log_error "Provisioning profile has expired!"
            log_error "  Expiry: $expiry_date"
            log_error "  Current: $current_date"
            return 1
        else
            log_success "Provisioning profile is valid until: $expiry_date"
        fi
    fi
    
    # Export profile details to environment
    export PROFILE_NAME="$profile_name"
    export PROFILE_UUID="$profile_uuid"
    export PROFILE_TYPE_DETECTED="$detected_type"
    export PROFILE_BUNDLE_ID="$bundle_id"
    export PROFILE_TEAM_ID="$team_id"
    export PROFILE_EXPIRY="$expiry_date"
    
    log_success "Provisioning profile validation successful!"
    log_success "Profile type '$detected_type' matches expected '$expected_profile_type'"
    
    return 0
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

    # First, check if we already have valid certificates
    log_info "--- Checking for Existing Certificates ---"
    if check_existing_certificates; then
        log_success "Valid iOS distribution certificate already exists in keychain!"
        cert_installed=true
    else
        log_info "No valid certificates found, proceeding with installation..."
    fi

    # Try P12 certificate first if URL is provided and no cert installed yet
    if [ "$cert_installed" = false ] && [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" == http* ]]; then
        log_info "P12 certificate URL provided, attempting installation..."
        log_info "P12 URL: ${CERT_P12_URL}"
        log_info "CERT_PASSWORD: ${CERT_PASSWORD:+<provided>}${CERT_PASSWORD:-<not provided>}"
        
        if install_p12_certificate "$CERT_P12_URL"; then
            cert_installed=true
            log_success "P12 certificate installation successful!"
        else
            log_warn "P12 certificate installation failed, will try CER+KEY method..."
            
            # Check if certificate was actually installed despite error
            log_info "Checking if certificate was installed despite error..."
            if check_existing_certificates; then
                log_success "Certificate found in keychain after P12 installation!"
                cert_installed=true
            fi
        fi
    else
        if [ "$cert_installed" = false ]; then
            log_info "No P12 certificate URL provided, skipping P12 method"
        fi
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
            
            # Check if certificate was actually installed despite error
            log_info "Checking if certificate was installed despite error..."
            if check_existing_certificates; then
                log_success "Certificate found in keychain after CER+KEY installation!"
                cert_installed=true
            fi
        fi
    else
        if [ "$cert_installed" = false ]; then
            log_info "No CER+KEY certificate URLs provided, skipping CER+KEY method"
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
    
    # Extract certificate information after successful installation
    log_info "--- Certificate Information Extraction ---"
    if ! extract_certificate_info "ios/certificates/certificate.p12" "installed"; then
        log_error "Failed to extract certificate information"
        exit 1
    fi

    # Handle provisioning profiles
    profile_installed=false
    if [[ -n "${PROVISIONING_PROFILE_URL:-}" ]] && [[ "${PROVISIONING_PROFILE_URL}" == http* ]]; then
        log_info "--- Provisioning Profile Installation ---"
        log_info "Provisioning profile URL provided, installing..."
        if install_provisioning_profile "$PROVISIONING_PROFILE_URL"; then
            profile_installed=true
            
            # Validate provisioning profile after installation
            log_info "--- Provisioning Profile Validation ---"
            if validate_provisioning_profile "ios/certificates/profile.mobileprovision"; then
                log_success "Provisioning profile validation completed successfully!"
            else
                log_error "Provisioning profile validation failed"
                exit 1
            fi
        else
            log_warn "Provisioning profile installation failed"
        fi
    fi

    if [ "$profile_installed" = false ]; then
        log_warn "No provisioning profile installed - this may cause code signing issues"
        log_info "To install provisioning profile, set: PROVISIONING_PROFILE_URL"
        log_warn "Continuing without provisioning profile validation..."
    fi

    # Summary of extracted information
    log_info "--- Code Signing Summary ---"
    log_info "Certificate Information:"
    log_info "  Identity: ${CERT_IDENTITY:-<not extracted>}"
    log_info "  SHA-1: ${CERT_HASH:-<not extracted>}"

    if [ "$profile_installed" = true ]; then
        log_info "Provisioning Profile Information:"
        log_info "  Name: ${PROFILE_NAME:-<not extracted>}"
        log_info "  UUID: ${PROFILE_UUID:-<not extracted>}"
        log_info "  Type: ${PROFILE_TYPE_DETECTED:-<not extracted>}"
        log_info "  Bundle ID: ${PROFILE_BUNDLE_ID:-<not extracted>}"
        log_info "  Team ID: ${PROFILE_TEAM_ID:-<not extracted>}"
        log_info "  Expiry: ${PROFILE_EXPIRY:-<not extracted>}"
    fi

    log_success "Certificate and Profile Setup completed successfully!"
    return 0
}

# Run main function
main "$@"
