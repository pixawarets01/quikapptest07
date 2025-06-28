#!/bin/bash

#  iOS Branding Assets Handler
# Purpose: Download and process branding assets for iOS builds

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info " Starting iOS Branding Assets Setup..."

# Function to download asset with multiple fallbacks
download_asset_with_fallbacks() {
    local url="$1"
    local output_path="$2"
    local asset_name="$3"
    local max_retries=5
    local retry_delay=3
    
    log_info " Downloading $asset_name from: $url"
    
    # Try multiple download methods
    for attempt in $(seq 1 $max_retries); do
        log_info " Download attempt $attempt/$max_retries for $asset_name"
        
        # Method 1: curl with timeout and retry
        if curl -L --connect-timeout 30 --max-time 120 --retry 3 --retry-delay 2 \
            --fail --silent --show-error --output "$output_path" "$url"; then
            log_success "$asset_name downloaded successfully"
            return 0
        fi
        
        # Method 2: wget as fallback
        if command_exists wget; then
            log_info " Trying wget for $asset_name..."
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
    
    log_info " Creating fallback asset for $asset_name"
    
    # Create a minimal PNG as fallback
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$output_path" 2>/dev/null || {
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc`\x00\x00\x00\x04\x00\x01\xf5\xd7\xd4\xc2\x00\x00\x00\x00IEND\xaeB\x82' > "$output_path"
    }
    log_success "Created minimal PNG fallback asset"
}

# Main execution
main() {
    log_info " iOS Branding Assets Setup Starting..."
    
    # Setup directories
    ensure_directory "assets/images"
    ensure_directory "assets/icons"
    ensure_directory "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ensure_directory "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    
    # Download logo
    if [ -n "${LOGO_URL:-}" ]; then
        log_info "Downloading logo from $LOGO_URL"
        download_asset_with_fallbacks "$LOGO_URL" "assets/images/logo.png" "logo"
    else
        log_warn "LOGO_URL is empty, creating default logo"
        create_fallback_asset "assets/images/logo.png" "logo"
    fi
    
    # Download splash
    if [ -n "${SPLASH_URL:-}" ]; then
        log_info "Downloading splash from $SPLASH_URL"
        download_asset_with_fallbacks "$SPLASH_URL" "assets/images/splash.png" "splash"
    else
        log_info "Using logo as splash"
        cp "assets/images/logo.png" "assets/images/splash.png"
    fi
    
    # Copy assets to iOS locations
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
    
    log_success " iOS Branding Assets Setup completed successfully!"
    return 0
}

# Run main function
main "$@"
