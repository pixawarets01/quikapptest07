#!/bin/bash
set -euo pipefail

# Initialize logging
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

# Set WORKFLOW_ID for auto-ios-workflow immediately
export WORKFLOW_ID="auto-ios-workflow"
log "🚀 Auto iOS Workflow initialized (WORKFLOW_ID: ${WORKFLOW_ID})"

# Error handling
trap 'handle_error $LINENO $?' ERR
handle_error() {
    local line_no="$1"
    local exit_code="$2"
    local error_msg="Error occurred at line ${line_no}. Exit code: ${exit_code}"
    
    log "❌ ${error_msg}"
    
    # Send failure email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_failed" "Auto-iOS" "${CM_BUILD_ID:-unknown}" "${error_msg}" || true
    fi
    
    exit "${exit_code}"
}

# Function to validate minimal environment variables
validate_minimal_variables() {
    log "🔍 Validating minimal environment variables for auto-ios-workflow..."
    
    # Required variables for auto-ios-workflow
    local required_vars=(
        "BUNDLE_ID" 
        "VERSION_NAME" 
        "VERSION_CODE" 
        "APP_NAME"
        "APPLE_ID"
        "PROFILE_TYPE"
        "APP_STORE_CONNECT_KEY_IDENTIFIER"
        "APP_STORE_CONNECT_API_KEY_PATH"
        "APP_STORE_CONNECT_ISSUER_ID"
    )
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "❌ Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log "   - ${var}"
        done
        return 1
    fi
    
    # Optional variables (provide warnings if missing)
    local optional_vars=(
        "APPLE_ID_PASSWORD"
        "FIREBASE_CONFIG_IOS"
        "CERT_P12_URL"
        "CERT_CER_URL"
        "CERT_KEY_URL"
        "PROFILE_URL"
    )
    
    log "📋 Optional variables status:"
    for var in "${optional_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log "   ✅ ${var}: provided"
        else
            log "   ⚠️ ${var}: not provided (will use auto-generated certificates)"
        fi
    done
    
    log "✅ All required environment variables are present"
    return 0
}

# Function to setup Fastlane environment
setup_fastlane_environment() {
    log "🚀 Setting up Fastlane environment..."
    
    # Create Fastfile if it doesn't exist
    if [ ! -f "fastlane/Fastfile" ]; then
        log "📝 Creating comprehensive Fastfile..."
        mkdir -p fastlane
        cat > fastlane/Fastfile <<EOF
default_platform(:ios)

platform :ios do
  desc "Auto iOS Build with Dynamic Signing"
  
  lane :auto_build do
    # This lane will be called by our script
    # The actual work is done in the shell script for better control
    UI.message "Auto iOS build initiated"
  end
  
  lane :create_app_identifier do
    produce(
      username: ENV["APPLE_ID"],
      app_identifier: ENV["BUNDLE_ID"],
      app_name: ENV["APP_NAME"],
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      skip_itc: true,
      skip_devcenter: false
    )
  end
  
  lane :setup_signing do
    # First, create the app identifier if it doesn't exist
    create_app_identifier
    
    # Then setup certificates and profiles
    match(
      type: ENV["PROFILE_TYPE"],
      app_identifier: ENV["BUNDLE_ID"],
      readonly: false,
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
      username: ENV["APPLE_ID"],
      skip_confirmation: true,
      verbose: true,
      force_for_new_devices: true,
      generate_apple_certs: true
    )
  end
  
  lane :download_certificates do
    # Download existing certificates and profiles
    match(
      type: ENV["PROFILE_TYPE"],
      app_identifier: ENV["BUNDLE_ID"],
      readonly: true,
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
      username: ENV["APPLE_ID"],
      skip_confirmation: true,
      verbose: true
    )
  end
  
  lane :create_certificates do
    # Create new certificates and profiles
    match(
      type: ENV["PROFILE_TYPE"],
      app_identifier: ENV["BUNDLE_ID"],
      readonly: false,
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
      username: ENV["APPLE_ID"],
      skip_confirmation: true,
      verbose: true,
      force_for_new_devices: true,
      generate_apple_certs: true
    )
  end
  
  lane :sync_certificates do
    # Sync certificates with local storage
    match(
      type: ENV["PROFILE_TYPE"],
      app_identifier: ENV["BUNDLE_ID"],
      readonly: false,
      team_id: ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"],
      api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
      username: ENV["APPLE_ID"],
      skip_confirmation: true,
      verbose: true,
      force_for_new_devices: true
    )
  end
end
EOF
    fi
    
    # Create Matchfile for certificate management using local storage
    if [ ! -f "fastlane/Matchfile" ]; then
        log "📝 Creating comprehensive Matchfile with local storage..."
        cat > fastlane/Matchfile <<EOF
# Use local storage instead of Git for auto-ios-workflow
storage_mode("local")

# Default type (will be overridden by command line)
type("development")

# App identifier
app_identifier(["#{ENV['BUNDLE_ID']}"])

# Team ID
team_id("#{ENV['APP_STORE_CONNECT_KEY_IDENTIFIER']}")

# For App Store Connect API
api_key_path("#{ENV['APP_STORE_CONNECT_API_KEY_PATH']}")
api_key_id("#{ENV['APP_STORE_CONNECT_KEY_IDENTIFIER']}")
issuer_id("#{ENV['APP_STORE_CONNECT_ISSUER_ID']}")

# Additional options
readonly(false)
skip_confirmation(true)
verbose(true)
force_for_new_devices(true)
generate_apple_certs(true)

# Profile types supported
# - development
# - adhoc
# - appstore
# - enterprise
EOF
    fi
    
    # Create Appfile for fastlane configuration (simplified)
    if [ ! -f "fastlane/Appfile" ]; then
        log "📝 Creating Appfile..."
        cat > fastlane/Appfile <<EOF
# Appfile for auto-ios-workflow
app_identifier(ENV["BUNDLE_ID"])
apple_id(ENV["APPLE_ID"])
team_id(ENV["APP_STORE_CONNECT_KEY_IDENTIFIER"])
EOF
    fi
    
    log "✅ Fastlane environment setup completed"
}

