#!/usr/bin/env python3
import os
import sys
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def get_env_var(name, default=""):
    return os.environ.get(name, default)

# QuikApp CSS Variables
QUIKAPP_STYLES = """
<style>
    :root {
        /* Primary Colors */
        --quik-primary: #667eea;
        --quik-primary-dark: #764ba2;
        --quik-secondary: #4fd1c5;
        --quik-secondary-dark: #38b2ac;
        
        /* Status Colors */
        --quik-success: #48bb78;
        --quik-warning: #f6ad55;
        --quik-error: #f56565;
        --quik-info: #4299e1;
        
        /* Neutral Colors */
        --quik-gray-100: #f7fafc;
        --quik-gray-200: #edf2f7;
        --quik-gray-300: #e2e8f0;
        --quik-gray-600: #718096;
        --quik-gray-800: #2d3748;
        --quik-gray-900: #1a202c;
        
        /* Font */
        --quik-font: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    
    body {
        font-family: var(--quik-font);
        line-height: 1.5;
        color: var(--quik-gray-800);
        background-color: var(--quik-gray-100);
        margin: 0;
        padding: 0;
    }
    
    .quik-container {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
    }
    
    .quik-header {
        background: linear-gradient(135deg, var(--quik-primary) 0%, var(--quik-primary-dark) 100%);
        color: white;
        padding: 2rem;
        border-radius: 1rem;
        text-align: center;
        margin-bottom: 2rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .quik-card {
        background: white;
        border-radius: 0.75rem;
        padding: 1.5rem;
        margin-bottom: 1.5rem;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
        border: 1px solid var(--quik-gray-200);
    }
    
    .quik-card-error {
        border-left: 4px solid var(--quik-error);
    }
    
    .quik-card-warning {
        border-left: 4px solid var(--quik-warning);
    }
    
    .quik-card-info {
        border-left: 4px solid var(--quik-info);
    }
    
    .quik-title {
        font-size: 1.5rem;
        font-weight: 600;
        color: var(--quik-gray-900);
        margin-bottom: 1rem;
    }
    
    .quik-subtitle {
        font-size: 1.25rem;
        font-weight: 500;
        color: var(--quik-gray-800);
        margin-bottom: 0.75rem;
    }
    
    .quik-text {
        color: var(--quik-gray-600);
        margin-bottom: 1rem;
    }
    
    .quik-list {
        list-style-type: none;
        padding: 0;
        margin: 0 0 1rem 0;
    }
    
    .quik-list li {
        padding: 0.5rem 0;
        border-bottom: 1px solid var(--quik-gray-200);
    }
    
    .quik-list li:last-child {
        border-bottom: none;
    }
    
    .quik-code {
        font-family: monospace;
        background: var(--quik-gray-100);
        padding: 0.25rem 0.5rem;
        border-radius: 0.25rem;
        font-size: 0.875rem;
        color: var(--quik-gray-800);
    }
    
    .quik-link {
        color: var(--quik-primary);
        text-decoration: none;
        font-weight: 500;
    }
    
    .quik-link:hover {
        text-decoration: underline;
    }
    
    .quik-footer {
        text-align: center;
        padding: 2rem;
        color: var(--quik-gray-600);
        border-top: 1px solid var(--quik-gray-200);
        margin-top: 2rem;
    }
    
    .quik-logo {
        height: 40px;
        margin-bottom: 1rem;
    }
    
    .quik-button {
        display: inline-block;
        padding: 0.75rem 1.5rem;
        background: var(--quik-primary);
        color: white;
        border-radius: 0.5rem;
        text-decoration: none;
        font-weight: 500;
        transition: background-color 0.2s;
    }
    
    .quik-button:hover {
        background: var(--quik-primary-dark);
        text-decoration: none;
    }
    
    .quik-steps {
        counter-reset: step;
        padding-left: 0;
    }
    
    .quik-steps li {
        position: relative;
        padding: 1rem 0 1rem 3rem;
        list-style: none;
    }
    
    .quik-steps li::before {
        counter-increment: step;
        content: counter(step);
        position: absolute;
        left: 0;
        top: 1rem;
        width: 2rem;
        height: 2rem;
        background: var(--quik-primary);
        color: white;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 500;
    }
</style>
"""

