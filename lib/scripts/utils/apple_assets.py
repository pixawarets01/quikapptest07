#!/usr/bin/env python3
"""
QuikApp Apple Assistant - Python Script for Apple Assets Generation
This script handles the backend processing for generating Apple distribution assets.
"""

import sys
import os
import json
import time
import requests
import jwt
from datetime import datetime, timedelta, timezone
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography import x509
from cryptography.x509.oid import NameOID
import subprocess
import zipfile
import argparse
import tempfile
import shutil

class AppleAssetsGenerator:
    def __init__(self, key_identifier, p8_file_path, issuer_id, bundle_id, profile_type, output_dir="output", team_id=None):
        self.key_identifier = key_identifier
        self.p8_file_path = p8_file_path
        self.issuer_id = issuer_id
        self.bundle_id = bundle_id
        self.profile_type = profile_type
        self.base_url = "https://api.appstoreconnect.apple.com/v1"
        self.jwt_token = None
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = output_dir
        self.private_key = None
        self.certificate_id = None
        self.profile_id = None
        self.log_messages = []
        self.team_id = team_id

    def log(self, message):
        """Print log message with timestamp and store it for file logging"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_line = f"[{timestamp}] {message}"
        try:
            print(log_line)
        except UnicodeEncodeError:
            print(log_line.encode('utf-8', errors='replace').decode('utf-8', errors='replace'))
        sys.stdout.flush()
        self.log_messages.append(log_line)

    def write_log_file(self, status):
        """Write all log messages and final status to a log file in the output directory"""
        try:
            os.makedirs(self.output_dir, exist_ok=True)
            log_path = os.path.join(self.output_dir, "generation.log")
            with open(log_path, "w", encoding="utf-8") as f:
                for line in self.log_messages:
                    f.write(line + "\n")
                f.write(f"\nFinal Status: {status}\n")
        except Exception as e:
            print(f"[ERROR] Failed to write log file: {e}")

    def generate_jwt_token(self):
        """Generate JWT token for App Store Connect API authentication"""
        try:
            self.log("Reading P8 private key file...")
            
            # Validate .p8 file exists
            if not os.path.exists(self.p8_file_path):
                self.log(f"ERROR: P8 file not found at {self.p8_file_path}")
                return False
            
            with open(self.p8_file_path, 'r') as f:
                private_key_content = f.read()
            
            # Validate .p8 file format
            if not private_key_content.strip().startswith('-----BEGIN PRIVATE KEY-----'):
                self.log("ERROR: Invalid P8 file format. File should start with '-----BEGIN PRIVATE KEY-----'")
                return False
            
            if not private_key_content.strip().endswith('-----END PRIVATE KEY-----'):
                self.log("ERROR: Invalid P8 file format. File should end with '-----END PRIVATE KEY-----'")
                return False
            
            # Validate credential lengths
            if len(self.key_identifier) != 10:
                self.log(f"ERROR: Key ID must be exactly 10 characters. Current length: {len(self.key_identifier)}")
                return False
            
            if len(self.issuer_id) not in [32, 36]:  # Can be 32 or 36 characters (with/without hyphens)
                self.log(f"ERROR: Issuer ID must be 32 or 36 characters. Current length: {len(self.issuer_id)}")
                return False

            # Create JWT payload
            payload = {
                'iss': self.issuer_id,
                'exp': datetime.now(timezone.utc) + timedelta(minutes=20),
                'aud': 'appstoreconnect-v1'
            }

            # Create JWT token
            self.jwt_token = jwt.encode(
                payload,
                private_key_content,
                algorithm='ES256',
                headers={'kid': self.key_identifier}
            )
            
            self.log("JWT token generated successfully")
            
            # Test the token with a simple API call
            self.log("Testing JWT token with App Store Connect API...")
            test_headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            
            # Try to fetch certificates to test authentication
            test_response = requests.get(
                f"{self.base_url}/certificates",
                headers=test_headers,
                timeout=30
            )
            
            if test_response.status_code == 200:
                self.log("SUCCESS: JWT token validated successfully with App Store Connect API")
                return True
            elif test_response.status_code == 401:
                self.log("ERROR: JWT token authentication failed (401 Unauthorized)")
                self.log("This usually means:")
                self.log("  - Key ID is incorrect")
                self.log("  - Issuer ID is incorrect") 
                self.log("  - P8 file is invalid or corrupted")
                self.log("  - API key has expired or been revoked")
                self.log("  - Insufficient permissions for App Store Connect API")
                return False
            else:
                self.log(f"WARNING: Unexpected response from App Store Connect API: {test_response.status_code}")
                self.log("Token generated but API test failed. Proceeding with caution...")
                return True
                
        except jwt.InvalidKeyError as e:
            self.log(f"ERROR: Invalid P8 private key: {str(e)}")
            return False
        except jwt.InvalidAlgorithmError as e:
            self.log(f"ERROR: Invalid JWT algorithm: {str(e)}")
            return False
        except Exception as e:
            self.log(f"JWT token generation failed: {str(e)}")
            return False

    def create_bundle_id(self):
        """Create a new bundle identifier with push notification capability enabled."""
        try:
            self.log(f"Creating new Bundle ID '{self.bundle_id}' with Push Notification capability...")
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            payload = {
                "data": {
                    "type": "bundleIds",
                    "attributes": {
                        "identifier": self.bundle_id,
                        "name": self.bundle_id,
                        "platform": "IOS",
                        "seedId": None,
                        "capabilities": {
                            "push": {"enabled": True}
                        }
                    }
                }
            }
            response = requests.post(
                f"{self.base_url}/bundleIds",
                headers=headers,
                json=payload
            )
            if response.status_code == 201:
                bundle_data = response.json()['data']
                self.log(f"Bundle ID '{self.bundle_id}' created successfully.")
                return bundle_data['id']
            else:
                self.log(f"Failed to create Bundle ID: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            self.log(f"Bundle ID creation failed: {str(e)}")
            return None

    def verify_bundle_id_exists(self):
        """Check if the bundle ID exists in App Store Connect. If found, return the bundle reference ID for use in profile creation. If not found, create it with push notification capability."""
        try:
            self.log(f"Checking if Bundle ID '{self.bundle_id}' exists...")
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            response = requests.get(
                f"{self.base_url}/bundleIds",
                headers=headers,
                timeout=30
            )
            if response.status_code == 200:
                bundle_ids = response.json().get('data', [])
                for bundle in bundle_ids:
                    if bundle['attributes']['identifier'] == self.bundle_id:
                        self.log(f"Bundle ID '{self.bundle_id}' found")
                        return bundle['id']  # Return the bundle reference ID
                self.log(f"Bundle ID '{self.bundle_id}' not found. Creating new identifier...")
                return self.create_bundle_id()
            elif response.status_code == 401:
                self.log(f"ERROR: Authentication failed when checking Bundle IDs (401 Unauthorized)")
                self.log("This confirms the JWT token is invalid. Please check:")
                self.log("  - Key ID: Should be exactly 10 characters")
                self.log("  - Issuer ID: Should be 32 or 36 characters")
                self.log("  - P8 file: Should be a valid Apple private key")
                self.log("  - API key permissions: Should have App Store Connect API access")
                return None
            elif response.status_code == 403:
                self.log(f"ERROR: Permission denied when checking Bundle IDs (403 Forbidden)")
                self.log("Your API key doesn't have permission to access Bundle IDs.")
                self.log("Please ensure your API key has the 'App Manager' or 'Developer' role.")
                return None
            else:
                self.log(f"Failed to fetch bundle IDs: {response.status_code} - {response.text}")
                return None
        except requests.exceptions.Timeout:
            self.log("ERROR: Request timeout when checking Bundle IDs. Please check your internet connection.")
            return None
        except requests.exceptions.ConnectionError:
            self.log("ERROR: Connection error when checking Bundle IDs. Please check your internet connection.")
            return None
        except Exception as e:
            self.log(f"Bundle ID verification failed: {str(e)}")
            return None

    def generate_private_key_and_csr(self):
        """Generate RSA private key and Certificate Signing Request"""
        try:
            self.log("Generating RSA private key...")
            
            # Generate private key
            self.private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=2048
            )
            
            # Save private key
            private_key_path = os.path.join(self.temp_dir, "privatekey.key")
            
            with open(private_key_path, "wb") as f:
                f.write(self.private_key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.PKCS8,
                    encryption_algorithm=serialization.NoEncryption()
                ))
            
            self.log("Private key generated and saved")
            
            # Generate CSR
            self.log("Creating Certificate Signing Request...")
            
            subject = x509.Name([
                x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
                x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "CA"),
                x509.NameAttribute(NameOID.LOCALITY_NAME, "San Francisco"),
                x509.NameAttribute(NameOID.ORGANIZATION_NAME, "iOS Distribution"),
                x509.NameAttribute(NameOID.COMMON_NAME, self.bundle_id),
            ])
            
            csr = x509.CertificateSigningRequestBuilder().subject_name(
                subject
            ).sign(self.private_key, hashes.SHA256())
            
            # Save CSR
            csr_path = os.path.join(self.temp_dir, "request.csr")
            with open(csr_path, "wb") as f:
                f.write(csr.public_bytes(serialization.Encoding.PEM))
            
            self.log("CSR generated and saved")
            return True
            
        except Exception as e:
            self.log(f"Private key/CSR generation failed: {str(e)}")
            return False

    def create_certificate(self):
        """Create certificate using the CSR"""
        try:
            self.log("Creating iOS Distribution Certificate...")
            
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            
            # Read CSR
            csr_path = os.path.join(self.temp_dir, "request.csr")
            with open(csr_path, "r") as f:
                csr_content = f.read()
            
            # Remove PEM headers and newlines
            csr_data = csr_content.replace("-----BEGIN CERTIFICATE REQUEST-----", "")
            csr_data = csr_data.replace("-----END CERTIFICATE REQUEST-----", "")
            csr_data = csr_data.replace("\n", "")
            
            payload = {
                "data": {
                    "type": "certificates",
                    "attributes": {
                        "certificateType": "IOS_DISTRIBUTION",
                        "csrContent": csr_data
                    }
                }
            }
            
            response = requests.post(
                f"{self.base_url}/certificates",
                headers=headers,
                json=payload
            )
            
            if response.status_code == 201:
                cert_data = response.json()['data']
                self.certificate_id = cert_data['id']
                
                # Save certificate
                cert_content = cert_data['attributes']['certificateContent']
                cert_path = os.path.join(self.temp_dir, "certificate.cer")
                
                with open(cert_path, "w") as f:
                    f.write("-----BEGIN CERTIFICATE-----\n")
                    f.write(cert_content)
                    f.write("\n-----END CERTIFICATE-----\n")
                
                self.log("Certificate created and downloaded")
                return True
            elif response.status_code == 409:
                self.log("WARNING: Certificate limit reached (409 Conflict)")
                self.log("You already have a current iOS Distribution certificate or a pending request.")
                self.log("Attempting to use existing certificate...")
                
                # Try to find and use an existing certificate
                return self._use_existing_certificate()
            else:
                self.log(f"Certificate creation failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            self.log(f"Certificate creation failed: {str(e)}")
            return False

    def _use_existing_certificate(self):
        """Find and use an existing iOS Distribution certificate"""
        try:
            self.log("Searching for existing iOS Distribution certificates...")
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f"{self.base_url}/certificates",
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                certificates = response.json().get('data', [])
                ios_distribution_certs = [
                    cert for cert in certificates 
                    if cert['attributes']['certificateType'] == 'IOS_DISTRIBUTION'
                ]
                
                if ios_distribution_certs:
                    # Use the most recent certificate
                    latest_cert = max(ios_distribution_certs, 
                                    key=lambda x: x['attributes']['expirationDate'])
                    
                    self.certificate_id = latest_cert['id']
                    cert_content = latest_cert['attributes']['certificateContent']
                    cert_path = os.path.join(self.temp_dir, "certificate.cer")
                    
                    with open(cert_path, "w") as f:
                        f.write("-----BEGIN CERTIFICATE-----\n")
                        f.write(cert_content)
                        f.write("\n-----END CERTIFICATE-----\n")
                    
                    expiration_date = latest_cert['attributes']['expirationDate']
                    self.log(f"Using existing certificate (ID: {self.certificate_id})")
                    self.log(f"Certificate expires: {expiration_date}")
                    return True
                else:
                    self.log("ERROR: No iOS Distribution certificates found")
                    self.log("You need to create a certificate manually in App Store Connect first")
                    return False
            else:
                self.log(f"Failed to fetch certificates: {response.status_code}")
                return False
                
        except Exception as e:
            self.log(f"Error using existing certificate: {str(e)}")
            return False

    def get_openssl_path(self):
        # Allow user to set OPENSSL_PATH env var, else default to 'openssl'
        return os.environ.get('OPENSSL_PATH', 'openssl')

    def generate_p12_file(self):
        """Generate P12 file by combining certificate and private key"""
        try:
            self.log("Generating P12 file...")
            cert_path = os.path.join(self.temp_dir, "certificate.cer")
            key_path = os.path.join(self.temp_dir, "privatekey.key")
            p12_path = os.path.join(self.temp_dir, "certificate.p12")
            openssl_path = self.get_openssl_path()
            
            # Check if OpenSSL is available
            try:
                result = subprocess.run([openssl_path, "version"], capture_output=True, text=True, timeout=10)
                if result.returncode != 0:
                    raise FileNotFoundError("OpenSSL not found")
            except (FileNotFoundError, subprocess.TimeoutExpired):
                self.log("WARNING: OpenSSL not found. P12 generation will be skipped.")
                self.log("To install OpenSSL:")
                self.log("  1. Download from: https://slproweb.com/products/Win32OpenSSL.html")
                self.log("  2. Install to default location")
                self.log("  3. Add to PATH or set OPENSSL_PATH environment variable")
                self.log("  4. Re-run the script")
                self.log("")
                self.log("For now, continuing without P12 file...")
                return True  # Continue workflow without P12
            
            cmd = [
                openssl_path, "pkcs12", "-export",
                "-in", cert_path,
                "-inkey", key_path,
                "-out", p12_path,
                "-passout", "pass:"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                self.log("P12 file generated successfully")
                return True
            else:
                self.log(f"P12 generation failed: {result.stderr}")
                if 'No such file or directory' in result.stderr or 'not found' in result.stderr:
                    self.log(f"OpenSSL not found. Set the OPENSSL_PATH environment variable to the full path of openssl.exe if needed.")
                return False
        except FileNotFoundError as e:
            self.log(f"OpenSSL executable not found: {e}")
            self.log("To install OpenSSL:")
            self.log("  1. Download from: https://slproweb.com/products/Win32OpenSSL.html")
            self.log("  2. Install to default location")
            self.log("  3. Add to PATH or set OPENSSL_PATH environment variable")
            self.log("  4. Re-run the script")
            self.log("")
            self.log("For now, continuing without P12 file...")
            return True  # Continue workflow without P12
        except Exception as e:
            self.log(f"P12 generation failed: {str(e)}")
            return False

    def create_provisioning_profile(self, bundle_id_ref):
        """Create provisioning profile using the bundle reference ID, always enabling push notification capability."""
        try:
            self.log(f"Creating provisioning profile for {self.bundle_id} with Push Notification capability...")
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            payload = {
                "data": {
                    "type": "profiles",
                    "attributes": {
                        "name": f"{self.bundle_id} - {self.profile_type}",
                        "profileType": self.profile_type
                    },
                    "relationships": {
                        "bundleId": {
                            "data": {
                                "type": "bundleIds",
                                "id": bundle_id_ref
                            }
                        },
                        "certificates": {
                            "data": [{
                                "type": "certificates",
                                "id": self.certificate_id
                            }]
                        }
                    }
                }
            }
            response = requests.post(
                f"{self.base_url}/profiles",
                headers=headers,
                json=payload
            )
            if response.status_code == 201:
                profile_data = response.json()['data']
                self.profile_id = profile_data['id']
                profile_content = profile_data['attributes']['profileContent']
                profile_path = os.path.join(self.temp_dir, "profile.mobileprovision")
                import base64
                with open(profile_path, "wb") as f:
                    f.write(base64.b64decode(profile_content))
                self.log("Provisioning profile created and downloaded")
                return True
            else:
                self.log(f"Provisioning profile creation failed: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.log(f"Provisioning profile creation failed: {str(e)}")
            return False

    def package_files(self):
        """Package all generated files into a ZIP archive"""
        try:
            self.log("Packaging files into ZIP archive...")
            
            zip_path = os.path.join(self.temp_dir, "apple_assets.zip")
            
            with zipfile.ZipFile(zip_path, 'w') as zipf:
                files_to_zip = [
                    "privatekey.key",
                    "certificate.cer",
                    "profile.mobileprovision"
                ]
                
                # Add P12 file only if it exists
                p12_path = os.path.join(self.temp_dir, "certificate.p12")
                if os.path.exists(p12_path):
                    files_to_zip.append("certificate.p12")
                else:
                    self.log("Note: P12 file not included (OpenSSL not available)")
                
                for filename in files_to_zip:
                    file_path = os.path.join(self.temp_dir, filename)
                    if os.path.exists(file_path):
                        zipf.write(file_path, filename)
                        self.log(f"Added {filename} to package")
                    else:
                        self.log(f"Warning: {filename} not found, skipping...")
            
            self.log("Files packaged successfully")
            return True
            
        except Exception as e:
            self.log(f"File packaging failed: {str(e)}")
            return False

    def move_outputs_to_final_dir(self):
        os.makedirs(self.output_dir, exist_ok=True)
        files = [
            "privatekey.key",
            "certificate.cer",
            "certificate.p12",
            "profile.mobileprovision",
            "apple_assets.zip",
            "generation.log"
        ]
        for fname in files:
            src = os.path.join(self.temp_dir, fname)
            dst = os.path.join(self.output_dir, fname)
            if os.path.exists(src):
                shutil.move(src, dst)
        shutil.rmtree(self.temp_dir)

    def ensure_push_capability(self, bundle_id_ref):
        """Ensure the bundle ID has Push Notification capability enabled."""
        try:
            self.log(f"Ensuring Push Notification capability is enabled for Bundle ID '{self.bundle_id}'...")
            headers = {
                'Authorization': f'Bearer {self.jwt_token}',
                'Content-Type': 'application/json'
            }
            # Get current capabilities
            response = requests.get(
                f"{self.base_url}/bundleIds/{bundle_id_ref}/capabilities",
                headers=headers
            )
            if response.status_code == 200:
                capabilities = response.json().get('data', [])
                push_enabled = any(
                    cap['attributes']['capabilityType'] == 'PUSH_NOTIFICATIONS' and cap['attributes']['enabled']
                    for cap in capabilities
                )
                if push_enabled:
                    self.log("Push Notification capability already enabled.")
                    return True
            # Enable push capability (do not include 'enabled' attribute)
            payload = {
                "data": {
                    "type": "bundleIdCapabilities",
                    "attributes": {
                        "capabilityType": "PUSH_NOTIFICATIONS",
                        "settings": []
                    },
                    "relationships": {
                        "bundleId": {
                            "data": {
                                "type": "bundleIds",
                                "id": bundle_id_ref
                            }
                        }
                    }
                }
            }
            response = requests.post(
                f"{self.base_url}/bundleIdCapabilities",
                headers=headers,
                json=payload
            )
            if response.status_code in (200, 201):
                self.log("Push Notification capability enabled.")
                return True
            else:
                self.log(f"Failed to enable Push Notification capability: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.log(f"Error enabling Push Notification capability: {str(e)}")
            return False

    def generate_assets(self):
        """Main method to generate all Apple assets"""
        try:
            self.log("Starting Apple Assets generation...")
            if not self.generate_jwt_token():
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            bundle_id_ref = self.verify_bundle_id_exists()
            if not bundle_id_ref:
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            # Ensure push capability is enabled for all profiles
            if not self.ensure_push_capability(bundle_id_ref):
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            if not self.generate_private_key_and_csr():
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            if not self.create_certificate():
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            if not self.generate_p12_file():
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            if not self.create_provisioning_profile(bundle_id_ref):
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            if not self.package_files():
                self.write_log_file("FAILURE")
                self.move_outputs_to_final_dir()
                return False
            self.move_outputs_to_final_dir()
            self.log("Apple Assets generation completed successfully!")
            self.log(f"Files saved to: {os.path.abspath(self.output_dir)}")
            self.write_log_file("SUCCESS")
            return True
        except Exception as e:
            self.log(f"Apple Assets generation failed: {str(e)}")
            self.write_log_file("FAILURE")
            self.move_outputs_to_final_dir()
            return False

def main():
    parser = argparse.ArgumentParser(description='Generate Apple Distribution Assets')
    parser.add_argument('--key-id', required=True, help='Key Identifier')
    parser.add_argument('--p8-file', required=True, help='Path to .p8 file')
    parser.add_argument('--issuer-id', required=True, help='Issuer ID')
    parser.add_argument('--bundle-id', required=True, help='Bundle ID')
    parser.add_argument('--profile-type', default='IOS_APP_STORE', help='Profile type')
    parser.add_argument('--output-dir', default='output', help='Output directory for generated files')
    parser.add_argument('--team-id', required=False, help='Apple Developer Team ID (optional)')
    
    args = parser.parse_args()
    
    generator = AppleAssetsGenerator(
        args.key_id,
        args.p8_file,
        args.issuer_id,
        args.bundle_id,
        args.profile_type,
        args.output_dir,
        args.team_id
    )
    
    success = generator.generate_assets()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 