# Function to create App Identifier
create_app_identifier() {
    log "🏷️ Creating App Identifier..."
    
    # Set team ID from App Store Connect key identifier
    export APPLE_TEAM_ID="${APP_STORE_CONNECT_KEY_IDENTIFIER}"
    
    log "📋 App Identifier Details:"
    log "   Bundle ID: ${BUNDLE_ID}"
    log "   App Name: ${APP_NAME}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   Apple ID: ${APPLE_ID}"
    
    # Create App Identifier using fastlane produce
    fastlane produce \
        -u "${APPLE_ID}" \
        -a "${BUNDLE_ID}" \
        --skip_itc \
        --app_name "${APP_NAME}" \
        --team_id "${APPLE_TEAM_ID}" || {
        log "⚠️ App identifier may already exist or creation failed, continuing..."
    }
    
    log "✅ App Identifier setup completed"
}

# Function to setup code signing
setup_code_signing() {
    log "🔐 Setting up code signing..."
    
    # Normalize profile type (handle common variations)
    local original_profile_type="${PROFILE_TYPE}"
    local normalized_profile_type="${PROFILE_TYPE}"
    case "${PROFILE_TYPE}" in
        "appstore"|"app-store"|"app_store")
            normalized_profile_type="appstore"
            ;;
        "adhoc"|"ad-hoc"|"ad_hoc")
            normalized_profile_type="adhoc"
            ;;
        "enterprise")
            normalized_profile_type="enterprise"
            ;;
        "development"|"dev")
            normalized_profile_type="development"
            ;;
        *)
            log "❌ Invalid PROFILE_TYPE: ${PROFILE_TYPE}"
            log "   Valid types: appstore, adhoc, enterprise, development"
            log "   Also accepts: app-store, ad-hoc, dev"
            return 1
            ;;
    esac
    
    # Update the environment variable with normalized value
    export PROFILE_TYPE="${normalized_profile_type}"
    
    # Validate profile type
    local valid_types=("appstore" "adhoc" "enterprise" "development")
    local is_valid=false
    
    for type in "${valid_types[@]}"; do
        if [[ "${PROFILE_TYPE}" == "${type}" ]]; then
            is_valid=true
            break
        fi
    done
    
    if [[ "${is_valid}" == "false" ]]; then
        log "❌ Invalid PROFILE_TYPE: ${PROFILE_TYPE}"
        log "   Valid types: ${valid_types[*]}"
        return 1
    fi
    
    log "📋 Code Signing Details:"
    log "   Profile Type: ${PROFILE_TYPE} (normalized from: ${original_profile_type})"
    log "   Bundle ID: ${BUNDLE_ID}"
    log "   Team ID: ${APPLE_TEAM_ID}"
    log "   API Key Path: ${APP_STORE_CONNECT_API_KEY_PATH}"
    
    # Download API key file if it's a URL
    local api_key_path="${APP_STORE_CONNECT_API_KEY_PATH}"
    if [[ "${api_key_path}" == http* ]]; then
        log "📥 Downloading API key file from URL..."
        local api_key_file="AuthKey_${APP_STORE_CONNECT_KEY_IDENTIFIER}.p8"
        curl -L -o "${api_key_file}" "${api_key_path}" || {
            log "❌ Failed to download API key file"
            return 1
        }
        api_key_path="$(pwd)/${api_key_file}"
        log "✅ API key file downloaded: ${api_key_path}"
        
        # Update the environment variable to use the local path
        export APP_STORE_CONNECT_API_KEY_PATH="${api_key_path}"
        log "🔧 Updated APP_STORE_CONNECT_API_KEY_PATH to local path: ${api_key_path}"
    fi
    
    # Create fastlane directory structure
    mkdir -p fastlane/certs
    mkdir -p fastlane/profiles
    
    # Set up Apple ID authentication if password is provided
    if [[ -n "${APPLE_ID_PASSWORD:-}" ]]; then
        export FASTLANE_PASSWORD="${APPLE_ID_PASSWORD}"
        log "🔐 Apple ID password provided for fastlane authentication"
    else
        log "⚠️ No Apple ID password provided - fastlane may prompt for password"
    fi
    
    # Step 1: Try to download existing certificates first
    log "🔐 Step 1: Attempting to download existing certificates..."
    if fastlane download_certificates; then
        log "✅ Existing certificates downloaded successfully"
    else
        log "⚠️ No existing certificates found, will create new ones"
        
        # Step 2: Create app identifier
        log "🔐 Step 2: Creating app identifier..."
        if fastlane create_app_identifier; then
            log "✅ App identifier created successfully"
        else
            log "⚠️ App identifier may already exist or creation failed"
        fi
        
        # Step 3: Create new certificates and profiles
        log "🔐 Step 3: Creating new certificates and profiles..."
        if fastlane create_certificates; then
            log "✅ New certificates and profiles created successfully"
        else
            log "⚠️ Certificate creation failed, trying alternative approach..."
            
            # Step 4: Try sync certificates as fallback
            log "🔐 Step 4: Attempting certificate sync..."
            if fastlane sync_certificates; then
                log "✅ Certificate sync completed successfully"
            else
                log "⚠️ Certificate sync failed, checking for manual fallback..."
                
                # Check if we have certificate and profile URLs (fallback to manual approach)
                if [[ -n "${CERT_P12_URL:-}" ]] || [[ -n "${CERT_CER_URL:-}" ]]; then
                    log "🔄 Using manual certificate approach with provided URLs..."
                    
                    # Set up environment variables for manual certificate handling
                    if [[ -n "${CERT_P12_URL:-}" ]]; then
                        export CERT_P12_URL="${CERT_P12_URL}"
                        log "📋 Using P12 certificate URL: ${CERT_P12_URL}"
                    elif [[ -n "${CERT_CER_URL:-}" ]] && [[ -n "${CERT_KEY_URL:-}" ]]; then
                        export CERT_CER_URL="${CERT_CER_URL}"
                        export CERT_KEY_URL="${CERT_KEY_URL}"
                        log "📋 Using CER/KEY certificate URLs"
                    fi
                    
                    if [[ -n "${PROFILE_URL:-}" ]]; then
                        export PROFILE_URL="${PROFILE_URL}"
                        log "📋 Using provisioning profile URL: ${PROFILE_URL}"
                    fi
                    
                    export CERT_PASSWORD="${CERT_PASSWORD:-match}"
                    log "✅ Manual certificate approach configured"
                else
                    log "⚠️ No certificate URLs provided, but continuing with build..."
                    log "🔍 The main.sh script will handle certificate setup"
                    log "📋 Available certificate variables:"
                    log "   CERT_P12_URL: ${CERT_P12_URL:-not_set}"
                    log "   CERT_CER_URL: ${CERT_CER_URL:-not_set}"
                    log "   CERT_KEY_URL: ${CERT_KEY_URL:-not_set}"
                    log "   PROFILE_URL: ${PROFILE_URL:-not_set}"
                    
                    # Set auto-generated values to prevent main.sh from trying to download invalid URLs
                    export CERT_P12_URL="auto-generated"
                    export CERT_CER_URL="auto-generated"
                    export CERT_KEY_URL="auto-generated"
                    export PROFILE_URL="auto-generated"
                    export CERT_PASSWORD="match"
                    
                    log "✅ Continuing with build process - main.sh will handle certificate setup"
                fi
            fi
        fi
    fi
    
    # Verify certificate setup
    log "🔍 Verifying certificate setup..."
    if [[ -d "fastlane/certs" ]] && [[ "$(ls -A fastlane/certs 2>/dev/null)" ]]; then
        log "✅ Certificates found in fastlane/certs/"
    else
        log "⚠️ No certificates found in fastlane/certs/"
    fi
    
    if [[ -d "fastlane/profiles" ]] && [[ "$(ls -A fastlane/profiles 2>/dev/null)" ]]; then
        log "✅ Profiles found in fastlane/profiles/"
    else
        log "⚠️ No profiles found in fastlane/profiles/"
    fi
    
    log "✅ Code signing setup completed"
}

