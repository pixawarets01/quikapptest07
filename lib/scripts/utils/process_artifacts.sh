#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ARTIFACTS] $1"; }

# process_artifacts: Processes Codemagic artifact links to generate download URLs
#
# This function reads the CM_ARTIFACT_LINKS environment variable, which contains
# a JSON array of artifact objects. It uses `jq` to parse this JSON and extract
# the public-facing download URL for each artifact.
#
# The URLs are then formatted into a single string, separated by newlines,
# which can be passed to the email notification script.
#
# If CM_ARTIFACT_LINKS is not set or is empty, it logs a warning and returns
# a "Not available" message.
#
# Returns:
#   A string containing all artifact download URLs, separated by newlines.
process_artifacts() {
    log "Processing artifact links..."

    if [[ -z "${CM_ARTIFACT_LINKS:-}" ]]; then
        log "⚠️ CM_ARTIFACT_LINKS variable is not set. No artifact URLs available."
        echo "Artifacts not available."
        return
    fi

    log "Raw artifact JSON: $CM_ARTIFACT_LINKS"

    # Try to extract public URLs first. These are non-expiring and accessible without login.
    local public_urls
    public_urls=$(echo "$CM_ARTIFACT_LINKS" | jq -r '.[] | .public_url | select(.)')

    if [[ -n "$public_urls" ]]; then
        log "Successfully extracted public artifact URLs."
        export ARTIFACT_URLS="$public_urls"
    else
        # If no public URLs are found, fall back to private URLs and issue a warning.
        log "WARNING: No public artifact URLs found. Falling back to private, expiring URLs."
        log "         This will result in 'FORBIDDEN' errors when accessing links from email without being logged into Codemagic."
        log "         To enable public links, a team admin must follow the guide at: docs/enabling_public_artifact_urls.md"
        
        local private_urls
        private_urls=$(echo "$CM_ARTIFACT_LINKS" | jq -r '.[] | .url | select(.)')
        export ARTIFACT_URLS="$private_urls"
    fi

    # Final check to see if any URLs were found at all.
    if [[ -z "$ARTIFACT_URLS" ]]; then
        log "No artifact URLs could be parsed from the CM_ARTIFACT_LINKS variable. No artifacts to process."
        return 0
    fi

    log "✅ Successfully processed artifact URLs:"
    # Log each URL for debugging
    while IFS= read -r url; do
        log "   - $url"
    done <<< "$ARTIFACT_URLS"

    # Return the newline-separated list of URLs
    echo "$ARTIFACT_URLS"
} 