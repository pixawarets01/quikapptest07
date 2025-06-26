# Default Email Configuration (can be overridden by API)
export DEFAULT_SMTP_SERVER="smtp.gmail.com"
export DEFAULT_SMTP_PORT="587"
export DEFAULT_SMTP_USER="prasannasrie@gmail.com"
export DEFAULT_SMTP_PASS="jbbf nzhm zoay lbwb"

# Default notification email addresses
export EMAIL_TO="prasannasrinivasan32@gmail.com"
export NOTIFICATION_EMAIL_FROM=$EMAIL_ID

# QuikApp required variables for local/dev builds

#!/bin/bash

# App Info
export APP_NAME="QuikApp"
export VERSION_NAME="1.0.0"
export VERSION_CODE="1"
export PKG_NAME="com.quikapp.app"
export BUNDLE_ID="com.quikapp.app"

# Organization
export ORG_NAME="QuikApp"
export WEB_URL="https://quikapp.co"
export EMAIL_ID="admin@quikapp.co"

# Feature Flags
export PUSH_NOTIFY="false"
export IS_CHATBOT="false"
export IS_DOMAIN_URL="false"
export IS_SPLASH="false"
export IS_PULLDOWN="false"
export IS_BOTTOMMENU="false"
export IS_LOAD_IND="false"

# Permissions
export IS_CAMERA="false"
export IS_LOCATION="false"
export IS_MIC="false"
export IS_NOTIFICATION="false"
export IS_CONTACT="false"
export IS_BIOMETRIC="false"
export IS_CALENDAR="false"
export IS_STORAGE="false"

# UI/Branding
export LOGO_URL=""
export SPLASH_URL=""
export SPLASH_BG=""
export SPLASH_BG_COLOR="#FFFFFF"
export SPLASH_TAGLINE=""
export SPLASH_TAGLINE_COLOR="#000000"
export SPLASH_ANIMATION="fade"
export SPLASH_DURATION="3"

# Bottom Menu Config
export BOTTOMMENU_ITEMS="[]"
export BOTTOMMENU_BG_COLOR="#FFFFFF"
export BOTTOMMENU_ICON_COLOR="#000000"
export BOTTOMMENU_TEXT_COLOR="#000000"
export BOTTOMMENU_FONT="Roboto"
export BOTTOMMENU_FONT_SIZE="12"
export BOTTOMMENU_FONT_BOLD="false"
export BOTTOMMENU_FONT_ITALIC="false"
export BOTTOMMENU_ACTIVE_TAB_COLOR="#0000FF"
export BOTTOMMENU_ICON_POSITION="above"
export BOTTOMMENU_VISIBLE_ON="all"

# Build Environment
export BUILD_MODE="debug"
export FLUTTER_VERSION="3.32.2"
export GRADLE_VERSION="8.0.0"
export JAVA_VERSION="17"
export ANDROID_COMPILE_SDK="34"
export ANDROID_MIN_SDK="21"
export ANDROID_TARGET_SDK="34"
export ANDROID_BUILD_TOOLS="34.0.0"
export ANDROID_NDK_VERSION="27.0.12077973"
export ANDROID_CMDLINE_TOOLS="latest"
export kotlin_version="1.9.0"

# Email Configuration
export EMAIL_SMTP_SERVER="smtp.gmail.com"
export EMAIL_SMTP_PORT="587"
export EMAIL_SMTP_USER="prasannasrie@gmail.com"
export EMAIL_SMTP_PASS="jbbf nzhm zoay lbwb"

# Application Details
export APP_NAME=${APP_NAME:-"Garbcode App"}
export PKG_NAME=${PKG_NAME:-"com.garbcode.garbcodeapp"}
export BUNDLE_ID=${BUNDLE_ID:-"com.garbcode.garbcodeapp"}
export VERSION_NAME=${VERSION_NAME:-"1.0.22"}
export VERSION_CODE=${VERSION_CODE:-"27"}
export OUTPUT_DIR=${OUTPUT_DIR:-"output"}
export ORG_NAME=${ORG_NAME:-"Garbcode Apparels Private Limited"}
export WEB_URL=${WEB_URL:-"https://garbcode.com/"}
export EMAIL_ID=${EMAIL_ID:-"prasannasrinivasan32@gmail.com"}

# Feature Flags
export PUSH_NOTIFY=${PUSH_NOTIFY:-"true"}
export IS_CHATBOT=${IS_CHATBOT:-"true"}
export IS_DOMAIN_URL=${IS_DOMAIN_URL:-"true"}
export IS_SPLASH=${IS_SPLASH:-"true"}
export IS_PULLDOWN=${IS_PULLDOWN:-"true"}
export IS_BOTTOMMENU=${IS_BOTTOMMENU:-"true"}
export IS_LOAD_IND=${IS_LOAD_IND:-"true"}
export IS_CAMERA=${IS_CAMERA:-"false"}
export IS_LOCATION=${IS_LOCATION:-"false"}
export IS_MIC=${IS_MIC:-"true"}
export IS_NOTIFICATION=${IS_NOTIFICATION:-"true"}
export IS_CONTACT=${IS_CONTACT:-"false"}
export IS_BIOMETRIC=${IS_BIOMETRIC:-"false"}
export IS_CALENDAR=${IS_CALENDAR:-"false"}
export IS_STORAGE=${IS_STORAGE:-"true"}

