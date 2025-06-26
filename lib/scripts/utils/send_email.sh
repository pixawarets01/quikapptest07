#!/bin/bash
set -euo pipefail

STATUS=$1
MESSAGE=$2

# Email configuration with provided Gmail credentials
EMAIL_SMTP_SERVER="smtp.gmail.com"
EMAIL_SMTP_PORT="587"
EMAIL_SMTP_USER="prasannasrie@gmail.com"
EMAIL_SMTP_PASS="lrnu krfm aarp urux"
EMAIL_ID=${EMAIL_ID:-"prasannasrie@gmail.com"}  # Default to sender if not set
ENABLE_EMAIL_NOTIFICATIONS=${ENABLE_EMAIL_NOTIFICATIONS:-"true"}  # Enable by default

# App Information
APP_NAME=${APP_NAME:-"Unknown App"}
ORG_NAME=${ORG_NAME:-"Unknown Organization"}
VERSION_NAME=${VERSION_NAME:-"1.0.0"}
VERSION_CODE=${VERSION_CODE:-"1"}
PKG_NAME=${PKG_NAME:-}
BUNDLE_ID=${BUNDLE_ID:-}
USER_NAME=${USER_NAME:-"Unknown User"}

# Feature Flags
PUSH_NOTIFY=${PUSH_NOTIFY:-"false"}
IS_CHATBOT=${IS_CHATBOT:-"false"}
IS_DOMAIN_URL=${IS_DOMAIN_URL:-"false"}
IS_SPLASH=${IS_SPLASH:-"false"}
IS_PULLDOWN=${IS_PULLDOWN:-"false"}
IS_BOTTOMMENU=${IS_BOTTOMMENU:-"false"}
IS_LOAD_IND=${IS_LOAD_IND:-"false"}
IS_CAMERA=${IS_CAMERA:-"false"}
IS_LOCATION=${IS_LOCATION:-"false"}
IS_MIC=${IS_MIC:-"false"}
IS_NOTIFICATION=${IS_NOTIFICATION:-"false"}
IS_CONTACT=${IS_CONTACT:-"false"}
IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
IS_CALENDAR=${IS_CALENDAR:-"false"}
IS_STORAGE=${IS_STORAGE:-"false"}

# Build info
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')
CM_BUILD_ID=${CM_BUILD_ID:-"Unknown"}
CM_PROJECT_ID=${CM_PROJECT_ID:-"Unknown"}

# Signing information
KEY_STORE_URL=${KEY_STORE_URL:-}
FIREBASE_CONFIG_ANDROID=${FIREBASE_CONFIG_ANDROID:-}
FIREBASE_CONFIG_IOS=${FIREBASE_CONFIG_IOS:-}

# Determine signing status
ANDROID_SIGNING="N/A"
IOS_SIGNING="N/A"

# Check if this is an Android build
if [ -f android/app/build.gradle.kts ] || [ -f android/app/build.gradle ]; then
    ANDROID_SIGNING="Debug"
    if [ -n "$KEY_STORE_URL" ] && [ -f android/app/keystore.properties ] && [ -f android/app/keystore.jks ]; then
        ANDROID_SIGNING="Release (Production)"
    elif [ -n "$KEY_STORE_URL" ]; then
        ANDROID_SIGNING="Release (Failed)"
    fi
fi

# Check if this is an iOS build
if [ -f ios/Runner.xcodeproj/project.pbxproj ] || [ -f ios/Runner.xcworkspace/contents.xcworkspacedata ]; then
    IOS_SIGNING="Unsigned"
    if [ -n "${CERT_CER_URL:-}" ] && [ -n "${CERT_KEY_URL:-}" ] && [ -n "${PROFILE_URL:-}" ] && [ -n "${CERT_PASSWORD:-}" ]; then
        if [ -f ios/certificates/cert.p12 ] || [ -f certs/cert.p12 ]; then
            IOS_SIGNING="Signed (Production)"
        else
            IOS_SIGNING="Signed (Failed)"
        fi
    fi
fi

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Function to convert status to uppercase (compatible with all shells)
get_status_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Function to get status badge color
get_status_color() {
    case "$1" in
        "success") echo "#28a745" ;;
        "failure") echo "#dc3545" ;;
        *) echo "#6c757d" ;;
    esac
}

