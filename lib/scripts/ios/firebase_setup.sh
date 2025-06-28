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
    log_info "📦 Checking Podfile for Firebase compatibility..."
    
    local podfile="ios/Podfile"
    
    if [ ! -f "$podfile" ]; then
        log_error "Podfile not found: $podfile"
        return 1
    fi
    
    # Check if Firebase dependencies are manually added (which causes conflicts)
    if grep -q "pod 'firebase_core'" "$podfile" || grep -q "pod 'firebase_messaging'" "$podfile"; then
        log_warn "Manual Firebase pod dependencies found in Podfile, removing to avoid conflicts..."
        
        # Create backup of Podfile
        cp "$podfile" "${podfile}.backup"
        
        # Remove manual Firebase dependencies
        sed -i.tmp '/pod.*firebase_core/d' "$podfile"
        sed -i.tmp '/pod.*firebase_messaging/d' "$podfile"
        sed -i.tmp '/# Firebase dependencies for push notifications/d' "$podfile"
        rm -f "${podfile}.tmp"
        
        log_success "Manual Firebase dependencies removed from Podfile"
    fi
    
    # Verify Flutter will handle Firebase through pubspec.yaml
    if [ -f "pubspec.yaml" ]; then
        if grep -q "firebase_core:" "pubspec.yaml" && grep -q "firebase_messaging:" "pubspec.yaml"; then
            log_success "Firebase dependencies found in pubspec.yaml - Flutter will manage them automatically"
        else
            log_warn "Firebase dependencies not found in pubspec.yaml"
            log_info "Please ensure firebase_core and firebase_messaging are added to pubspec.yaml dependencies"
        fi
    fi
    
    log_success "Podfile Firebase compatibility check completed"
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
    
    # Verify Firebase dependencies in pubspec.yaml
    if [ -f "pubspec.yaml" ]; then
        if grep -q "firebase_core:" "pubspec.yaml" && grep -q "firebase_messaging:" "pubspec.yaml"; then
            log_success "Firebase dependencies verified in pubspec.yaml"
        else
            log_warn "Firebase dependencies not found in pubspec.yaml"
            log_info "Flutter will attempt to resolve Firebase dependencies automatically"
        fi
    else
        log_warn "pubspec.yaml not found, skipping Firebase dependency verification"
    fi
    
    log_success "Firebase configuration verification completed"
    return 0
}

# Function to install CocoaPods dependencies
install_pods() {
    log_info "📦 Installing CocoaPods dependencies..."
    
    # First, ensure Flutter dependencies are resolved
    log_info "Running flutter clean to ensure fresh build..."
    flutter clean
    
    log_info "Running flutter pub get to generate required files..."
    if flutter pub get; then
        log_success "Flutter dependencies resolved"
    else
        log_error "Flutter pub get failed"
        return 1
    fi
    
    # Generate iOS platform files if needed
    log_info "Ensuring iOS platform files are generated..."
    flutter create --platforms ios . 2>/dev/null || true
    
    # Verify Generated.xcconfig exists
    if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
        log_warn "Generated.xcconfig not found after flutter pub get, trying flutter build ios --config-only..."
        if flutter build ios --config-only; then
            log_success "Flutter iOS configuration generated"
        else
            log_error "Failed to generate Flutter iOS configuration"
            return 1
        fi
    fi
    
    cd ios
    
    # Clean pods if requested
    if [ "${COCOAPODS_FAST_INSTALL:-true}" != "true" ]; then
        log_info "Cleaning CocoaPods cache..."
        pod cache clean --all 2>/dev/null || true
        rm -rf Pods/ 2>/dev/null || true
        rm -f Podfile.lock 2>/dev/null || true
    fi
    
    # Install pods with Firebase compatibility fixes
    log_info "Installing CocoaPods with Firebase optimizations..."
    if pod install --verbose --repo-update; then
        log_success "CocoaPods installation completed"
    else
        log_warn "Standard pod install failed, trying with legacy mode..."
        if pod install --verbose --repo-update --legacy; then
            log_success "CocoaPods installation completed with legacy mode"
        else
            log_warn "Legacy mode failed, trying with deintegrate and clean install..."
            
            # Deintegrate and clean install
            pod deintegrate 2>/dev/null || true
            rm -rf Pods/ 2>/dev/null || true
            rm -f Podfile.lock 2>/dev/null || true
            
            # Try again with clean state
            if pod install --verbose --repo-update; then
                log_success "CocoaPods clean installation completed"
            else
                log_error "CocoaPods installation failed even after clean install"
                cd ..
                return 1
            fi
        fi
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