#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Create a simple default logo using ImageMagick or a fallback method
create_default_logo() {
    log "🎨 Creating default app icon..."
    
    # Check if ImageMagick is available
    if command -v convert >/dev/null 2>&1; then
        log "✅ Using ImageMagick to create default icon"
        
        # Create a simple colored square with text as default icon
        convert -size 1024x1024 xc:#667eea \
                -fill white \
                -font Arial-Bold \
                -pointsize 200 \
                -gravity center \
                -annotate +0+0 "QA" \
                -quality 95 \
                assets/images/default_logo.png
        
        log "✅ Default icon created with ImageMagick"
    else
        log "⚠️ ImageMagick not available, creating minimal icon"
        
        # Create a proper 1024x1024 PNG using a different method
        # Use Python to create a simple colored square
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os

# Create a 1024x1024 image with blue background
img = Image.new('RGB', (1024, 1024), color='#667eea')
draw = ImageDraw.Draw(img)

# Try to add text (QA for QuikApp)
try:
    # Try to use a system font
    font = ImageFont.truetype('/System/Library/Fonts/Arial.ttf', 200)
except:
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 200)
    except:
        font = ImageFont.load_default()

# Add white text
text = 'QA'
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (1024 - text_width) // 2
y = (1024 - text_height) // 2
draw.text((x, y), text, fill='white', font=font)

# Save the image
img.save('assets/images/default_logo.png', 'PNG')
print('Default icon created with Python PIL')
"
            log "✅ Default icon created with Python PIL"
        else
            log "⚠️ Python not available, creating minimal icon"
            
            # Create a minimal but valid PNG using base64
            # This is a 1x1 blue pixel PNG
            echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > assets/images/default_logo.png
            
            log "✅ Minimal fallback icon created"
        fi
    fi
}

# Generate iOS app icons with proper dimensions
generate_ios_icons() {
    log "📱 Generating iOS app icons..."
    
    local source_icon="$1"
    local output_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Check if ImageMagick is available for resizing
    if command -v convert >/dev/null 2>&1; then
        log "✅ Using ImageMagick to resize icons"
        
        # Generate all required iOS icon sizes
        convert "$source_icon" -resize 20x20 "$output_dir/Icon-App-20x20@1x.png"
        convert "$source_icon" -resize 40x40 "$output_dir/Icon-App-20x20@2x.png"
        convert "$source_icon" -resize 60x60 "$output_dir/Icon-App-20x20@3x.png"
        convert "$source_icon" -resize 29x29 "$output_dir/Icon-App-29x29@1x.png"
        convert "$source_icon" -resize 58x58 "$output_dir/Icon-App-29x29@2x.png"
        convert "$source_icon" -resize 87x87 "$output_dir/Icon-App-29x29@3x.png"
        convert "$source_icon" -resize 40x40 "$output_dir/Icon-App-40x40@1x.png"
        convert "$source_icon" -resize 80x80 "$output_dir/Icon-App-40x40@2x.png"
        convert "$source_icon" -resize 120x120 "$output_dir/Icon-App-40x40@3x.png"
        convert "$source_icon" -resize 120x120 "$output_dir/Icon-App-60x60@2x.png"
        convert "$source_icon" -resize 180x180 "$output_dir/Icon-App-60x60@3x.png"
        convert "$source_icon" -resize 76x76 "$output_dir/Icon-App-76x76@1x.png"
        convert "$source_icon" -resize 152x152 "$output_dir/Icon-App-76x76@2x.png"
        convert "$source_icon" -resize 167x167 "$output_dir/Icon-App-83.5x83.5@2x.png"
        convert "$source_icon" -resize 1024x1024 "$output_dir/Icon-App-1024x1024@1x.png"
        
        log "✅ iOS icons generated with proper dimensions"
    else
        log "⚠️ ImageMagick not available, copying source icon"
        
        # Fallback: copy the source icon to all locations
        cp "$source_icon" "$output_dir/Icon-App-20x20@1x.png"
        cp "$source_icon" "$output_dir/Icon-App-20x20@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-20x20@3x.png"
        cp "$source_icon" "$output_dir/Icon-App-29x29@1x.png"
        cp "$source_icon" "$output_dir/Icon-App-29x29@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-29x29@3x.png"
        cp "$source_icon" "$output_dir/Icon-App-40x40@1x.png"
        cp "$source_icon" "$output_dir/Icon-App-40x40@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-40x40@3x.png"
        cp "$source_icon" "$output_dir/Icon-App-60x60@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-60x60@3x.png"
        cp "$source_icon" "$output_dir/Icon-App-76x76@1x.png"
        cp "$source_icon" "$output_dir/Icon-App-76x76@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-83.5x83.5@2x.png"
        cp "$source_icon" "$output_dir/Icon-App-1024x1024@1x.png"
        
        log "⚠️ Icons copied without resizing (may cause issues)"
    fi
}

# Validate generated icons
validate_icons() {
    log "🔍 Validating generated icons..."
    
    local output_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local required_icons=(
        "Icon-App-20x20@1x.png"
        "Icon-App-20x20@2x.png"
        "Icon-App-20x20@3x.png"
        "Icon-App-29x29@1x.png"
        "Icon-App-29x29@2x.png"
        "Icon-App-29x29@3x.png"
        "Icon-App-40x40@1x.png"
        "Icon-App-40x40@2x.png"
        "Icon-App-40x40@3x.png"
        "Icon-App-60x60@2x.png"
        "Icon-App-60x60@3x.png"
        "Icon-App-76x76@1x.png"
        "Icon-App-76x76@2x.png"
        "Icon-App-83.5x83.5@2x.png"
        "Icon-App-1024x1024@1x.png"
    )
    
    local missing_icons=()
    
    for icon in "${required_icons[@]}"; do
        if [ ! -f "$output_dir/$icon" ]; then
            missing_icons+=("$icon")
        elif [ ! -s "$output_dir/$icon" ]; then
            log "❌ Icon $icon is empty"
            missing_icons+=("$icon")
        fi
    done
    
    if [ ${#missing_icons[@]} -eq 0 ]; then
        log "✅ All required icons are present and valid"
        return 0
    else
        log "❌ Missing or invalid icons: ${missing_icons[*]}"
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting iOS icon generation..."
    
    # Create assets directory if it doesn't exist
    mkdir -p assets/images
    
    # Create default logo if it doesn't exist or is invalid
    if [ ! -f "assets/images/default_logo.png" ] || [ ! -s "assets/images/default_logo.png" ]; then
        create_default_logo
    fi
    
    # Generate iOS icons
    generate_ios_icons "assets/images/default_logo.png"
    
    # Validate the generated icons
    if validate_icons; then
        log "🎉 iOS icon generation completed successfully"
        return 0
    else
        log "❌ iOS icon generation failed validation"
        return 1
    fi
}

# Run main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
    exit $?
fi 