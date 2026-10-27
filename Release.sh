#!/bin/sh

# Release helper for the Tailwind Admin Dashboard droplet.
#
# This adapts the disk-inventory-x release flow to this repository, which has no
# Xcode project: the app bundle is already present as Contents/.

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
echo SCRIPT_DIR=$SCRIPT_DIR
APP_ROOT="$SCRIPT_DIR"
BUILD_DIR="$APP_ROOT/build"
APP_NAME="dashboard.app"
CONTENTS="$APP_ROOT/Contents"

CHECK_ONLY=0
NOTARIZE=0
TAG=""
APPLE_ID_DEFAULT="randymcmillan1@mac.com"
APPLE_ID="${APPLE_ID:-$APPLE_ID_DEFAULT}"
TEAM_ID="${TEAM_ID:-}"
PASSWORD="${NOTARY_PASSWORD:-${PASSWORD:-}}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

usage() {
    echo "Usage: $0 [--check] [--notarize] [--apple-id EMAIL] [--team-id TEAM] [--password PASS] [tag]" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            ;;
        --notarize)
            NOTARIZE=1
            ;;
        --apple-id)
            shift
            [ $# -gt 0 ] || usage
            APPLE_ID="$1"
            ;;
        --team-id)
            shift
            [ $# -gt 0 ] || usage
            TEAM_ID="$1"
            ;;
        --password)
            shift
            [ $# -gt 0 ] || usage
            PASSWORD="$1"
            ;;
        --signing-identity)
            shift
            [ $# -gt 0 ] || usage
            SIGNING_IDENTITY="$1"
            ;;
        --help|-h)
            usage
            ;;
        --*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            if [ -n "$TAG" ]; then
                echo "Unexpected extra argument: $1" >&2
                usage
            fi
            TAG="$1"
            ;;
    esac
    shift
done

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CONTENTS/Info.plist" 2>/dev/null || true)
if [ -z "$VERSION" ]; then
    VERSION=$(plutil -extract CFBundleShortVersionString raw "$CONTENTS/Info.plist" 2>/dev/null || true)
fi
if [ -z "$VERSION" ]; then
    echo "Unable to determine CFBundleShortVersionString from Contents/Info.plist." >&2
    exit 1
fi

if [ -z "$TAG" ]; then
    TAG="v${VERSION}"
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    CHECK_PARENT=""
    cleanup_check() {
        if [ -n "$CHECK_PARENT" ]; then
            rm -rf "$CHECK_PARENT"
        fi
    }
    trap cleanup_check EXIT

    if [ -d "$APP_ROOT/../dashboard-signed.app" ]; then
        APP_TO_CHECK="$APP_ROOT/../dashboard-signed.app"
    else
        CHECK_PARENT="$(mktemp -d)"
        CHECK_APP="$CHECK_PARENT/dashboard.app"
        mkdir -p "$CHECK_APP"
        cp -R "$CONTENTS" "$CHECK_APP/Contents"
        (cd "$CHECK_APP" && "$APP_ROOT/sign.sh")
        APP_TO_CHECK="$CHECK_PARENT/dashboard-signed.app"
    fi

    codesign -dv --verbose=4 "$APP_TO_CHECK" 2>&1 | sed -n '1,40p'
    codesign --verify --deep --strict --verbose=2 "$APP_TO_CHECK"
    spctl --assess --type execute --verbose=4 "$APP_TO_CHECK"
    exit 0
fi

if [ -z "$TEAM_ID" ]; then
    TEAM_ID="M684FYCYG6"
fi

# Choose a signing identity when one was not supplied. Developer ID Application
# is required for notarization; otherwise prefer Apple Development for local
# testing, falling back to Developer ID Application.
if [ -z "$SIGNING_IDENTITY" ]; then
    if [ "$NOTARIZE" -eq 1 ]; then
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/Developer ID Application:/{print $2; exit}')
    else
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/Apple Development:/{print $2; exit}')
    fi
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | awk '/Developer ID Application:/{print $2; exit}')
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    if [ "$NOTARIZE" -eq 1 ]; then
        echo "No Developer ID Application signing identity was found in your keychain." >&2
        echo "Install a Developer ID Application certificate, or rerun without --notarize for local signing only." >&2
    else
        echo "Unable to find an Apple Development or Developer ID Application codesigning identity. Set SIGNING_IDENTITY and retry." >&2
    fi
    security find-identity -v -p codesigning >&2
    exit 1
fi

# sign.sh stages a clean bundle containing only Contents and signs it.
(cd "$APP_ROOT" && SIGNING_IDENTITY="$SIGNING_IDENTITY" ./sign.sh)

git add Contents
git add .
git commit -m $TAG
git tag $TAG
git push --tags

SIGNED_APP="$APP_ROOT/../dashboard-signed.app"
if [ ! -d "$SIGNED_APP" ]; then
    echo "Signed app bundle was not created: $SIGNED_APP" >&2
    exit 1
fi

if [ "$NOTARIZE" -eq 1 ]; then
    if [ -z "$PASSWORD" ]; then
        echo "Missing --password (or NOTARY_PASSWORD/PASSWORD)." >&2
        exit 1
    fi

    NOTARIZE_ZIP="$BUILD_DIR/dashboard-notarize.zip"
    mkdir -p "$BUILD_DIR"
    ditto -c -k --keepParent "$SIGNED_APP" "$NOTARIZE_ZIP"

    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$PASSWORD" \
        --wait
    xcrun stapler staple "$SIGNED_APP"
    codesign --verify --deep --strict --verbose=2 "$SIGNED_APP"
    spctl --assess --type execute --verbose=4 "$SIGNED_APP"
fi

mkdir -p "$BUILD_DIR"
ZIP_NAME="$BUILD_DIR/dashboard-${TAG}.zip"

# Repackage the signed bundle under the final app name so the release zip
# unpacks as dashboard.app instead of dashboard-signed.app.
PACKAGE_DIR="$(mktemp -d)"
cp -R "$SIGNED_APP" "$PACKAGE_DIR/dashboard.app"
ditto -c -k --keepParent "$PACKAGE_DIR/dashboard.app" "$ZIP_NAME"
rm -rf "$PACKAGE_DIR"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    git tag "$TAG"
fi
if ! git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    git push origin "refs/tags/$TAG"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP_NAME" --clobber
else
    gh release create "$TAG" \
        --title "Dashboard ${TAG}" \
        --generate-notes \
        "$ZIP_NAME"
fi

REPO_NAME_WITH_OWNER=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
ASSET_NAME=$(basename "$ZIP_NAME")
RELEASE_ASSET_URL="https://github.com/${REPO_NAME_WITH_OWNER}/releases/download/${TAG}/${ASSET_NAME}"
echo "Release asset: ${RELEASE_ASSET_URL}"
open $RELEASE_ASSET_URL