# Function to get feature status badge
get_feature_badge() {
    local feature_value=$1
    if [ "$feature_value" = "true" ]; then
        echo '<span style="background-color: #28a745; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px;">Enabled</span>'
    else
        echo '<span style="background-color: #6c757d; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px;">Disabled</span>'
    fi
}

# Function to generate artifact URLs (adjust based on your Codemagic setup)
get_artifact_urls() {
    local status=$1
    if [ "$status" = "success" ]; then
        cat << EOF
        <div style="margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 8px;">
            <h3 style="margin: 0 0 10px 0; color: #28a745;">📦 Build Artifacts</h3>
            <p style="margin: 5px 0;"><strong>APK:</strong> <a href="https://api.codemagic.io/artifacts/${CM_PROJECT_ID}/${CM_BUILD_ID}/app-release.apk" style="color: #007bff;">Download APK</a></p>
EOF
        if [ -n "$KEY_STORE_URL" ]; then
            echo '            <p style="margin: 5px 0;"><strong>AAB:</strong> <a href="https://api.codemagic.io/artifacts/'${CM_PROJECT_ID}'/'${CM_BUILD_ID}'/app-release.aab" style="color: #007bff;">Download AAB</a></p>'
        fi
        echo '            <p style="margin: 5px 0;"><strong>IPA:</strong> <a href="https://api.codemagic.io/artifacts/'${CM_PROJECT_ID}'/'${CM_BUILD_ID}'/Runner.ipa" style="color: #007bff;">Download IPA</a></p>'
        echo '        </div>'
    fi
}

# Function to get feature status
get_feature_status() {
    local feature="$1"
    if [ "${feature:-false}" = "true" ]; then
        echo "✅ Enabled"
    else
        echo "❌ Disabled"
    fi
}

# Function to generate app details section
generate_app_details() {
    cat << EOF
<div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #2c3e50; margin-bottom: 15px;">📱 App Details</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">App Name:</td><td>${APP_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Version:</td><td>${VERSION_NAME:-N/A} (${VERSION_CODE:-N/A})</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Package Name (Android):</td><td>${PKG_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Bundle ID (iOS):</td><td>${BUNDLE_ID:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Organization:</td><td>${ORG_NAME:-N/A}</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Website:</td><td>${WEB_URL:-N/A}</td></tr>
    </table>
</div>
EOF
}

# Function to generate customization details
generate_customization_details() {
    cat << EOF
<div style="background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #27ae60; margin-bottom: 15px;">🎨 Customization Features</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Custom Logo:</td><td>$(get_feature_status "${LOGO_URL:+true}")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Splash Screen:</td><td>$(get_feature_status "$IS_SPLASH")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Pull to Refresh:</td><td>$(get_feature_status "$IS_PULLDOWN")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Loading Indicator:</td><td>$(get_feature_status "$IS_LOAD_IND")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Bottom Navigation Bar:</td><td>$(get_feature_status "$IS_BOTTOMMENU")</td></tr>
    </table>
</div>
EOF
}

# Function to generate integration details
generate_integration_details() {
    cat << EOF
<div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #1976d2; margin-bottom: 15px;">🔗 Integration Features</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Push Notifications:</td><td>$(get_feature_status "$PUSH_NOTIFY")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Chat Bot:</td><td>$(get_feature_status "$IS_CHATBOT")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Deep Linking:</td><td>$(get_feature_status "$IS_DOMAIN_URL")</td></tr>
    </table>
</div>
EOF
}

# Function to generate permissions details
generate_permissions_details() {
    cat << EOF
<div style="background: #fce4ec; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h3 style="color: #d81b60; margin-bottom: 15px;">🔐 Permissions</h3>
    <table style="width: 100%; border-collapse: collapse;">
        <tr><td style="padding: 5px 0; font-weight: bold;">Camera:</td><td>$(get_feature_status "$IS_CAMERA")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Location:</td><td>$(get_feature_status "$IS_LOCATION")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Microphone:</td><td>$(get_feature_status "$IS_MIC")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Notifications:</td><td>$(get_feature_status "$IS_NOTIFICATION")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Contacts:</td><td>$(get_feature_status "$IS_CONTACT")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Biometric:</td><td>$(get_feature_status "$IS_BIOMETRIC")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Calendar:</td><td>$(get_feature_status "$IS_CALENDAR")</td></tr>
        <tr><td style="padding: 5px 0; font-weight: bold;">Storage:</td><td>$(get_feature_status "$IS_STORAGE")</td></tr>
    </table>
</div>
EOF
}

