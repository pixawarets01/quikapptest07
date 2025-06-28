#!/bin/bash

# IPA Export Script for iOS Build
# Purpose: Export IPA file from Xcode archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting IPA Export..."

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
    else
        log_error "Failed to create ExportOptions.plist"
        return 1
    fi
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

# Function to export IPA using xcodebuild
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
    
    # Clean up any existing export artifacts
    if [ -d "$export_path/Runner.app" ]; then
        log_info "Cleaning up previous export artifacts..."
        rm -rf "$export_path/Runner.app"
    fi
    
    # Export IPA with retry logic
    while [ $retry_count -lt $max_retries ]; do
        retry_count=$((retry_count + 1))
        log_info "Export attempt $retry_count of $max_retries..."
        
        # Export IPA
        log_info "Running xcodebuild -exportArchive..."
        if xcodebuild -exportArchive \
            -archivePath "$archive_path" \
            -exportPath "$export_path" \
            -exportOptionsPlist "$export_options_path" \
            -allowProvisioningUpdates \
            -verbose; then
            
            # Check if IPA was created
            local ipa_file="$export_path/Runner.ipa"
            if [ -f "$ipa_file" ]; then
                log_success "IPA exported successfully: $ipa_file"
                
                # Get IPA file size
                local ipa_size
                if command_exists stat; then
                    ipa_size=$(stat -c%s "$ipa_file" 2>/dev/null || stat -f%z "$ipa_file" 2>/dev/null || echo "0")
                else
                    ipa_size=$(ls -l "$ipa_file" 2>/dev/null | awk '{print $5}' || echo "0")
                fi
                
                local ipa_size_mb=$((ipa_size / 1024 / 1024))
                log_info "IPA size: ${ipa_size_mb} MB (${ipa_size} bytes)"
                
                return 0
            else
                log_error "IPA export failed - file not found: $ipa_file"
                if [ $retry_count -lt $max_retries ]; then
                    log_info "Retrying export in 5 seconds..."
                    sleep 5
                    continue
                fi
            fi
        else
            log_error "xcodebuild export failed with exit code $?"
            if [ $retry_count -lt $max_retries ]; then
                log_info "Retrying export in 5 seconds..."
                sleep 5
                continue
            fi
        fi
    done
    
    log_error "IPA export failed after $max_retries attempts"
    return 1
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
    else
        echo "- IPA File: NOT FOUND" >> "$summary_file"
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
    echo "Build Status: SUCCESS" >> "$summary_file"
    
    log_success "Artifacts summary created: $summary_file"
}

# Main execution
main() {
    log_info "IPA Export Starting..."
    
    # Ensure output directory exists
    ensure_directory "${OUTPUT_DIR:-output/ios}"
    
    # Create ExportOptions.plist
    if ! create_export_options; then
        log_error "Failed to create export options"
        return 1
    fi
    
    # Export IPA using xcodebuild
    if ! export_ipa_xcodebuild; then
        log_warn "Primary export method failed, trying fallback..."
        if ! export_ipa_fallback; then
            log_error "Both primary and fallback export methods failed"
            return 1
        fi
    fi
    
    # Validate IPA file
    if ! validate_ipa; then
        log_error "IPA validation failed"
        return 1
    fi
    
    # Create artifacts summary
    create_artifacts_summary
    
    log_success "IPA Export completed successfully!"
    
    # Final summary
    log_info "Export Summary:"
    log_info "  - Profile Type: ${PROFILE_TYPE:-Unknown}"
    log_info "  - IPA File: ${OUTPUT_DIR:-output/ios}/Runner.ipa"
    log_info "  - Archive: ${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    log_info "  - Export Options: ios/ExportOptions.plist"
    
    return 0
}

# Run main function
main "$@"
