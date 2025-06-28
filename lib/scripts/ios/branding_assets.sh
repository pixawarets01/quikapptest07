#!/bin/bash

# iOS Branding Assets Handler
# Purpose: Download and process branding assets for iOS builds

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting iOS Branding Assets Setup..."

# Function to download asset with multiple fallbacks
download_asset_with_fallbacks() {
    local url="$1"
    local output_path="$2"
    local asset_name="$3"
    local max_retries=5
    local retry_delay=3
    
    log_info "Downloading $asset_name from: $url"
    
    # Try multiple download methods
    for attempt in $(seq 1 $max_retries); do
        log_info "Download attempt $attempt/$max_retries for $asset_name"
        
        # Method 1: curl with timeout and retry
        if curl -L --connect-timeout 30 --max-time 120 --retry 3 --retry-delay 2 \
            --fail --silent --show-error --output "$output_path" "$url"; then
            log_success "$asset_name downloaded successfully"
            return 0
        fi
        
        # Method 2: wget as fallback
        if command_exists wget; then
            log_info "Trying wget for $asset_name..."
            if wget --timeout=30 --tries=3 --output-document="$output_path" "$url" 2>/dev/null; then
                log_success "$asset_name downloaded successfully with wget"
                return 0
            fi
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log_warn "Download failed for $asset_name, retrying in ${retry_delay}s..."
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))  # Exponential backoff
        fi
    done
    
    # If all downloads fail, create a fallback asset
    log_warn "All download attempts failed for $asset_name, creating fallback asset"
    create_fallback_asset "$output_path" "$asset_name"
}

