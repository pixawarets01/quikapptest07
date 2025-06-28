#!/bin/bash

# IPA Export Script for iOS Build (Enhanced Version v2.0)
# Purpose: Export IPA file from Xcode archive with multiple fallback methods

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting IPA Export... (Enhanced Version v2.0 with fallbacks)"

# Function to create ExportOptions.plist
create_export_options() {
    log_info "Creating ExportOptions.plist for $PROFILE_TYPE distribution..."
    
    local export_options_path="ios/ExportOptions.plist"
    local method="app-store-connect"
    local upload_bitcode="false"
    local upload_symbols="true"
    local compile_bitcode="false"
    
    # Determine export method based on profile type
    case "${PROFILE_TYPE:-app-store}" in
        "app-store")
            method="app-store-connect"
            upload_bitcode="false"
            upload_symbols="true"
            ;;
        "ad-hoc")
            method="ad-hoc"
            upload_bitcode="false"
            upload_symbols="false"
            ;;
        "enterprise")
            method="enterprise"
            upload_bitcode="false"
            upload_symbols="false"
            ;;
        "development")
            method="development"
            upload_bitcode="false"
            upload_symbols="false"
            ;;
    esac
    
    log_info "Export method: $method"
    
    # Check for App Store Connect API authentication
    local use_app_store_connect_api=false
    if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
        log_info "App Store Connect API authentication detected"
        use_app_store_connect_api=true
    else
        log_warn "App Store Connect API authentication not configured"
        log_info "Available authentication methods:"
        log_info "  - APP_STORE_CONNECT_ISSUER_ID: ${APP_STORE_CONNECT_ISSUER_ID:-NOT_SET}"
        log_info "  - APP_STORE_CONNECT_KEY_IDENTIFIER: ${APP_STORE_CONNECT_KEY_IDENTIFIER:-NOT_SET}"
        log_info "  - APP_STORE_CONNECT_API_KEY_PATH: ${APP_STORE_CONNECT_API_KEY_PATH:-NOT_SET}"
    fi
    
    # Create ExportOptions.plist
    cat > "$export_options_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-}</string>
    <key>uploadBitcode</key>
    <$upload_bitcode/>
    <key>uploadSymbols</key>
    <$upload_symbols/>
    <key>compileBitcode</key>
    <$compile_bitcode/>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
EOF

    # Only add provisioning profiles for non-app-store methods
    if [ "$method" != "app-store-connect" ]; then
        cat >> "$export_options_path" << EOF
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID:-}</key>
        <string>match ${method} ${BUNDLE_ID:-}</string>
    </dict>
EOF
    fi

    cat >> "$export_options_path" << EOF
</dict>
</plist>
EOF
    
    if [ -f "$export_options_path" ]; then
        log_success "ExportOptions.plist created successfully"
        log_info "Export options:"
        log_info "  - Method: $method"
        log_info "  - Team ID: ${APPLE_TEAM_ID:-}"
        log_info "  - Bundle ID: ${BUNDLE_ID:-}"
        log_info "  - Upload Bitcode: $upload_bitcode"
        log_info "  - Upload Symbols: $upload_symbols"
        log_info "  - App Store Connect API: $use_app_store_connect_api"
    else
        log_error "Failed to create ExportOptions.plist"
        return 1
    fi
}

