#!/usr/bin/env python3
"""
Test script to debug artifact URL generation
"""

import os
import urllib.parse

def test_artifact_urls():
    print("=== Artifact URL Debug Test ===")
    
    # Test environment variables
    env_vars = [
        "CM_BUILD_ID",
        "FCI_BUILD_ID", 
        "BUILD_NUMBER",
        "CM_PROJECT_ID",
        "FCI_PROJECT_ID"
    ]
    
    print("\n📋 Environment Variables:")
    for var in env_vars:
        value = os.environ.get(var, "NOT SET")
        print(f"  {var}: {value}")
    
    # Test build ID resolution
    print("\n🔍 Build ID Resolution:")
    cm_build_id = (os.environ.get("CM_BUILD_ID") or 
                  os.environ.get("FCI_BUILD_ID") or 
                  os.environ.get("BUILD_NUMBER") or 
                  "unknown")
    
    cm_project_id = (os.environ.get("CM_PROJECT_ID") or 
                    os.environ.get("FCI_PROJECT_ID") or 
                    "unknown")
    
    print(f"  Resolved build_id: {cm_build_id}")
    print(f"  Resolved project_id: {cm_project_id}")
    
    # Test artifact URLs
    print("\n🔗 Artifact URL Generation:")
    base_url = f"https://api.codemagic.io/artifacts/{cm_project_id}/{cm_build_id}"
    print(f"  Base URL: {base_url}")
    
    test_files = ["app-release.apk", "app-release.aab", "Runner.ipa"]
    for filename in test_files:
        encoded_filename = urllib.parse.quote(filename)
        download_url = f"{base_url}/{encoded_filename}"
        print(f"  {filename}: {download_url}")
    
    # Test Codemagic build URL
    codemagic_build_url = f"https://codemagic.io/builds/{cm_build_id}"
    print(f"\n📱 Codemagic Build URL: {codemagic_build_url}")
    
    # Test if files exist locally
    print("\n📁 Local File Check:")
    local_paths = [
        "output/android/app-release.apk",
        "output/android/app-release.aab", 
        "output/ios/Runner.ipa"
    ]
    
    for path in local_paths:
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"  ✅ {path} exists ({size} bytes)")
        else:
            print(f"  ❌ {path} not found")
    
    print("\n=== End Debug Test ===")

if __name__ == "__main__":
    test_artifact_urls() 