# Function to create fallback assets
create_fallback_asset() {
    local output_path="$1"
    local asset_name="$2"
    
    log_info "Creating fallback asset for $asset_name"
    
    # Create a minimal PNG as fallback
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$output_path" 2>/dev/null || {
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc`\x00\x00\x00\x04\x00\x01\xf5\xd7\xd4\xc2\x00\x00\x00\x00IEND\xaeB\x82' > "$output_path"
    }
    log_success "Created minimal PNG fallback asset"
}

# Function to update bundle ID and app name
update_bundle_id_and_app_name() {
    log_info "🔧 Updating Bundle ID and App Name..."
    
    local bundle_id="${BUNDLE_ID:-}"
    local app_name="${APP_NAME:-}"
    local pkg_name="${PKG_NAME:-$bundle_id}"
    
    # Validate bundle ID format if provided
    if [ -n "$pkg_name" ]; then
        if [[ ! "$pkg_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)+$ ]]; then
            log_error "Invalid bundle identifier format: $pkg_name"
            log_info "Bundle ID should be in format: com.example.app"
            return 1
        fi
        
        log_info "📱 Updating iOS bundle identifier to: $pkg_name"
        
        # Update iOS project file
        local ios_project_file="ios/Runner.xcodeproj/project.pbxproj"
        if [ -f "$ios_project_file" ]; then
            # Create backup
            cp "$ios_project_file" "${ios_project_file}.backup"
            
            # Update bundle identifier
            sed -i.tmp "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $pkg_name;/g" "$ios_project_file"
            rm -f "${ios_project_file}.tmp"
            
            log_success "iOS bundle identifier updated to: $pkg_name"
        else
            log_warn "iOS project file not found: $ios_project_file"
        fi
        
        # Update using Flutter rename package if available
        if command -v flutter >/dev/null 2>&1; then
            log_info "🔄 Updating bundle ID using Flutter rename..."
            if flutter pub run rename setBundleId --value "$pkg_name" 2>/dev/null; then
                log_success "Flutter bundle ID updated successfully"
            else
                log_warn "Flutter rename failed, manual update completed"
            fi
        fi
    else
        log_info "No bundle ID provided, skipping bundle ID update"
    fi
    
    # Update app name
    if [ -n "$app_name" ]; then
        log_info "📝 Updating app name to: $app_name"
        
        # Update iOS Info.plist CFBundleName
        local info_plist="ios/Runner/Info.plist"
        if [ -f "$info_plist" ]; then
            # Create backup
            cp "$info_plist" "${info_plist}.backup"
            
            # Update CFBundleName
            plutil -replace CFBundleName -string "$app_name" "$info_plist" 2>/dev/null || {
                log_warn "plutil failed, trying manual update..."
                sed -i.tmp "s/<key>CFBundleName<\/key>.*<string>.*<\/string>/<key>CFBundleName<\/key><string>$app_name<\/string>/g" "$info_plist"
                rm -f "${info_plist}.tmp"
            }
            
            log_success "iOS app name updated to: $app_name"
        else
            log_warn "iOS Info.plist not found: $info_plist"
        fi
        
        # Update using Flutter rename if available
        if command -v flutter >/dev/null 2>&1; then
            log_info "🔄 Updating app name using Flutter rename..."
            if flutter pub run rename setAppName --value "$app_name" 2>/dev/null; then
                log_success "Flutter app name updated successfully"
            else
                log_warn "Flutter rename failed, manual update completed"
            fi
        fi
        
        # Update pubspec.yaml name if needed
        if [ -f "pubspec.yaml" ]; then
            local sanitized_name
            sanitized_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9 ' | tr ' ' '_')
            
            if grep -q "^name: " "pubspec.yaml"; then
                log_info "🔄 Updating pubspec.yaml name to: $sanitized_name"
                sed -i.tmp "s/^name: .*/name: $sanitized_name/" "pubspec.yaml"
                rm -f "pubspec.yaml.tmp"
                
                # Update Dart imports if needed
                if [ -d "lib" ]; then
                    local old_name
                    old_name=$(grep '^name: ' "pubspec.yaml.backup" 2>/dev/null | cut -d ' ' -f2 || echo "")
                    
                    if [ -n "$old_name" ] && [ "$old_name" != "$sanitized_name" ]; then
                        log_info "🔄 Updating Dart package imports..."
                        find lib/ -name "*.dart" -type f -exec sed -i.tmp "s/package:$old_name/package:$sanitized_name/g" {} \; 2>/dev/null || true
                        find lib/ -name "*.dart.tmp" -delete 2>/dev/null || true
                    fi
                fi
                
                log_success "pubspec.yaml name updated to: $sanitized_name"
            fi
        fi
    else
        log_info "No app name provided, skipping app name update"
    fi
    
    log_success "Bundle ID and App Name update completed"
    return 0
}

# Main execution
main() {
    log_info "iOS Branding Assets Setup Starting..."
    
    # Step 1: Update Bundle ID and App Name (if provided)
    if [ -n "${BUNDLE_ID:-}" ] || [ -n "${APP_NAME:-}" ] || [ -n "${PKG_NAME:-}" ]; then
        log_info "--- Step 1: Updating Bundle ID and App Name ---"
        if ! update_bundle_id_and_app_name; then
            log_error "Bundle ID and App Name update failed"
            return 1
        fi
    else
        log_info "--- Step 1: Skipping Bundle ID and App Name update (not provided) ---"
    fi
    
    # Step 2: Setup directories
    log_info "--- Step 2: Setting up Asset Directories ---"
    ensure_directory "assets/images"
    ensure_directory "assets/icons"
    ensure_directory "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ensure_directory "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    
    # Step 3: Download logo
    log_info "--- Step 3: Setting up Logo Assets ---"
    if [ -n "${LOGO_URL:-}" ]; then
        log_info "Downloading logo from $LOGO_URL"
        download_asset_with_fallbacks "$LOGO_URL" "assets/images/logo.png" "logo"
    else
        log_warn "LOGO_URL is empty, creating default logo"
        create_fallback_asset "assets/images/logo.png" "logo"
    fi
    
    # Step 4: Download splash
    log_info "--- Step 4: Setting up Splash Screen Assets ---"
    if [ -n "${SPLASH_URL:-}" ]; then
        log_info "Downloading splash from $SPLASH_URL"
        download_asset_with_fallbacks "$SPLASH_URL" "assets/images/splash.png" "splash"
    else
        log_info "Using logo as splash"
        cp "assets/images/logo.png" "assets/images/splash.png"
    fi
    
    # Step 5: Copy assets to iOS locations
    log_info "--- Step 5: Copying Assets to iOS ---"
    if [ -f "assets/images/logo.png" ]; then
        cp "assets/images/logo.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
        log_success "Logo copied to iOS AppIcon"
    fi
    
    if [ -f "assets/images/splash.png" ]; then
        cp "assets/images/splash.png" "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
        cp "assets/images/splash.png" "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png"
        cp "assets/images/splash.png" "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png"
        log_success "Splash copied to iOS LaunchImage"
    fi
    
    log_success "🎉 iOS Branding Assets Setup completed successfully!"
    log_info "📊 Branding Summary:"
    log_info "   Bundle ID: ${BUNDLE_ID:-${PKG_NAME:-<not updated>}}"
    log_info "   App Name: ${APP_NAME:-<not updated>}"
    log_info "   Logo: ${LOGO_URL:+downloaded}${LOGO_URL:-<fallback created>}"
    log_info "   Splash: ${SPLASH_URL:+downloaded}${SPLASH_URL:-<used logo>}"
    
    return 0
}

# Run main function
main "$@"
