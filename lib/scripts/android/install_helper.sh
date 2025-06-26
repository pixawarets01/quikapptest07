#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INSTALL_HELPER] $1"; }

log "🔧 QuikApp Android Installation Helper"
log "======================================"

# Check if running on macOS/Linux with adb access
ADB_AVAILABLE=false
if command -v adb >/dev/null 2>&1; then
    ADB_AVAILABLE=true
    log "✅ ADB is available on this system"
else
    log "⚠️ ADB is not available on this system"
fi

# Function to check connected devices
check_devices() {
    if [ "$ADB_AVAILABLE" = true ]; then
        log "📱 Checking connected Android devices..."
        local devices=$(adb devices | grep -v "List of devices" | grep -E "\t(device|unauthorized)")
        
        if [ -n "$devices" ]; then
            log "✅ Connected devices:"
            echo "$devices" | while read -r line; do
                log "   $line"
            done
            return 0
        else
            log "❌ No Android devices connected or unauthorized"
            log "💡 Please:"
            log "   1. Connect your Android device via USB"
            log "   2. Enable Developer Options and USB Debugging"
            log "   3. Authorize the computer when prompted"
            return 1
        fi
    else
        log "💡 ADB not available. Please install Android SDK Platform Tools"
        return 1
    fi
}

# Function to get package info from APK
get_apk_info() {
    local apk_path=$1
    
    if [ "$ADB_AVAILABLE" = true ]; then
        log "📋 Getting APK information..."
        
        # Try to get package name from APK
        local pkg_name=$(aapt dump badging "$apk_path" 2>/dev/null | grep package | awk '{print $2}' | sed "s/name='\(.*\)'/\1/" || echo "unknown")
        local version_name=$(aapt dump badging "$apk_path" 2>/dev/null | grep versionName | awk '{print $4}' | sed "s/versionName='\(.*\)'/\1/" || echo "unknown")
        local version_code=$(aapt dump badging "$apk_path" 2>/dev/null | grep versionCode | awk '{print $3}' | sed "s/versionCode='\(.*\)'/\1/" || echo "unknown")
        
        log "   Package: $pkg_name"
        log "   Version: $version_name ($version_code)"
        
        # Check if package is already installed
        if adb shell pm list packages | grep -q "$pkg_name"; then
            log "⚠️ Package $pkg_name is already installed on device"
            
            # Get installed version
            local installed_version=$(adb shell dumpsys package "$pkg_name" | grep versionName | head -1 | awk '{print $1}' | cut -d= -f2 || echo "unknown")
            log "   Installed version: $installed_version"
            
            return 1  # Package conflict detected
        else
            log "✅ Package $pkg_name is not installed - safe to install"
            return 0
        fi
    else
        log "⚠️ Cannot check APK info without ADB/AAPT tools"
        return 0
    fi
}

# Function to uninstall existing package
uninstall_package() {
    local pkg_name=$1
    
    if [ "$ADB_AVAILABLE" = true ]; then
        log "🗑️ Uninstalling existing package: $pkg_name"
        
        if adb uninstall "$pkg_name"; then
            log "✅ Successfully uninstalled $pkg_name"
            return 0
        else
            log "❌ Failed to uninstall $pkg_name"
            log "💡 Try manually uninstalling from device settings"
            return 1
        fi
    else
        log "❌ Cannot uninstall without ADB"
        return 1
    fi
}

# Function to install APK
install_apk() {
    local apk_path=$1
    local force_reinstall=${2:-false}
    
    if [ ! -f "$apk_path" ]; then
        log "❌ APK file not found: $apk_path"
        return 1
    fi
    
    if [ "$ADB_AVAILABLE" = true ]; then
        log "📱 Installing APK: $apk_path"
        
        local install_cmd="adb install"
        if [ "$force_reinstall" = true ]; then
            install_cmd="adb install -r"
            log "🔄 Using force reinstall mode"
        fi
        
        if $install_cmd "$apk_path"; then
            log "✅ APK installed successfully!"
            return 0
        else
            log "❌ APK installation failed"
            log "💡 Try using force reinstall or manual uninstall first"
            return 1
        fi
    else
        log "❌ Cannot install without ADB"
        log "💡 Please install APK manually on device"
        return 1
    fi
}

