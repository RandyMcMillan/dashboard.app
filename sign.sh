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

echo "Starting code signing process for: $APP_PATH"

# Remove extended attributes that often break signatures
xattr -cr "$APP_PATH"

# Apply code signature with hardened runtime
codesign --force --deep --sign "$SIGNING_IDENTITY" --options runtime "$APP_PATH"

# Verify the signature
echo ""
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "Code signing complete!"
