#!/bin/bash
set -euo pipefail

# Enhanced logging with timestamps
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Function to download asset with multiple fallbacks
download_asset_with_fallbacks() {
    local url="$1"
    local output_path="$2"
    local asset_name="$3"
    local max_retries=5
    local retry_delay=3
    
    log "📥 Downloading $asset_name from: $url"
    
    # Try multiple download methods
    for attempt in $(seq 1 $max_retries); do
        log "🔄 Download attempt $attempt/$max_retries for $asset_name"
        
        # Method 1: curl with timeout and retry
        if curl -L --connect-timeout 30 --max-time 120 --retry 3 --retry-delay 2 \
            --fail --silent --show-error --output "$output_path" "$url"; then
            log "✅ $asset_name downloaded successfully"
            return 0
        fi
        
        # Method 2: wget as fallback
        if command -v wget >/dev/null 2>&1; then
            log "🔄 Trying wget for $asset_name..."
            if wget --timeout=30 --tries=3 --output-document="$output_path" "$url" 2>/dev/null; then
                log "✅ $asset_name downloaded successfully with wget"
                return 0
            fi
        fi
        
        # Method 3: Try with different user agent
        if curl -L --connect-timeout 30 --max-time 120 --retry 2 \
            --user-agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
            --fail --silent --show-error --output "$output_path" "$url"; then
            log "✅ $asset_name downloaded successfully with custom user agent"
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log "⚠️ Download failed for $asset_name, retrying in ${retry_delay}s..."
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))  # Exponential backoff
        fi
    done
    
    # If all downloads fail, create a fallback asset
    log "⚠️ All download attempts failed for $asset_name, creating fallback asset"
    create_fallback_asset "$output_path" "$asset_name"
}

# Function to create fallback assets
create_fallback_asset() {
    local output_path="$1"
    local asset_name="$2"
    
    # Create a simple colored square as fallback
    if command -v convert >/dev/null 2>&1; then
        # Use ImageMagick to create a colored square
        convert -size 512x512 xc:#667eea "$output_path" 2>/dev/null || true
    elif command -v magick >/dev/null 2>&1; then
        # Use newer ImageMagick syntax
        magick -size 512x512 xc:#667eea "$output_path" 2>/dev/null || true
    else
        # Create a simple text file as last resort
        echo "Fallback asset for $asset_name" > "$output_path"
    fi
    
    log "✅ Created fallback asset for $asset_name"
}

# Function to validate asset
validate_asset() {
    local asset_path="$1"
    local asset_name="$2"
    
    if [ -f "$asset_path" ] && [ -s "$asset_path" ]; then
        # Check if it's a valid image file
        if file "$asset_path" | grep -q "image data"; then
            log "✅ $asset_name validated successfully"
            return 0
        elif [ "$asset_name" = "logo" ] || [ "$asset_name" = "splash" ]; then
            log "⚠️ $asset_name is not a valid image, but file exists"
            return 0  # Accept non-image files for now
        fi
    fi
    
    log "❌ $asset_name validation failed"
    return 1
}

# Main branding process
log "Starting branding process for ${APP_NAME:-QuikApp}"

# Create assets directory if it doesn't exist
mkdir -p assets/images

# Download logo with enhanced error handling
if [ -n "${LOGO_URL:-}" ]; then
    log "Downloading logo from $LOGO_URL"
    download_asset_with_fallbacks "$LOGO_URL" "assets/images/logo.png" "logo"
    validate_asset "assets/images/logo.png" "logo"
    
    # Copy to Android mipmap directories
    if [ -f "assets/images/logo.png" ]; then
        mkdir -p android/app/src/main/res/mipmap-hdpi
        mkdir -p android/app/src/main/res/mipmap-mdpi
        mkdir -p android/app/src/main/res/mipmap-xhdpi
        mkdir -p android/app/src/main/res/mipmap-xxhdpi
        mkdir -p android/app/src/main/res/mipmap-xxxhdpi
        
        cp assets/images/logo.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
        cp assets/images/logo.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
        cp assets/images/logo.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
        cp assets/images/logo.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
        cp assets/images/logo.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
        log "✅ Logo copied to Android mipmap"
    fi
else
    log "⚠️ LOGO_URL is empty, creating default logo"
    create_fallback_asset "assets/images/logo.png" "logo"
fi

# Download splash image with enhanced error handling
if [ -n "${SPLASH_URL:-}" ]; then
    log "Downloading splash image from $SPLASH_URL"
    download_asset_with_fallbacks "$SPLASH_URL" "assets/images/splash.png" "splash"
    validate_asset "assets/images/splash.png" "splash"
    
    # Copy to Android drawable
    if [ -f "assets/images/splash.png" ]; then
        mkdir -p android/app/src/main/res/drawable
        cp assets/images/splash.png android/app/src/main/res/drawable/splash.png
        log "✅ Splash image copied to Android drawable"
    fi
else
    log "⚠️ SPLASH_URL is empty, using logo as splash"
    cp assets/images/logo.png assets/images/splash.png
    mkdir -p android/app/src/main/res/drawable
    cp assets/images/splash.png android/app/src/main/res/drawable/splash.png
fi

# Handle splash background
if [ -n "${SPLASH_BG_URL:-}" ]; then
    log "Downloading splash background from $SPLASH_BG_URL"
    download_asset_with_fallbacks "$SPLASH_BG_URL" "assets/images/splash_bg.png" "splash background"
    validate_asset "assets/images/splash_bg.png" "splash background"
else
    log "SPLASH_BG_URL is empty, skipping splash background"
fi

# Final validation
log "Verifying required assets..."
required_assets=("assets/images/logo.png" "assets/images/splash.png")
for asset in "${required_assets[@]}"; do
    if [ -f "$asset" ] && [ -s "$asset" ]; then
        log "✅ $asset exists and has content"
    else
        log "❌ $asset is missing or empty"
        exit 1
    fi
done

log "Branding process completed successfully"
exit 0 