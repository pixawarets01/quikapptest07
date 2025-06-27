#!/bin/bash

# Swift Compiler Fix Script for Xcode 15.4 and Firebase
# This script fixes common Swift compiler issues that occur with newer Xcode versions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to fix Podfile with Swift compiler flags
fix_podfile() {
    local podfile_path="ios/Podfile"
    
    if [[ ! -f "$podfile_path" ]]; then
        error "Podfile not found at $podfile_path"
        return 1
    fi
    
    log "🔧 Fixing Podfile with Swift compiler flags..."
    
    # Check if post_install hook already exists
    if grep -q "post_install" "$podfile_path"; then
        warning "Post-install hook already exists in Podfile"
        log "Updating existing post-install hook..."
        
        # Remove existing post_install block
        sed -i '' '/post_install do |installer|/,/^end$/d' "$podfile_path"
    fi
    
    # Add the post_install hook at the end of the file
    cat >> "$podfile_path" << 'EOF'

# Fix Swift compiler issues with Xcode 15.4 and Firebase
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Enable experimental access level on import feature
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] ||= ['$(inherited)']
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] << 'SWIFT_PACKAGE'
      
      # Add Swift compiler flags for Firebase compatibility
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['$(inherited)']
      config.build_settings['OTHER_SWIFT_FLAGS'] << '-enable-experimental-feature'
      config.build_settings['OTHER_SWIFT_FLAGS'] << 'AccessLevelOnImport'
      
      # Set deployment target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      
      # Fix for Xcode 15.4
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'SWIFT_PACKAGE=1'
      
      # Additional fixes for Firebase
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      
      # Fix Flutter header search paths
      config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/plugins/*/ios/Classes'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/plugins/*/ios/include'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/Headers/Public'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/Headers/Public/*'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/Classes'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/include'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/Classes/Flutter'
      config.build_settings['HEADER_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/include/Flutter'
      
      # Fix framework search paths
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/plugins/*/ios/Frameworks'
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/Frameworks'
      
      # Fix library search paths
      config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(PODS_ROOT)/../.symlinks/plugins/*/ios/Libraries'
      
      # Additional Flutter-specific fixes
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['SWIFT_INCLUDE_PATHS'] ||= ['$(inherited)']
      config.build_settings['SWIFT_INCLUDE_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/Classes'
      config.build_settings['SWIFT_INCLUDE_PATHS'] << '$(PODS_ROOT)/../.symlinks/flutter/ios/include'
    end
  end
end
EOF
    
    success "Podfile updated with Swift compiler fixes"
}

# Function to fix Flutter xcconfig files
fix_flutter_xcconfig() {
    log "🔧 Fixing Flutter xcconfig files..."
    
    cd ios/Flutter
    
    # Fix Release.xcconfig
    if [[ -f "Release.xcconfig" ]]; then
        # Ensure Pods configuration is included
        if ! grep -q "Pods-Runner.release.xcconfig" "Release.xcconfig"; then
            echo -e "\n#include? \"Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig\"" >> "Release.xcconfig"
        fi
        
        # Add comprehensive Flutter header search paths
        if ! grep -q "HEADER_SEARCH_PATHS" "Release.xcconfig"; then
            echo -e "\nHEADER_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Classes \$(PODS_ROOT)/../.symlinks/plugins/*/ios/include \$(PODS_ROOT)/Headers/Public \$(PODS_ROOT)/Headers/Public/* \$(PODS_ROOT)/../.symlinks/flutter/ios/Classes \$(PODS_ROOT)/../.symlinks/flutter/ios/include" >> "Release.xcconfig"
        fi
        
        # Add framework search paths
        if ! grep -q "FRAMEWORK_SEARCH_PATHS" "Release.xcconfig"; then
            echo -e "\nFRAMEWORK_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Frameworks \$(PODS_ROOT)/../.symlinks/flutter/ios/Frameworks" >> "Release.xcconfig"
        fi
    fi
    
    # Fix Debug.xcconfig
    if [[ -f "Debug.xcconfig" ]]; then
        # Ensure Pods configuration is included
        if ! grep -q "Pods-Runner.debug.xcconfig" "Debug.xcconfig"; then
            echo -e "\n#include? \"Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig\"" >> "Debug.xcconfig"
        fi
        
        # Add comprehensive Flutter header search paths
        if ! grep -q "HEADER_SEARCH_PATHS" "Debug.xcconfig"; then
            echo -e "\nHEADER_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Classes \$(PODS_ROOT)/../.symlinks/plugins/*/ios/include \$(PODS_ROOT)/Headers/Public \$(PODS_ROOT)/Headers/Public/* \$(PODS_ROOT)/../.symlinks/flutter/ios/Classes \$(PODS_ROOT)/../.symlinks/flutter/ios/include" >> "Debug.xcconfig"
        fi
        
        # Add framework search paths
        if ! grep -q "FRAMEWORK_SEARCH_PATHS" "Debug.xcconfig"; then
            echo -e "\nFRAMEWORK_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Frameworks \$(PODS_ROOT)/../.symlinks/flutter/ios/Frameworks" >> "Debug.xcconfig"
        fi
    fi
    
    # Fix Profile.xcconfig
    if [[ -f "Profile.xcconfig" ]]; then
        # Ensure Pods configuration is included
        if ! grep -q "Pods-Runner.profile.xcconfig" "Profile.xcconfig"; then
            echo -e "\n#include? \"Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig\"" >> "Profile.xcconfig"
        fi
        
        # Add comprehensive Flutter header search paths
        if ! grep -q "HEADER_SEARCH_PATHS" "Profile.xcconfig"; then
            echo -e "\nHEADER_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Classes \$(PODS_ROOT)/../.symlinks/plugins/*/ios/include \$(PODS_ROOT)/Headers/Public \$(PODS_ROOT)/Headers/Public/* \$(PODS_ROOT)/../.symlinks/flutter/ios/Classes \$(PODS_ROOT)/../.symlinks/flutter/ios/include" >> "Profile.xcconfig"
        fi
        
        # Add framework search paths
        if ! grep -q "FRAMEWORK_SEARCH_PATHS" "Profile.xcconfig"; then
            echo -e "\nFRAMEWORK_SEARCH_PATHS = \$(inherited) \$(PODS_ROOT)/../.symlinks/plugins/*/ios/Frameworks \$(PODS_ROOT)/../.symlinks/flutter/ios/Frameworks" >> "Profile.xcconfig"
        fi
    fi
    
    cd ../..
    success "Flutter xcconfig files updated with comprehensive header search paths"
}

