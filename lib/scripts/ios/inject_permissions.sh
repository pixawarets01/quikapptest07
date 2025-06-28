#!/bin/bash

# Dynamic Permission Injection Script for iOS
# Purpose: Inject permissions into iOS Info.plist based on environment variables

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Dynamic Permission Injection for iOS..."

# Function to validate permission variable
validate_permission() {
    local permission_var="$1"
    local permission_name="$2"
    
    if [ "${!permission_var:-false}" = "true" ]; then
        log_info "✅ $permission_name permission enabled"
        return 0
    else
        log_info "⏭️ $permission_name permission disabled"
        return 1
    fi
}

# Function to add permission to Info.plist
add_permission_to_plist() {
    local plist_file="$1"
    local permission_key="$2"
    local usage_description="$3"
    
    log_info "Adding permission: $permission_key"
    
    # Add the permission key and usage description
    plutil -insert "$permission_key" -string "$usage_description" "$plist_file" 2>/dev/null || \
    plutil -replace "$permission_key" -string "$usage_description" "$plist_file" 2>/dev/null || \
    log_warn "Failed to add permission: $permission_key"
}

# Function to remove permission from Info.plist
remove_permission_from_plist() {
    local plist_file="$1"
    local permission_key="$2"
    
    log_info "Removing permission: $permission_key"
    
    plutil -remove "$permission_key" "$plist_file" 2>/dev/null || \
    log_info "Permission not found or already removed: $permission_key"
}

# Function to backup original Info.plist
backup_info_plist() {
    local plist_file="$1"
    local backup_file="${plist_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$plist_file" ]; then
        cp "$plist_file" "$backup_file"
        log_success "Info.plist backed up to: $backup_file"
    else
        log_error "Info.plist not found: $plist_file"
        return 1
    fi
}

# Function to restore Info.plist from backup
restore_info_plist() {
    local plist_file="$1"
    local backup_file="$2"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$plist_file"
        log_success "Info.plist restored from backup"
    else
        log_error "Backup file not found: $backup_file"
        return 1
    fi
}

# Function to inject permissions
inject_permissions() {
    local plist_file="ios/Runner/Info.plist"
    local backup_file=""
    
    log_info "Injecting permissions into: $plist_file"
    
    # Backup original Info.plist
    if ! backup_info_plist "$plist_file"; then
        return 1
    fi
    backup_file="${plist_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Track permissions added
    local permissions_added=0
    local permissions_removed=0
    
    # Camera Permission
    if validate_permission "IS_CAMERA" "Camera"; then
        add_permission_to_plist "$plist_file" "NSCameraUsageDescription" \
            "This app needs camera access to take photos and videos for ${APP_NAME:-the app} functionality."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSCameraUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Location Permission
    if validate_permission "IS_LOCATION" "Location"; then
        add_permission_to_plist "$plist_file" "NSLocationWhenInUseUsageDescription" \
            "This app needs location access to provide location-based services for ${APP_NAME:-the app}."
        add_permission_to_plist "$plist_file" "NSLocationAlwaysAndWhenInUseUsageDescription" \
            "This app needs location access to provide location-based services for ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 2))
    else
        remove_permission_from_plist "$plist_file" "NSLocationWhenInUseUsageDescription"
        remove_permission_from_plist "$plist_file" "NSLocationAlwaysAndWhenInUseUsageDescription"
        remove_permission_from_plist "$plist_file" "NSLocationAlwaysUsageDescription"
        permissions_removed=$((permissions_removed + 3))
    fi
    
    # Microphone Permission
    if validate_permission "IS_MIC" "Microphone"; then
        add_permission_to_plist "$plist_file" "NSMicrophoneUsageDescription" \
            "This app needs microphone access to record audio for ${APP_NAME:-the app} features."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSMicrophoneUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Notification Permission
    if validate_permission "IS_NOTIFICATION" "Notifications"; then
        # Notifications are handled by Firebase/APNS, but we can add a custom description
        add_permission_to_plist "$plist_file" "NSUserNotificationUsageDescription" \
            "This app uses notifications to keep you updated with important information from ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSUserNotificationUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Contacts Permission
    if validate_permission "IS_CONTACT" "Contacts"; then
        add_permission_to_plist "$plist_file" "NSContactsUsageDescription" \
            "This app needs contacts access to help you connect with friends and family through ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSContactsUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Biometric Permission (Face ID / Touch ID)
    if validate_permission "IS_BIOMETRIC" "Biometric"; then
        add_permission_to_plist "$plist_file" "NSFaceIDUsageDescription" \
            "This app uses Face ID to securely authenticate you and protect your data in ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSFaceIDUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Calendar Permission
    if validate_permission "IS_CALENDAR" "Calendar"; then
        add_permission_to_plist "$plist_file" "NSCalendarsUsageDescription" \
            "This app needs calendar access to help you manage your schedule and events in ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 1))
    else
        remove_permission_from_plist "$plist_file" "NSCalendarsUsageDescription"
        permissions_removed=$((permissions_removed + 1))
    fi
    
    # Photo Library Permission
    if validate_permission "IS_STORAGE" "Photo Library"; then
        add_permission_to_plist "$plist_file" "NSPhotoLibraryUsageDescription" \
            "This app needs photo library access to save and share images through ${APP_NAME:-the app}."
        add_permission_to_plist "$plist_file" "NSPhotoLibraryAddUsageDescription" \
            "This app needs permission to save photos to your library from ${APP_NAME:-the app}."
        permissions_added=$((permissions_added + 2))
    else
        remove_permission_from_plist "$plist_file" "NSPhotoLibraryUsageDescription"
        remove_permission_from_plist "$plist_file" "NSPhotoLibraryAddUsageDescription"
        permissions_removed=$((permissions_removed + 2))
    fi
    
    # Add additional iOS-specific permissions based on app features
    
    # Background Modes (if needed for specific features)
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        log_info "Adding background modes for push notifications"
        # Add background modes for push notifications
        plutil -insert "UIBackgroundModes" -array "$plist_file" 2>/dev/null || true
        plutil -insert "UIBackgroundModes.0" -string "remote-notification" "$plist_file" 2>/dev/null || true
        permissions_added=$((permissions_added + 1))
    fi
    
    # Network permissions (if needed)
    if [ "${IS_DOMAIN_URL:-false}" = "true" ]; then
        log_info "Adding network security settings for domain access"
        # Add network security settings
        plutil -insert "NSAppTransportSecurity" -dict "$plist_file" 2>/dev/null || true
        plutil -insert "NSAppTransportSecurity.NSAllowsArbitraryLoads" -bool true "$plist_file" 2>/dev/null || true
        permissions_added=$((permissions_added + 1))
    fi
    
    # Log summary
    log_success "Permission injection completed!"
    log_info "Permissions Summary:"
    log_info "  - Added: $permissions_added permissions"
    log_info "  - Removed: $permissions_removed permissions"
    log_info "  - Backup: $backup_file"
    
    # Validate the modified plist
    if plutil -lint "$plist_file" >/dev/null 2>&1; then
        log_success "Info.plist validation passed"
    else
        log_error "Info.plist validation failed, restoring from backup"
        restore_info_plist "$plist_file" "$backup_file"
        return 1
    fi
    
    return 0
}

