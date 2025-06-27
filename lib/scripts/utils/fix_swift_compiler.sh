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
    end
  end
end
EOF
    
    success "Podfile updated with Swift compiler fixes"
}

# Function to clean and reinstall pods
clean_and_reinstall_pods() {
    log "🧹 Cleaning and reinstalling CocoaPods..."
    
    cd ios
    
    # Clean existing pods
    rm -rf Pods Podfile.lock
    rm -rf ~/Library/Caches/CocoaPods
    rm -rf ~/.cocoapods/repos
    
    # Install pods with repo update
    if pod install --repo-update; then
        success "CocoaPods installed successfully"
    else
        error "Failed to install CocoaPods"
        return 1
    fi
    
    cd ..
}

# Function to apply Xcode project fixes
fix_xcode_project() {
    log "🔧 Applying Xcode project fixes..."
    
    cd ios
    
    # Update project.pbxproj with Swift compiler flags
    if [[ -f "Runner.xcodeproj/project.pbxproj" ]]; then
        # Add Swift compiler flags to the project
        sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 5.0;\n\t\t\t\tOTHER_SWIFT_FLAGS = ("-enable-experimental-feature", "AccessLevelOnImport");/g' Runner.xcodeproj/project.pbxproj
        
        success "Xcode project updated with Swift compiler flags"
    fi
    
    cd ..
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
    
    # Create backup
    create_backup
    
    # Check Xcode version
    if check_xcode_version; then
        # Apply fixes for Xcode 15.x
        fix_podfile
        fix_xcode_project
        clean_and_reinstall_pods
        success "Swift compiler fixes applied successfully!"
    else
        log "Xcode version doesn't require Swift compiler fixes"
    fi
    
    log "✅ Swift compiler fix script completed"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 