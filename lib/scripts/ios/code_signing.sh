#!/bin/bash

# 🔐 Enhanced Code Signing Configuration for iOS
# Ensures code signing is properly enabled for all profile types

set -euo pipefail

# Source common functions
source "$(dirname "$0")/../utils/safe_run.sh"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔐 $1"
}

# Function to configure Xcode project for code signing
configure_xcode_code_signing() {
    log "🔧 Configuring Xcode project for code signing..."
    
    local project_file="ios/Runner.xcodeproj/project.pbxproj"
    local profile_type="${PROFILE_TYPE:-app-store}"
    
    # Backup original project file
    cp "$project_file" "${project_file}.backup"
    log "✅ Project file backed up"
    
    # Determine code signing identity based on profile type
    local code_sign_identity="iOS Distribution Certificate"
    local code_sign_style="Manual"
    
    case "$profile_type" in
        "app-store")
            code_sign_identity="iOS Distribution Certificate"
            code_sign_style="Manual"
            ;;
        "ad-hoc")
            code_sign_identity="iOS Distribution Certificate"
            code_sign_style="Manual"
            ;;
        "enterprise")
            code_sign_identity="iOS Distribution Certificate"
            code_sign_style="Manual"
            ;;
        "development")
            code_sign_identity="iPhone Developer"
            code_sign_style="Automatic"
            ;;
        *)
            log "⚠️ Unknown profile type: $profile_type, using app-store defaults"
            code_sign_identity="iOS Distribution Certificate"
            code_sign_style="Manual"
            ;;
    esac
    
    log "📋 Profile Type: $profile_type"
    log "🔑 Code Sign Identity: $code_sign_identity"
    log "🎯 Code Sign Style: $code_sign_style"
    
    # Update project.pbxproj with proper code signing settings
    # This ensures all build configurations have the correct code signing settings
    
    # Update Release configuration
    sed -i.bak \
        -e 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = '"$code_sign_style"';/g' \
        -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "'"$code_sign_identity"'";/g' \
        -e 's/DEVELOPMENT_TEAM = "";/DEVELOPMENT_TEAM = "'"$APPLE_TEAM_ID"'";/g' \
        -e 's/PROVISIONING_PROFILE_SPECIFIER = "";/PROVISIONING_PROFILE_SPECIFIER = "'"$(basename ios/certificates/profile.mobileprovision .mobileprovision)"'";/g' \
        "$project_file"
    
    # Update Debug configuration (for development builds)
    if [ "$profile_type" = "development" ]; then
        sed -i.bak \
            -e 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Automatic;/g' \
            -e 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";/g' \
            -e 's/DEVELOPMENT_TEAM = "";/DEVELOPMENT_TEAM = "'"$APPLE_TEAM_ID"'";/g' \
            "$project_file"
    fi
    
    # Verify changes
    if grep -q "CODE_SIGN_STYLE = $code_sign_style" "$project_file"; then
        log "✅ Code signing style updated successfully"
    else
        log "❌ Failed to update code signing style"
        return 1
    fi
    
    if grep -q "CODE_SIGN_IDENTITY.*$code_sign_identity" "$project_file"; then
        log "✅ Code signing identity updated successfully"
    else
        log "❌ Failed to update code signing identity"
        return 1
    fi
    
    log "✅ Xcode project code signing configuration completed"
}