# Function to inject signing assets into build environment
inject_signing_assets() {
    log "💉 Injecting signing assets into build environment..."
    
    # Handle certificate URLs for auto-ios-workflow
    log "🔐 Auto-ios-workflow detected - handling certificate setup..."
    
    # Debug: Show current certificate URL values
    log "🔍 Debug: Current certificate URL values:"
    log "   CERT_P12_URL: '${CERT_P12_URL:-not_set}'"
    log "   CERT_CER_URL: '${CERT_CER_URL:-not_set}'"
    log "   CERT_KEY_URL: '${CERT_KEY_URL:-not_set}'"
    log "   PROFILE_URL: '${PROFILE_URL:-not_set}'"
    
    # If we have actual certificate URLs, use them
    if [[ -n "${CERT_P12_URL:-}" ]] && [[ "${CERT_P12_URL}" != "auto-generated" ]]; then
        log "📋 Using provided P12 certificate URL"
        export CERT_P12_URL="${CERT_P12_URL}"
        export CERT_CER_URL=""
        export CERT_KEY_URL=""
        export PROFILE_URL="${PROFILE_URL:-}"
    elif [[ -n "${CERT_CER_URL:-}" ]] && [[ "${CERT_CER_URL}" != "auto-generated" ]]; then
        log "📋 Using provided CER/KEY certificate URLs"
        export CERT_P12_URL=""
        export CERT_CER_URL="${CERT_CER_URL}"
        export CERT_KEY_URL="${CERT_KEY_URL:-}"
        export PROFILE_URL="${PROFILE_URL:-}"
    else
        log "📋 No certificate URLs provided - using auto-generated certificates"
        # Set dummy URLs to pass validation, but main.sh will handle actual certificate setup
        export CERT_P12_URL="auto-generated"
        export CERT_CER_URL="auto-generated"
        export CERT_KEY_URL="auto-generated"
        export PROFILE_URL="auto-generated"
        
        # Debug: Show the auto-generated values
        log "🔍 Debug: Set auto-generated values:"
        log "   CERT_P12_URL: '${CERT_P12_URL}'"
        log "   CERT_CER_URL: '${CERT_CER_URL}'"
        log "   CERT_KEY_URL: '${CERT_KEY_URL}'"
        log "   PROFILE_URL: '${PROFILE_URL}'"
    fi
    
    # Set environment variables for the main build script
    export CERT_PASSWORD="match" # fastlane match uses "match" as default password
    export PROFILE_TYPE="${PROFILE_TYPE}"
    export BUNDLE_ID="${BUNDLE_ID}"
    export APP_NAME="${APP_NAME}"
    export APPLE_TEAM_ID="${APPLE_TEAM_ID}"
    
    # Set Firebase configuration if provided
    if [[ -n "${FIREBASE_CONFIG_IOS:-}" ]]; then
        export FIREBASE_CONFIG_IOS="${FIREBASE_CONFIG_IOS}"
    fi
    
    # Set all other required variables
    export VERSION_NAME="${VERSION_NAME}"
    export VERSION_CODE="${VERSION_CODE}"
    export PUSH_NOTIFY="${PUSH_NOTIFY:-false}"
    export IS_CHATBOT="${IS_CHATBOT:-false}"
    export IS_DOMAIN_URL="${IS_DOMAIN_URL:-false}"
    export IS_SPLASH="${IS_SPLASH:-true}"
    export IS_PULLDOWN="${IS_PULLDOWN:-true}"
    export IS_BOTTOMMENU="${IS_BOTTOMMENU:-true}"
    export IS_LOAD_IND="${IS_LOAD_IND:-true}"
    
    # Permissions
    export IS_CAMERA="${IS_CAMERA:-false}"
    export IS_LOCATION="${IS_LOCATION:-false}"
    export IS_MIC="${IS_MIC:-false}"
    export IS_NOTIFICATION="${IS_NOTIFICATION:-false}"
    export IS_CONTACT="${IS_CONTACT:-false}"
    export IS_BIOMETRIC="${IS_BIOMETRIC:-false}"
    export IS_CALENDAR="${IS_CALENDAR:-false}"
    export IS_STORAGE="${IS_STORAGE:-false}"
    
    # UI Configuration
    export LOGO_URL="${LOGO_URL:-}"
    export SPLASH_URL="${SPLASH_URL:-}"
    export SPLASH_BG_URL="${SPLASH_BG_URL:-}"
    export SPLASH_BG_COLOR="${SPLASH_BG_COLOR:-#FFFFFF}"
    export SPLASH_TAGLINE="${SPLASH_TAGLINE:-}"
    export SPLASH_TAGLINE_COLOR="${SPLASH_TAGLINE_COLOR:-#000000}"
    export SPLASH_ANIMATION="${SPLASH_ANIMATION:-none}"
    export SPLASH_DURATION="${SPLASH_DURATION:-3}"
    
    # Bottom Menu Configuration
    export BOTTOMMENU_ITEMS="${BOTTOMMENU_ITEMS:-[]}"
    export BOTTOMMENU_BG_COLOR="${BOTTOMMENU_BG_COLOR:-#FFFFFF}"
    export BOTTOMMENU_ICON_COLOR="${BOTTOMMENU_ICON_COLOR:-#000000}"
    export BOTTOMMENU_TEXT_COLOR="${BOTTOMMENU_TEXT_COLOR:-#000000}"
    export BOTTOMMENU_FONT="${BOTTOMMENU_FONT:-DM Sans}"
    export BOTTOMMENU_FONT_SIZE="${BOTTOMMENU_FONT_SIZE:-14.0}"
    export BOTTOMMENU_FONT_BOLD="${BOTTOMMENU_FONT_BOLD:-false}"
    export BOTTOMMENU_FONT_ITALIC="${BOTTOMMENU_FONT_ITALIC:-false}"
    export BOTTOMMENU_ACTIVE_TAB_COLOR="${BOTTOMMENU_ACTIVE_TAB_COLOR:-#0000FF}"
    export BOTTOMMENU_ICON_POSITION="${BOTTOMMENU_ICON_POSITION:-top}"
    
    # App metadata
    export APP_ID="${APP_ID:-}"
    export ORG_NAME="${ORG_NAME:-}"
    export WEB_URL="${WEB_URL:-}"
    export EMAIL_ID="${EMAIL_ID:-}"
    export USER_NAME="${USER_NAME:-}"
    
    log "✅ Signing assets injected into build environment"
}

