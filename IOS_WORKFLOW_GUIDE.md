# 🍎 iOS Workflow Complete Guide for Codemagic

## 📋 Table of Contents
1. [Overview](#overview)
2. [Workflow Structure](#workflow-structure)
3. [Environment Variables](#environment-variables)
4. [Scripts and Logic](#scripts-and-logic)
5. [Build Process](#build-process)
6. [Code Signing](#code-signing)
7. [Firebase Integration](#firebase-integration)
8. [Email Notifications](#email-notifications)
9. [Artifacts](#artifacts)
10. [Troubleshooting](#troubleshooting)

## 🎯 Overview

The iOS workflow (`ios-workflow`) is a comprehensive build system that creates iOS Universal IPA files for all distribution types:
- **App Store** - For App Store distribution
- **Ad Hoc** - For internal testing
- **Enterprise** - For enterprise distribution
- **Development** - For development testing

### Key Features
- ✅ Universal profile type support
- ✅ Dynamic code signing with fallback mechanisms
- ✅ Firebase integration for push notifications
- ✅ Email notifications for build status
- ✅ Multiple export methods (xcodebuild, fastlane)
- ✅ Comprehensive error handling and retry logic
- ✅ Build acceleration optimizations
- ✅ Modular script architecture for maintainability

## 🏗️ Workflow Structure

### Basic Configuration
```yaml
ios-workflow:
  name: iOS Universal Build (App Store + Ad Hoc + Enterprise + Development)
  max_build_duration: 90
  instance_type: mac_mini_m2
  environment:
    flutter: 3.32.2
    java: 17
    xcode: 15.4
    cocoapods: 1.16.2
```

### Modular Scripts Architecture
The iOS workflow now uses a modular architecture with individual scripts orchestrated by `main.sh`:

```
lib/scripts/ios/
├── main.sh                    # 🎯 Main orchestration script
├── utils.sh                   # 🔧 Common utility functions
├── setup_environment.sh       # 🚀 Environment validation and cleanup
├── handle_certificates.sh     # 🔐 Certificate and profile management
├── branding_assets.sh         # 🎨 Logo, splash, and custom icons
├── firebase_setup.sh          # 🔥 Firebase integration
├── build_flutter_app.sh       # 🏗️ Flutter build and archive
├── export_ipa.sh              # 📦 IPA export with fallbacks
└── email_notifications.sh     # 📧 Email notification system
```

### Scripts Execution Sequence
The `main.sh` script orchestrates the entire build process by calling individual, modular scripts:

1. **Pre-build Setup** - Environment validation and cleanup (`setup_environment.sh`)
2. **Email Notification** - Build started notification (`email_notifications.sh`)
3. **Certificate Handling** - Downloads and sets up certificates and provisioning profiles (`handle_certificates.sh`)
4. **Branding Assets** - Downloads and processes logo, splash screens, and custom icons (`branding_assets.sh`)
5. **Firebase Integration** - Configures Firebase if PUSH_NOTIFY is enabled (`firebase_setup.sh`)
6. **Flutter Build Process** - Builds the Flutter iOS app and creates archive (`build_flutter_app.sh`)
7. **IPA Export** - Exports the IPA file using xcodebuild or Fastlane (`export_ipa.sh`)
8. **Email Notification** - Build success/failure notification (`email_notifications.sh`)

## 🔧 Environment Variables

### 📱 Required Variables

#### App Configuration
```yaml
# Basic App Info
APP_NAME: "Your App Name"
BUNDLE_ID: "com.yourcompany.yourapp"
VERSION_NAME: "1.0.0"
VERSION_CODE: "1"
ORG_NAME: "Your Organization"
WEB_URL: "https://yourapp.com"
```

#### iOS Signing (Required)
```yaml
# Certificate Configuration
CERT_PASSWORD: "your_certificate_password"
PROFILE_URL: "https://your-domain.com/profile.mobileprovision"
PROFILE_TYPE: "app-store" # app-store, ad-hoc, enterprise, development
APPLE_TEAM_ID: "YOUR_TEAM_ID"

# Certificate URLs (Choose one option)
# Option 1: P12 Certificate
CERT_P12_URL: "https://your-domain.com/certificate.p12"

# Option 2: Separate Certificate and Key
CERT_CER_URL: "https://your-domain.com/certificate.cer"
CERT_KEY_URL: "https://your-domain.com/privatekey.key"
```

#### App Store Connect (For TestFlight)
```yaml
# App Store Connect API (Optional but recommended)
APP_STORE_CONNECT_KEY_IDENTIFIER: "YOUR_KEY_ID"
APP_STORE_CONNECT_ISSUER_ID: "your-issuer-id"
APP_STORE_CONNECT_API_KEY_PATH: "https://your-domain.com/AuthKey.p8"
IS_TESTFLIGHT: "true"
```

### 🔥 Optional Variables

#### Firebase Configuration
```yaml
# Firebase (Required if PUSH_NOTIFY=true)
FIREBASE_CONFIG_IOS: "https://your-domain.com/GoogleService-Info.plist"
PUSH_NOTIFY: "true" # Enable push notifications
```

#### Feature Flags
```yaml
# App Features
IS_CHATBOT: "true"
IS_DOMAIN_URL: "true"
IS_SPLASH: "true"
IS_PULLDOWN: "true"
IS_BOTTOMMENU: "true"
IS_LOAD_IND: "true"
```

#### Permissions
```yaml
# Device Permissions
IS_CAMERA: "false"
IS_LOCATION: "false"
IS_MIC: "true"
IS_NOTIFICATION: "true"
IS_CONTACT: "false"
IS_BIOMETRIC: "false"
IS_CALENDAR: "false"
IS_STORAGE: "true"
```

#### UI Configuration
```yaml
# Branding
LOGO_URL: "https://your-domain.com/logo.png"
SPLASH_URL: "https://your-domain.com/splash.png"
SPLASH_BG_COLOR: "#FFFFFF"
SPLASH_TAGLINE: "Welcome to Your App"
SPLASH_TAGLINE_COLOR: "#000000"
SPLASH_ANIMATION: "zoom"
SPLASH_DURATION: "3"

# Bottom Menu
BOTTOMMENU_ITEMS: '[{"label": "Home", "icon": "home", "url": "https://yourapp.com"}]'
BOTTOMMENU_BG_COLOR: "#FFFFFF"
BOTTOMMENU_ICON_COLOR: "#000000"
BOTTOMMENU_TEXT_COLOR: "#000000"
BOTTOMMENU_FONT: "DM Sans"
BOTTOMMENU_FONT_SIZE: "14"
BOTTOMMENU_FONT_BOLD: "false"
BOTTOMMENU_FONT_ITALIC: "false"
BOTTOMMENU_ACTIVE_TAB_COLOR: "#0000FF"
BOTTOMMENU_ICON_POSITION: "top"
BOTTOMMENU_VISIBLE_ON: "home,settings"
```

#### Email Notifications
```yaml
# Email Configuration
ENABLE_EMAIL_NOTIFICATIONS: "true"
EMAIL_SMTP_SERVER: "smtp.gmail.com"
EMAIL_SMTP_PORT: "587"
EMAIL_SMTP_USER: "your-email@gmail.com"
EMAIL_SMTP_PASS: "your-app-password"
EMAIL_ID: "recipient@example.com"
```

#### Build Environment
```yaml
# Build Configuration
OUTPUT_DIR: "output/ios"
CM_BUILD_ID: "$CM_BUILD_ID" # Auto-set by Codemagic
CM_BUILD_DIR: "$CM_BUILD_DIR" # Auto-set by Codemagic
```

## 🔄 Scripts and Logic

The core logic for the iOS workflow now resides in modular scripts within `lib/scripts/ios/`. The `main.sh` acts as the primary entry point, orchestrating the execution of these individual scripts based on defined conditions and environment variables.

### Main Orchestration Script: `lib/scripts/ios/main.sh`
**Purpose**: This script serves as the central control for the iOS build workflow. It loads environment variables, defines the build sequence, and calls specific scripts for each stage.

**Logic Flow**:
```bash
#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Define the directory where individual scripts are located
SCRIPT_DIR="$(dirname "$0")"

# Source common utility functions
source "${SCRIPT_DIR}/utils.sh"

# Load all required environment variables
load_environment_variables() {
  echo "Loading environment variables..."
  # Validate essential variables
  if [ -z "${BUNDLE_ID}" ]; then
    log_error "BUNDLE_ID is not set. Exiting."
    exit 1
  fi
  if [ -z "${PROFILE_TYPE}" ]; then
    log_error "PROFILE_TYPE is not set. Exiting."
    exit 1
  fi
}

# 1. Pre-build Setup
echo "--- Stage 1: Pre-build Setup ---"
"${SCRIPT_DIR}/setup_environment.sh" || { send_email "build_failed" "iOS" "${CM_BUILD_ID}" "Pre-build setup failed."; exit 1; }

# 2. Email Notification: Build Started
if [ "${ENABLE_EMAIL_NOTIFICATIONS}" = "true" ]; then
  echo "--- Stage 2: Sending Build Started Email ---"
  "${SCRIPT_DIR}/email_notifications.sh" "build_started" "iOS" "${CM_BUILD_ID}" || log_warn "Failed to send build started email."
fi

# 3. Handle Certificates and Provisioning Profiles
echo "--- Stage 3: Handling Certificates and Provisioning Profiles ---"
"${SCRIPT_DIR}/handle_certificates.sh" || { send_email "build_failed" "iOS" "${CM_BUILD_ID}" "Certificate and profile handling failed."; exit 1; }

# 4. Firebase Integration (Conditional)
if [ "${PUSH_NOTIFY}" = "true" ]; then
  echo "--- Stage 4: Setting up Firebase ---"
  "${SCRIPT_DIR}/firebase_setup.sh" || { send_email "build_failed" "iOS" "${CM_BUILD_ID}" "Firebase setup failed."; exit 1; }
fi

# 5. Flutter Build Process
echo "--- Stage 5: Building Flutter iOS App ---"
"${SCRIPT_DIR}/build_flutter_app.sh" || { send_email "build_failed" "iOS" "${CM_BUILD_ID}" "Flutter build failed."; exit 1; }

# 6. IPA Export
echo "--- Stage 6: Exporting IPA ---"
"${SCRIPT_DIR}/export_ipa.sh" || { send_email "build_failed" "iOS" "${CM_BUILD_ID}" "IPA export failed."; exit 1; }

# 7. Email Notification: Build Success
if [ "${ENABLE_EMAIL_NOTIFICATIONS}" = "true" ]; then
  echo "--- Stage 7: Sending Build Success Email ---"
  "${SCRIPT_DIR}/email_notifications.sh" "build_success" "iOS" "${CM_BUILD_ID}" || log_warn "Failed to send build success email."
fi

echo "iOS workflow completed successfully!"
```

### Individual Scripts

#### 1. `lib/scripts/ios/utils.sh`
**Purpose**: Common utility functions used across all iOS build scripts.

**Key Functions**:
- ✅ Logging functions with timestamps and emojis (`log_info`, `log_success`, `log_warn`, `log_error`)
- ✅ Environment variable validation (`validate_required_vars`, `validate_profile_type`)
- ✅ File operations (`download_file`, `validate_file`, `ensure_directory`)
- ✅ Email notification wrapper (`send_email`)
- ✅ Command existence checking (`command_exists`)

#### 2. `lib/scripts/ios/setup_environment.sh`
**Purpose**: Environment validation, cleanup, and optimization.

**Key Functions**:
- ✅ Validates Flutter, Xcode, CocoaPods versions
- ✅ Cleans previous build artifacts
- ✅ Validates Firebase configuration based on PUSH_NOTIFY
- ✅ Validates iOS signing configuration
- ✅ Validates profile type (app-store, ad-hoc, enterprise, development)
- ✅ Checks for required build scripts
- ✅ Sets up required directories
- ✅ Configures build environment variables

#### 3. `lib/scripts/ios/handle_certificates.sh`
**Purpose**: Manages the download and installation of certificates and provisioning profiles required for code signing.

**Key Functions**:
- ✅ Downloads P12 certificate or separate .cer and .key files based on configuration
- ✅ Implements intelligent password detection logic with fallback mechanisms
- ✅ Imports certificates into the keychain with multiple import methods
- ✅ Downloads and installs the provisioning profile
- ✅ Validates bundle ID match between environment and provisioning profile
- ✅ Sets up keychain with proper security settings

#### 4. `lib/scripts/ios/branding_assets.sh`
**Purpose**: Downloads and processes branding assets for iOS builds including logo, splash screens, and custom bottom navigation icons.

**Key Functions**:
- ✅ Downloads logo from LOGO_URL with multiple fallback mechanisms
- ✅ Generates iOS app icons in all required sizes (20x20 to 1024x1024)
- ✅ Downloads splash screen from SPLASH_URL or uses logo as fallback
- ✅ Sets up iOS launch images and splash screens
- ✅ Downloads custom SVG icons for bottom navigation menu
- ✅ Creates fallback assets when downloads fail
- ✅ Validates all downloaded assets
- ✅ Copies assets to appropriate iOS directories (Assets.xcassets)

**Asset Paths**:
- Logo: `assets/images/logo.png` → `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Splash: `assets/images/splash.png` → `ios/Runner/Assets.xcassets/LaunchImage.imageset/`
- Custom Icons: `assets/icons/*.svg` (for bottom navigation)

#### 5. `lib/scripts/ios/firebase_setup.sh`
**Purpose**: Configures Firebase integration if PUSH_NOTIFY is enabled.

**Key Functions**:
- ✅ Downloads GoogleService-Info.plist from the specified URL
- ✅ Copies the Firebase configuration to the appropriate assets directory
- ✅ Updates Info.plist with push notification permissions
- ✅ Adds Firebase dependencies to the Podfile
- ✅ Installs CocoaPods dependencies
- ✅ Verifies Firebase configuration integrity

#### 6. `lib/scripts/ios/build_flutter_app.sh`
**Purpose**: Executes the main Flutter iOS build process.

**Key Functions**:
- ✅ Updates iOS project configuration (Info.plist, privacy descriptions)
- ✅ Configures Xcode project for code signing based on profile type
- ✅ Generates environment configuration for the app
- ✅ Runs `flutter build ios --release --no-codesign`
- ✅ Creates the Xcode archive using xcodebuild
- ✅ Verifies build output and archive integrity

#### 7. `lib/scripts/ios/export_ipa.sh`
**Purpose**: Handles the export of the IPA file, including fallback mechanisms.

**Key Functions**:
- ✅ Generates ExportOptions.plist based on profile type
- ✅ Attempts IPA export using xcodebuild -exportArchive
- ✅ Implements optional Fastlane export as an alternative
- ✅ Provides direct IPA export as a fallback method with App Store Connect API authentication
- ✅ Handles multiple export attempts and detailed error reporting

#### 8. `lib/scripts/ios/email_notifications.sh`
**Purpose**: Sends email notifications for build status.

**Key Functions**:
- ✅ Sends "Build Started", "Build Success", and "Build Failed" notifications
- ✅ Includes build information, environment details, duration, and artifact information
- ✅ Integrates with the existing Python email system
- ✅ Provides flexible notification types and error message handling

### Benefits of Modular Architecture

#### ✅ **Maintainability**
- Each script has a single responsibility
- Easy to debug and troubleshoot individual components
- Clear separation of concerns

#### ✅ **Reusability**
- Individual scripts can be run independently for testing
- Common functions are centralized in utils.sh
- Scripts can be reused in other workflows

#### ✅ **Reliability**
- Better error handling with specific error messages
- Granular failure points for easier debugging
- Comprehensive logging throughout the process

#### ✅ **Flexibility**
- Easy to add new features or modify existing ones
- Conditional execution based on environment variables
- Support for different certificate configurations and profile types

## 🔐 Code Signing

### Certificate Handling
The workflow supports two certificate configurations handled by `handle_certificates.sh`:

#### Option 1: P12 Certificate
```yaml
CERT_P12_URL: "https://your-domain.com/certificate.p12"
CERT_PASSWORD: "your_password"
```

#### Option 2: Separate Certificate and Key
```yaml
CERT_CER_URL: "https://your-domain.com/certificate.cer"
CERT_KEY_URL: "https://your-domain.com/privatekey.key"
CERT_PASSWORD: "your_password"
```

### Password Detection Logic
The system includes intelligent password detection in `handle_certificates.sh`:

```bash
# 1. Check if CERT_PASSWORD is valid (not placeholder)
if [ -n "$CERT_PASSWORD" ] && [ "$CERT_PASSWORD" != "set" ]; then
  actual_password="$CERT_PASSWORD"
else
  # 2. Try common passwords
  common_passwords=("" "password" "123456" "certificate" "ios" "apple" "distribution" "match" "User@54321" "your_cert_password")
  for common_pass in "${common_passwords[@]}"; do
    if openssl pkcs12 -in cert.p12 -noout -passin "pass:$common_pass"; then
      actual_password="$common_pass"
      break
    fi
  done
fi
```

### Provisioning Profile
```yaml
PROFILE_URL: "https://your-domain.com/profile.mobileprovision"
PROFILE_TYPE: "app-store" # app-store, ad-hoc, enterprise, development
```

## 🔥 Firebase Integration

### Configuration
```yaml
FIREBASE_CONFIG_IOS: "https://your-domain.com/GoogleService-Info.plist"
PUSH_NOTIFY: "true"
```

### Setup Process
The setup process is now centralized in `firebase_setup.sh`:

1. **Download Firebase config** from URL
2. **Copy to assets** directory
3. **Update Info.plist** with push notification permissions
4. **Add Firebase dependencies** to Podfile
5. **Install CocoaPods dependencies**
6. **Verify configuration** integrity

### Conditional Logic
```bash
# The conditional logic is handled in main.sh
if [ "${PUSH_NOTIFY}" = "true" ]; then
  echo "🔔 Push notifications ENABLED - Setting up Firebase"
  # Call firebase_setup.sh
else
  echo "🔕 Push notifications DISABLED - Skipping Firebase"
fi
```

## 📧 Email Notifications

### Configuration
```yaml
ENABLE_EMAIL_NOTIFICATIONS: "true"
EMAIL_SMTP_SERVER: "smtp.gmail.com"
EMAIL_SMTP_PORT: "587"
EMAIL_SMTP_USER: "your-email@gmail.com"
EMAIL_SMTP_PASS: "your-app-password"
EMAIL_ID: "recipient@example.com"
```

### Notification Types
1. **Build Started** - Sent when build begins
2. **Build Success** - Sent when build completes successfully
3. **Build Failed** - Sent when build fails with error details

### Email Content
- 📊 Build information (ID, platform, version)
- 🔧 Environment details
- ⏱️ Build duration
- 📦 Artifact information
- 🔗 Download links (if applicable)

## 📦 Artifacts

### Primary Artifacts
```yaml
artifacts:
  # IPA Files
  - output/ios/*.ipa
  - build/ios/ipa/*.ipa
  - ios/build/*.ipa
  - "*.ipa"
  
  # Archive Files (when IPA export fails)
  - output/ios/*.xcarchive
  - build/ios/archive/*.xcarchive
  - ios/build/*.xcarchive
  - "*.xcarchive"
```

### Documentation
```yaml
artifacts:
  # Build Documentation
  - output/ios/ARTIFACTS_SUMMARY.txt
  - ios/ExportOptions.plist
  
  # Build Logs
  - build/ios/logs/
  - output/ios/logs/
  
  # Additional Build Artifacts
  - output/ios/
  - build/ios/
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Certificate Import Failure
**Symptoms**: `security: SecKeychainItemImport: User interaction is not allowed`

**Solutions**:
- ✅ Check certificate password validity
- ✅ Ensure certificate is in correct format (P12)
- ✅ Verify certificate URLs are accessible
- ✅ Check certificate expiration

#### 2. Provisioning Profile Mismatch
**Symptoms**: `Bundle ID mismatch detected`

**Solutions**:
- ✅ Verify BUNDLE_ID matches provisioning profile
- ✅ Check provisioning profile type (app-store, ad-hoc, etc.)
- ✅ Ensure provisioning profile is valid and not expired

#### 3. Firebase Configuration Error
**Symptoms**: `Firebase configuration verification failed`

**Solutions**:
- ✅ Verify FIREBASE_CONFIG_IOS URL is accessible
- ✅ Check GoogleService-Info.plist format
- ✅ Ensure Firebase project is properly configured

#### 4. IPA Export Failure
**Symptoms**: `xcodebuild -exportArchive failed`

**Solutions**:
- ✅ Check ExportOptions.plist configuration
- ✅ Verify code signing setup
- ✅ Ensure App Store Connect API credentials (if using)
- ✅ Try alternative export methods (fastlane)

### Debug Information

#### Environment Variables Check
```bash
# Check all environment variables
env | grep -E "(BUNDLE_ID|VERSION_|APPLE_TEAM_ID|CERT_|PROFILE_|APP_STORE_CONNECT_)"
```

#### Certificate Validation
```bash
# Validate P12 certificate
openssl pkcs12 -in certificate.p12 -noout -passin "pass:your_password"

# Check certificate details
security find-identity -v -p codesigning build.keychain
```

#### Provisioning Profile Validation
```bash
# Validate provisioning profile
security cms -D -i profile.mobileprovision

# Extract profile information
security cms -D -i profile.mobileprovision | plutil -extract Name raw -
```

### Log Analysis

#### Key Log Patterns
- ✅ `✅ Certificate imported successfully` - Certificate setup successful
- ✅ `✅ Provisioning profile installed` - Profile setup successful
- ✅ `✅ IPA export completed successfully` - Build completed
- ❌ `❌ Certificate import failed` - Certificate issue
- ❌ `❌ Bundle ID mismatch` - Profile configuration issue
- ❌ `❌ Export failed` - IPA export issue

#### Debug Commands
```bash
# Check build logs
tail -f build/ios/logs/build.log

# Check keychain status
security list-keychains

# Check installed profiles
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/

# Test individual scripts
./lib/scripts/ios/setup_environment.sh
./lib/scripts/ios/handle_certificates.sh
./lib/scripts/ios/firebase_setup.sh
```

## 📚 Best Practices

### 1. Environment Variables
- ✅ Use descriptive variable names
- ✅ Provide default values where appropriate
- ✅ Validate critical variables in scripts
- ✅ Use secure storage for sensitive data

### 2. Certificate Management
- ✅ Store certificates in secure, accessible locations
- ✅ Use HTTPS URLs for certificate downloads
- ✅ Implement password fallback mechanisms
- ✅ Regular certificate renewal monitoring

### 3. Build Optimization
- ✅ Enable build acceleration features
- ✅ Use appropriate instance types
- ✅ Implement retry logic for transient failures
- ✅ Clean build artifacts between builds

### 4. Error Handling
- ✅ Implement comprehensive error checking
- ✅ Provide detailed error messages
- ✅ Use multiple fallback mechanisms
- ✅ Send notifications for build status

### 5. Security
- ✅ Use App Store Connect API when possible
- ✅ Secure certificate storage
- ✅ Encrypt sensitive configuration
- ✅ Regular security audits

### 6. Script Maintenance
- ✅ Keep scripts modular and focused
- ✅ Use common utility functions
- ✅ Implement comprehensive logging
- ✅ Test scripts independently
- ✅ Document script dependencies

## 🔗 Related Documentation

- [Codemagic iOS Build Documentation](https://docs.codemagic.io/building/building-for-ios/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Fastlane Documentation](https://docs.fastlane.tools/)

---

**Note**: This guide covers the complete iOS workflow configuration with the new modular architecture. For specific implementation details, refer to the individual script files in `lib/scripts/ios/`.