# Function to generate QuikApp branding footer
generate_branding_footer() {
    cat << EOF
<div style="background: #263238; color: #ffffff; padding: 30px; border-radius: 8px; margin: 30px 0; text-align: center;">
    <h3 style="color: #4fc3f7; margin-bottom: 20px;">🚀 Powered by QuikApp</h3>
    <p style="margin: 10px 0; color: #b0bec5;">Build mobile apps faster with QuikApp's no-code platform</p>
    
    <div style="margin: 20px 0;">
        <a href="https://quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">🌐 Website</a>
        <a href="https://docs.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">📚 Documentation</a>
        <a href="https://support.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">🎧 Support</a>
        <a href="https://community.quikapp.io" style="color: #4fc3f7; text-decoration: none; margin: 0 15px;">👥 Community</a>
    </div>
    
    <hr style="border: none; border-top: 1px solid #37474f; margin: 20px 0;">
    
    <p style="margin: 10px 0; font-size: 12px; color: #78909c;">
        © 2024 QuikApp Technologies. All rights reserved.<br>
        This email was sent automatically by the QuikApp Build System.
    </p>
</div>
EOF
}

# Function to generate troubleshooting steps for failures
generate_troubleshooting_steps() {
    local platform="$1"
    local error_type="$2"
    
    cat << EOF
<div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f44336;">
    <h3 style="color: #c62828; margin-bottom: 15px;">🔧 Troubleshooting Steps</h3>
    
    <h4 style="color: #d32f2f;">Common Solutions:</h4>
    <ol style="color: #424242; line-height: 1.6;">
        <li><strong>Check Environment Variables:</strong>
            <ul>
                <li>Verify all required variables are set correctly</li>
                <li>Ensure URLs are accessible and files are downloadable</li>
                <li>Check API credentials and keys</li>
            </ul>
        </li>
        
        <li><strong>Certificate Issues (iOS):</strong>
            <ul>
                <li>Verify certificate (.cer) and private key (.key) files are valid</li>
                <li>Ensure provisioning profile (.mobileprovision) matches the app</li>
                <li>Verify APPLE_TEAM_ID matches your developer account</li>
            </ul>
        </li>
        
        <li><strong>Keystore Issues (Android):</strong>
            <ul>
                <li>Verify keystore file is accessible at KEY_STORE_URL</li>
                <li>Check CM_KEYSTORE_PASSWORD and CM_KEY_PASSWORD are correct</li>
                <li>Ensure CM_KEY_ALIAS exists in the keystore</li>
            </ul>
        </li>
        
        <li><strong>Firebase Configuration:</strong>
            <ul>
                <li>Verify google-services.json (Android) or GoogleService-Info.plist (iOS) are valid</li>
                <li>Check Firebase project settings match your app</li>
                <li>Ensure package name/bundle ID matches Firebase configuration</li>
            </ul>
        </li>
        
        <li><strong>Build Dependencies:</strong>
            <ul>
                <li>Check Flutter and Dart SDK versions</li>
                <li>Verify Gradle and Android build tools versions</li>
                <li>Clear build cache and regenerate dependencies</li>
            </ul>
        </li>
    </ol>
    
    <h4 style="color: #d32f2f;">Next Steps:</h4>
    <ul style="color: #424242; line-height: 1.6;">
        <li>📋 Check the build logs in Codemagic for detailed error messages</li>
        <li>🔄 Fix the identified issues and restart the build</li>
        <li>📞 Contact support if the issue persists</li>
    </ul>
</div>
EOF
}