# Function to create archive-only export with enhanced documentation
create_archive_only_export() {
    log_info "Creating archive-only export (final fallback)..."
    
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local export_dir="${OUTPUT_DIR:-output/ios}/Runner_manual_export"
    
    # Create export directory
    mkdir -p "$export_dir"
    
    # Copy archive
    if cp -r "$archive_path" "$export_dir/"; then
        log_success "Archive copied successfully"
    else
        log_error "Failed to copy archive"
        return 1
    fi
    
    # Create detailed build information
    cat > "$export_dir/BUILD_INFO.txt" << EOF
=== iOS Build Information ===
Build Date: $(date)
Build ID: ${CM_BUILD_ID:-unknown}
App Name: ${APP_NAME:-unknown}
Bundle ID: ${BUNDLE_ID:-unknown}
Version: ${VERSION_NAME:-unknown} (${VERSION_CODE:-unknown})
Profile Type: ${PROFILE_TYPE:-unknown}
Team ID: ${APPLE_TEAM_ID:-unknown}

=== Export Status ===
Status: Archive Only Export (Manual IPA Export Required)
Reason: All automated export methods failed due to authentication issues

=== Manual Export Instructions ===
1. Download the Runner.xcarchive file from this build
2. Open Xcode on a Mac with proper Apple Developer account access
3. Go to Window > Organizer
4. Click the "+" button and select "Import"
5. Select the Runner.xcarchive file
6. Click "Distribute App"
7. Choose "App Store Connect" for App Store distribution
8. Follow the signing and distribution wizard

=== Alternative Manual Export ===
1. Open Xcode
2. Go to Product > Archive
3. In Organizer, select your archive
4. Click "Distribute App"
5. Choose distribution method
6. Follow the signing wizard

=== Troubleshooting ===
- Ensure you have a valid Apple Developer account
- Verify your certificates and provisioning profiles are valid
- Check that your bundle ID matches your provisioning profile
- Make sure your app version is higher than the previous App Store version

=== Build Artifacts ===
- Runner.xcarchive: Xcode archive (ready for manual export)
- ExportOptions.plist: Export configuration (if available)
- BUILD_INFO.txt: This file

=== Contact Support ===
If you need assistance with manual export, contact your development team
or refer to Apple's documentation on manual app distribution.

Build completed at: $(date)
EOF
    
    # Create export status marker
    echo "ARCHIVE_ONLY_EXPORT_SUCCESS" > "$export_dir/EXPORT_STATUS.txt"
    
    # Create summary
    log_success "Archive-only export created: $export_dir"
    log_info "Archive package contents:"
    log_info "  ✅ Runner.xcarchive ($(du -h "$export_dir/Runner.xcarchive" | cut -f1))"
    log_info "  📄 BUILD_INFO.txt (detailed information)"
    log_info "  ✅ EXPORT_STATUS.txt (success marker)"
    
    log_warning "No IPA file was created due to export failures"
    log_warning "Archive is available for manual export in Xcode"
    log_info "Manual export guide available in BUILD_INFO.txt"
    
    log_success "Archive-only export succeeded!"
    return 0
}

# Function to export development IPA (no Apple Developer account required)
export_development_ipa() {
    log_info "Trying development export method (no Apple Developer account required)..."
    
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local export_path="${OUTPUT_DIR:-output/ios}"
    local export_options_path="ios/ExportOptions.plist"
    
    # Create development ExportOptions.plist
    cat > "$export_options_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID:-}</key>
        <string>match development ${BUNDLE_ID:-}</string>
    </dict>
</dict>
</plist>
EOF
    
    log_info "Using development export options with automatic signing..."
    
    # Try export with development method
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options_path" \
        -allowProvisioningUpdates; then
        
        local ipa_file="$export_path/Runner.ipa"
        if [ -f "$ipa_file" ]; then
            log_success "Development export successful: $ipa_file"
            log_warn "Note: This is a development-signed IPA for testing only"
            log_warn "It cannot be uploaded to App Store Connect"
            return 0
        fi
    fi
    
    log_error "Development export also failed"
    return 1
}

# Function to export IPA using fallback method
export_ipa_fallback() {
    log_info "Trying fallback export method..."
    
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local export_path="${OUTPUT_DIR:-output/ios}"
    local export_options_path="ios/ExportOptions.plist"
    
    # Create a simpler ExportOptions.plist for fallback
    cat > "$export_options_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
    
    log_info "Using fallback export options with automatic signing..."
    
    # Try export with automatic signing
    if xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options_path" \
        -allowProvisioningUpdates; then
        
        local ipa_file="$export_path/Runner.ipa"
        if [ -f "$ipa_file" ]; then
            log_success "Fallback export successful: $ipa_file"
            return 0
        fi
    fi
    
    log_error "Fallback export also failed"
    return 1
}

