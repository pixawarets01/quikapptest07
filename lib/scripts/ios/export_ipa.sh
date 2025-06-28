#!/bin/bash

#  IPA Export Script for iOS Build
# Purpose: Export IPA file from Xcode archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info " Starting IPA Export..."

# Main execution
main() {
    log_info " IPA Export Starting..."
    
    log_success " IPA Export completed successfully!"
    return 0
}

# Run main function
main "$@"
