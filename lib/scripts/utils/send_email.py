#!/usr/bin/env python3
"""
QuikApp Enhanced Email Notification System v2.0
Professional email notifications for build status with modern UI design
"""

import os
import sys
import smtplib
import urllib.parse
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.header import Header
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class QuikAppEmailNotifier:
    def __init__(self):
        """Initialize the email notifier with environment variables"""
        # SMTP Configuration
        self.smtp_server = os.environ.get("EMAIL_SMTP_SERVER", "smtp.gmail.com")
        self.smtp_port = int(os.environ.get("EMAIL_SMTP_PORT", "587"))
        self.smtp_user = os.environ.get("EMAIL_SMTP_USER", "")
        self.smtp_pass = os.environ.get("EMAIL_SMTP_PASS", "")
        self.recipient = os.environ.get("EMAIL_ID", "")
        
        # App Configuration
        self.app_name = os.environ.get("APP_NAME", "QuikApp")
        self.version_name = os.environ.get("VERSION_NAME", "1.0.0")
        self.version_code = os.environ.get("VERSION_CODE", "1")
        self.org_name = os.environ.get("ORG_NAME", "QuikApp Technologies")
        self.user_name = os.environ.get("USER_NAME", "Developer")
        self.workflow_id = os.environ.get("WORKFLOW_ID", "unknown")
        self.project_id = os.environ.get("CM_PROJECT_ID", "unknown")
        
        # Feature flags
        self.features = {
            'push_notify': os.environ.get("PUSH_NOTIFY", "false").lower() == "true",
            'is_chatbot': os.environ.get("IS_CHATBOT", "false").lower() == "true",
            'is_domain_url': os.environ.get("IS_DOMAIN_URL", "false").lower() == "true",
            'is_splash': os.environ.get("IS_SPLASH", "false").lower() == "true",
            'is_pulldown': os.environ.get("IS_PULLDOWN", "false").lower() == "true",
            'is_bottommenu': os.environ.get("IS_BOTTOMMENU", "false").lower() == "true"
        }
        
        # Permissions
        self.permissions = {
            'camera': os.environ.get("IS_CAMERA", "false").lower() == "true",
            'location': os.environ.get("IS_LOCATION", "false").lower() == "true",
            'microphone': os.environ.get("IS_MIC", "false").lower() == "true",
            'notification': os.environ.get("IS_NOTIFICATION", "false").lower() == "true",
            'contact': os.environ.get("IS_CONTACT", "false").lower() == "true",
            'biometric': os.environ.get("IS_BIOMETRIC", "false").lower() == "true",
            'calendar': os.environ.get("IS_CALENDAR", "false").lower() == "true",
            'storage': os.environ.get("IS_STORAGE", "false").lower() == "true"
        }
        
        logger.info(f"Email notifier initialized for {self.app_name} v{self.version_name}")
        logger.info(f"SMTP: {self.smtp_server}:{self.smtp_port}, User: {self.smtp_user}")
        logger.info(f"Recipient: {self.recipient}")

    def get_file_size(self, file_path):
        """Get human readable file size"""
        try:
            size = os.path.getsize(file_path)
            for unit in ['B', 'KB', 'MB', 'GB']:
                if size < 1024.0:
                    return f"{size:.1f} {unit}"
                size /= 1024.0
            return f"{size:.1f} TB"
        except:
            return "Unknown"

    def scan_artifacts(self):
        """Scan for build artifacts in output directories"""
        artifacts = []
        
        # Android artifacts
        android_files = [
            ("output/android/app-release.apk", "Android APK", "Install directly on Android devices", "#4CAF50"),
            ("output/android/app-release.aab", "Android Bundle", "Upload to Google Play Console", "#2196F3")
        ]
        
        for file_path, name, description, color in android_files:
            if os.path.exists(file_path):
                artifacts.append({
                    'name': name,
                    'description': description,
                    'size': self.get_file_size(file_path),
                    'filename': os.path.basename(file_path),
                    'color': color
                })
        
        # iOS artifacts
        ios_files = [
            ("output/ios/app-release.ipa", "iOS IPA", "Install on iOS devices or upload to App Store", "#FF9800")
        ]
        
        for file_path, name, description, color in ios_files:
            if os.path.exists(file_path):
                artifacts.append({
                    'name': name,
                    'description': description,
                    'size': self.get_file_size(file_path),
                    'filename': os.path.basename(file_path),
                    'color': color
                })
        
        logger.info(f"Found {len(artifacts)} artifacts: {[a['filename'] for a in artifacts]}")
        return artifacts

    def generate_artifact_cards(self, build_id):
        """Generate HTML cards for downloadable artifacts"""
        artifacts = self.scan_artifacts()
        
        if not artifacts:
            return """
            <div style="background: #fff3cd; padding: 25px; border-radius: 12px; margin: 30px 0; text-align: center;">
                <h3 style="color: #856404; margin: 0 0 15px 0;">⚠️ No Artifacts Found</h3>
                <p style="color: #856404; margin: 0;">Build completed but no output files were detected. Please check the build logs.</p>
            </div>
            """
        
        cards_html = """
        <div style="background: #f8f9fa; padding: 30px; border-radius: 16px; margin: 30px 0;">
            <h3 style="color: #2c3e50; margin: 0 0 20px 0; text-align: center;">📦 Download Individual Files</h3>
            <p style="margin: 0 0 25px 0; text-align: center; color: #6c757d;">Click the buttons below to download specific app files:</p>
            <div style="display: grid; gap: 20px;">
        """
        
        # Get the correct build ID and project ID from environment variables
        cm_build_id = (os.environ.get("CM_BUILD_ID") or 
                      os.environ.get("FCI_BUILD_ID") or 
                      os.environ.get("BUILD_NUMBER") or 
                      build_id)
        
        cm_project_id = (os.environ.get("CM_PROJECT_ID") or 
                        os.environ.get("FCI_PROJECT_ID") or 
                        self.project_id)
        
        logger.info(f"Using build_id: {cm_build_id} (from env: {os.environ.get('CM_BUILD_ID', 'NOT SET')})")
        logger.info(f"Using project_id: {cm_project_id} (from env: {os.environ.get('CM_PROJECT_ID', 'NOT SET')})")
        
        # Check if we have valid IDs
        if cm_build_id == "unknown" or cm_project_id == "unknown":
            logger.warning("Invalid build_id or project_id, using fallback URLs")
            # Use fallback - direct links to Codemagic build page
            codemagic_build_url = f"https://codemagic.io/builds/{build_id}"
            
            for artifact in artifacts:
                cards_html += f"""
                <div style="background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border: 2px solid {artifact['color']}20; display: flex; justify-content: space-between; align-items: center; min-height: 100px;">
                    <div style="flex: 1;">
                        <h4 style="margin: 0 0 8px 0; color: {artifact['color']}; font-size: 18px;">{artifact['name']}</h4>
                        <p style="margin: 0 0 5px 0; color: #666; font-size: 14px; line-height: 1.4;">{artifact['description']}</p>
                        <p style="margin: 0; color: #999; font-size: 12px;">Size: {artifact['size']}</p>
                    </div>
                    <div style="margin-left: 20px;">
                        <a href="{codemagic_build_url}" style="background: {artifact['color']}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 14px; display: inline-block; transition: all 0.3s ease; box-shadow: 0 2px 4px rgba(0,0,0,0.2);">
                            📥 Download from Codemagic
                        </a>
                    </div>
                </div>
                """
        else:
            # Use the correct Codemagic artifact URL format
            base_url = f"https://api.codemagic.io/artifacts/{cm_project_id}/{cm_build_id}"
            logger.info(f"Generated base URL: {base_url}")
            
            for artifact in artifacts:
                # URL encode the filename to handle special characters
                encoded_filename = urllib.parse.quote(artifact['filename'])
                download_url = f"{base_url}/{encoded_filename}"
                logger.info(f"Generated download URL for {artifact['filename']}: {download_url}")
                
                cards_html += f"""
                <div style="background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border: 2px solid {artifact['color']}20; display: flex; justify-content: space-between; align-items: center; min-height: 100px;">
                    <div style="flex: 1;">
                        <h4 style="margin: 0 0 8px 0; color: {artifact['color']}; font-size: 18px;">{artifact['name']}</h4>
                        <p style="margin: 0 0 5px 0; color: #666; font-size: 14px; line-height: 1.4;">{artifact['description']}</p>
                        <p style="margin: 0; color: #999; font-size: 12px;">Size: {artifact['size']}</p>
                    </div>
                    <div style="margin-left: 20px;">
                        <a href="{download_url}" style="background: {artifact['color']}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 14px; display: inline-block; transition: all 0.3s ease; box-shadow: 0 2px 4px rgba(0,0,0,0.2);">
                            📥 Download
                        </a>
                    </div>
                </div>
                """
        
        # Add alternative download method
        codemagic_build_url = f"https://codemagic.io/builds/{cm_build_id if cm_build_id != 'unknown' else build_id}"
        
        cards_html += f"""
            </div>
            <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin-top: 25px;">
                <h4 style="margin: 0 0 15px 0; color: #1976d2;">📋 Download Instructions:</h4>
                <ul style="margin: 0; padding-left: 20px; color: #424242; line-height: 1.8;">
                    <li><strong>APK:</strong> Right-click → "Save As" to download, then install on Android device</li>
                    <li><strong>AAB:</strong> Upload directly to Google Play Console for store distribution</li>
                    <li><strong>IPA:</strong> Upload to App Store Connect using Xcode or Transporter app</li>
                </ul>
            </div>
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 15px;">
                <p style="margin: 0; color: #856404; font-size: 14px;">
                    <strong>Note:</strong> If download links don't work, you can also download artifacts from the 
                    <a href="{codemagic_build_url}" style="color: #1976d2;">Codemagic build page</a>.
                </p>
            </div>
        </div>
        """
        
        return cards_html
    
    def generate_feature_badges(self):
        """Generate HTML for feature and permission badges"""
        def get_badge(enabled):
            if enabled:
                return '<span style="background: #28a745; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">✅ Enabled</span>'
            else:
                return '<span style="background: #6c757d; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">❌ Disabled</span>'
        
        features_html = f"""
        <div style="background: #e8f5e8; padding: 25px; border-radius: 12px; margin: 20px 0;">
            <h3 style="color: #27ae60; margin: 0 0 20px 0;">🎨 App Features</h3>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <div>Push Notifications: {get_badge(self.features['push_notify'])}</div>
                <div>Chat Bot: {get_badge(self.features['is_chatbot'])}</div>
                <div>Deep Linking: {get_badge(self.features['is_domain_url'])}</div>
                <div>Splash Screen: {get_badge(self.features['is_splash'])}</div>
                <div>Pull to Refresh: {get_badge(self.features['is_pulldown'])}</div>
                <div>Bottom Menu: {get_badge(self.features['is_bottommenu'])}</div>
            </div>
        </div>
        
        <div style="background: #fce4ec; padding: 25px; border-radius: 12px; margin: 20px 0;">
            <h3 style="color: #d81b60; margin: 0 0 20px 0;">🔐 App Permissions</h3>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <div>Camera: {get_badge(self.permissions['camera'])}</div>
                <div>Location: {get_badge(self.permissions['location'])}</div>
                <div>Microphone: {get_badge(self.permissions['microphone'])}</div>
                <div>Notifications: {get_badge(self.permissions['notification'])}</div>
                <div>Contacts: {get_badge(self.permissions['contact'])}</div>
                <div>Biometric: {get_badge(self.permissions['biometric'])}</div>
                <div>Calendar: {get_badge(self.permissions['calendar'])}</div>
                <div>Storage: {get_badge(self.permissions['storage'])}</div>
            </div>
        </div>
        """
        
        return features_html
    
    def send_build_started_email(self, platform, build_id):
        """Send build started notification"""
        subject = f"🚀 QuikApp Build Started - {self.app_name}"
        
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>QuikApp Build Started</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f7fa; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }}
                .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 30px; text-align: center; }}
                .content {{ padding: 30px; }}
                .footer {{ background: #2c3e50; color: white; padding: 30px; text-align: center; }}
                .app-info {{ background: #f8f9fa; padding: 25px; border-radius: 12px; margin: 20px 0; }}
                .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }}
                @media (max-width: 600px) {{ .grid {{ grid-template-columns: 1fr; }} }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div style="font-size: 48px; margin-bottom: 15px;">🚀</div>
                    <h1 style="margin: 0; font-size: 28px;">Build Started</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9;">Your QuikApp build process has begun</p>
                </div>
                
                <div class="content">
                    <div class="app-info">
                        <h2 style="margin: 0 0 15px 0; color: #2c3e50;">📱 {self.app_name}</h2>
                        <div class="grid">
                            <div><strong>Version:</strong> {self.version_name} ({self.version_code})</div>
                            <div><strong>Platform:</strong> {platform}</div>
                            <div><strong>Build ID:</strong> {build_id}</div>
                            <div><strong>Workflow:</strong> {self.workflow_id}</div>
                            <div><strong>Organization:</strong> {self.org_name}</div>
                            <div><strong>Developer:</strong> {self.user_name}</div>
                        </div>
                    </div>
                    
                    {self.generate_feature_badges()}
                    
                    <div style="background: #e3f2fd; padding: 25px; border-radius: 12px; text-align: center;">
                        <h3 style="color: #1976d2; margin: 0 0 15px 0;">⏱️ Build in Progress</h3>
                        <p style="margin: 0;">Your app is currently being built. You'll receive another email when it's ready!</p>
                        <p style="margin: 10px 0 0 0; color: #666;"><strong>Estimated Time:</strong> 5-15 minutes</p>
                    </div>
                </div>
                
                <div class="footer">
                    <div style="font-size: 20px; font-weight: 700; color: #667eea; margin-bottom: 15px;">🚀 QuikApp</div>
                    <p style="margin: 0; opacity: 0.8;">© 2025 QuikApp Technologies. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return self._send_email(subject, html)
    
    def send_build_success_email(self, platform, build_id):
        """Send build success notification with download links"""
        subject = f"🎉 QuikApp Build Successful - {self.app_name}"
        
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>QuikApp Build Successful</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f7fa; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }}
                .header {{ background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 40px 30px; text-align: center; }}
                .content {{ padding: 30px; }}
                .footer {{ background: #2c3e50; color: white; padding: 30px; text-align: center; }}
                .app-info {{ background: #f8f9fa; padding: 25px; border-radius: 12px; margin: 20px 0; }}
                .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }}
                .actions {{ background: #e8f5e8; padding: 25px; border-radius: 12px; text-align: center; margin: 20px 0; }}
                .btn {{ display: inline-block; background: #27ae60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 5px; }}
                @media (max-width: 600px) {{ .grid {{ grid-template-columns: 1fr; }} }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div style="font-size: 48px; margin-bottom: 15px;">🎉</div>
                    <h1 style="margin: 0; font-size: 28px;">Build Successful!</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9;">Your QuikApp has been built successfully</p>
                </div>
                
                <div class="content">
                    <div class="app-info">
                        <h2 style="margin: 0 0 15px 0; color: #2c3e50;">📱 {self.app_name}</h2>
                        <div class="grid">
                            <div><strong>Version:</strong> {self.version_name} ({self.version_code})</div>
                            <div><strong>Platform:</strong> {platform}</div>
                            <div><strong>Build ID:</strong> {build_id}</div>
                            <div><strong>Workflow:</strong> {self.workflow_id}</div>
                            <div><strong>Organization:</strong> {self.org_name}</div>
                            <div><strong>Completed:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</div>
                        </div>
                    </div>
                    
                    {self.generate_artifact_cards(build_id)}
                    
                    {self.generate_feature_badges()}
                    
                    <div style="background: #fff3cd; padding: 25px; border-radius: 12px; margin: 20px 0;">
                        <h3 style="color: #856404; margin: 0 0 15px 0;">📋 Next Steps</h3>
                        <ul style="color: #856404; line-height: 1.8; margin: 0; padding-left: 20px;">
                            <li><strong>Android APK:</strong> Download and install directly on device for testing</li>
                            <li><strong>Android AAB:</strong> Upload to Google Play Console for store distribution</li>
                            <li><strong>iOS IPA:</strong> Upload to App Store Connect or distribute via TestFlight</li>
                            <li><strong>Testing:</strong> Test the app thoroughly on different devices before publishing</li>
                        </ul>
                    </div>
                    
                    <div style="background: #e3f2fd; padding: 25px; border-radius: 12px; margin: 20px 0;">
                        <h3 style="color: #1976d2; margin: 0 0 15px 0;">🔧 Installation Conflict Resolution</h3>
                        <p style="color: #424242; margin: 0 0 15px 0;">If you get "package conflicts with existing package" error:</p>
                        <ul style="color: #424242; line-height: 1.8; margin: 0; padding-left: 20px;">
                            <li><strong>Method 1:</strong> Uninstall existing app first → Install new APK</li>
                            <li><strong>Method 2:</strong> Use ADB: <code>adb install -r app-release.apk</code></li>
                            <li><strong>Method 3:</strong> Force uninstall: <code>adb uninstall package.name</code></li>
                            <li><strong>Different Versions:</strong> Debug and Release APKs have different signatures</li>
                        </ul>
                        <p style="color: #666; margin: 15px 0 0 0; font-size: 14px;">💡 Check your download for detailed installation guides with your specific package information.</p>
                    </div>
                    
                    <div class="actions">
                        <h3 style="color: #27ae60; margin: 0 0 20px 0;">🔗 Quick Actions</h3>
                        <a href="https://codemagic.io/builds/{build_id}" class="btn" style="background: #1976d2;">📋 View Build Logs</a>
                        <a href="https://codemagic.io" class="btn" style="background: #27ae60;">🚀 Start New Build</a>
                    </div>
                </div>
                
                <div class="footer">
                    <div style="font-size: 20px; font-weight: 700; color: #667eea; margin-bottom: 15px;">🚀 QuikApp</div>
                    <div style="margin: 15px 0;">
                        <a href="https://quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Website</a>
                        <a href="https://docs.quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Docs</a>
                        <a href="mailto:support@quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Support</a>
                    </div>
                    <p style="margin: 0; opacity: 0.8;">© 2025 QuikApp Technologies. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return self._send_email(subject, html)
    
    def send_build_failed_email(self, platform, build_id, error_message):
        """Send build failure notification"""
        subject = f"❌ QuikApp Build Failed - {self.app_name}"
        
        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>QuikApp Build Failed</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f7fa; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }}
                .header {{ background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 40px 30px; text-align: center; }}
                .content {{ padding: 30px; }}
                .footer {{ background: #2c3e50; color: white; padding: 30px; text-align: center; }}
                .app-info {{ background: #f8f9fa; padding: 25px; border-radius: 12px; margin: 20px 0; }}
                .error-box {{ background: #ffebee; padding: 25px; border-radius: 12px; border-left: 4px solid #f44336; margin: 20px 0; }}
                .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin: 20px 0; }}
                .actions {{ background: #e3f2fd; padding: 25px; border-radius: 12px; text-align: center; margin: 20px 0; }}
                .btn {{ display: inline-block; background: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 5px; }}
                @media (max-width: 600px) {{ .grid {{ grid-template-columns: 1fr; }} }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div style="font-size: 48px; margin-bottom: 15px;">❌</div>
                    <h1 style="margin: 0; font-size: 28px;">Build Failed</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9;">There was an issue with your QuikApp build</p>
                </div>
                
                <div class="content">
                    <div class="app-info">
                        <h2 style="margin: 0 0 15px 0; color: #2c3e50;">📱 {self.app_name}</h2>
                        <div class="grid">
                            <div><strong>Version:</strong> {self.version_name} ({self.version_code})</div>
                            <div><strong>Platform:</strong> {platform}</div>
                            <div><strong>Build ID:</strong> {build_id}</div>
                            <div><strong>Workflow:</strong> {self.workflow_id}</div>
                            <div><strong>Organization:</strong> {self.org_name}</div>
                            <div><strong>Failed At:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</div>
                        </div>
                    </div>
                    
                    <div class="error-box">
                        <h3 style="color: #c62828; margin: 0 0 15px 0;">⚠️ Error Details</h3>
                        <div style="background: white; padding: 15px; border-radius: 8px; border: 1px solid #e0e0e0;">
                            <code style="color: #d32f2f; font-family: 'Courier New', monospace; white-space: pre-wrap; font-size: 14px;">{error_message}</code>
                        </div>
                    </div>
                    
                    <div style="background: #ffebee; padding: 25px; border-radius: 12px; margin: 20px 0;">
                        <h3 style="color: #c62828; margin: 0 0 15px 0;">🔧 Troubleshooting Steps</h3>
                        <ol style="color: #424242; line-height: 1.8; margin: 0; padding-left: 20px;">
                            <li><strong>Check Environment Variables:</strong> Verify all required variables are set correctly</li>
                            <li><strong>Validate URLs:</strong> Ensure all asset URLs are accessible and return valid files</li>
                            <li><strong>Review Certificates:</strong> Check iOS certificates and Android keystore configuration</li>
                            <li><strong>Firebase Configuration:</strong> Verify Firebase config files are valid</li>
                            <li><strong>Build Dependencies:</strong> Check Flutter, Gradle, and Xcode versions</li>
                        </ol>
                    </div>
                    
                    <div class="actions">
                        <h3 style="color: #1976d2; margin: 0 0 20px 0;">🔄 Ready to Try Again?</h3>
                        <p style="margin: 0 0 20px 0;">After fixing the issues above, you can restart your build.</p>
                        <a href="https://codemagic.io" class="btn" style="background: #1976d2;">🚀 Restart Build</a>
                        <a href="https://codemagic.io/builds/{build_id}" class="btn" style="background: #757575;">📋 View Logs</a>
                    </div>
                </div>
                
                <div class="footer">
                    <div style="font-size: 20px; font-weight: 700; color: #667eea; margin-bottom: 15px;">🚀 QuikApp</div>
                    <div style="margin: 15px 0;">
                        <a href="https://quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Website</a>
                        <a href="https://docs.quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Docs</a>
                        <a href="mailto:support@quikapp.co" style="color: #667eea; text-decoration: none; margin: 0 15px;">Support</a>
                    </div>
                    <p style="margin: 0; opacity: 0.8;">© 2025 QuikApp Technologies. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """

        return self._send_email(subject, html)
    
    def _send_email(self, subject, html_content):
        """Send email with enhanced error handling and logging"""
        if not self.smtp_user or not self.smtp_pass:
            logger.warning("Missing SMTP credentials. Skipping email.")
            return False
        
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = Header(subject, 'utf-8')
            msg['From'] = Header(f"QuikApp Build System <{self.smtp_user}>", 'utf-8')
            msg['To'] = Header(self.recipient, 'utf-8')
            msg['X-Priority'] = '2'  # High priority
            msg['X-Mailer'] = 'QuikApp Build System v2.0'
            
            # Attach HTML content
            html_part = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(html_part)
            
            # Send email with enhanced connection handling
            logger.info(f"Sending email to {self.recipient} via {self.smtp_server}:{self.smtp_port}")
            
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.set_debuglevel(0)  # Set to 1 for debugging
                server.starttls()
                server.login(self.smtp_user, self.smtp_pass)
                
                # Send email
                result = server.sendmail(self.smtp_user, [self.recipient], msg.as_string())
                
                if result:
                    logger.warning(f"Email delivery issues: {result}")
                else:
                    logger.info(f"✅ Email sent successfully to {self.recipient}")
                    return True
                    
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ SMTP Authentication failed: {e}")
        except smtplib.SMTPRecipientsRefused as e:
            logger.error(f"❌ Recipient refused: {e}")
        except smtplib.SMTPServerDisconnected as e:
            logger.error(f"❌ SMTP server disconnected: {e}")
        except Exception as e:
            logger.error(f"❌ Failed to send email: {e}")
            
        return False

def main():
    """Main function to handle command line arguments"""
    # Add debugging information
    logger.info("=== QuikApp Email System Debug Info ===")
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Arguments received: {sys.argv}")
    logger.info(f"Environment variables:")
    logger.info(f"  EMAIL_SMTP_SERVER: {os.environ.get('EMAIL_SMTP_SERVER', 'NOT SET')}")
    logger.info(f"  EMAIL_SMTP_PORT: {os.environ.get('EMAIL_SMTP_PORT', 'NOT SET')}")
    logger.info(f"  EMAIL_SMTP_USER: {os.environ.get('EMAIL_SMTP_USER', 'NOT SET')}")
    logger.info(f"  EMAIL_SMTP_PASS: {'SET' if os.environ.get('EMAIL_SMTP_PASS') else 'NOT SET'}")
    logger.info(f"  EMAIL_ID: {os.environ.get('EMAIL_ID', 'NOT SET')}")
    logger.info(f"  ENABLE_EMAIL_NOTIFICATIONS: {os.environ.get('ENABLE_EMAIL_NOTIFICATIONS', 'NOT SET')}")
    logger.info(f"  APP_NAME: {os.environ.get('APP_NAME', 'NOT SET')}")
    logger.info(f"  CM_BUILD_ID: {os.environ.get('CM_BUILD_ID', 'NOT SET')}")
    logger.info(f"  CM_PROJECT_ID: {os.environ.get('CM_PROJECT_ID', 'NOT SET')}")
    logger.info(f"  FCI_BUILD_ID: {os.environ.get('FCI_BUILD_ID', 'NOT SET')}")
    logger.info(f"  FCI_PROJECT_ID: {os.environ.get('FCI_PROJECT_ID', 'NOT SET')}")
    logger.info(f"  BUILD_NUMBER: {os.environ.get('BUILD_NUMBER', 'NOT SET')}")
    logger.info("=======================================")
    
    if len(sys.argv) < 4:
        print("Usage: send_email.py <email_type> <platform> <build_id> [error_message]")
        print("Email types: build_started, build_success, build_failed")
        sys.exit(1)
    
    email_type = sys.argv[1]
    platform = sys.argv[2]
    build_id = sys.argv[3]
    error_message = sys.argv[4] if len(sys.argv) > 4 else "Unknown error occurred"
    
    logger.info(f"Processing email: type={email_type}, platform={platform}, build_id={build_id}")
    
    # Check if email notifications are enabled
    if os.environ.get("ENABLE_EMAIL_NOTIFICATIONS", "true").lower() == "false":
        logger.info("Email notifications are disabled. Exiting.")
        sys.exit(0)
    
    # Initialize email notifier
    try:
        notifier = QuikAppEmailNotifier()
        logger.info("Email notifier initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize email notifier: {e}")
        sys.exit(1)
    
    # Send appropriate email
    success = False
    try:
        if email_type == "build_started":
            success = notifier.send_build_started_email(platform, build_id)
        elif email_type == "build_success":
            success = notifier.send_build_success_email(platform, build_id)
        elif email_type == "build_failed":
            success = notifier.send_build_failed_email(platform, build_id, error_message)
        else:
            logger.error(f"Unknown email type: {email_type}")
            sys.exit(1)
    except Exception as e:
        logger.error(f"Failed to send email: {e}")
        sys.exit(1)
    
    if success:
        logger.info("✅ Email sent successfully")
        sys.exit(0)
    else:
        logger.error("❌ Failed to send email")
        sys.exit(1)

if __name__ == "__main__":
    main() 