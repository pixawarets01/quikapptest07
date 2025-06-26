#!/bin/bash

# Download Custom Icons Script for QuikApp
# This script downloads custom SVG icons from BOTTOMMENU_ITEMS and saves them to assets/icons/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to download custom icons
download_custom_icons() {
    local bottom_menu_items="$1"
    
    if [ -z "$bottom_menu_items" ]; then
        log "No BOTTOMMENU_ITEMS provided, skipping custom icon download"
        return 0
    fi
    
    log "Processing BOTTOMMENU_ITEMS for custom icons..."
    
    # Create assets/icons directory if it doesn't exist
    mkdir -p assets/icons
    
    # Use Python to parse JSON and download icons
    python3 -c "
import json
import os
import requests
import sys
from urllib.parse import urlparse

try:
    # Parse the JSON string
    menu_items = json.loads('$bottom_menu_items')
    
    if not isinstance(menu_items, list):
        print('BOTTOMMENU_ITEMS is not a valid JSON array')
        sys.exit(1)
    
    downloaded_count = 0
    
    for item in menu_items:
        if not isinstance(item, dict):
            continue
            
        icon_data = item.get('icon')
        label = item.get('label', 'unknown')
        
        # Skip if icon is not a custom type
        if not isinstance(icon_data, dict) or icon_data.get('type') != 'custom':
            continue
            
        icon_url = icon_data.get('icon_url')
        if not icon_url:
            continue
            
        # Sanitize label for filename
        label_sanitized = label.lower().replace(' ', '_').replace('-', '_')
        filename = f'{label_sanitized}.svg'
        filepath = f'assets/icons/{filename}'
        
        # Download icon if it doesn't exist or if forced
        if not os.path.exists(filepath):
            try:
                print(f'Downloading {label} icon from {icon_url}...')
                response = requests.get(icon_url, timeout=30)
                response.raise_for_status()
                
                with open(filepath, 'wb') as f:
                    f.write(response.content)
                
                print(f'✓ Downloaded {filename}')
                downloaded_count += 1
                
            except requests.exceptions.RequestException as e:
                print(f'✗ Failed to download {label} icon: {e}')
                continue
        else:
            print(f'✓ {filename} already exists, skipping download')
    
    print(f'Downloaded {downloaded_count} new custom icons')
    
except json.JSONDecodeError as e:
    print(f'Invalid JSON in BOTTOMMENU_ITEMS: {e}')
    sys.exit(1)
except Exception as e:
    print(f'Error processing BOTTOMMENU_ITEMS: {e}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        success "Custom icons download completed successfully"
    else
        error "Failed to download custom icons"
        return 1
    fi
}

# Main execution
main() {
    log "Starting custom icons download process..."
    
    # Check if bottom menu is enabled
    if [ "${IS_BOTTOMMENU:-false}" != "true" ]; then
        log "Bottom menu disabled (IS_BOTTOMMENU=false), skipping custom icon download"
        return 0
    fi
    
    # Check if BOTTOMMENU_ITEMS environment variable is set
    if [ -z "$BOTTOMMENU_ITEMS" ]; then
        warning "BOTTOMMENU_ITEMS environment variable not set"
        log "Skipping custom icon download"
        return 0
    fi
    
    # Download custom icons
    download_custom_icons "$BOTTOMMENU_ITEMS"
    
    log "Custom icons download process completed"
}

# Run main function
main "$@" 