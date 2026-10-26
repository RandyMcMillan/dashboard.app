#!/bin/bash
#
# org.gnostr.gnostr.droplet
#
# Exit immediately if any command fails
set -e

# Configuration: Target app bundle path (adjust if running from outside the .app folder)
APP_PATH="."

echo "=================================================="
echo "Searching macOS Keychain for Developer ID..."
echo "=================================================="

# Automatically extract the Developer ID Application identity string from keychain
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Error: No 'Developer ID Application' certificate found in your keychain!"
    exit 1
fi

echo "Using Identity: $SIGNING_IDENTITY"
echo ""

# Stage a clean bundle so only Contents is present at the bundle root.
# (The working tree keeps dev files like .git, sign.sh, etc. at the root.)
STAGE_DIR="$(mktemp -d)/dashboard.app"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH/Contents" "$STAGE_DIR/Contents"

OUTPUT_PATH="$(cd "$APP_PATH/.." && pwd)/dashboard-signed.app"
rm -rf "$OUTPUT_PATH"
cp -R "$STAGE_DIR" "$OUTPUT_PATH"

echo "Starting code signing process for: $OUTPUT_PATH"

# Remove extended attributes that often break signatures
xattr -cr "$OUTPUT_PATH"

# Apply code signature with hardened runtime
codesign --force --deep --sign "$SIGNING_IDENTITY" --options runtime "$OUTPUT_PATH"

# Verify the signature
echo ""
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$OUTPUT_PATH"

echo ""
echo "Code signing complete!"
echo "Signed app: $OUTPUT_PATH"
cp $OUTPUT_PATH/* .
