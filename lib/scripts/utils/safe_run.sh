#!/bin/bash
# A utility to run a script in a controlled environment, ensuring the CWD is restored.

safe_run() {
    local script_to_run="$1"
    shift # The rest of the arguments are passed to the script.

    if [ ! -f "$script_to_run" ]; then
        log "❌ Cannot execute: Script '$script_to_run' not found."
        return 1
    fi

    # Save the current directory.
    local original_dir
    original_dir=$(pwd)
    
    log "🚀 Safely running '$script_to_run'..."
    log "   Original CWD: $original_dir"

    # Ensure the script is executable.
    chmod +x "$script_to_run"

    # Run the script in a subshell to isolate directory changes.
    (
        # The 'cd' in the subshell will not affect the parent shell.
        "$script_to_run" "$@"
    )
    local exit_code=$?

    # Check if the CWD has changed (it shouldn't, but as a safeguard).
    if [ "$(pwd)" != "$original_dir" ]; then
        log "⚠️ CWD changed unexpectedly after running $script_to_run. Restoring..."
        cd "$original_dir"
    fi
    
    log "   Finished running '$script_to_run' (Exit Code: $exit_code). CWD is now: $(pwd)"
    
    return $exit_code
} 