# Function to set up keychain and certificates
setup_keychain_and_certificates() {
    log "🔑 Setting up keychain and certificates..."
    
    # Create and configure keychain
    log "🔐 Creating build keychain..."
    
    # Remove existing keychain if it exists (more robust approach)
    log "🗑️ Checking for existing build keychain..."
    if security list-keychains | grep -q "build.keychain"; then
        log "🗑️ Removing existing build keychain..."
        # Try to delete the keychain
        security delete-keychain build.keychain 2>/dev/null || true
        # Wait a moment for the deletion to complete
        sleep 2
        
        # Check if it was actually deleted
        if security list-keychains | grep -q "build.keychain"; then
            log "⚠️ Keychain still exists, trying force removal..."
            # Try to remove from keychain search list first
            security list-keychains | grep -v "build.keychain" | tr '\n' ' ' | xargs security list-keychains -s 2>/dev/null || true
            sleep 1
            # Try deletion again
            security delete-keychain build.keychain 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # Also try to remove from keychain search list
    security list-keychains | grep -v "build.keychain" | tr '\n' ' ' | xargs security list-keychains -s 2>/dev/null || true
    
    # Create new keychain with error handling
    log "🔐 Creating new build keychain..."
    if security create-keychain -p "" build.keychain; then
        log "✅ Build keychain created successfully"
    else
        log "❌ Failed to create build keychain"
        log "🔍 Debug: Checking if keychain already exists..."
        if security list-keychains | grep -q "build.keychain"; then
            log "✅ Keychain already exists, proceeding with existing keychain"
        else
            return 1
        fi
    fi
    
    # Configure the keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "" build.keychain
    security set-keychain-settings -t 3600 -u build.keychain
    
    # Set keychain search list
    security list-keychains -s build.keychain
    security show-keychain-info build.keychain
    
    # Import certificate - handle both P12 and CER/KEY scenarios
    log "📜 Importing certificate..."
    
    # Check if P12 file exists
    if [ -f "ios/certificates/cert.p12" ]; then
        log "🔍 Certificate file found: ios/certificates/cert.p12"
        log "🔍 Certificate file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
        
        # Use the robust import approach from old Codemagic file
        log "🔍 Attempting certificate import with multiple methods..."
        
        # Method 1: Try importing with password and all tools (from old file)
        if [ -n "$CERT_PASSWORD" ]; then
            log "🔍 Method 1: Importing with password and all tools..."
            if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                log "✅ Certificate imported successfully (Method 1)"
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
                # Add a small delay to ensure keychain is properly set up
                sleep 1
                return 0
            fi
        fi
        
        # Method 2: Try importing without password first (from old file)
        log "🔍 Method 2: Importing without password..."
        if security import ios/certificates/cert.p12 -k build.keychain -A; then
            log "✅ Certificate imported successfully (Method 2 - no password)"
            security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
            # Add a small delay to ensure keychain is properly set up
            sleep 1
            return 0
        fi
        
        # Method 3: Try importing with password but without -A flag (from old file)
        if [ -n "$CERT_PASSWORD" ]; then
            log "🔍 Method 3: Importing with password but without -A flag..."
            if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD"; then
                log "✅ Certificate imported successfully (Method 3)"
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
                # Add a small delay to ensure keychain is properly set up
                sleep 1
                return 0
            fi
        fi
        
        # Method 4: Try importing with specific tool access only (from old file)
        if [ -n "$CERT_PASSWORD" ]; then
            log "🔍 Method 4: Importing with specific tool access..."
            if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign; then
                log "✅ Certificate imported successfully (Method 4)"
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
                # Add a small delay to ensure keychain is properly set up
                sleep 1
                return 0
            fi
        fi
        
        # Method 5: Try importing certificate and key separately (from old file approach)
        log "🔍 Method 5: Attempting separate certificate and key import..."
        local temp_dir="ios/certificates/temp"
        mkdir -p "$temp_dir"
        
        # Extract certificate and key from P12
        if [ -n "$CERT_PASSWORD" ]; then
            if openssl pkcs12 -in ios/certificates/cert.p12 -clcerts -nokeys -out "$temp_dir/cert.pem" -passin "pass:$CERT_PASSWORD" -passout "pass:" -legacy && \
               openssl pkcs12 -in ios/certificates/cert.p12 -nocerts -out "$temp_dir/key.pem" -passin "pass:$CERT_PASSWORD" -passout "pass:" -legacy; then
                
                # Import certificate
                if security import "$temp_dir/cert.pem" -k build.keychain -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                    log "✅ Certificate imported separately"
                    
                    # Try importing key
                    if security import "$temp_dir/key.pem" -k build.keychain -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                        log "✅ Private key imported separately"
                        security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain
                        rm -rf "$temp_dir"
                        return 0
                    else
                        log "⚠️ Certificate imported but key import failed"
                        security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain
                        rm -rf "$temp_dir"
                        return 0  # Return success since certificate was imported
                    fi
                fi
            fi
        fi
        
        rm -rf "$temp_dir"
        
        # If we get here, all methods failed
        log "❌ All certificate import methods failed"
        log "🔍 Debug info:"
        log "   Password provided: $([ -n "$CERT_PASSWORD" ] && echo 'yes' || echo 'no')"
        log "   Password length: ${#CERT_PASSWORD}"
        log "   Keychain status: $(security list-keychains | grep build.keychain || echo 'not found')"
        log "   P12 file type: $(file ios/certificates/cert.p12)"
        return 1
    else
        log "❌ Certificate file not found: ios/certificates/cert.p12"
        log "🔍 Checking for CER/KEY files to generate P12..."
        
        # Check if we have CER and KEY files to generate P12
        if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ]; then
            log "🔐 CERT_P12_URL not provided, generating P12 from CER/KEY files..."
            
            # Check if this is auto-ios-workflow with auto-generated certificates
            if [[ "${WORKFLOW_ID:-}" == "auto-ios-workflow" ]] && [[ "${CERT_CER_URL}" == "auto-generated" ]]; then
                log "🔐 Auto-ios-workflow detected with auto-generated certificates"
                log "📋 Skipping manual certificate download - using fastlane-generated certificates"
                log "✅ Certificate setup handled by auto-ios-workflow"
                return 0
            fi
            
            # Download CER and KEY files
            log "🔐 Downloading Certificate and Key..."
            log "🔍 CER URL: ${CERT_CER_URL}"
            log "🔍 KEY URL: ${CERT_KEY_URL}"
            log "🔍 Using CERT_PASSWORD for P12 generation"
            
            # Ensure certificates directory exists
            mkdir -p ios/certificates
            
            if curl -L --fail --silent --show-error --output "ios/certificates/cert.cer" "${CERT_CER_URL}"; then
                log "✅ Certificate downloaded successfully"
            else
                log "❌ Failed to download certificate"
                return 1
            fi
            
            if curl -L --fail --silent --show-error --output "ios/certificates/cert.key" "${CERT_KEY_URL}"; then
                log "✅ Private key downloaded successfully"
            else
                log "❌ Failed to download private key"
                return 1
            fi
            
            # Verify downloaded files
            log "🔍 Verifying downloaded certificate files..."
            if [ -s "ios/certificates/cert.cer" ] && [ -s "ios/certificates/cert.key" ]; then
                log "✅ Certificate files are not empty"
            else
                log "❌ Certificate files are empty"
                return 1
            fi
            
            # Convert CER to PEM
            log "🔄 Converting certificate to PEM format..."
            if openssl x509 -in ios/certificates/cert.cer -inform DER -out ios/certificates/cert.pem -outform PEM; then
                log "✅ Certificate converted to PEM"
            else
                log "❌ Failed to convert certificate to PEM"
                return 1
            fi
            
            # Generate P12 with compatible password handling
            # Verify PEM and KEY files before P12 generation
            log "🔍 Verifying PEM and KEY files before P12 generation..."
            if [ ! -f "ios/certificates/cert.pem" ] || [ ! -f "ios/certificates/cert.key" ]; then
                log "❌ PEM or KEY file missing"
                log "   PEM exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
                log "   KEY exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
                return 1
            fi
            
            # Check PEM file content
            if openssl x509 -in ios/certificates/cert.pem -text -noout >/dev/null 2>&1; then
                log "✅ PEM file is valid certificate"
            else
                log "❌ PEM file is not a valid certificate"
                return 1
            fi
            
            # Check KEY file content
            if openssl rsa -in ios/certificates/cert.key -check -noout >/dev/null 2>&1; then
                log "✅ KEY file is valid private key"
            else
                log "❌ KEY file is not a valid private key"
                return 1
            fi
            
            log "🔍 Attempting P12 generation with CERT_PASSWORD..."
            if openssl pkcs12 -export \
                -inkey ios/certificates/cert.key \
                -in ios/certificates/cert.pem \
                -out ios/certificates/cert.p12 \
                -password "pass:${CERT_PASSWORD}" \
                -name "iOS Distribution Certificate" \
                -legacy; then
                log "✅ P12 certificate generated successfully (with password)"
                
                # Verify the generated P12 with password
                log "🔍 Verifying generated P12 file with password..."
                if openssl pkcs12 -in ios/certificates/cert.p12 -noout -passin "pass:${CERT_PASSWORD}" -legacy 2>/dev/null; then
                    log "✅ Generated P12 verification successful (with password)"
                    log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                else
                    log "⚠️ P12 verification with password failed, trying without password..."
                    
                    # Try generating without password as fallback
                    if openssl pkcs12 -export \
                        -inkey ios/certificates/cert.key \
                        -in ios/certificates/cert.pem \
                        -out ios/certificates/cert.p12 \
                        -password "pass:" \
                        -name "iOS Distribution Certificate" \
                        -legacy; then
                        log "✅ P12 certificate generated successfully (no password)"
                        
                        # Verify the generated P12 without password
                        log "🔍 Verifying generated P12 file without password..."
                        if openssl pkcs12 -in ios/certificates/cert.p12 -noout -legacy 2>/dev/null; then
                            log "✅ Generated P12 verification successful (no password)"
                            log "🔍 P12 file size: $(ls -lh ios/certificates/cert.p12 | awk '{print $5}')"
                        else
                            log "❌ Generated P12 verification failed (no password)"
                            log "🔍 Attempting to debug P12 file..."
                            file ios/certificates/cert.p12
                            log "🔍 P12 file content (first 100 chars):"
                            head -c 100 ios/certificates/cert.p12 | xxd
                            return 1
                        fi
                    else
                        log "❌ Failed to generate P12 certificate (both with and without password)"
                        return 1
                    fi
                fi
                
                # Now import the generated P12 file
                log "📜 Importing generated P12 certificate..."
                if [ -n "$CERT_PASSWORD" ]; then
                    if security import ios/certificates/cert.p12 -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                        log "✅ Generated P12 certificate imported successfully"
                        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
                        sleep 1
                        return 0
                    fi
                else
                    if security import ios/certificates/cert.p12 -k build.keychain -A; then
                        log "✅ Generated P12 certificate imported successfully (no password)"
                        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
                        sleep 1
                        return 0
                    fi
                fi
                
                log "❌ Failed to import generated P12 certificate"
                return 1
            else
                log "❌ Failed to generate P12 certificate with password"
                log "🔍 Debug info:"
                log "   CERT_PASSWORD length: ${#CERT_PASSWORD}"
                log "   CERT_PASSWORD starts with: ${CERT_PASSWORD:0:3}***"
                log "   PEM file exists: $([ -f ios/certificates/cert.pem ] && echo 'yes' || echo 'no')"
                log "   KEY file exists: $([ -f ios/certificates/cert.key ] && echo 'yes' || echo 'no')"
                return 1
            fi
        else
            log "❌ No certificate URLs provided (CERT_CER_URL and CERT_KEY_URL required when CERT_P12_URL is not provided)"
            log "🔍 Available files in certificates directory:"
            ls -la ios/certificates/ 2>/dev/null || log "   Directory not accessible"
            return 1
        fi
    fi
    
    log "✅ Keychain and certificate setup completed"
}