# Function to generate individual artifact download URLs
generate_individual_artifact_urls() {
    local platform="$1"
    local build_id="$2"
    
    # Base URL for Codemagic artifacts
    local base_url="https://api.codemagic.io/artifacts"
    local project_id="${CM_PROJECT_ID:-unknown}"
    
    # Scan output directories for actual files
    local artifacts_found=""
    local artifacts_html=""
    
    cat << EOF
    <div style="background: #e8f5e8; padding: 25px; border-radius: 8px; margin: 20px 0; border: 2px solid #27ae60;">
        <h3 style="color: #27ae60; margin-bottom: 20px;">📦 Download Individual Files</h3>
        <p style="margin-bottom: 20px;">Click the links below to download specific app files:</p>
        
        <div style="display: grid; gap: 15px; margin: 20px 0;">
EOF

    # Check for Android artifacts
    if [ -f "output/android/app-release.apk" ]; then
        local apk_size=$(du -h output/android/app-release.apk 2>/dev/null | cut -f1)
        artifacts_found="true"
        cat << EOF
            <div style="background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #27ae60; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h4 style="margin: 0; color: #27ae60;">📱 Android APK</h4>
                    <p style="margin: 5px 0; color: #666; font-size: 14px;">Install directly on Android devices</p>
                    <p style="margin: 0; color: #999; font-size: 12px;">Size: ${apk_size:-Unknown}</p>
                </div>
                <a href="${base_url}/${project_id}/${build_id}/app-release.apk" 
                   style="background: #27ae60; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                   📥 Download APK
                </a>
            </div>
EOF
    fi

    if [ -f "output/android/app-release.aab" ]; then
        local aab_size=$(du -h output/android/app-release.aab 2>/dev/null | cut -f1)
        artifacts_found="true"
        cat << EOF
            <div style="background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #4caf50; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h4 style="margin: 0; color: #4caf50;">📦 Android AAB</h4>
                    <p style="margin: 5px 0; color: #666; font-size: 14px;">Upload to Google Play Store</p>
                    <p style="margin: 0; color: #999; font-size: 12px;">Size: ${aab_size:-Unknown}</p>
                </div>
                <a href="${base_url}/${project_id}/${build_id}/app-release.aab" 
                   style="background: #4caf50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                   📥 Download AAB
                </a>
            </div>
EOF
    fi

    # Check for iOS artifacts
    if [ -f "output/ios/Runner.ipa" ]; then
        local ipa_size=$(du -h output/ios/Runner.ipa 2>/dev/null | cut -f1)
        artifacts_found="true"
        cat << EOF
            <div style="background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #2196f3; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h4 style="margin: 0; color: #2196f3;">🍎 iOS IPA</h4>
                    <p style="margin: 5px 0; color: #666; font-size: 14px;">Upload to App Store Connect or TestFlight</p>
                    <p style="margin: 0; color: #999; font-size: 12px;">Size: ${ipa_size:-Unknown}</p>
                </div>
                <a href="${base_url}/${project_id}/${build_id}/Runner.ipa" 
                   style="background: #2196f3; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                   📥 Download IPA
                </a>
            </div>
EOF
    fi

    # Check for any other files in output directories
    if [ -d "output/android" ]; then
        for file in output/android/*; do
            if [ -f "$file" ] && [[ "$file" != *"app-release.apk" ]] && [[ "$file" != *"app-release.aab" ]]; then
                local filename=$(basename "$file")
                local filesize=$(du -h "$file" 2>/dev/null | cut -f1)
                artifacts_found="true"
                cat << EOF
            <div style="background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #ff9800; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h4 style="margin: 0; color: #ff9800;">📄 ${filename}</h4>
                    <p style="margin: 5px 0; color: #666; font-size: 14px;">Additional Android artifact</p>
                    <p style="margin: 0; color: #999; font-size: 12px;">Size: ${filesize:-Unknown}</p>
                </div>
                <a href="${base_url}/${project_id}/${build_id}/${filename}" 
                   style="background: #ff9800; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                   📥 Download
                </a>
            </div>
EOF
            fi
        done
    fi

    if [ -d "output/ios" ]; then
        for file in output/ios/*; do
            if [ -f "$file" ] && [[ "$file" != *"Runner.ipa" ]]; then
                local filename=$(basename "$file")
                local filesize=$(du -h "$file" 2>/dev/null | cut -f1)
                artifacts_found="true"
                cat << EOF
            <div style="background: #fff; padding: 15px; border-radius: 8px; border: 1px solid #9c27b0; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h4 style="margin: 0; color: #9c27b0;">📄 ${filename}</h4>
                    <p style="margin: 5px 0; color: #666; font-size: 14px;">Additional iOS artifact</p>
                    <p style="margin: 0; color: #999; font-size: 12px;">Size: ${filesize:-Unknown}</p>
                </div>
                <a href="${base_url}/${project_id}/${build_id}/${filename}" 
                   style="background: #9c27b0; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                   📥 Download
                </a>
            </div>
EOF
            fi
        done
    fi

    cat << EOF
        </div>
        
        <div style="background: #f0f8ff; padding: 15px; border-radius: 6px; margin-top: 20px;">
            <h4 style="margin: 0 0 10px 0; color: #1976d2;">📋 Download Instructions:</h4>
            <ul style="margin: 0; padding-left: 20px; color: #424242; line-height: 1.6;">
                <li><strong>APK:</strong> Right-click → "Save As" to download, then install on Android device</li>
                <li><strong>AAB:</strong> Upload directly to Google Play Console for store distribution</li>
                <li><strong>IPA:</strong> Upload to App Store Connect using Xcode or Transporter app</li>
            </ul>
        </div>
    </div>
EOF

    # Add fallback if no artifacts found
    if [ "$artifacts_found" != "true" ]; then
        cat << EOF
        <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
            <h4 style="color: #856404; margin: 0 0 10px 0;">⚠️ No Artifacts Found</h4>
            <p style="color: #856404; margin: 0;">Build completed but no output files were detected. Please check the build logs.</p>
        </div>
EOF
    fi
}

# Function to send build started email
send_build_started_email() {
    local platform="$1"
    local build_id="$2"
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Started</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">🚀 Build Started</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Your QuikApp build process has begun</p>
    </div>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2; margin: 0;">📱 Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
    </div>
    
    $(generate_app_details)
    $(generate_customization_details)
    $(generate_integration_details)
    $(generate_permissions_details)
    
    <div style="background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2;">⏱️ Build Progress</h3>
        <p>Your app is currently being built. You will receive another email when the build completes.</p>
        <p><strong>Estimated Time:</strong> 5-15 minutes</p>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_curl "🚀 QuikApp Build Started - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send build success email with individual URLs
send_build_success_email() {
    local platform="$1"
    local build_id="$2"
    local artifacts_url="$3"  # This is now optional, we generate individual URLs
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Successful</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">🎉 Build Successful!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Your QuikApp has been built successfully</p>
    </div>
    
    <div style="background: #e8f5e8; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #27ae60; margin: 0;">✅ Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
        <p style="margin: 5px 0 0 0; color: #424242;">Build Time: $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
    </div>
    
    $(generate_app_details)
    $(generate_customization_details)
    $(generate_integration_details)
    $(generate_permissions_details)
    
    $(generate_individual_artifact_urls "$platform" "$build_id")
    
    <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
        <h3 style="color: #856404;">📋 Next Steps</h3>
        <ul style="color: #856404; line-height: 1.8;">
            <li><strong>Android (APK):</strong> Download and install directly on device for testing</li>
            <li><strong>Android (AAB):</strong> Upload to Google Play Console for store distribution</li>
            <li><strong>iOS (IPA):</strong> Upload to App Store Connect or distribute via TestFlight</li>
            <li><strong>Testing:</strong> Test the app thoroughly on different devices before publishing</li>
            <li><strong>Distribution:</strong> Share APK files directly or publish to app stores</li>
        </ul>
    </div>
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2;">🔗 Quick Actions</h3>
        <div style="margin: 15px 0;">
            <a href="https://codemagic.io/builds/${build_id}" style="display: inline-block; background: #1976d2; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">📋 View Build Logs</a>
            <a href="https://codemagic.io" style="display: inline-block; background: #27ae60; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">🚀 Start New Build</a>
        </div>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_curl "🎉 QuikApp Build Successful - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send build failed email
send_build_failed_email() {
    local platform="$1"
    local build_id="$2"
    local error_message="$3"
    
    cat << EOF > /tmp/email_content.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>QuikApp Build Failed</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 30px;">
        <h1 style="margin: 0; font-size: 28px;">❌ Build Failed</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">There was an issue with your QuikApp build</p>
    </div>
    
    <div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #c62828; margin: 0;">🔴 Platform: ${platform}</h3>
        <p style="margin: 10px 0 0 0; color: #424242;">Build ID: ${build_id}</p>
    </div>
    
    $(generate_app_details)
    
    <div style="background: #ffebee; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f44336;">
        <h3 style="color: #c62828; margin-bottom: 15px;">⚠️ Error Details</h3>
        <div style="background: #fff; padding: 15px; border-radius: 4px; border: 1px solid #e0e0e0;">
            <code style="color: #d32f2f; font-family: 'Courier New', monospace; white-space: pre-wrap;">${error_message}</code>
        </div>
    </div>
    
    $(generate_troubleshooting_steps "$platform" "build_failed")
    
    <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
        <h3 style="color: #1976d2;">🔄 Ready to Try Again?</h3>
        <p>After fixing the issues above, you can restart your build.</p>
        <a href="https://codemagic.io" style="display: inline-block; background: #1976d2; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">🚀 Restart Build</a>
        <a href="https://codemagic.io/builds/${build_id}" style="display: inline-block; background: #757575; color: white; padding: 12px 25px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 5px;">📋 View Logs</a>
    </div>
    
    $(generate_branding_footer)
    
</body>
</html>
EOF

    send_email_via_curl "❌ QuikApp Build Failed - ${APP_NAME:-Your App}" "/tmp/email_content.html"
}

# Function to send email using curl (lightweight, no installation needed)
send_email_via_curl() {
    local subject="$1"
    local html_file="$2"
    
    # Check if curl is available (it should be on most CI systems)
    if ! command -v curl &> /dev/null; then
        log "⚠️  curl not available, skipping email notification"
        rm -f "$html_file"
        return 0
    fi
    
    # Check if required email variables are set
    if [ -z "$EMAIL_SMTP_USER" ] || [ -z "$EMAIL_SMTP_PASS" ]; then
        log "⚠️  Email credentials not configured, skipping email notification"
        rm -f "$html_file"
        return 0
    fi
    
    # Create temporary email file
    local temp_email_file="/tmp/email_message.txt"
    
    # Build email message
    cat > "$temp_email_file" << EOF
To: ${EMAIL_ID:-$EMAIL_SMTP_USER}
From: $EMAIL_SMTP_USER
Subject: $subject
Content-Type: text/html; charset=UTF-8

$(cat "$html_file")
EOF
    
    # Debug information
    log "📧 Attempting to send email..."
    log "📧 SMTP Server: $EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT"
    log "📧 From: $EMAIL_SMTP_USER"
    log "📧 To: ${EMAIL_ID:-$EMAIL_SMTP_USER}"
    log "📧 Subject: $subject"
    
    # Send email using curl with Gmail SMTP (with verbose error reporting)
    local curl_output="/tmp/curl_output.log"
    local curl_error="/tmp/curl_error.log"
    
    if curl --url "smtps://$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
            --ssl-reqd \
            --mail-from "$EMAIL_SMTP_USER" \
            --mail-rcpt "${EMAIL_ID:-$EMAIL_SMTP_USER}" \
            --upload-file "$temp_email_file" \
            --user "$EMAIL_SMTP_USER:$EMAIL_SMTP_PASS" \
            --max-time 30 \
            --connect-timeout 10 \
            --output "$curl_output" \
            --stderr "$curl_error" \
            --write-out "HTTP_CODE:%{http_code};TIME_TOTAL:%{time_total};SIZE_UPLOAD:%{size_upload}" \
            --verbose 2>&1; then
        log "✅ Email sent successfully to ${EMAIL_ID:-$EMAIL_SMTP_USER}"
        
        # Show curl statistics if available
        if [ -f "$curl_output" ]; then
            local stats=$(cat "$curl_output" 2>/dev/null | tail -1)
            log "📊 Email stats: $stats"
        fi
    else
        local exit_code=$?
        log "❌ Failed to send email notification"
        log "❌ Curl exit code: $exit_code"
        
        # Show detailed error information
        if [ -f "$curl_error" ]; then
            log "❌ Curl error details:"
            cat "$curl_error" | tail -10 | while read line; do
                log "   $line"
            done
        fi
        
        # Try alternative method with different curl options
        log "🔄 Trying alternative email method..."
        if curl --url "smtp://$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" \
                --mail-from "$EMAIL_SMTP_USER" \
                --mail-rcpt "${EMAIL_ID:-$EMAIL_SMTP_USER}" \
                --upload-file "$temp_email_file" \
                --user "$EMAIL_SMTP_USER:$EMAIL_SMTP_PASS" \
                --use-ssl \
                --max-time 30 \
                --silent 2>/dev/null; then
            log "✅ Email sent successfully using alternative method"
        else
            # Try with basic authentication
            log "🔄 Trying basic SMTP without SSL..."
            if curl --url "smtp://$EMAIL_SMTP_SERVER:25" \
                    --mail-from "$EMAIL_SMTP_USER" \
                    --mail-rcpt "${EMAIL_ID:-$EMAIL_SMTP_USER}" \
                    --upload-file "$temp_email_file" \
                    --user "$EMAIL_SMTP_USER:$EMAIL_SMTP_PASS" \
                    --max-time 30 \
                    --silent 2>/dev/null; then
                log "✅ Email sent successfully using basic SMTP"
            else
                log "⚠️  All email sending methods failed (non-critical)"
                
                # Show email content for debugging (first few lines only)
                log "📧 Email content preview:"
                head -10 "$temp_email_file" | while read line; do
                    log "   $line"
                done
            fi
        fi
    fi
    
    # Clean up
    rm -f "$html_file" "$temp_email_file" "$curl_output" "$curl_error"
}

# Main function to handle different email types
send_notification_email() {
    local email_type="$1"
    local platform="$2"
    local build_id="$3"
    local error_message="${4:-No error message provided}"
    
    # Skip email if disabled
    if [ "${ENABLE_EMAIL_NOTIFICATIONS:-true}" = "false" ]; then
        log "📧 Email notifications disabled, skipping $email_type notification"
        return 0
    fi
    
    log "📧 Sending $email_type email for $platform build $build_id"
    
    # Try to use enhanced Python email sender if available
    if command -v python3 >/dev/null 2>&1; then
        log "📧 Using enhanced Python email system..."
        
        # Export environment variables for Python script
        export EMAIL_SMTP_SERVER EMAIL_SMTP_PORT EMAIL_SMTP_USER EMAIL_SMTP_PASS EMAIL_ID
        export ENABLE_EMAIL_NOTIFICATIONS
        export APP_NAME ORG_NAME USER_NAME VERSION_NAME VERSION_CODE WEB_URL
        export CM_BUILD_ID CM_PROJECT_ID WORKFLOW_ID
        export PUSH_NOTIFY IS_CHATBOT IS_DOMAIN_URL IS_SPLASH IS_PULLDOWN IS_BOTTOMMENU IS_LOAD_IND
        export IS_CAMERA IS_LOCATION IS_MIC IS_NOTIFICATION IS_CONTACT IS_BIOMETRIC IS_CALENDAR IS_STORAGE
        export PKG_NAME BUNDLE_ID
        
        # Run the Python email script
        if python3 lib/scripts/utils/send_email.py "$email_type" "$platform" "$build_id" "$error_message"; then
            log "✅ Enhanced Python email sent successfully"
            return 0
        else
            log "❌ Python email failed with exit code $?"
            return 1
        fi
    else
        log "❌ Python3 not available, cannot send email"
        return 1
    fi
}

# Test function to verify email setup
test_email_setup() {
    log "🧪 Testing email configuration..."
    log "📧 SMTP Server: $EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT"
    log "📧 User: $EMAIL_SMTP_USER"
    log "📧 Password length: ${#EMAIL_SMTP_PASS} characters"
    log "📧 Recipient: $EMAIL_ID"
    
    # Test curl availability
    if command -v curl &> /dev/null; then
        log "✅ curl is available"
        curl --version | head -1
    else
        log "❌ curl not found"
        return 1
    fi
    
    # Test basic connectivity to Gmail SMTP
    log "🔗 Testing connection to Gmail SMTP..."
    if curl --connect-timeout 10 --max-time 30 -I "smtp.gmail.com:587" 2>/dev/null; then
        log "✅ Can connect to Gmail SMTP server"
    else
        log "⚠️  Cannot connect to Gmail SMTP server"
    fi
    
    # Send a simple test email
    log "📧 Sending test email..."
    cat > /tmp/test_email.html << EOF
<!DOCTYPE html>
<html>
<head><title>Test Email</title></head>
<body>
    <h2>🧪 QuikApp Email Test</h2>
    <p>This is a test email from your QuikApp build system.</p>
    <p>Time: $(date)</p>
    <p>If you receive this, email notifications are working correctly!</p>
</body>
</html>
EOF
    
    send_email_via_curl "🧪 QuikApp Email Test" "/tmp/test_email.html"
}

# If script is called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -lt 3 ]; then
        echo "Usage: $0 <email_type> <platform> <build_id> [error_message]"
        echo "Email types: build_started, build_success, build_failed"
        exit 1
    fi
    
    send_notification_email "$@"
fi 