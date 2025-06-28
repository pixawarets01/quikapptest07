#!/bin/bash

# 🔥 Firebase Setup Script for iOS Build
# Purpose: Configure Firebase integration for push notifications

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "🔥 Starting Firebase Setup..."

# Function to download Firebase configuration
download_firebase_config() {
    log_info "📥 Downloading Firebase configuration..."
    
    if [ -z "${FIREBASE_CONFIG_IOS:-}" ]; then
        log_error "FIREBASE_CONFIG_IOS is not set"
        return 1
    fi
    
    if [[ "${FIREBASE_CONFIG_IOS}" != http* ]]; then
        log_error "FIREBASE_CONFIG_IOS must be a valid HTTP/HTTPS URL"
        return 1
    fi
    
    local firebase_file="ios/Runner/GoogleService-Info.plist"
    
    # Download Firebase configuration
    if ! download_file "${FIREBASE_CONFIG_IOS}" "$firebase_file"; then
        log_error "Failed to download Firebase configuration"
        return 1
    fi
    
    # Validate file
    if ! validate_file "$firebase_file" 100; then
        log_error "Downloaded Firebase configuration is invalid"
        return 1
    fi
    
    # Verify it's a valid plist file
    if ! plutil -lint "$firebase_file" >/dev/null 2>&1; then
        log_error "Downloaded file is not a valid plist file"
        return 1
    fi
    
    log_success "Firebase configuration downloaded and validated"
    return 0
}

# Function to copy Firebase config to assets
copy_firebase_to_assets() {
    log_info "📁 Copying Firebase configuration to assets..."
    
    local firebase_source="ios/Runner/GoogleService-Info.plist"
    local assets_dir="assets"
    local firebase_dest="$assets_dir/GoogleService-Info.plist"
    
    if [ ! -f "$firebase_source" ]; then
        log_error "Firebase source file not found: $firebase_source"
        return 1
    fi
    
    # Ensure assets directory exists
    ensure_directory "$assets_dir"
    
    # Copy Firebase configuration
    cp "$firebase_source" "$firebase_dest"
    
    if [ -f "$firebase_dest" ]; then
        log_success "Firebase configuration copied to assets"
    else
        log_error "Failed to copy Firebase configuration to assets"
        return 1
    fi
    
    return 0
}

# Function to update Info.plist for push notifications
update_info_plist() {
    log_info "📝 Updating Info.plist for push notifications..."
    
    local info_plist="ios/Runner/Info.plist"
    
    if [ ! -f "$info_plist" ]; then
        log_error "Info.plist not found: $info_plist"
        return 1
    fi
    
    # Add push notification capabilities
    log_info "Adding push notification permissions..."
    
    # Add remote notification background mode
    plutil -replace UIBackgroundModes -json '["remote-notification"]' "$info_plist" 2>/dev/null || true
    
    # Add app transport security exception for Firebase
    plutil -replace NSAppTransportSecurity -json '{
        "NSAllowsArbitraryLoads": true,
        "NSExceptionDomains": {
            "googleapis.com": {
                "NSIncludesSubdomains": true,
                "NSThirdPartyExceptionAllowsInsecureHTTPLoads": true
            },
            "googleapis.com": {
                "NSIncludesSubdomains": true,
                "NSThirdPartyExceptionAllowsInsecureHTTPLoads": true
            }
        }
    }' "$info_plist" 2>/dev/null || true
    
    log_success "Info.plist updated for push notifications"
    return 0
}

# Function to add Firebase dependencies to Podfile
update_podfile() {
    log_info "📦 Adding Firebase dependencies to Podfile..."
    
    local podfile="ios/Podfile"
    
    if [ ! -f "$podfile" ]; then
        log_error "Podfile not found: $podfile"
        return 1
    fi
    
    # Check if Firebase dependencies are already added
    if grep -q "firebase_core" "$podfile" && grep -q "firebase_messaging" "$podfile"; then
        log_info "Firebase dependencies already present in Podfile"
        return 0
    fi
    
    # Create backup of Podfile
    cp "$podfile" "${podfile}.backup"
    
    # Add Firebase dependencies
    log_info "Adding Firebase Core and Messaging dependencies..."
    
    # Find the target section and add Firebase dependencies
    if grep -q "target 'Runner' do" "$podfile"; then
        # Add Firebase dependencies after the target line
        sed -i.tmp "/target 'Runner' do/a\\
  # Firebase dependencies for push notifications\\
  pod 'firebase_core'\\
  pod 'firebase_messaging'\\
" "$podfile"
        rm -f "${podfile}.tmp"
    else
        log_warn "Could not find target 'Runner' in Podfile, adding at end"
        cat >> "$podfile" << EOF

# Firebase dependencies for push notifications
pod 'firebase_core'
pod 'firebase_messaging'
EOF
    fi
    
    log_success "Firebase dependencies added to Podfile"
    return 0
}