# Function to install provisioning profile
install_provisioning_profile() {
    log "📱 Installing provisioning profile..."
    
    local profile_path="ios/certificates/profile.mobileprovision"
    local profile_type="${PROFILE_TYPE:-app-store}"
    
    # Check if profile exists, if not download it from PROFILE_URL
    if [ ! -f "$profile_path" ]; then
        log "📥 Provisioning profile not found locally, downloading from PROFILE_URL..."
        
        # Check if this is auto-ios-workflow with auto-generated profile
        if [[ "${WORKFLOW_ID:-}" == "auto-ios-workflow" ]] && [[ "${PROFILE_URL:-}" == "auto-generated" ]]; then
            log "🔐 Auto-ios-workflow detected with auto-generated profile"
            log "📋 Skipping manual profile download - using fastlane-generated profile"
            log "✅ Profile setup handled by auto-ios-workflow"
            return 0
        fi
        
        # Check if PROFILE_URL is provided
        if [ -z "${PROFILE_URL:-}" ]; then
            log "❌ PROFILE_URL is not provided"
            log "🔍 Available environment variables:"
            env | grep -i profile || log "   No profile-related variables found"
            return 1
        fi
        
        # Ensure certificates directory exists
        mkdir -p ios/certificates
        
        # Download provisioning profile
        log "📥 Downloading provisioning profile from: ${PROFILE_URL}"
        if curl -L --fail --silent --show-error --output "$profile_path" "${PROFILE_URL}"; then
            log "✅ Provisioning profile downloaded successfully"
            log "🔍 Profile file size: $(ls -lh "$profile_path" | awk '{print $5}')"
        else
            log "❌ Failed to download provisioning profile"
            return 1
        fi
        
        # Verify downloaded profile
        if [ ! -s "$profile_path" ]; then
            log "❌ Downloaded provisioning profile is empty"
            return 1
        fi
        
        log "✅ Provisioning profile downloaded and verified"
    else
        log "✅ Provisioning profile found locally: $profile_path"
    fi
    
    # Get profile UUID
    local profile_uuid=$(security cms -D -i "$profile_path" | plutil -extract UUID raw -)
    if [ -z "$profile_uuid" ]; then
        log "❌ Failed to extract profile UUID"
        log "🔍 Attempting to debug profile file..."
        file "$profile_path"
        log "🔍 Profile file content (first 100 chars):"
        head -c 100 "$profile_path" | xxd
        return 1
    fi
    
    log "📋 Profile UUID: $profile_uuid"
    
    # Install profile
    local profile_dest="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"
    mkdir -p "$(dirname "$profile_dest")"
    cp "$profile_path" "$profile_dest"
    
    if [ -f "$profile_dest" ]; then
        log "✅ Provisioning profile installed: $profile_dest"
    else
        log "❌ Failed to install provisioning profile"
        return 1
    fi
    
    # Verify profile installation
    if security cms -D -i "$profile_dest" >/dev/null 2>&1; then
        log "✅ Provisioning profile verification successful"
    else
        log "❌ Provisioning profile verification failed"
        return 1
    fi
    
    log "✅ Provisioning profile installation completed"
}

