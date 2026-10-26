# Release flow

`Release.sh` is the one-stop release entry point for signing, notarizing, and publishing the `dashboard.app` droplet as a GitHub Release asset.

This repository has no Xcode project; the app bundle is already present as `Contents/`. The release flow therefore stages a clean bundle, signs it, optionally notarizes it, and uploads the resulting zip.

## Local signature check

Verify the existing app bundle without publishing:

```sh
./Release.sh --check
```

This runs `codesign --verify` and `spctl` against `../dashboard-signed.app`, or creates a temporary signed copy if one does not exist.

## Notarized release

For a notarized release, use:

```sh
./Release.sh --notarize --password "app-specific-password"
```

Optional overrides:

```sh
./Release.sh --notarize \
  --apple-id you@example.com \
  --team-id TEAMID \
  --signing-identity "Developer ID Application: Your Name (TEAMID)" \
  --password "app-specific-password" \
  v1.2
```

If no tag is supplied, the script reads `CFBundleShortVersionString` from `Contents/Info.plist` and prefixes it with `v`.

## What the script does

1. Reads the version from `Contents/Info.plist`.
2. Chooses a signing identity:
   - `Developer ID Application` when `--notarize` is set
   - `Apple Development` otherwise, falling back to `Developer ID Application`
3. Calls `./sign.sh` to stage a clean bundle (only `Contents`) and sign it.
4. If `--notarize` is set:
   - creates a temporary zip for `xcrun notarytool`
   - submits the archive and waits for approval
   - staples the notarization ticket to the signed app
   - verifies Gatekeeper acceptance with `spctl`
5. Creates the final release zip in `build/dashboard-<tag>.zip`.
6. Creates the Git tag locally if it does not exist and pushes it to `origin` if it is not already on the remote.
7. Creates or updates the GitHub Release asset with `gh release`.
8. Prints the direct download URL for the release asset.

## Defaults and inputs

The script can infer sensible defaults:

- Apple ID from `APPLE_ID` or the built-in default
- Team ID from `TEAM_ID`
- Signing identity from `SIGNING_IDENTITY` or the installed certificate

You can override any of these with flags or environment variables.

## Typical notarized release

```sh
./Release.sh --notarize --password "app-specific-password"
```

If the tag already exists locally but not on `origin`, the script pushes it before creating the GitHub Release.
