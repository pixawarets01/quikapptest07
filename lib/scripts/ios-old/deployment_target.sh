#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

log "Updating iOS deployment target to 13.0 for Firebase compatibility..."

# Update Xcode project file
if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
    log "Updating Xcode project deployment target..."
    sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9][0-9]*\.[0-9]/IPHONEOS_DEPLOYMENT_TARGET = 13.0/g' ios/Runner.xcodeproj/project.pbxproj
    log "Xcode project updated"
else
    log "Warning: Xcode project file not found"
fi

# Dynamically generate Podfile with all required variables
log "Dynamically generating Podfile with required variables..."

# Get current directory for Flutter root detection
CURRENT_DIR=$(pwd)

# Generate dynamic Podfile
cat > ios/Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end

  # Dynamic pre_install hook for manual signing configuration
  pre_install do |installer|
    puts "🔧 Injecting dynamic signing configuration"
    installer.pod_targets.each do |pod|
      pod.build_configurations.each do |config|
        config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
        config.build_settings['DEVELOPMENT_TEAM'] = ENV['APPLE_TEAM_ID'] || '9H2AD7NQ49'
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV['PROFILE_NAME'] || 'Twinklub App Store'
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Ensure deployment target is set correctly for Firebase compatibility
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      
      # Dynamic signing configuration
      if ENV['CODE_SIGN_STYLE'] == 'Manual'
        config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
        config.build_settings['DEVELOPMENT_TEAM'] = ENV['APPLE_TEAM_ID'] || '9H2AD7NQ49'
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV['PROFILE_NAME'] || 'Twinklub App Store'
        config.build_settings['CODE_SIGN_IDENTITY'] = ENV['CODE_SIGN_IDENTITY'] || 'Apple Distribution'
        config.build_settings['CODE_SIGNING_REQUIRED'] = 'YES'
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'YES'
        config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ENV['CODE_SIGN_IDENTITY'] || 'Apple Distribution'
        config.build_settings['CODE_SIGN_INJECT_BASE_ENTITLEMENTS'] = 'YES'
        config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
        
        # Keychain configuration if available
        if ENV['KEYCHAIN_NAME']
          config.build_settings['OTHER_CODE_SIGN_FLAGS'] = "--keychain $HOME/Library/Keychains/#{ENV['KEYCHAIN_NAME']}-db"
        end
      end
    end
  end
end
EOF

log "Podfile dynamically generated with all required variables"

# Update AppFrameworkInfo.plist
if [ -f ios/Flutter/AppFrameworkInfo.plist ]; then
    log "Updating AppFrameworkInfo.plist..."
    sed -i.bak 's/<string>[0-9][0-9]*\.0<\/string>/<string>13.0<\/string>/g' ios/Flutter/AppFrameworkInfo.plist
    log "AppFrameworkInfo.plist updated"
else
    log "Warning: AppFrameworkInfo.plist not found"
fi

# Clean up backup files
rm -f ios/Runner.xcodeproj/project.pbxproj.bak || true
rm -f ios/Podfile.bak || true
rm -f ios/Flutter/AppFrameworkInfo.plist.bak || true

log "iOS deployment target update completed"

# Display generated Podfile for verification
log "Generated Podfile contents:"
echo "=========================================="
cat ios/Podfile
echo "==========================================" 