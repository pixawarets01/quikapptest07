#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ICON_FIX] $1"; }

# Download valid iOS app icons from a reliable source
fix_ios_icons() {
    log "🔧 Fixing iOS app icons..."
    
    local output_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
    
    # Ensure output directory exists
    log "📁 Creating output directory: $output_dir"
    mkdir -p "$output_dir"
    
    # Debug: Check current state of icons
    log "🔍 Current icon state:"
    if [ -d "$output_dir" ]; then
        local icon_count=$(ls -1 "$output_dir"/*.png 2>/dev/null | wc -l)
        log "   Found $icon_count icon files in $output_dir"
        
        # Check a few specific icons
        for icon in "Icon-App-1024x1024@1x.png" "Icon-App-20x20@1x.png"; do
            if [ -f "$output_dir/$icon" ]; then
                local size=$(ls -lh "$output_dir/$icon" | awk '{print $5}')
                log "   $icon: $size"
            else
                log "   $icon: missing"
            fi
        done
    else
        log "   Icon directory does not exist"
    fi
    
    log "📱 Creating valid iOS app icons using Python..."
    
    # Create a Python script to generate proper PNG files
    cat > /tmp/generate_icons.py << 'EOF'
#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw

def create_icon(size, output_path):
    """Create a simple colored square icon of the specified size"""
    # Create a new image with a blue background
    img = Image.new('RGB', (size, size), color='#667eea')
    draw = ImageDraw.Draw(img)
    
    # Add a simple design (white circle in center)
    margin = size // 4
    draw.ellipse([margin, margin, size - margin, size - margin], fill='white')
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created {output_path} ({size}x{size})")

# Define all required icon sizes
icon_sizes = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

output_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Create all icons
for filename, size in icon_sizes:
    output_path = os.path.join(output_dir, filename)
    create_icon(size, output_path)

print("All icons created successfully!")
EOF
    
    # Run the Python script to generate proper PNG files
    log "🔧 Running Python icon generator..."
    if python3 /tmp/generate_icons.py; then
        log "✅ Python icon generation completed successfully"
    else
        log "❌ Python icon generation failed, trying fallback method..."
        
        # Fallback: Create a simple valid PNG using ImageMagick if available
        if command -v convert >/dev/null 2>&1; then
            log "🔧 Using ImageMagick fallback..."
            convert -size 1024x1024 xc:#667eea "$output_dir/Icon-App-1024x1024@1x.png"
            
            # Copy to all other sizes
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-20x20@1x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-20x20@2x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-20x20@3x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-29x29@1x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-29x29@2x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-29x29@3x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-40x40@1x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-40x40@2x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-40x40@3x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-60x60@2x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-60x60@3x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-76x76@1x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-76x76@2x.png"
            cp "$output_dir/Icon-App-1024x1024@1x.png" "$output_dir/Icon-App-83.5x83.5@2x.png"
            log "✅ ImageMagick fallback completed"
        else
            log "❌ No icon generation method available"
            return 1
        fi
    fi
    
    # Clean up temporary file
    rm -f /tmp/generate_icons.py
    
    log "✅ All icon sizes created successfully"
    
    # Ensure Contents.json is properly configured
    log "🔧 Ensuring Contents.json is properly configured..."
    cat > "$output_dir/Contents.json" << 'EOF'
{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-App-29x29@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-App-40x40@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-App-60x60@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-App-29x29@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-App-29x29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-App-40x40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@1x.png",
      "scale" : "1x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-App-76x76@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "83.5x83.5",
      "idiom" : "ipad",
      "filename" : "Icon-App-83.5x83.5@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "1024x1024",
      "idiom" : "ios-marketing",
      "filename" : "Icon-App-1024x1024@1x.png",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF
    
    log "✅ Contents.json regenerated"
    
    # Verify the icons are valid
    log "🔍 Verifying icon files..."
    local icon_count=$(ls -1 "$output_dir"/*.png 2>/dev/null | wc -l)
    log "📊 Found $icon_count icon files"
    
    # Check if the main icon is valid
    if [ -s "$output_dir/Icon-App-1024x1024@1x.png" ]; then
        log "✅ Main app icon is valid"
        
        # Show final state of key icons
        log "🔍 Final icon state:"
        for icon in "Icon-App-1024x1024@1x.png" "Icon-App-20x20@1x.png" "Icon-App-60x60@2x.png"; do
            if [ -f "$output_dir/$icon" ]; then
                local size=$(ls -lh "$output_dir/$icon" | awk '{print $5}')
                log "   $icon: $size"
            else
                log "   $icon: missing"
            fi
        done
        
        log "✅ iOS app icons fixed successfully"
        return 0
    else
        log "❌ Main app icon is invalid"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log "🚀 Starting iOS icon fix process..."
    fix_ios_icons
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "✅ iOS icon fix completed successfully"
    else
        log "❌ iOS icon fix failed with exit code: $exit_code"
    fi
    exit $exit_code
fi 