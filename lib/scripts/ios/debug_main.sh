#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

log "🔍 DEBUG: Starting iOS main.sh with enhanced logging..."

# Show current directory and script location
log "🔍 DEBUG: Current directory: $(pwd)"
log "🔍 DEBUG: Script location: $0"

# Show all environment variables
log "🔍 DEBUG: All environment variables:"
env | sort

# Check if required tools are available
log "🔍 DEBUG: Checking required tools..."
log "   curl: $(which curl 2>/dev/null || echo 'not found')"
log "   openssl: $(which openssl 2>/dev/null || echo 'not found')"
log "   security: $(which security 2>/dev/null || echo 'not found')"
log "   plutil: $(which plutil 2>/dev/null || echo 'not found')"

# Check if directories exist
log "🔍 DEBUG: Checking directories..."
log "   lib/scripts/ios/: $([ -d lib/scripts/ios ] && echo 'exists' || echo 'missing')"
log "   lib/scripts/utils/: $([ -d lib/scripts/utils ] && echo 'exists' || echo 'missing')"

# Check if main script exists and is executable
log "🔍 DEBUG: Checking main script..."
if [ -f "lib/scripts/ios/main.sh" ]; then
    log "   main.sh exists"
    log "   main.sh permissions: $(ls -la lib/scripts/ios/main.sh)"
    log "   main.sh is executable: $([ -x lib/scripts/ios/main.sh ] && echo 'yes' || echo 'no')"
else
    log "   main.sh does not exist"
    log "   Available files in lib/scripts/ios/:"
    ls -la lib/scripts/ios/ 2>/dev/null || log "   Directory not accessible"
fi

# Try to run the main script with more verbose output
log "🔍 DEBUG: Attempting to run main.sh..."
if [ -f "lib/scripts/ios/main.sh" ]; then
    log "🔍 DEBUG: Making main.sh executable..."
    chmod +x lib/scripts/ios/main.sh
    
    log "🔍 DEBUG: Running main.sh with bash -x for verbose output..."
    bash -x lib/scripts/ios/main.sh
else
    log "❌ DEBUG: main.sh not found"
    exit 1
fi 