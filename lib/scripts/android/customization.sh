#!/bin/bash
set -euo pipefail
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

PKG_NAME=${PKG_NAME:-}
APP_NAME=${APP_NAME:-}

log "Starting Android app customization"

# Ensure required Java imports are present in build.gradle.kts for all workflows
log "Checking and injecting Java imports in build.gradle.kts..."

# Create backup
cp android/app/build.gradle.kts android/app/build.gradle.kts.backup

# Check if imports are already present
if grep -q 'import java.util.Properties' android/app/build.gradle.kts && grep -q 'import java.io.FileInputStream' android/app/build.gradle.kts; then
  log "Java imports already present in build.gradle.kts"
else
  log "Java imports missing, injecting them..."
  
  # Remove any existing import lines to avoid duplicates
  sed -i.tmp '/^import java\.util\.Properties$/d' android/app/build.gradle.kts
  sed -i.tmp '/^import java\.io\.FileInputStream$/d' android/app/build.gradle.kts
  
  # Add imports at the very top
  sed -i.tmp '1i\
import java.util.Properties\
import java.io.FileInputStream\
' android/app/build.gradle.kts
  
  # Clean up temp file
  rm -f android/app/build.gradle.kts.tmp
  
  log "Java imports injected successfully"
fi

# Verify imports are present and file is valid
if grep -q 'import java.util.Properties' android/app/build.gradle.kts && grep -q 'import java.io.FileInputStream' android/app/build.gradle.kts; then
  log "✅ Java imports verified in build.gradle.kts"
  
  # Show first few lines for debugging
  log "First 5 lines of build.gradle.kts:"
  head -5 android/app/build.gradle.kts | while read line; do
    log "  $line"
  done
else
  log "❌ Java imports verification failed, restoring backup"
  cp android/app/build.gradle.kts.backup android/app/build.gradle.kts
  exit 1
fi

# Update package name in build.gradle.kts (already handled by version management)
if [ -n "$PKG_NAME" ]; then
  log "Package name already updated by version management: $PKG_NAME"
  
  # Verify the package name is correctly set in build.gradle.kts
  if [ -f android/app/build.gradle.kts ]; then
    if grep -q "applicationId = \"$PKG_NAME\"" android/app/build.gradle.kts; then
      log "✅ Package name verified in build.gradle.kts: $PKG_NAME"
    else
      log "⚠️ Package name mismatch in build.gradle.kts, updating..."
      sed -i.bak "s/applicationId = \".*\"/applicationId = \"$PKG_NAME\"/" android/app/build.gradle.kts
    fi
  fi
  
  # Also update legacy build.gradle if it exists
  if [ -f android/app/build.gradle ]; then
    sed -i.bak "s/applicationId .*/applicationId \"$PKG_NAME\"/" android/app/build.gradle
  fi
fi

# Update app name in AndroidManifest.xml
if [ -n "$APP_NAME" ]; then
  log "Updating app name to $APP_NAME"
  if [ -f android/app/src/main/AndroidManifest.xml ]; then
    sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
  fi
fi

# Update app icon if logo exists in assets
if [ -f assets/images/logo.png ]; then
  log "Updating app icon from assets/images/logo.png"
  mkdir -p android/app/src/main/res/mipmap-hdpi
  mkdir -p android/app/src/main/res/mipmap-mdpi
  mkdir -p android/app/src/main/res/mipmap-xhdpi
  mkdir -p android/app/src/main/res/mipmap-xxhdpi
  mkdir -p android/app/src/main/res/mipmap-xxxhdpi
  
  # Copy logo to all density folders (you may want to resize these appropriately)
  cp assets/images/logo.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
  cp assets/images/logo.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
fi

log "Android app customization completed successfully"
exit 0 