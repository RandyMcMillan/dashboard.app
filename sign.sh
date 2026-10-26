#!/bin/bash
#
# org.gnostr.gnostr.droplet

#!/bin/bash

# Exit immediately if any command fails
set -e

echo "=================================================="
echo "Searching macOS Keychain for Code Signing Identities..."
echo "=================================================="
echo ""

# Check all valid code-signing identities present in the keychain
echo "--- All Valid Code Signing Identities ---"
security find-identity -v -p codesigning

echo ""
echo "=================================================="
echo "--- Filtered: Developer ID Application Only ---"
echo "=================================================="

# Filter specifically for Developer ID Application certificates
DEVELOPER_IDS=$(security find-identity -v -p codesigning | grep "Developer ID Application" || true)

if [ -z "$DEVELOPER_IDS" ]; then
    echo "No 'Developer ID Application' certificates found in your keychain."
    echo "Ensure your Apple Developer certificate is installed in Keychain Access."
else
    echo "$DEVELOPER_IDS"
    echo ""
    echo "💡 Copy the string inside the quotes (e.g., \"Developer ID Application: Your Name (TEAMID)\") for your codesign command."
fi


# Configuration
APP_PATH="."
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" # Use "-" for ad-hoc

echo "Starting code signing process for: $APP_PATH"

# Remove extended attributes that often break signatures
xattr -cr "$APP_PATH"

# Apply code signature with hardened runtime
codesign --force --deep --sign "$SIGNING_IDENTITY" --options runtime "$APP_PATH"

# Verify the signature
echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Code signing complete!"