def send_email(subject, html_content):
    # Email configuration
    smtp_server = get_env_var("EMAIL_SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(get_env_var("EMAIL_SMTP_PORT", "587"))
    smtp_user = get_env_var("EMAIL_SMTP_USER")
    smtp_pass = get_env_var("EMAIL_SMTP_PASS")
    recipient = get_env_var("EMAIL_ID", smtp_user)

    if not smtp_user or not smtp_pass:
        print("[send_ios_emails.py] Missing email credentials. Skipping email.")
        return

    # Create message
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = smtp_user
    msg['To'] = recipient
    msg.attach(MIMEText(html_content, 'html'))

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.sendmail(smtp_user, [recipient], msg.as_string())
        print(f"[send_ios_emails.py] Email sent to {recipient}")
    except Exception as e:
        print(f"[send_ios_emails.py] Failed to send email: {e}")

def get_certificate_error_template(error_details):
    app_name = get_env_var("APP_NAME", "Your App")
    p12_url = get_env_var("CERT_P12_URL", "Not provided")
    cer_url = get_env_var("CERT_CER_URL", "Not provided")
    key_url = get_env_var("CERT_KEY_URL", "Not provided")
    support_email = get_env_var("SUPPORT_EMAIL", "support@quikapp.co")

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{app_name} - Certificate Error</title>
        {QUIKAPP_STYLES}
    </head>
    <body>
        <div class="quik-container">
            <div class="quik-header">
                <img src="https://quikapp.co/images/logo.png" alt="QuikApp" class="quik-logo">
                <h1>iOS Certificate Error</h1>
                <p>{app_name} - Certificate Configuration Failed</p>
            </div>

            <div class="quik-card quik-card-error">
                <h2 class="quik-title">Current Configuration</h2>
                <ul class="quik-list">
                    <li>📄 P12 Certificate URL: <code class="quik-code">{p12_url}</code></li>
                    <li>📄 CER Certificate URL: <code class="quik-code">{cer_url}</code></li>
                    <li>🔑 Private Key URL: <code class="quik-code">{key_url}</code></li>
                </ul>
            </div>

            <div class="quik-card quik-card-warning">
                <h2 class="quik-title">Error Details</h2>
                <pre class="quik-code">{error_details}</pre>
            </div>

            <div class="quik-card quik-card-info">
                <h2 class="quik-title">How to Fix</h2>
                
                <h3 class="quik-subtitle">1. Get iOS Distribution Certificate</h3>
                <ol class="quik-steps">
                    <li>Open Xcode</li>
                    <li>Go to Preferences > Accounts</li>
                    <li>Select your Apple Developer account</li>
                    <li>Click 'Manage Certificates'</li>
                    <li>Click '+' and select 'iOS Distribution'</li>
                </ol>

                <h3 class="quik-subtitle">2. Export Certificates</h3>
                <div class="quik-card">
                    <h4 class="quik-subtitle">Option 1 - P12 Certificate (Recommended)</h4>
                    <ol class="quik-steps">
                        <li>Open Keychain Access</li>
                        <li>Find your iOS Distribution Certificate</li>
                        <li>Right-click > Export</li>
                        <li>Choose .p12 format</li>
                        <li>Set a strong password</li>
                        <li>Upload to secure location</li>
                        <li>Update CERT_P12_URL</li>
                    </ol>
                </div>

                <div class="quik-card">
                    <h4 class="quik-subtitle">Option 2 - CER and KEY Files</h4>
                    <ol class="quik-steps">
                        <li>Export certificate (.cer) from Keychain</li>
                        <li>Export private key (.key) from Keychain</li>
                        <li>Upload both files</li>
                        <li>Update CERT_CER_URL and CERT_KEY_URL</li>
                    </ol>
                </div>
            </div>

            <div class="quik-card">
                <h2 class="quik-title">Need Help?</h2>
                <ul class="quik-list">
                    <li>
                        <a href="https://developer.apple.com/support/certificates/" class="quik-link">
                            📚 Apple Documentation
                        </a>
                    </li>
                    <li>
                        <a href="https://help.apple.com/xcode/mac/current/" class="quik-link">
                            ❓ Xcode Help
                        </a>
                    </li>
                    <li>
                        <a href="mailto:{support_email}" class="quik-link">
                            📧 Contact Support
                        </a>
                    </li>
                </ul>
            </div>

            <div class="quik-footer">
                <img src="https://quikapp.co/images/logo-dark.png" alt="QuikApp" class="quik-logo">
                <p>This is an automated message from the QuikApp Build System</p>
                <div>
                    <a href="https://quikapp.co" class="quik-link">Website</a> |
                    <a href="https://app.quikapp.co" class="quik-link">Portal</a> |
                    <a href="https://docs.quikapp.co" class="quik-link">Documentation</a>
                </div>
            </div>
        </div>
    </body>
    </html>
    """

def get_provisioning_error_template(error_details):
    app_name = get_env_var("APP_NAME", "Your App")
    profile_url = get_env_var("PROFILE_URL", "Not provided")
    bundle_id = get_env_var("BUNDLE_ID", "Not provided")
    profile_type = get_env_var("PROFILE_TYPE", "Not provided")
    support_email = get_env_var("SUPPORT_EMAIL", "support@quikapp.co")

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{app_name} - Provisioning Profile Error</title>
        {QUIKAPP_STYLES}
    </head>
    <body>
        <div class="quik-container">
            <div class="quik-header">
                <img src="https://quikapp.co/images/logo.png" alt="QuikApp" class="quik-logo">
                <h1>iOS Provisioning Profile Error</h1>
                <p>{app_name} - Profile Configuration Failed</p>
            </div>

            <div class="quik-card quik-card-error">
                <h2 class="quik-title">Current Configuration</h2>
                <ul class="quik-list">
                    <li>📄 Profile URL: <code class="quik-code">{profile_url}</code></li>
                    <li>🆔 Bundle ID: <code class="quik-code">{bundle_id}</code></li>
                    <li>📱 Profile Type: <code class="quik-code">{profile_type}</code></li>
                </ul>
            </div>

            <div class="quik-card quik-card-warning">
                <h2 class="quik-title">Error Details</h2>
                <pre class="quik-code">{error_details}</pre>
            </div>

            <div class="quik-card quik-card-info">
                <h2 class="quik-title">How to Fix</h2>
                
                <h3 class="quik-subtitle">1. Create Provisioning Profile</h3>
                <ol class="quik-steps">
                    <li>Go to <a href="https://developer.apple.com/account/resources/profiles/list" class="quik-link">Apple Developer Portal</a></li>
                    <li>Click Certificates, Identifiers & Profiles</li>
                    <li>Select Profiles > '+'</li>
                    <li>Choose profile type:
                        <ul class="quik-list">
                            <li>App Store: For App Store distribution</li>
                            <li>Ad Hoc: For internal testing</li>
                        </ul>
                    </li>
                    <li>Select your app ID</li>
                    <li>Choose your distribution certificate</li>
                    <li>Name and generate profile</li>
                </ol>

                <h3 class="quik-subtitle">2. Profile Requirements</h3>
                <ul class="quik-list">
                    <li>Must match Bundle ID: <code class="quik-code">{bundle_id}</code></li>
                    <li>Must be type: <code class="quik-code">{profile_type}</code></li>
                    <li>Must not be expired</li>
                    <li>Must include your distribution certificate</li>
                </ul>
            </div>

            <div class="quik-card">
                <h2 class="quik-title">Need Help?</h2>
                <ul class="quik-list">
                    <li>
                        <a href="https://developer.apple.com/support/profiles/" class="quik-link">
                            📚 Apple Profiles Guide
                        </a>
                    </li>
                    <li>
                        <a href="https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases" class="quik-link">
                            📱 Distribution Guide
                        </a>
                    </li>
                    <li>
                        <a href="mailto:{support_email}" class="quik-link">
                            📧 Contact Support
                        </a>
                    </li>
                </ul>
            </div>

            <div class="quik-footer">
                <img src="https://quikapp.co/images/logo-dark.png" alt="QuikApp" class="quik-logo">
                <p>This is an automated message from the QuikApp Build System</p>
                <div>
                    <a href="https://quikapp.co" class="quik-link">Website</a> |
                    <a href="https://app.quikapp.co" class="quik-link">Portal</a> |
                    <a href="https://docs.quikapp.co" class="quik-link">Documentation</a>
                </div>
            </div>
        </div>
    </body>
    </html>
    """

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: send_ios_emails.py <error_type> <error_details>")
        sys.exit(1)

    error_type = sys.argv[1]
    error_details = sys.argv[2]
    app_name = get_env_var("APP_NAME", "iOS App")

    if error_type == "certificates":
        subject = f"❌ {app_name} - iOS Certificate Error"
        html_content = get_certificate_error_template(error_details)
    elif error_type == "provisioning":
        subject = f"❌ {app_name} - iOS Provisioning Profile Error"
        html_content = get_provisioning_error_template(error_details)
    else:
        print(f"[send_ios_emails.py] Unknown error type: {error_type}")
        sys.exit(1)

    send_email(subject, html_content) 