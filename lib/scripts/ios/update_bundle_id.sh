#!/bin/bash

# 🔧 Bundle ID Update Script for iOS Xcode Project
# Updates all PRODUCT_BUNDLE_IDENTIFIER entries in the project file

set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🔧 $1"
}

# Function to update bundle ID in Xcode project file
update_bundle_id() {
    local project_file="$1"
    local new_bundle_id="$2"
    local backup_file="${project_file}.bundle_backup"
    
    log "🔧 Updating bundle ID in Xcode project file..."
    log "📋 Project file: $project_file"
    log "📋 New bundle ID: $new_bundle_id"
    
    # Validate inputs
    if [ ! -f "$project_file" ]; then
        log "❌ Project file not found: $project_file"
        return 1
    fi
    
    if [ -z "$new_bundle_id" ]; then
        log "❌ New bundle ID is empty"
        return 1
    fi
    
    # Backup the project file
    cp "$project_file" "$backup_file"
    log "✅ Project file backed up to: $backup_file"
    
    # Show current bundle IDs
    log "🔍 Current PRODUCT_BUNDLE_IDENTIFIER entries:"
    grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$project_file" 2>/dev/null || log "   No PRODUCT_BUNDLE_IDENTIFIER found"
    
    # Create a more robust awk script that handles all formats
    local temp_file="${project_file}.temp"
    local test_bundle_id="${new_bundle_id}.RunnerTests"
    
    log "🔧 Creating updated project file..."
    
    # Use awk to update all PRODUCT_BUNDLE_IDENTIFIER entries
    if awk -v new_bundle_id="$new_bundle_id" -v test_bundle_id="$test_bundle_id" '
    BEGIN {
        updated_count = 0
    }
    /PRODUCT_BUNDLE_IDENTIFIER/ {
        original_line = $0
        if ($0 ~ /RunnerTests/) {
            # Update test target bundle ID
            if (match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"[^"]*"/)) {
                sub(/PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"[^"]*"/, "PRODUCT_BUNDLE_IDENTIFIER = \"" test_bundle_id "\"")
            } else if (match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*[^;]*/)) {
                sub(/PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*[^;]*/, "PRODUCT_BUNDLE_IDENTIFIER = \"" test_bundle_id "\"")
            }
            log_message = "Updated test target bundle ID to: " test_bundle_id
        } else {
            # Update main app bundle ID
            if (match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"[^"]*"/)) {
                sub(/PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"[^"]*"/, "PRODUCT_BUNDLE_IDENTIFIER = \"" new_bundle_id "\"")
            } else if (match($0, /PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*[^;]*/)) {
                sub(/PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*[^;]*/, "PRODUCT_BUNDLE_IDENTIFIER = \"" new_bundle_id "\"")
            }
            log_message = "Updated main app bundle ID to: " new_bundle_id
        }
        
        if ($0 != original_line) {
            updated_count++
            printf "// %s\n", log_message > "/dev/stderr"
        }
    }
    { print }
    END {
        printf "// Updated %d PRODUCT_BUNDLE_IDENTIFIER entries\n", updated_count > "/dev/stderr"
    }
    ' "$project_file" > "$temp_file" 2>&1; then
        
        # Check if the temporary file was created and has content
        if [ -s "$temp_file" ]; then
            # Verify that at least one bundle ID was updated
            local updated_entries=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER" "$temp_file" 2>/dev/null || echo "0")
            local original_entries=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER" "$project_file" 2>/dev/null || echo "0")
            
            if [ "$updated_entries" -eq "$original_entries" ] && [ "$updated_entries" -gt 0 ]; then
                # Replace original file with updated version
                mv "$temp_file" "$project_file"
                log "✅ Bundle ID update completed successfully"
                log "📊 Updated $updated_entries PRODUCT_BUNDLE_IDENTIFIER entries"
                
                # Show the updated entries
                log "🔍 Updated PRODUCT_BUNDLE_IDENTIFIER entries:"
                grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$project_file" 2>/dev/null || log "   No PRODUCT_BUNDLE_IDENTIFIER found"
                
                return 0
            else
                log "❌ Bundle ID update verification failed"
                log "   Original entries: $original_entries"
                log "   Updated entries: $updated_entries"
                rm -f "$temp_file"
                mv "$backup_file" "$project_file"
                return 1
            fi
        else
            log "❌ Temporary file is empty or was not created"
            rm -f "$temp_file"
            mv "$backup_file" "$project_file"
            return 1
        fi
    else
        log "❌ Failed to update bundle IDs with awk"
        rm -f "$temp_file"
        mv "$backup_file" "$project_file"
        return 1
    fi
}

# Function to verify bundle ID update
verify_bundle_id_update() {
    local project_file="$1"
    local expected_bundle_id="$2"
    
    log "🔍 Verifying bundle ID update..."
    
    # Extract bundle ID from project file
    local extracted_bundle_id=$(grep 'PRODUCT_BUNDLE_IDENTIFIER' "$project_file" 2>/dev/null | grep -v "RunnerTests" | head -1 | sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=[[:space:]]*"*\([^";]*\)"*;.*/\1/p' 2>/dev/null || echo "")
    
    # Clean up extracted bundle ID
    extracted_bundle_id=$(echo "$extracted_bundle_id" | xargs | sed 's/^"*\|"*$//g')
    
    log "🔍 Bundle ID verification:"
    log "   Expected: '$expected_bundle_id'"
    log "   Extracted: '$extracted_bundle_id'"
    
    if [ "$extracted_bundle_id" = "$expected_bundle_id" ]; then
        log "✅ Bundle ID verification successful"
        return 0
    else
        log "❌ Bundle ID verification failed"
        return 1
    fi
}

# Main execution
main() {
    local project_file="${1:-ios/Runner.xcodeproj/project.pbxproj}"
    local new_bundle_id="${2:-}"
    
    # Validate arguments
    if [ -z "$new_bundle_id" ]; then
        log "❌ Usage: $0 <project_file> <new_bundle_id>"
        log "❌ Example: $0 ios/Runner.xcodeproj/project.pbxproj com.example.myapp"
        exit 1
    fi
    
    log "🚀 Starting bundle ID update process..."
    
    # Update bundle ID
    if update_bundle_id "$project_file" "$new_bundle_id"; then
        # Verify the update
        if verify_bundle_id_update "$project_file" "$new_bundle_id"; then
            log "✅ Bundle ID update completed and verified successfully"
            exit 0
        else
            log "❌ Bundle ID update verification failed"
            exit 1
        fi
    else
        log "❌ Bundle ID update failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 