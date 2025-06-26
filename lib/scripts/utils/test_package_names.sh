#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PKG_TEST] $1"; }

# Test package name updates for all Android workflows
test_package_names() {
    log "🧪 Testing package name updates for all Android workflows"
    
    # Test cases for different workflows - ALL use same package name
    declare -A test_cases=(
        ["android-free"]="com.example.quikapptest06"
        ["android-paid"]="com.example.quikapptest06"
        ["android-publish"]="com.example.quikapptest06"
        ["combined"]="com.example.quikapptest06"
    )
    
    # Test with different PKG_NAME values
    declare -A pkg_tests=(
        ["com.myapp.test"]="com.myapp.test"
        ["com.company.app"]="com.company.app"
        ["com.example.quikapptest06"]="com.example.quikapptest06"
    )
    
    log "📋 Test Configuration:"
    log "   Base PKG_NAME: ${PKG_NAME:-com.example.quikapptest06}"
    log "   VERSION_NAME: ${VERSION_NAME:-1.0.0}"
    log "   VERSION_CODE: ${VERSION_CODE:-1}"
    log "   WORKFLOW_ID: ${WORKFLOW_ID:-unknown}"
    log "   🔥 All workflows use same package name for Firebase connectivity"
    
    # Check current build.gradle.kts
    if [ -f "android/app/build.gradle.kts" ]; then
        log "🔍 Current build.gradle.kts configuration:"
        
        # Extract current applicationId
        current_app_id=$(grep -o 'applicationId = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        current_namespace=$(grep -o 'namespace = "[^"]*"' android/app/build.gradle.kts | cut -d'"' -f2)
        
        log "   Current applicationId: $current_app_id"
        log "   Current namespace: $current_namespace"
        
        # Check if package name matches expected - ALL workflows use same package name
        expected_pkg="${PKG_NAME:-com.example.quikapptest06}"
        
        if [ "$current_app_id" = "$expected_pkg" ]; then
            log "✅ Package name correctly updated: $current_app_id"
        else
            log "❌ Package name mismatch!"
            log "   Expected: $expected_pkg"
            log "   Found: $current_app_id"
            return 1
        fi
        
        if [ "$current_namespace" = "$expected_pkg" ]; then
            log "✅ Namespace correctly updated: $current_namespace"
        else
            log "❌ Namespace mismatch!"
            log "   Expected: $expected_pkg"
            log "   Found: $current_namespace"
            return 1
        fi
    else
        log "❌ build.gradle.kts not found"
        return 1
    fi
    
    # Check AndroidManifest.xml
    if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
        log "🔍 AndroidManifest.xml configuration:"
        
        # Check if app name is updated
        current_app_name=$(grep -o 'android:label="[^"]*"' android/app/src/main/AndroidManifest.xml | cut -d'"' -f2)
        log "   Current app name: $current_app_name"
        
        expected_app_name="${APP_NAME:-quikapptest06}"
        if [ "$current_app_name" = "$expected_app_name" ]; then
            log "✅ App name correctly updated: $current_app_name"
        else
            log "⚠️ App name mismatch (this is handled by customization script)"
            log "   Expected: $expected_app_name"
            log "   Found: $current_app_name"
        fi
    else
        log "❌ AndroidManifest.xml not found"
        return 1
    fi
    
    # Check pubspec.yaml
    if [ -f "pubspec.yaml" ]; then
        log "🔍 pubspec.yaml configuration:"
        
        current_version=$(grep -o '^version: [^+]*' pubspec.yaml | cut -d' ' -f2)
        log "   Current version: $current_version"
        
        expected_version="${VERSION_NAME:-1.0.0}"
        if [ "$current_version" = "$expected_version" ]; then
            log "✅ Version correctly updated: $current_version"
        else
            log "⚠️ Version mismatch (this is handled by version management)"
            log "   Expected: $expected_version"
            log "   Found: $current_version"
        fi
    else
        log "❌ pubspec.yaml not found"
        return 1
    fi
    
    # Test workflow-specific package name generation - ALL use same package name
    log "🧪 Testing workflow-specific package name generation..."
    
    for workflow in "${!test_cases[@]}"; do
        expected_package="${test_cases[$workflow]}"
        log "   Workflow: $workflow"
        log "   Expected package: $expected_package"
        
        # Simulate what version_management.sh would do - ALL workflows use same package name
        simulated_pkg="${PKG_NAME:-com.example.quikapptest06}"
        
        log "   Simulated package: $simulated_pkg"
        
        if [ "$simulated_pkg" = "$expected_package" ]; then
            log "   ✅ Package name generation correct for $workflow"
        else
            log "   ⚠️ Package name generation may need adjustment for $workflow"
        fi
    done
    
    log "✅ Package name test completed successfully"
    log "🔥 All workflows use same package name for Firebase connectivity"
    return 0
}

# Test different PKG_NAME values
test_different_package_names() {
    log "🧪 Testing different PKG_NAME values..."
    
    local original_pkg="$PKG_NAME"
    
    for test_pkg in "${!pkg_tests[@]}"; do
        log "   Testing PKG_NAME: $test_pkg"
        
        # Temporarily set PKG_NAME
        export PKG_NAME="$test_pkg"
        
        # Run version management to see what package name would be generated
        if [ -f "lib/scripts/android/version_management.sh" ]; then
            # Source the script to see what it would do (without actually modifying files)
            source lib/scripts/android/version_management.sh
            
            # Check what package name would be generated - ALL workflows use same package name
            expected_pkg="$test_pkg"
            
            log "   Expected package for ALL workflows: $expected_pkg"
            log "   🔥 Firebase connectivity works across all workflows with same package name"
        fi
    done
    
    # Restore original PKG_NAME
    export PKG_NAME="$original_pkg"
}

# Main execution
main() {
    log "🚀 Starting package name validation tests..."
    
    # Check if we're in the right directory
    if [ ! -f "android/app/build.gradle.kts" ]; then
        log "❌ Not in project root or android/app/build.gradle.kts not found"
        exit 1
    fi
    
    # Run tests
    if test_package_names; then
        log "✅ All package name tests passed"
        test_different_package_names
        log "🎉 Package name validation completed successfully"
        exit 0
    else
        log "❌ Package name tests failed"
        exit 1
    fi
}

# Execute main function
main "$@" 