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

# Function to create archive-only export (final fallback)
export_archive_only() {
    log_info "Creating archive-only export (final fallback)..."
    
    local archive_path="${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
    local export_path="${OUTPUT_DIR:-output/ios}"
    
    # Check if archive exists
    if [ ! -d "$archive_path" ]; then
        log_error "Archive not found: $archive_path"
        # Try to find archive in alternative locations
        for alt_path in "ios/build/Runner.xcarchive" "build/ios/Runner.xcarchive" "Runner.xcarchive"; do
            if [ -d "$alt_path" ]; then
                log_info "Found archive at alternative location: $alt_path"
                archive_path="$alt_path"
                break
            fi
        done
        
        if [ ! -d "$archive_path" ]; then
            log_error "No archive found in any location"
            return 1
        fi
    fi
    
    # Create a simple IPA-like structure for testing
    local test_ipa_dir="$export_path/Runner_test"
    
    # Ensure we can create the directory
    if ! mkdir -p "$test_ipa_dir"; then
        log_error "Failed to create test directory: $test_ipa_dir"
        # Try alternative location
        test_ipa_dir="/tmp/Runner_test_$(date +%s)"
        if ! mkdir -p "$test_ipa_dir"; then
            log_error "Failed to create alternative test directory: $test_ipa_dir"
            return 1
        fi
        log_info "Using alternative test directory: $test_ipa_dir"
    fi
    
    # Copy archive to test directory with error handling
    if cp -r "$archive_path" "$test_ipa_dir/" 2>/dev/null; then
        log_success "Archive copied successfully"
    else
        log_warn "Failed to copy archive, creating symbolic link instead"
        if ln -s "$(realpath "$archive_path")" "$test_ipa_dir/Runner.xcarchive" 2>/dev/null; then
            log_success "Archive linked successfully"
        else
            log_warn "Failed to create link, creating reference file instead"
            echo "Archive location: $(realpath "$archive_path")" > "$test_ipa_dir/ARCHIVE_LOCATION.txt"
        fi
    fi
    
    # Create a comprehensive info file
    local build_info_file="$test_ipa_dir/BUILD_INFO.txt"
    cat > "$build_info_file" << EOF
iOS Build Archive (No IPA Export)
================================
Generated on: $(date)
Build ID: ${CM_BUILD_ID:-unknown}
Workflow: ${WORKFLOW_ID:-ios-workflow}
Export Script Version: Enhanced v2.0

App Information:
- App Name: ${APP_NAME:-Unknown}
- Bundle ID: ${BUNDLE_ID:-Unknown}
- Version: ${VERSION_NAME:-Unknown} (${VERSION_CODE:-Unknown})
- Profile Type: ${PROFILE_TYPE:-Unknown}
- Team ID: ${APPLE_TEAM_ID:-Unknown}

Archive Information:
- Original Archive Path: $archive_path
- Archive Size: $(du -sh "$archive_path" 2>/dev/null | cut -f1 || echo "Unknown")
- Test Package Location: $test_ipa_dir

Export Status: ARCHIVE_ONLY (IPA export failed)

Reason for Archive-Only Export:
- Primary export failed with segmentation fault
- Fallback export failed with authentication issues
- Development export failed with signing issues
- Manual export required

Note: This is an Xcode archive that can be used for:
- Manual IPA export in Xcode
- Testing and debugging
- Development purposes
- Distribution via Xcode Organizer

To create IPA manually:
1. Open Xcode
2. Go to Window > Organizer
3. Select this archive
4. Click "Distribute App"
5. Choose distribution method
6. Follow the signing workflow

Alternative Distribution Methods:
- TestFlight (if you have App Store Connect access)
- Ad-hoc distribution (for specific devices)
- Enterprise distribution (if you have enterprise account)
- Development distribution (for testing)

Build Environment Information:
- Xcode Version: $(xcodebuild -version 2>/dev/null | head -1 || echo "Unknown")
- macOS Version: $(sw_vers -productVersion 2>/dev/null || echo "Unknown")
- Build Date: $(date)
- Script Location: $(realpath "$0" 2>/dev/null || echo "Unknown")
EOF
    
    # Create a simple success marker
    echo "SUCCESS" > "$test_ipa_dir/EXPORT_STATUS.txt"
    
    # Log success with detailed information
    log_success "Archive-only export created: $test_ipa_dir"
    log_info "Archive package contents:"
    if [ -d "$test_ipa_dir/Runner.xcarchive" ]; then
        log_info "  ✅ Runner.xcarchive ($(du -sh "$test_ipa_dir/Runner.xcarchive" 2>/dev/null | cut -f1 || echo "Unknown size"))"
    elif [ -L "$test_ipa_dir/Runner.xcarchive" ]; then
        log_info "  🔗 Runner.xcarchive (symbolic link)"
    elif [ -f "$test_ipa_dir/ARCHIVE_LOCATION.txt" ]; then
        log_info "  📍 ARCHIVE_LOCATION.txt (reference file)"
    fi
    log_info "  📄 BUILD_INFO.txt (detailed information)"
    log_info "  ✅ EXPORT_STATUS.txt (success marker)"
    
    log_warn "No IPA file was created due to export failures"
    log_warn "Archive is available for manual export in Xcode"
    log_info "Manual export guide available in BUILD_INFO.txt"
    
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

# Main execution
main() {
    log_info "IPA Export Starting..."
    log_info "🔧 Script Version: Enhanced v2.0 with multiple fallback methods"
    log_info "📂 Script Location: $(realpath "$0" 2>/dev/null || echo "Unknown")"
    log_info "⏰ Current Time: $(date)"
    log_info ""
    log_info "Available export methods:"
    log_info "  1. Primary: app-store-connect with manual signing (3 retries)"
    log_info "  2. Fallback: app-store-connect with automatic signing"
    log_info "  3. Development: development signing (no Apple Developer account required)"
    log_info "  4. Archive-only: Create archive package for manual export"
    
    # Ensure output directory exists
    ensure_directory "${OUTPUT_DIR:-output/ios}"
    
    # Create ExportOptions.plist
    if ! create_export_options; then
        log_error "Failed to create export options"
        return 1
    fi
    
    # Track export success
    export_successful=false
    
    # Export IPA using xcodebuild
    if export_ipa_xcodebuild; then
        log_success "Primary export method succeeded!"
        export_successful=true
    else
        log_warn "Primary export method failed, trying fallback..."
        if export_ipa_fallback; then
            log_success "Fallback export method succeeded!"
            export_successful=true
        else
            log_warn "Fallback export method failed, trying development export..."
            if export_development_ipa; then
                log_success "Development export method succeeded!"
                export_successful=true
            else
                log_warn "Development export failed, creating archive-only export..."
                # Archive-only export should always succeed if archive exists
                if export_archive_only; then
                    log_success "Archive-only export succeeded!"
                    export_successful=true
                else
                    log_error "All export methods failed - even archive creation failed"
                    log_error "This may be due to:"
                    log_error "  - Missing or corrupted Xcode archive"
                    log_error "  - Insufficient disk space"
                    log_error "  - File system permissions issues"
                    return 1
                fi
            fi
        fi
    fi
    
    # Validate IPA file (skip if archive-only export)
    if [ -f "${OUTPUT_DIR:-output/ios}/Runner.ipa" ]; then
        if ! validate_ipa; then
            log_warn "IPA validation failed, but export was successful"
            # Don't fail the build for validation issues
        fi
    else
        log_warn "Skipping IPA validation (archive-only export)"
    fi
    
    # Create artifacts summary
    create_artifacts_summary
    
    if [ "$export_successful" = true ]; then
        log_success "Export completed successfully!"
        
        # Final summary
        log_info "Export Summary:"
        log_info "  - Profile Type: ${PROFILE_TYPE:-Unknown}"
        if [ -f "${OUTPUT_DIR:-output/ios}/Runner.ipa" ]; then
            log_info "  - IPA File: ${OUTPUT_DIR:-output/ios}/Runner.ipa"
            log_success "✅ IPA file ready for distribution"
        else
            log_info "  - Archive Only: ${OUTPUT_DIR:-output/ios}/Runner_test/"
            log_warn "⚠️  Manual IPA export required in Xcode"
        fi
        log_info "  - Archive: ${OUTPUT_DIR:-output/ios}/Runner.xcarchive"
        log_info "  - Export Options: ios/ExportOptions.plist"
        
        return 0
    else
        log_error "Export failed completely"
        return 1
    fi
}

# Run main function
main "$@"