# Function to fix Xcode project configuration
fix_xcode_project() {
    log "🔧 Applying Xcode project fixes..."
    
    cd ios
    
    # Update project.pbxproj with Swift compiler flags and header search paths
    if [[ -f "Runner.xcodeproj/project.pbxproj" ]]; then
        # Add Swift compiler flags to the project
        sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 5.0;\n\t\t\t\tOTHER_SWIFT_FLAGS = ("-enable-experimental-feature", "AccessLevelOnImport");/g' Runner.xcodeproj/project.pbxproj
        
        # Add header search paths
        sed -i '' 's/HEADER_SEARCH_PATHS = (/HEADER_SEARCH_PATHS = (\n\t\t\t\t\t"$(PODS_ROOT)\/..\/.symlinks\/plugins\/*\/ios\/Classes",\n\t\t\t\t\t"$(PODS_ROOT)\/..\/.symlinks\/plugins\/*\/ios\/include",/g' Runner.xcodeproj/project.pbxproj
        
        success "Xcode project updated with Swift compiler flags and header search paths"
    fi
    
    cd ..
}

# Function to clean and reinstall pods
clean_and_reinstall_pods() {
    log "🧹 Cleaning and reinstalling CocoaPods..."
    
    cd ios
    
    # Clean existing pods
    rm -rf Pods Podfile.lock
    rm -rf ~/Library/Caches/CocoaPods
    rm -rf ~/.cocoapods/repos
    
    cd ..
    
    # Install pods with repo update
    cd ios
    if pod install --repo-update; then
        success "CocoaPods installed successfully"
    else
        error "Failed to install CocoaPods"
        return 1
    fi
    
    cd ..
}

# Function to verify Flutter setup
verify_flutter_setup() {
    log "🔍 Verifying Flutter setup..."
    
    # Check if Flutter is properly configured
    if ! flutter doctor --android-licenses --quiet; then
        warning "Flutter doctor check failed, but continuing..."
    fi
    
    # Verify iOS setup
    if ! flutter doctor --verbose | grep -q "iOS toolchain"; then
        warning "iOS toolchain not properly configured"
    else
        success "Flutter iOS setup verified"
    fi
}

# Function to check Xcode version
check_xcode_version() {
    local xcode_version
    xcode_version=$(xcodebuild -version | grep "Xcode" | cut -d' ' -f2)
    
    log "📱 Detected Xcode version: $xcode_version"
    
    # Check if version is 15.0 or higher
    if [[ "$xcode_version" =~ ^15\. ]]; then
        warning "Xcode 15.x detected - applying Swift compiler fixes"
        return 0
    else
        log "Xcode version $xcode_version - Swift compiler fixes may not be needed"
        return 1
    fi
}

# Function to create backup
create_backup() {
    local backup_dir="ios/backup_$(date +%Y%m%d_%H%M%S)"
    
    log "💾 Creating backup in $backup_dir"
    mkdir -p "$backup_dir"
    
    if [[ -f "ios/Podfile" ]]; then
        cp "ios/Podfile" "$backup_dir/"
    fi
    
    if [[ -f "ios/Runner.xcodeproj/project.pbxproj" ]]; then
        cp "ios/Runner.xcodeproj/project.pbxproj" "$backup_dir/"
    fi
    
    success "Backup created in $backup_dir"
}

# Main function
main() {
    log "🔧 Swift Compiler Fix Script"
    log "============================"
    
    # Check if we're in the right directory
    if [[ ! -d "ios" ]]; then
        error "iOS directory not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check if Flutter-generated files exist
    if [[ ! -f "ios/Flutter/Generated.xcconfig" ]]; then
        error "Flutter-generated files not found. Please run 'flutter pub get' first."
        exit 1
    fi
    
    # Create backup
    create_backup
    
    # Verify Flutter setup
    verify_flutter_setup
    
    # Check Xcode version
    if check_xcode_version; then
        # Apply fixes for Xcode 15.x
        fix_podfile
        fix_flutter_xcconfig
        fix_xcode_project
        clean_and_reinstall_pods
        success "Swift compiler fixes applied successfully!"
    else
        log "Xcode version doesn't require Swift compiler fixes"
        # Still apply Flutter configuration fixes
        fix_flutter_xcconfig
        fix_xcode_project
        clean_and_reinstall_pods
    fi
    
    log "✅ Swift compiler fix script completed"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 