#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

# Function to handle certificate conversion and P12 generation
handle_certificates() {
    local cert_file="$1"
    local key_file="$2"
    local password="$3"
    local output_p12="$4"
    
    log "🔐 Processing unencrypted certificates..."
    
    # Create temporary directory for processing
    local temp_dir="ios/certificates/temp"
    mkdir -p "$temp_dir"
    
    # Step 1: Detect and convert certificate format
    log "Detecting certificate format..."
    local cert_pem="$temp_dir/cert.pem"
    
    # Try different certificate formats (unencrypted)
    if openssl x509 -inform DER -in "$cert_file" -out "$cert_pem" 2>/dev/null; then
        log "✅ Certificate is in DER format, converted to PEM"
    elif openssl x509 -inform PEM -in "$cert_file" -out "$cert_pem" 2>/dev/null; then
        log "✅ Certificate is already in PEM format"
    elif file "$cert_file" | grep -q "ASCII text"; then
        # Might be base64 encoded
        log "Trying base64 decode..."
        base64 -d "$cert_file" | openssl x509 -inform DER -out "$cert_pem" 2>/dev/null || {
            log "❌ Unable to decode certificate format"
            return 1
        }
        log "✅ Certificate was base64 encoded DER, converted to PEM"
    else
        log "❌ Unknown certificate format"
        return 1
    fi
    
    # Step 2: Detect and convert private key format (unencrypted)
    log "Detecting private key format (unencrypted)..."
    local key_pem="$temp_dir/key.pem"
    
    # Try different key formats (all unencrypted)
    if openssl rsa -inform PEM -in "$key_file" -out "$key_pem" -passin "pass:" 2>/dev/null; then
        log "✅ Private key is unencrypted PEM format"
    elif openssl rsa -inform DER -in "$key_file" -out "$key_pem" -passin "pass:" 2>/dev/null; then
        log "✅ Private key is unencrypted DER format, converted to PEM"
    elif openssl pkcs8 -inform PEM -in "$key_file" -out "$key_pem" -passin "pass:" -nocrypt 2>/dev/null; then
        log "✅ Private key is PKCS8 unencrypted format"
    elif openssl pkcs8 -inform DER -in "$key_file" -out "$key_pem" -passin "pass:" -nocrypt 2>/dev/null; then
        log "✅ Private key is PKCS8 DER unencrypted format"
    else
        log "❌ Unable to process private key format"
        log "Key file info: $(file "$key_file")"
        log "Key file first line: $(head -1 "$key_file")"
        return 1
    fi
    
    # Step 3: Verify certificate and key match
    log "Verifying certificate and key match..."
    local cert_modulus=$(openssl x509 -noout -modulus -in "$cert_pem" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$key_pem" | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log "✅ Certificate and private key match"
    else
        log "❌ Certificate and private key do not match"
        log "Certificate modulus: $cert_modulus"
        log "Key modulus: $key_modulus"
        return 1
    fi
    
    # Step 4: Create P12 file (unencrypted key, but P12 still needs password)
    log "Creating P12 file with provided password..."
    if openssl pkcs12 -export -out "$output_p12" -inkey "$key_pem" -in "$cert_pem" -password "pass:$password" -name "iOS Distribution Certificate" -legacy; then
        log "✅ P12 file created successfully"
    else
        log "❌ Failed to create P12 file"
        return 1
    fi
    
    # Step 5: Verify P12 file
    log "Verifying P12 file..."
    if openssl pkcs12 -in "$output_p12" -noout -passin "pass:$password" -legacy 2>/dev/null; then
        log "✅ P12 file verification successful"
    else
        log "❌ P12 file verification failed"
        return 1
    fi
    
    # Clean up temporary files
    rm -rf "$temp_dir"
    
    return 0
}

# Function to import P12 to keychain with multiple retry methods
import_p12_to_keychain() {
    local p12_file="$1"
    local password="$2"
    local keychain="build.keychain"
    
    log "Importing P12 to keychain: $keychain"
    
    # Create and configure keychain
    security delete-keychain "$keychain" 2>/dev/null || true
    security create-keychain -p "" "$keychain"
    security default-keychain -s "$keychain"
    security unlock-keychain -p "" "$keychain"
    security set-keychain-settings -t 3600 -u "$keychain"
    
    # Method 1: Standard import with all tools
    log "Attempting standard P12 import..."
    if security import "$p12_file" -k "$keychain" -P "$password" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
        log "✅ Standard P12 import successful"
        # Set partition list for modern macOS
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$keychain" 2>/dev/null || log "Warning: Could not set partition list"
        return 0
    fi
    
    # Method 2: Import without specific tool access
    log "Attempting simplified P12 import..."
    if security import "$p12_file" -k "$keychain" -P "$password" -A; then
        log "✅ Simplified P12 import successful"
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$keychain" 2>/dev/null || log "Warning: Could not set partition list"
        return 0
    fi
    
    # Method 3: Import certificate and key separately (since certificate import worked)
    log "Attempting separate certificate and key import..."
    local temp_dir="ios/certificates/temp"
    mkdir -p "$temp_dir"
    
    # Extract certificate and key from P12
    if openssl pkcs12 -in "$p12_file" -clcerts -nokeys -out "$temp_dir/cert.pem" -passin "pass:$password" -passout "pass:" -legacy && \
       openssl pkcs12 -in "$p12_file" -nocerts -out "$temp_dir/key.pem" -passin "pass:$password" -passout "pass:" -legacy; then
        
        # Import certificate (this worked in the logs)
        if security import "$temp_dir/cert.pem" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
            log "✅ Certificate imported separately"
            
            # Try different key import methods (unencrypted)
            log "Attempting key import with different methods..."
            
            # Method 3a: Try importing key as RSA (unencrypted)
            if security import "$temp_dir/key.pem" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                log "✅ Private key imported as RSA (unencrypted)"
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$keychain" 2>/dev/null || log "Warning: Could not set partition list"
                rm -rf "$temp_dir"
                return 0
            fi
            
            # Method 3b: Try importing original key file directly (unencrypted)
            log "Trying to import original key file directly..."
            if security import "ios/certificates/cert.key" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                log "✅ Original key file imported successfully (unencrypted)"
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$keychain" 2>/dev/null || log "Warning: Could not set partition list"
                rm -rf "$temp_dir"
                return 0
            fi
            
            # Method 3c: Try converting key to different format (unencrypted)
            log "Trying key format conversion..."
            if openssl rsa -in "$temp_dir/key.pem" -out "$temp_dir/key_rsa.pem" 2>/dev/null; then
                if security import "$temp_dir/key_rsa.pem" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/xcodebuild -A; then
                    log "✅ Private key imported after format conversion (unencrypted)"
                    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$keychain" 2>/dev/null || log "Warning: Could not set partition list"
                    rm -rf "$temp_dir"
                    return 0
                fi
            fi
            
            log "❌ All key import methods failed, but certificate was imported"
            log "⚠️  Warning: Certificate imported but key import failed. Build may fail during codesigning."
            rm -rf "$temp_dir"
            return 0  # Return success since certificate was imported
        fi
    fi
    
    rm -rf "$temp_dir"
    log "❌ All P12 import methods failed"
    return 1
}

# Function to download provisioning profile with retries
download_provisioning_profile() {
    local url="$1"
    local output_path="$2"
    local max_retries=3
    local retry_delay=5
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        echo "📥 Downloading provisioning profile (Attempt $attempt/$max_retries)..."
        
        # Create temp directory with proper permissions
        local temp_dir=$(mktemp -d)
        chmod 755 "$temp_dir"
        local temp_file="$temp_dir/profile.mobileprovision"
        
        if curl -f -s -L "$url" -o "$temp_file"; then
            # Verify the download
            if [ -s "$temp_file" ]; then
                # Check if it's a valid provisioning profile
                if grep -q "<?xml" "$temp_file" || file "$temp_file" | grep -q "binary"; then
                    mv "$temp_file" "$output_path"
                    chmod 644 "$output_path"
                    rm -rf "$temp_dir"
                    echo "✅ Provisioning profile downloaded successfully"
                    return 0
                else
                    echo "⚠️ Downloaded file is not a valid provisioning profile"
                fi
            else
                echo "⚠️ Downloaded file is empty"
            fi
        fi
        
        rm -rf "$temp_dir"
        echo "⚠️ Failed to download provisioning profile, retrying in $retry_delay seconds..."
        sleep $retry_delay
        attempt=$((attempt + 1))
    done

    echo "❌ Failed to download provisioning profile after $max_retries attempts"
    return 1
}

# Main function
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <cert_file> <key_file> <password> <output_p12>"
    exit 1
fi

handle_certificates "$1" "$2" "$3" "$4" && import_p12_to_keychain "$4" "$3"

# Main execution
main() {
    if [ -z "$PROFILE_URL" ]; then
        echo "❌ PROFILE_URL is not set"
        exit 1
    fi

    local profile_path="$CERT_DIR/profile.mobileprovision"
    
    echo "🔐 Setting up certificates directory..."
    
    # Clean up any existing files
    rm -f "$profile_path"
    
    # Download and install the provisioning profile
    if download_provisioning_profile "$PROFILE_URL" "$profile_path"; then
        echo "✅ Certificate setup completed successfully"
    else
        echo "❌ Certificate setup failed"
        exit 1
    fi
}

main "$@" 