# Asset URLs
export LOGO_URL=${LOGO_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"}
export SPLASH=${SPLASH:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"}
export SPLASH_BG=${SPLASH_BG:-""}

# Splash Screen Customization
export SPLASH_BG_COLOR=${SPLASH_BG_COLOR:-"#cbdbf5"}
export SPLASH_TAGLINE=${SPLASH_TAGLINE:-"Welcome to Garbcode"}
export SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR:-"#a30237"}
export SPLASH_ANIMATION=${SPLASH_ANIMATION:-"zoom"}
export SPLASH_DURATION=${SPLASH_DURATION:-"4"}

# Bottom Menu Configuration
export BOTTOMMENU_ITEMS=${BOTTOMMENU_ITEMS:-'[{"label": "Home", "icon": "home", "url": "https://pixaware.co/"}, {"label": "services", "icon": "services", "url": "https://pixaware.co/solutions/"}, {"label": "About", "icon": "info", "url": "https://pixaware.co/who-we-are/"}, {"label": "Contact", "icon": "phone", "url": "https://pixaware.co/lets-talk/"}]'}
export BOTTOMMENU_BG_COLOR=${BOTTOMMENU_BG_COLOR:-"#FFFFFF"}
export BOTTOMMENU_ICON_COLOR=${BOTTOMMENU_ICON_COLOR:-"#6d6e8c"}
export BOTTOMMENU_TEXT_COLOR=${BOTTOMMENU_TEXT_COLOR:-"#6d6e8c"}
export BOTTOMMENU_FONT=${BOTTOMMENU_FONT:-"DM Sans"}
export BOTTOMMENU_FONT_SIZE=${BOTTOMMENU_FONT_SIZE:-"12"}
export BOTTOMMENU_FONT_BOLD=${BOTTOMMENU_FONT_BOLD:-"false"}
export BOTTOMMENU_FONT_ITALIC=${BOTTOMMENU_FONT_ITALIC:-"false"}
export BOTTOMMENU_ACTIVE_TAB_COLOR=${BOTTOMMENU_ACTIVE_TAB_COLOR:-"#a30237"}
export BOTTOMMENU_ICON_POSITION=${BOTTOMMENU_ICON_POSITION:-"above"}
export BOTTOMMENU_VISIBLE_ON=${BOTTOMMENU_VISIBLE_ON:-"home,settings,profile"}

# Firebase & Apple Developer Configurations
export firebase_config_android=${firebase_config_android:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services (gc).json"}
export firebase_config_ios=${firebase_config_ios:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/GoogleService-Info-gc.plist"}
export APPLE_TEAM_ID=${APPLE_TEAM_ID:-"9H2AD7NQ49"}
export APNS_KEY_ID=${APNS_KEY_ID:-"V566SWNF69"}
export APNS_AUTH_KEY_URL=${APNS_AUTH_KEY_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey_V566SWNF69.p8"}
export CERT_PASSWORD=${CERT_PASSWORD:-"User@54321"}
export PROFILE_URL=${PROFILE_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/Garbcode_App_Store.mobileprovision"}
export CERT_CER_URL=${CERT_CER_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/apple_distribution.cer"}
export CERT_KEY_URL=${CERT_KEY_URL:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"}
export APP_STORE_CONNECT_KEY_IDENTIFIER=${APP_STORE_CONNECT_KEY_IDENTIFIER:-"F5229W2Q8S"}

# Android Keystore Configuration
export KEY_STORE=${KEY_STORE:-"https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"}
export CM_KEYSTORE_PASSWORD=${CM_KEYSTORE_PASSWORD:-"opeN@1234"}
export CM_KEY_ALIAS=${CM_KEY_ALIAS:-"my_key_alias"}
export CM_KEY_PASSWORD=${CM_KEY_PASSWORD:-"opeN@1234"}

## Local environment variables for development and testing
## These variables will override values set in lib/scripts/utils/variables.sh if sourced.
#
#export APP_NAME="MyTestApp"
#export PKG_NAME="com.example.mytestapp"
#export BUNDLE_ID="com.example.mytestapp.ios"
#export VERSION_NAME="1.0.0-test"
#export VERSION_CODE="1"
#export OUTPUT_DIR="output"
#
## Firebase (ensure these URLs are valid for testing)
#export firebase_config_android="https://raw.githubusercontent.com/prasanna91/QuikApp/main/google-services-gc.json"
#export firebase_config_ios="https://raw.githubusercontent.com/prasanna91/QuikApp/main/GoogleService-Info-gc.plist"
#
## Keystore (for Android-Publish testing)
## export KEY_STORE="/path/to/your/test_keystore.jks"
## export CM_KEYSTORE_PASSWORD="your_test_keystore_password"
## export CM_KEY_ALIAS="your_test_key_alias"
## export CM_KEY_PASSWORD="your_test_key_password"
#
## Push Notifications (set to true/false for testing workflow logic)
#export PUSH_NOTIFY="true"
#
## Other variables (can be customized as needed)
#export ORG_NAME="Test Organization"
#export WEB_URL="https://test.example.com"
#export EMAIL_ID="test@example.com"
#export IS_CHATBOT="false"
#export IS_DOMAIN_URL="false"
#export IS_SPLASH="true"
#export IS_PULLDOWN="true"
#export IS_BOTTOMMENU="false"
#export IS_LOAD_IND="true"
#export IS_CAMERA="false"
#export IS_LOCATION="false"
#export IS_MIC="true"
#export IS_NOTIFICATION="true"
#export IS_CONTACT="false"
#export IS_BIOMETRIC="false"
#export IS_CALENDAR="false"
#export IS_STORAGE="true"
#export LOGO_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"
#export SPLASH="https://raw.githubusercontent.com/prasanna91/QuikApp/main/logo-gc.png"
#export SPLASH_BG=""
#export SPLASH_BG_COLOR="#cbdbf5"
#export SPLASH_TAGLINE="Welcome to Test App"
#export SPLASH_TAGLINE_COLOR="#a30237"
#export SPLASH_ANIMATION="zoom"
#export SPLASH_DURATION="4"
#export BOTTOMMENU_ITEMS='[{"label": "Home", "icon": "home", "url": "https://test.pixaware.co/"}]'
#export BOTTOMMENU_BG_COLOR="#F0F0F0"
#export BOTTOMMENU_ICON_COLOR="#666666"
#export BOTTOMMENU_TEXT_COLOR="#333333"
#export BOTTOMMENU_FONT="Arial"
#export BOTTOMMENU_FONT_SIZE="14"
#export BOTTOMMENU_FONT_BOLD="false"
#export BOTTOMMENU_FONT_ITALIC="false"
#export BOTTOMMENU_ACTIVE_TAB_COLOR="#FF0000"
#export BOTTOMMENU_ICON_POSITION="above"
#export BOTTOMMENU_VISIBLE_ON="home"
#
## iOS Signing Variables (for iOS-Only or Combined workflow testing)
## export APPLE_TEAM_ID="YOUR_APPLE_TEAM_ID"
## export APNS_KEY_ID="YOUR_APNS_KEY_ID"
## export APNS_AUTH_KEY_URL="/path/to/your/AuthKey.p8"
## export CERT_PASSWORD="your_cert_password"
## export PROFILE_URL="/path/to/your/profile.mobileprovision"
## export CERT_CER_URL="/path/to/your/apple_distribution.cer"
## export CERT_KEY_URL="/path/to/your/privatekey.key"
## export APP_STORE_CONNECT_KEY_IDENTIFIER="YOUR_APP_STORE_KEY_ID"

# iOS Signing Variables
export CERT_CER_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/apple_distribution.cer"
export CERT_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"
export PROFILE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/Garbcode_App_Store.mobileprovision"
export CERT_PASSWORD="your_cert_password"
export APPLE_TEAM_ID="your_team_id"
export APNS_KEY_ID="your_apns_key_id"
export APNS_AUTH_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/AuthKey.p8"
export APP_STORE_CONNECT_KEY_IDENTIFIER="your_key_identifier"
export BUNDLE_ID="com.garbcode.garbcodeapp"
export PROFILE_TYPE="app-store"

# Email Configuration
export EMAIL_SMTP_SERVER="smtp.gmail.com"
export EMAIL_SMTP_PORT="587"
export EMAIL_SMTP_USER="prasannasrie@gmail.com"
export EMAIL_SMTP_PASS="lrnu krfm aarp urux"
export EMAIL_ID="prasannasrinivasan32@gmail.com"
export ENABLE_EMAIL_NOTIFICATIONS="true"

# App Information
export APP_NAME="Garbcode App"
export ORG_NAME="Garbcode"
export VERSION_NAME="1.0.0"
export VERSION_CODE="1"
export WEB_URL="https://garbcode.com"
export USER_NAME="Prasanna"

# Feature Flags
export PUSH_NOTIFY="true"
export IS_CHATBOT="false"
export IS_DOMAIN_URL="false"
export IS_SPLASH="true"
export IS_PULLDOWN="true"
export IS_BOTTOMMENU="true"
export IS_LOAD_IND="true"

# Permissions
export IS_CAMERA="false"
export IS_LOCATION="false"
export IS_MIC="true"
export IS_NOTIFICATION="true"
export IS_CONTACT="false"
export IS_BIOMETRIC="false"
export IS_CALENDAR="false"
export IS_STORAGE="true"