# Function to verify Firebase configuration
verify_firebase_config() {
    log_info "🔍 Verifying Firebase configuration..."
    
    local firebase_file="ios/Runner/GoogleService-Info.plist"
    local assets_file="assets/GoogleService-Info.plist"
    local info_plist="ios/Runner/Info.plist"
    local podfile="ios/Podfile"
    
    # Check all required files exist
    local missing_files=()
    
    [ ! -f "$firebase_file" ] && missing_files+=("$firebase_file")
    [ ! -f "$assets_file" ] && missing_files+=("$assets_file")
    [ ! -f "$info_plist" ] && missing_files+=("$info_plist")
    [ ! -f "$podfile" ] && missing_files+=("$podfile")
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing Firebase configuration files:"
        for file in "${missing_files[@]}"; do
            log_error "   - $file"
        done
        return 1
    fi
    
    # Verify Firebase plist contains required keys
    log_info "Checking Firebase configuration keys..."
    local required_keys=("BUNDLE_ID" "PROJECT_ID" "GOOGLE_APP_ID")
    
    for key in "${required_keys[@]}"; do
        if ! plutil -extract "$key" raw "$firebase_file" >/dev/null 2>&1; then
            log_warn "Firebase configuration missing key: $key"
        else
            log_debug "Firebase key found: $key"
        fi
    done
    
    # Verify Podfile has Firebase dependencies
    if grep -q "firebase_core" "$podfile" && grep -q "firebase_messaging" "$podfile"; then
        log_success "Firebase dependencies verified in Podfile"
    else
        log_error "Firebase dependencies not found in Podfile"
        return 1
    fi
    
    log_success "Firebase configuration verification completed"
    return 0
}

# Function to install CocoaPods dependencies
install_pods() {
    log_info "📦 Installing CocoaPods dependencies..."
    
    cd ios
    
    # Clean pods if requested
    if [ "${COCOAPODS_FAST_INSTALL:-true}" != "true" ]; then
        log_info "Cleaning CocoaPods cache..."
        pod cache clean --all 2>/dev/null || true
        rm -rf Pods/ 2>/dev/null || true
        rm -f Podfile.lock 2>/dev/null || true
    fi
    
    # Install pods
    log_info "Running pod install..."
    if pod install --verbose; then
        log_success "CocoaPods installation completed"
    else
        log_error "CocoaPods installation failed"
        cd ..
        return 1
    fi
    
    cd ..
    return 0
}

# Main execution
main() {
    log_info "🎯 Firebase Setup Starting..."
    
    # Check if Firebase setup is required
    if [ "${PUSH_NOTIFY:-false}" != "true" ]; then
        log_info "🔕 Push notifications disabled - skipping Firebase setup"
        return 0
    fi
    
    log_info "🔔 Push notifications enabled - setting up Firebase"
    
    # Download Firebase configuration
    if ! download_firebase_config; then
        log_error "Firebase configuration download failed"
        return 1
    fi
    
    # Copy to assets directory
    if ! copy_firebase_to_assets; then
        log_error "Firebase assets setup failed"
        return 1
    fi
    
    # Update Info.plist
    if ! update_info_plist; then
        log_error "Info.plist update failed"
        return 1
    fi
    
    # Update Podfile
    if ! update_podfile; then
        log_error "Podfile update failed"
        return 1
    fi
    
    # Verify configuration
    if ! verify_firebase_config; then
        log_error "Firebase configuration verification failed"
        return 1
    fi
    
    # Install CocoaPods dependencies
    if ! install_pods; then
        log_error "CocoaPods installation failed"
        return 1
    fi
    
    log_success "🎉 Firebase Setup completed successfully!"
    log_info "📊 Firebase Summary:"
    log_info "   Push Notifications: enabled"
    log_info "   Firebase Status: configured"
    log_info "   CocoaPods: updated"
    
    return 0
}

# Run main function
main "$@" 