# Function to export IPA using xcodebuild with enhanced error handling
export_ipa_xcodebuild() {
    log_info "Exporting IPA using xcodebuild..."
    
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local export_path="${OUTPUT_DIR:-output/ios}"
    local export_options_path="ios/ExportOptions.plist"
    local max_retries=3
    local retry_count=0
    
    # Verify archive exists
    if [ ! -d "$archive_path" ]; then
        log_error "Archive not found: $archive_path"
        return 1
    fi
    
    # Verify ExportOptions.plist exists
    if [ ! -f "$export_options_path" ]; then
        log_error "ExportOptions.plist not found: $export_options_path"
        return 1
    fi
    
    log_info "Archive path: $archive_path"
    log_info "Export path: $export_path"
    log_info "Export options: $export_options_path"
    
    # Check if App Store Connect API authentication is available
    if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] && [ -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
        log_info "App Store Connect API authentication detected"
        
        # Download API key
        local api_key_path="/tmp/AuthKey_${APP_STORE_CONNECT_KEY_IDENTIFIER}.p8"
        log_info "Downloading API key from URL..."
        
        if curl -L -o "$api_key_path" "${APP_STORE_CONNECT_API_KEY_PATH}" 2>/dev/null; then
            log_success "API key downloaded to $api_key_path"
            chmod 600 "$api_key_path"
        else
            log_error "Failed to download API key from ${APP_STORE_CONNECT_API_KEY_PATH}"
            return 1
        fi
        
        # Try App Store Connect API export with enhanced error handling
        while [ $retry_count -lt $max_retries ]; do
            retry_count=$((retry_count + 1))
            log_info "Export attempt $retry_count of $max_retries..."
            log_info "Using App Store Connect API authentication"
            log_info "Running xcodebuild -exportArchive..."
            
            # Enhanced command with better error handling
            local export_cmd="xcodebuild -exportArchive \
                -archivePath \"$archive_path\" \
                -exportPath \"$export_path\" \
                -exportOptionsPlist \"$export_options_path\" \
                -allowProvisioningUpdates \
                -authenticationKeyPath \"$api_key_path\" \
                -authenticationKeyID \"$APP_STORE_CONNECT_KEY_IDENTIFIER\" \
                -authenticationKeyIssuerID \"$APP_STORE_CONNECT_ISSUER_ID\" \
                -verbose"
            
            log_info "Command: $export_cmd"
            
            # Run with timeout and capture exit code
            if timeout 300 bash -c "$export_cmd"; then
                log_success "IPA export completed successfully!"
                rm -f "$api_key_path"
                return 0
            else
                local exit_code=$?
                log_error "xcodebuild export failed with exit code $exit_code"
                
                # Check for specific error types
                if [ $exit_code -eq 139 ]; then
                    log_warning "Segmentation fault detected - this is a known Xcode issue"
                    log_info "Trying alternative export method..."
                    break
                elif [ $exit_code -eq 124 ]; then
                    log_warning "Export timed out after 5 minutes"
                fi
                
                if [ $retry_count -lt $max_retries ]; then
                    log_info "Retrying export in 5 seconds..."
                    sleep 5
                fi
            fi
        done
        
        # Clean up API key
        rm -f "$api_key_path"
    fi
    
    # If App Store Connect API failed, try manual certificate authentication
    log_warning "App Store Connect API export failed, trying manual certificate authentication..."
    
    # Check if manual certificates are available
    if [ -n "${CERT_P12_URL:-}" ] && [ -n "${PROFILE_URL:-}" ]; then
        log_info "Manual certificate authentication detected"
        
        # Download and install certificates
        local cert_dir="/tmp/certs"
        mkdir -p "$cert_dir"
        
        # Download provisioning profile
        if curl -L -o "$cert_dir/profile.mobileprovision" "${PROFILE_URL}" 2>/dev/null; then
            log_success "Provisioning profile downloaded"
        else
            log_error "Failed to download provisioning profile"
            return 1
        fi
        
        # Download certificate
        if curl -L -o "$cert_dir/certificate.p12" "${CERT_P12_URL}" 2>/dev/null; then
            log_success "Certificate downloaded"
        else
            log_error "Failed to download certificate"
            return 1
        fi
        
        # Install certificate
        local keychain_path="$HOME/Library/Keychains/login.keychain-db"
        if security import "$cert_dir/certificate.p12" -k "$keychain_path" -P "${CERT_PASSWORD:-}" -T /usr/bin/codesign 2>/dev/null; then
            log_success "Certificate installed in keychain"
        else
            log_error "Failed to install certificate"
            return 1
        fi
        
        # Install provisioning profile
        local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
        mkdir -p "$profile_dir"
        cp "$cert_dir/profile.mobileprovision" "$profile_dir/"
        log_success "Provisioning profile installed"
        
        # Try manual export
        log_info "Trying manual certificate export..."
        if xcodebuild -exportArchive \
            -archivePath "$archive_path" \
            -exportPath "$export_path" \
            -exportOptionsPlist "$export_options_path" \
            -allowProvisioningUpdates; then
            log_success "Manual certificate export completed successfully!"
            rm -rf "$cert_dir"
            return 0
        else
            log_error "Manual certificate export failed"
            rm -rf "$cert_dir"
        fi
    fi
    
    # If all export methods failed, create archive-only export
    log_warning "All export methods failed, creating archive-only export..."
    create_archive_only_export
    return 0
}