# Function to generate enhanced ExportOptions.plist
generate_export_options() {
    log "📦 Generating enhanced ExportOptions.plist..."
    
    local profile_type="${PROFILE_TYPE:-app-store}"
    local method="$profile_type"
    
    # Determine export options based on profile type
    local upload_symbols="true"
    local upload_bitcode="false"
    local compile_bitcode="false"
    local thinning="none"
    local destination="export"
    
    case "$profile_type" in
        "app-store")
            upload_symbols="true"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="none"
            destination="upload"
            ;;
        "ad-hoc")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="none"
            destination="export"
            ;;
        "enterprise")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="none"
            destination="export"
            ;;
        "development")
            upload_symbols="false"
            upload_bitcode="false"
            compile_bitcode="false"
            thinning="none"
            destination="export"
            ;;
    esac
    
    # Get profile UUID for provisioning profiles section
    local profile_uuid=""
    if [ -f "ios/certificates/profile.mobileprovision" ]; then
        profile_uuid=$(security cms -D -i "ios/certificates/profile.mobileprovision" | plutil -extract UUID raw -)
    fi
    
    # Create enhanced ExportOptions.plist
    cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>iOS Distribution Certificate</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$(basename ios/certificates/profile.mobileprovision .mobileprovision)</string>
    </dict>
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>thinning</key>
    <string>$thinning</string>
    <key>destination</key>
    <string>$destination</string>