# Function to generate installation report
generate_report() {
    local apk_path=$1
    local status=$2
    local details=$3
    
    local report_file="output/android/installation_report.txt"
    
    cat > "$report_file" <<EOF
📱 QuikApp Android Installation Report
=====================================

Installation Details:
- APK File: $apk_path
- Date: $(date)
- Status: $status
- Details: $details

System Information:
- ADB Available: $ADB_AVAILABLE
- Platform: $(uname -s)
- Connected Devices: $(if [ "$ADB_AVAILABLE" = true ]; then adb devices | grep -c "device\$" || echo "0"; else echo "N/A"; fi)

Recommended Actions:
EOF

    case $status in
        "SUCCESS")
            cat >> "$report_file" <<EOF
✅ Installation completed successfully!
- App should now be available on your device
- Check the app drawer or home screen
- Test the app functionality

EOF
            ;;
        "CONFLICT")
            cat >> "$report_file" <<EOF
⚠️ Package conflict detected!
- An app with the same package name is already installed
- Options to resolve:
  1. Uninstall the existing app first
  2. Use force reinstall: adb install -r app-release.apk
  3. Try manual installation on device

EOF
            ;;
        "FAILED")
            cat >> "$report_file" <<EOF
❌ Installation failed!
- Common solutions:
  1. Enable Developer Options on device
  2. Enable USB Debugging
  3. Allow installation from unknown sources
  4. Check USB connection
  5. Try manual installation

EOF
            ;;
    esac
    
    cat >> "$report_file" <<EOF
Manual Installation Steps:
1. Copy app-release.apk to your device (via USB, email, etc.)
2. On device, go to Settings > Security
3. Enable "Install apps from unknown sources" or "Allow from this source"
4. Use a file manager to find the APK file
5. Tap the APK file and follow installation prompts

ADB Installation Commands:
- Check devices: adb devices
- Install: adb install app-release.apk
- Force reinstall: adb install -r app-release.apk
- Uninstall: adb uninstall <package_name>

Troubleshooting:
- If "Device unauthorized": Check device for authorization prompt
- If "Installation blocked": Disable Play Protect temporarily
- If "Signatures don't match": Uninstall existing app first
- If "Insufficient storage": Free up space on device

Support:
- Documentation: https://docs.quikapp.co
- Support: support@quikapp.co
EOF

    log "📋 Installation report generated: $report_file"
}

# Main installation process
main() {
    local apk_path="${1:-output/android/app-release.apk}"
    local auto_mode="${2:-false}"
    
    log "🎯 Starting installation process for: $apk_path"
    
    # Check if APK exists
    if [ ! -f "$apk_path" ]; then
        log "❌ APK file not found: $apk_path"
        generate_report "$apk_path" "FAILED" "APK file not found"
        exit 1
    fi
    
    # Get APK file size
    local apk_size=$(du -h "$apk_path" | cut -f1)
    log "📦 APK Size: $apk_size"
    
    # Check device connectivity
    if ! check_devices; then
        log "📱 No devices connected - providing manual installation guide"
        generate_report "$apk_path" "MANUAL" "No ADB devices connected"
        
        log ""
        log "📖 Manual Installation Guide:"
        log "=========================="
        log "1. Copy $apk_path to your Android device"
        log "2. On device: Settings > Security > Enable 'Unknown sources'"
        log "3. Use file manager to find and tap the APK file"
        log "4. Follow installation prompts"
        log ""
        exit 0
    fi
    
    # Get APK information and check for conflicts
    if get_apk_info "$apk_path"; then
        log "✅ No package conflicts detected"
        
        # Attempt installation
        if install_apk "$apk_path"; then
            log "🎉 Installation completed successfully!"
            generate_report "$apk_path" "SUCCESS" "APK installed without conflicts"
            exit 0
        else
            log "❌ Installation failed despite no conflicts"
            generate_report "$apk_path" "FAILED" "Installation failed for unknown reason"
            exit 1
        fi
    else
        log "⚠️ Package conflict detected - existing app needs to be handled"
        
        if [ "$auto_mode" = true ]; then
            log "🔄 Auto mode: Attempting force reinstall..."
            if install_apk "$apk_path" true; then
                log "🎉 Force reinstall completed successfully!"
                generate_report "$apk_path" "SUCCESS" "APK force reinstalled over existing app"
                exit 0
            else
                log "❌ Force reinstall failed"
                generate_report "$apk_path" "FAILED" "Force reinstall failed"
                exit 1
            fi
        else
            log "💡 Manual resolution required"
            log "Options:"
            log "1. Run with auto mode: $0 $apk_path true"
            log "2. Manually uninstall existing app"
            log "3. Use force reinstall: adb install -r $apk_path"
            
            generate_report "$apk_path" "CONFLICT" "Package conflict requires manual resolution"
            exit 1
        fi
    fi
}

# Execute main function with arguments
main "$@" 