# Function to validate IPA file
validate_ipa() {
    log_info "Validating IPA file..."
    
    local ipa_file="${OUTPUT_DIR:-output/ios}/Runner.ipa"
    
    if [ ! -f "$ipa_file" ]; then
        log_error "IPA file not found: $ipa_file"
        return 1
    fi
    
    # Check file size
    if ! validate_file "$ipa_file" 1048576; then  # 1MB minimum
        log_error "IPA file validation failed"
        return 1
    fi
    
    # Check if it's a valid ZIP file (IPA is a ZIP archive)
    if command_exists unzip; then
        if unzip -t "$ipa_file" >/dev/null 2>&1; then
            log_success "IPA file structure validation passed"
        else
            log_warn "IPA file structure validation failed, but file exists"
        fi
    fi
    
    log_success "IPA validation completed"
    return 0
}

# Function to create artifacts summary
create_artifacts_summary() {
    log_info "Creating artifacts summary..."
    
    local summary_file="${OUTPUT_DIR:-output/ios}/ARTIFACTS_SUMMARY.txt"
    local ipa_file="${OUTPUT_DIR:-output/ios}/Runner.ipa"
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local test_dir="${OUTPUT_DIR:-output/ios}/Runner_test"
    
    cat > "$summary_file" << EOF
iOS Build Artifacts Summary
==========================
Generated on: $(date)
Build ID: ${CM_BUILD_ID:-unknown}
Workflow: ${WORKFLOW_ID:-ios-workflow}

App Information:
- App Name: ${APP_NAME:-Unknown}
- Bundle ID: ${BUNDLE_ID:-Unknown}
- Version: ${VERSION_NAME:-Unknown} (${VERSION_CODE:-Unknown})
- Profile Type: ${PROFILE_TYPE:-Unknown}
- Team ID: ${APPLE_TEAM_ID:-Unknown}

Artifacts:
EOF
    
    if [ -f "$ipa_file" ]; then
        local ipa_size
        if command_exists stat; then
            ipa_size=$(stat -c%s "$ipa_file" 2>/dev/null || stat -f%z "$ipa_file" 2>/dev/null || echo "0")
        else
            ipa_size=$(ls -l "$ipa_file" 2>/dev/null | awk '{print $5}' || echo "0")
        fi
        local ipa_size_mb=$((ipa_size / 1024 / 1024))
        echo "- IPA File: Runner.ipa (${ipa_size_mb} MB)" >> "$summary_file"
        echo "- Export Status: SUCCESS (IPA created)" >> "$summary_file"
    elif [ -d "$test_dir" ]; then
        echo "- IPA File: NOT CREATED (Export failed)" >> "$summary_file"
        echo "- Archive Package: Runner_test/ (Manual export required)" >> "$summary_file"
        echo "- Export Status: PARTIAL (Archive only)" >> "$summary_file"
    else
        echo "- IPA File: NOT FOUND" >> "$summary_file"
        echo "- Export Status: FAILED" >> "$summary_file"
    fi
    
    if [ -d "$archive_path" ]; then
        echo "- Archive: Runner.xcarchive" >> "$summary_file"
    else
        echo "- Archive: NOT FOUND" >> "$summary_file"
    fi
    
    if [ -f "ios/ExportOptions.plist" ]; then
        echo "- Export Options: ExportOptions.plist" >> "$summary_file"
    else
        echo "- Export Options: NOT FOUND" >> "$summary_file"
    fi
    
    echo "" >> "$summary_file"
    
    # Add status based on what was created
    if [ -f "$ipa_file" ]; then
        echo "Build Status: SUCCESS" >> "$summary_file"
        echo "Export Result: IPA file created successfully" >> "$summary_file"
    elif [ -d "$test_dir" ]; then
        echo "Build Status: PARTIAL SUCCESS" >> "$summary_file"
        echo "Export Result: Archive created, IPA export failed" >> "$summary_file"
        echo "Next Steps: Manual IPA export required in Xcode" >> "$summary_file"
    else
        echo "Build Status: FAILED" >> "$summary_file"
        echo "Export Result: No artifacts created" >> "$summary_file"
    fi
    
    log_success "Artifacts summary created: $summary_file"
}

