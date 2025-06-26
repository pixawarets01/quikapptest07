#!/bin/bash
set -e

# Export IPA from xcarchive using xcodebuild
# Usage: ./export_ipa.sh [ARCHIVE_PATH] [EXPORT_OPTIONS_PLIST] [OUTPUT_DIR]

ARCHIVE_PATH="${1:-output/ios/Runner.xcarchive}"
EXPORT_OPTIONS_PLIST="${2:-ios/ExportOptions.plist}"
OUTPUT_DIR="${3:-output/ios}"

log() {
  echo "[export_ipa.sh] $1"
}

error() {
  echo "[export_ipa.sh] ❌ $1" >&2
}

log "Starting IPA export..."
log "Archive: $ARCHIVE_PATH"
log "ExportOptions.plist: $EXPORT_OPTIONS_PLIST"
log "Output directory: $OUTPUT_DIR"

# Check for archive
if [ ! -d "$ARCHIVE_PATH" ]; then
  error "Archive not found: $ARCHIVE_PATH"
  exit 1
fi

# Check for ExportOptions.plist
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
  error "ExportOptions.plist not found: $EXPORT_OPTIONS_PLIST"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Run xcodebuild export
log "Running xcodebuild -exportArchive..."
set +e
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$OUTPUT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
RESULT=$?
set -e

if [ $RESULT -ne 0 ]; then
  error "xcodebuild exportArchive failed. See above for details."
  exit $RESULT
fi

# Find the IPA file
IPA_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.ipa" | head -1)
if [ -f "$IPA_FILE" ]; then
  log "✅ IPA export successful: $IPA_FILE"
  log "📊 IPA size: $(du -h "$IPA_FILE" | cut -f1)"
else
  error "IPA file not found in $OUTPUT_DIR after export."
  exit 2
fi

exit 0 