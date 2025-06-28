#!/bin/bash

# Email Notifications Script for iOS Build
# Purpose: Send email notifications for build status

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info "Starting Email Notifications..."

# Function to send email notification
send_notification() {
    local email_type="$1"
    local platform="$2"
    local build_id="${3:-unknown}"
    local error_message="${4:-}"
    
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-false}" = "true" ] && [ -f "lib/scripts/utils/send_email.py" ]; then
        log_info "Sending $email_type email for $platform build $build_id"
        if python3 lib/scripts/utils/send_email.py "$email_type" "$platform" "$build_id" "$error_message"; then
            log_success "Email sent successfully"
        else
            log_warn "Failed to send email notification"
        fi
    else
        log_debug "Email notifications disabled or email script not found"
    fi
}

# Main execution
main() {
    local email_type="${1:-build_started}"
    local platform="${2:-iOS}"
    local build_id="${3:-unknown}"
    local error_message="${4:-}"

    log_info "Email Notification Starting..."
    log_info "   Type: $email_type"
    log_info "   Platform: $platform"
    log_info "   Build ID: $build_id"

    send_notification "$email_type" "$platform" "$build_id" "$error_message"

    log_success "Email Notification completed!"
    return 0
}

# Run main function
main "$@"