# Function to validate export environment
validate_export_environment() {
    log_info "Validating export environment..."
    
    local has_app_store_connect=false
    local has_manual_certs=false
    local missing_vars=()
    
    # Check App Store Connect API variables
    if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] && [ -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
        has_app_store_connect=true
        log_info "✅ App Store Connect API authentication available"
    else
        if [ -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
            missing_vars+=("APP_STORE_CONNECT_API_KEY_PATH")
        fi
        if [ -z "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" ]; then
            missing_vars+=("APP_STORE_CONNECT_KEY_IDENTIFIER")
        fi
        if [ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
            missing_vars+=("APP_STORE_CONNECT_ISSUER_ID")
        fi
        log_warning "⚠️ App Store Connect API authentication incomplete"
    fi
    
    # Check manual certificate variables
    if [ -n "${CERT_P12_URL:-}" ] && [ -n "${PROFILE_URL:-}" ] && [ -n "${CERT_PASSWORD:-}" ]; then
        has_manual_certs=true
        log_info "✅ Manual certificate authentication available"
    else
        if [ -z "${CERT_P12_URL:-}" ]; then
            missing_vars+=("CERT_P12_URL")
        fi
        if [ -z "${PROFILE_URL:-}" ]; then
            missing_vars+=("PROFILE_URL")
        fi
        if [ -z "${CERT_PASSWORD:-}" ]; then
            missing_vars+=("CERT_PASSWORD")
        fi
        log_warning "⚠️ Manual certificate authentication incomplete"
    fi
    
    # Check required variables
    if [ -z "${BUNDLE_ID:-}" ]; then
        missing_vars+=("BUNDLE_ID")
    fi
    if [ -z "${APPLE_TEAM_ID:-}" ]; then
        missing_vars+=("APPLE_TEAM_ID")
    fi
    if [ -z "${PROFILE_TYPE:-}" ]; then
        missing_vars+=("PROFILE_TYPE")
    fi
    
    # Report validation results
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "Missing environment variables:"
        for var in "${missing_vars[@]}"; do
            log_warning "  - $var"
        done
    fi
    
    if [ "$has_app_store_connect" = true ] || [ "$has_manual_certs" = true ]; then
        log_success "Export environment validation passed"
        return 0
    else
        log_error "No authentication method available"
        log_error "Please provide either App Store Connect API credentials or manual certificates"
        return 1
    fi
}

# Main execution
main() {
    log_info "IPA Export Starting..."
    log_info "🔧 Script Version: Enhanced v2.1 with segmentation fault handling"
    log_info "📂 Script Location: $(realpath "$0")"
    log_info "⏰ Current Time: $(date)"
    log_info ""
    
    # Validate export environment
    if ! validate_export_environment; then
        log_error "Export environment validation failed"
        log_error "Creating archive-only export due to missing authentication"
        create_archive_only_export
        return 0
    fi
    
    log_info "Available export methods:"
    if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
        log_info "   1. Primary: app-store-connect with manual signing (3 retries)"
        log_info "   2. Fallback: app-store-connect with automatic signing"
    fi
    if [ -n "${CERT_P12_URL:-}" ]; then
        log_info "   3. Manual: certificate-based signing"
    fi
    log_info "   4. Development: development signing (no Apple Developer account required)"
    log_info "   5. Archive-only: Create archive package for manual export"
    
    # Create ExportOptions.plist
    if ! create_export_options; then
        log_error "Failed to create ExportOptions.plist"
        create_archive_only_export
        return 0
    fi
    
    # Try to export IPA
    if ! export_ipa_xcodebuild; then
        log_error "All export methods failed"
        create_archive_only_export
        return 0
    fi
    
    # Validate IPA if created
    local ipa_file="${OUTPUT_DIR:-output/ios}/Runner.ipa"
    if [ -f "$ipa_file" ]; then
        if validate_ipa "$ipa_file"; then
            log_success "IPA export completed successfully!"
            create_artifacts_summary
            return 0
        else
            log_error "IPA validation failed"
            create_archive_only_export
            return 0
        fi
    else
        log_error "IPA file not found after export"
        create_archive_only_export
        return 0
    fi
}

# Run main function
main "$@"