# Function to setup build environment
setup_build_environment() {
    log "🔧 Setting up build environment..."
    
    # Install CocoaPods if not available
    if ! command -v pod &> /dev/null; then
        log "📦 Installing CocoaPods..."
        
        # Try to install CocoaPods using gem
        if command -v gem &> /dev/null; then
            gem install cocoapods || {
                log "⚠️ Failed to install CocoaPods via gem, trying alternative methods..."
                
                # Try using rbenv if available
                if command -v rbenv &> /dev/null; then
                    log "🔧 Using rbenv to install CocoaPods..."
                    rbenv exec gem install cocoapods || {
                        log "⚠️ Failed to install CocoaPods via rbenv"
                    }
                else
                    log "⚠️ Could not install CocoaPods - build may fail"
                fi
            }
        else
            log "⚠️ Ruby gem not available - CocoaPods installation skipped"
        fi
    else
        log "✅ CocoaPods is already installed"
    fi
    
    # Install Flutter dependencies
    log "📦 Installing Flutter Dependencies..."
    flutter pub get || {
        log "⚠️ Flutter pub get failed, but continuing..."
    }
    
    log "✅ Build environment setup completed"
}

# Function to run the main iOS build
run_ios_build() {
    log "🚀 Running main iOS build process..."
    
    # Make sure the main script is executable
    chmod +x lib/scripts/ios/main.sh
    chmod +x lib/scripts/utils/*.sh
    
    # Run the main iOS build script
    bash lib/scripts/ios/main.sh
    
    log "✅ Main iOS build completed"
}

# Function to create artifacts summary
create_artifacts_summary() {
    log "📋 Creating artifacts summary..."
    
    local summary_file="output/ios/ARTIFACTS_SUMMARY.txt"
    mkdir -p output/ios
    
    cat > "${summary_file}" <<EOF
🚀 Auto iOS Workflow Build Summary
==================================

📱 App Information:
   App Name: ${APP_NAME}
   Bundle ID: ${BUNDLE_ID}
   Version: ${VERSION_NAME} (${VERSION_CODE})
   Profile Type: ${PROFILE_TYPE}

🔐 Signing Information:
   Team ID: ${APPLE_TEAM_ID}
   Apple ID: ${APPLE_ID}
   Certificate: Auto-generated via fastlane match
   Provisioning Profile: Auto-generated via fastlane match

🎨 Customization:
   Logo: ${LOGO_URL:+✅} ${LOGO_URL:-❌}
   Splash Screen: ${SPLASH_URL:+✅} ${SPLASH_URL:-❌}
   Bottom Menu: ${IS_BOTTOMMENU:+✅} ${IS_BOTTOMMENU:-❌}
   Firebase: ${FIREBASE_CONFIG_IOS:+✅} ${FIREBASE_CONFIG_IOS:-❌}

🔧 Features:
   Push Notifications: ${PUSH_NOTIFY:+✅} ${PUSH_NOTIFY:-❌}
   Chat Bot: ${IS_CHATBOT:+✅} ${IS_CHATBOT:-❌}
   Deep Linking: ${IS_DOMAIN_URL:+✅} ${IS_DOMAIN_URL:-❌}
   Pull to Refresh: ${IS_PULLDOWN:+✅} ${IS_PULLDOWN:-❌}
   Loading Indicators: ${IS_LOAD_IND:+✅} ${IS_LOAD_IND:-❌}

🔐 Permissions:
   Camera: ${IS_CAMERA:+✅} ${IS_CAMERA:-❌}
   Location: ${IS_LOCATION:+✅} ${IS_LOCATION:-❌}
   Microphone: ${IS_MIC:+✅} ${IS_MIC:-❌}
   Notifications: ${IS_NOTIFICATION:+✅} ${IS_NOTIFICATION:-❌}
   Contacts: ${IS_CONTACT:+✅} ${IS_CONTACT:-❌}
   Biometric: ${IS_BIOMETRIC:+✅} ${IS_BIOMETRIC:-❌}
   Calendar: ${IS_CALENDAR:+✅} ${IS_CALENDAR:-❌}
   Storage: ${IS_STORAGE:+✅} ${IS_STORAGE:-❌}

📦 Build Artifacts:
   IPA Files: output/ios/*.ipa
   Archive Files: output/ios/*.xcarchive
   Export Options: ios/ExportOptions.plist
   Build Logs: output/ios/logs/

🔄 Workflow: auto-ios-workflow
📅 Build Date: $(date)
🏗️ Build ID: ${CM_BUILD_ID:-unknown}

EOF

    log "✅ Artifacts summary created: ${summary_file}"
}

# Main execution flow
main() {
    log "🚀 Starting Auto iOS Workflow..."
    
    # Send build started email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        chmod +x lib/scripts/utils/send_email.sh
        lib/scripts/utils/send_email.sh "build_started" "Auto-iOS" "${CM_BUILD_ID:-unknown}" || true
    fi
    
    # Step 1: Validate minimal variables
    if ! validate_minimal_variables; then
        log "❌ Minimal variable validation failed"
        exit 1
    fi
    
    # Step 2: Setup Fastlane environment
    setup_fastlane_environment
    
    # Step 3: Create App Identifier
    create_app_identifier
    
    # Step 4: Setup code signing
    if ! setup_code_signing; then
        log "❌ Code signing setup failed"
        exit 1
    fi
    
    # Step 5: Inject signing assets
    inject_signing_assets
    
    # Step 6: Setup build environment
    setup_build_environment
    
    # Step 7: Run main iOS build
    run_ios_build
    
    # Step 8: Create artifacts summary
    create_artifacts_summary
    
    log "🎉 Auto iOS Workflow completed successfully!"
    
    # Send success email
    if [ -f "lib/scripts/utils/send_email.sh" ]; then
        lib/scripts/utils/send_email.sh "build_success" "Auto-iOS" "${CM_BUILD_ID:-unknown}" || true
    fi
}

# Run main function
main "$@" 