# Function to create permission summary
create_permission_summary() {
    local summary_file="${OUTPUT_DIR:-output/ios}/PERMISSIONS_SUMMARY.txt"
    
    log_info "Creating permissions summary..."
    
    cat > "$summary_file" << EOF
iOS Permissions Summary
======================
Generated on: $(date)
Build ID: ${CM_BUILD_ID:-unknown}
App: ${APP_NAME:-Unknown}

Permission Status:
EOF
    
    # Camera
    if [ "${IS_CAMERA:-false}" = "true" ]; then
        echo "- Camera: ENABLED" >> "$summary_file"
    else
        echo "- Camera: DISABLED" >> "$summary_file"
    fi
    
    # Location
    if [ "${IS_LOCATION:-false}" = "true" ]; then
        echo "- Location: ENABLED" >> "$summary_file"
    else
        echo "- Location: DISABLED" >> "$summary_file"
    fi
    
    # Microphone
    if [ "${IS_MIC:-false}" = "true" ]; then
        echo "- Microphone: ENABLED" >> "$summary_file"
    else
        echo "- Microphone: DISABLED" >> "$summary_file"
    fi
    
    # Notifications
    if [ "${IS_NOTIFICATION:-false}" = "true" ]; then
        echo "- Notifications: ENABLED" >> "$summary_file"
    else
        echo "- Notifications: DISABLED" >> "$summary_file"
    fi
    
    # Contacts
    if [ "${IS_CONTACT:-false}" = "true" ]; then
        echo "- Contacts: ENABLED" >> "$summary_file"
    else
        echo "- Contacts: DISABLED" >> "$summary_file"
    fi
    
    # Biometric
    if [ "${IS_BIOMETRIC:-false}" = "true" ]; then
        echo "- Biometric (Face ID/Touch ID): ENABLED" >> "$summary_file"
    else
        echo "- Biometric (Face ID/Touch ID): DISABLED" >> "$summary_file"
    fi
    
    # Calendar
    if [ "${IS_CALENDAR:-false}" = "true" ]; then
        echo "- Calendar: ENABLED" >> "$summary_file"
    else
        echo "- Calendar: DISABLED" >> "$summary_file"
    fi
    
    # Photo Library
    if [ "${IS_STORAGE:-false}" = "true" ]; then
        echo "- Photo Library: ENABLED" >> "$summary_file"
    else
        echo "- Photo Library: DISABLED" >> "$summary_file"
    fi
    
    # Push Notifications
    if [ "${PUSH_NOTIFY:-false}" = "true" ]; then
        echo "- Push Notifications: ENABLED" >> "$summary_file"
    else
        echo "- Push Notifications: DISABLED" >> "$summary_file"
    fi
    
    echo "" >> "$summary_file"
    echo "Info.plist Location: ios/Runner/Info.plist" >> "$summary_file"
    echo "Backup Location: ios/Runner/Info.plist.backup.*" >> "$summary_file"
    
    log_success "Permissions summary created: $summary_file"
}

# Main execution function
main() {
    log_info "Dynamic Permission Injection Starting..."
    log_info "📂 Script Location: $(realpath "$0" 2>/dev/null || echo "Unknown")"
    log_info "⏰ Current Time: $(date)"
    log_info ""
    
    # Validate required environment variables
    if [ -z "${APP_NAME:-}" ]; then
        log_warn "APP_NAME not set, using default app name"
        export APP_NAME="iOS App"
    fi
    
    # Check if Info.plist exists
    if [ ! -f "ios/Runner/Info.plist" ]; then
        log_error "Info.plist not found at ios/Runner/Info.plist"
        return 1
    fi
    
    # Inject permissions
    if ! inject_permissions; then
        log_error "Permission injection failed"
        return 1
    fi
    
    # Create permission summary
    create_permission_summary
    
    log_success "Dynamic permission injection completed successfully!"
    log_info "Permissions have been injected into Info.plist"
    log_info "Summary file created: ${OUTPUT_DIR:-output/ios}/PERMISSIONS_SUMMARY.txt"
    
    return 0
}

# Run main function
main "$@" 