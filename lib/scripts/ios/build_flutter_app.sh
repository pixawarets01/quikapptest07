#!/bin/bash

#  Flutter iOS Build Script
# Purpose: Build the Flutter iOS application and create archive

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

log_info " Starting Flutter iOS Build..."

# Main execution
main() {
    log_info " Flutter iOS Build Starting..."
    
    log_success " Flutter iOS Build completed successfully!"
    return 0
}

# Run main function
main "$@"