EOF
    
    # Add TestFlight specific options
    if [ "${IS_TESTFLIGHT:-false}" = "true" ] && [ "$method" = "app-store" ]; then
        cat >> ios/ExportOptions.plist << EOF
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
EOF
    fi
    
    # Add Ad-Hoc specific options
    if [ "$method" = "ad-hoc" ]; then
        cat >> ios/ExportOptions.plist << EOF
    <key>manifest</key>
    <dict>
        <key>appURL</key>
        <string>${INSTALL_URL:-}</string>
        <key>displayImageURL</key>
        <string>${DISPLAY_IMAGE_URL:-}</string>
        <key>fullSizeImageURL</key>
        <string>${FULL_SIZE_IMAGE_URL:-}</string>
    </dict>
EOF
    fi
    
    cat >> ios/ExportOptions.plist << EOF
</dict>
</plist>
EOF
    
    log "✅ ExportOptions.plist generated for $profile_type"
    log "📋 Export method: $method"
    log "📦 Destination: $destination"
    log "🔧 Thinning: $thinning"
}

# Function to verify code signing setup
verify_code_signing_setup() {
    log "🔍 Verifying code signing setup..."
    
    local profile_type="${PROFILE_TYPE:-app-store}"
    local verification_passed=true
    
    # Check keychain
    if ! security list-keychains | grep -q "build.keychain"; then
        log "❌ Build keychain not found"
        verification_passed=false
    else
        log "✅ Build keychain found"
    fi
    
    # Check certificate with better debugging
    log "🔍 Checking for code signing certificates..."
    local identities_output=$(security find-identity -v -p codesigning build.keychain 2>/dev/null)
    log "🔍 Available code signing identities:"
    echo "$identities_output"
    
    if echo "$identities_output" | grep -q "iPhone Distribution\|iPhone Developer\|iOS Distribution Certificate\|Apple Distribution"; then
        log "✅ Code signing certificate found"
    else
        log "❌ Code signing certificate not found"
        log "🔍 Debug: Checking all identities in keychain..."
        log "🔍 All identities (including non-codesigning):"
        security find-identity -v build.keychain
        verification_passed=false
    fi
    
    # Check provisioning profile
    if [ ! -f "ios/certificates/profile.mobileprovision" ]; then
        log "❌ Provisioning profile not found"
        verification_passed=false
    else
        log "✅ Provisioning profile found"
    fi
    
    # Check ExportOptions.plist
    if [ ! -f "ios/ExportOptions.plist" ]; then
        log "❌ ExportOptions.plist not found"
        verification_passed=false
    else
        log "✅ ExportOptions.plist found"
    fi
    
    # Check Xcode project configuration
    if ! grep -q "CODE_SIGN_STYLE" ios/Runner.xcodeproj/project.pbxproj; then
        log "❌ Code signing not configured in Xcode project"
        verification_passed=false
    else
        log "✅ Code signing configured in Xcode project"
    fi
    
    if [ "$verification_passed" = true ]; then
        log "✅ Code signing setup verification passed"
        return 0
    else
        log "❌ Code signing setup verification failed"
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting enhanced code signing configuration..."
    
    # Validate required environment variables
    if [ -z "${CERT_PASSWORD:-}" ]; then
        log "❌ CERT_PASSWORD is required"
        exit 1
    fi
    
    if [ -z "${APPLE_TEAM_ID:-}" ]; then
        log "❌ APPLE_TEAM_ID is required"
        exit 1
    fi
    
    if [ -z "${BUNDLE_ID:-}" ]; then
        log "❌ BUNDLE_ID is required"
        exit 1
    fi
    
    if [ -z "${PROFILE_TYPE:-}" ]; then
        log "⚠️ PROFILE_TYPE not set, defaulting to app-store"
        export PROFILE_TYPE="app-store"
    fi
    
    log "📋 Code Signing Configuration:"
    log "   Profile Type: ${PROFILE_TYPE}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   Bundle ID: ${BUNDLE_ID}"
    
    # Execute code signing setup steps
    configure_xcode_code_signing
    setup_keychain_and_certificates
    install_provisioning_profile
    generate_export_options
    
    # Add a small delay to ensure everything is properly set up
    log "⏳ Waiting for keychain setup to complete..."
    sleep 2
    
    verify_code_signing_setup
    
    log "✅ Enhanced code signing configuration completed successfully!"
}

# Run main function
main "$@" 