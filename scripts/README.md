# Claudit Distribution Scripts

This directory contains scripts for building and distributing Claudit.

## Building the DMG Installer

### Quick Start

```bash
cd /Users/ravishankar/Work/MyApps/Claudit
./scripts/build-installer.sh
```

This will:
1. Clean the build directory
2. Build a Release archive
3. Export the app
4. Create a DMG installer at `build/Claudit.dmg`

## Distribution Process

### 1. Build the Installer

Run the build script:
```bash
./scripts/build-installer.sh
```

### 2. Code Signing (Required for Distribution)

Sign the app with your Apple Developer ID:

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Ravi Shankar (YOUR_TEAM_ID)" \
  --options runtime \
  "build/Export/Claudit.app"
```

**Important**: Replace `YOUR_TEAM_ID` with your actual Apple Developer Team ID.

### 3. Create a Signed DMG

After signing the app, rebuild the DMG:

```bash
# Create DMG with signed app
hdiutil create -volname "Claudit" \
  -srcfolder build/Export/Claudit.app \
  -ov -format UDZO \
  "build/Claudit-signed.dmg"
```

### 4. Notarization (Required for macOS Gatekeeper)

#### Setup Notarization Profile (One-time)

Create an app-specific password:
1. Go to https://appleid.apple.com/account/manage
2. Sign in with your Apple ID
3. Under "Security" → "App-Specific Passwords"
4. Generate a new password
5. Save it in Keychain:

```bash
xcrun notarytool store-credentials "claudit-notary-profile" \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

#### Submit for Notarization

```bash
xcrun notarytool submit "build/Claudit-signed.dmg" \
  --keychain-profile "claudit-notary-profile" \
  --wait
```

This will:
- Upload the DMG to Apple's notarization service
- Wait for the notarization to complete
- Display the result (usually takes 2-5 minutes)

#### Check Notarization Status

If you need to check status later:

```bash
xcrun notarytool log <submission-id> \
  --keychain-profile "claudit-notary-profile"
```

### 5. Staple the Notarization Ticket

After successful notarization, staple the ticket to the DMG:

```bash
xcrun stapler staple "build/Claudit-signed.dmg"
```

Verify stapling:

```bash
xcrun stapler validate "build/Claudit-signed.dmg"
```

### 6. Verify the Final DMG

Check code signature:

```bash
spctl -a -vv -t install "build/Claudit-signed.dmg"
```

Expected output:
```
build/Claudit-signed.dmg: accepted
source=Notarized Developer ID
```

## Uploading to Gumroad

### 1. Rename for Distribution

```bash
mv build/Claudit-signed.dmg build/Claudit-v1.0.0.dmg
```

### 2. Upload to Gumroad

1. Log in to https://gumroad.com
2. Create a new product or edit existing
3. Upload `Claudit-v1.0.0.dmg`
4. Set product details:
   - **Name**: Claudit - Track Claude Code Usage Costs
   - **Price**: Your pricing
   - **Description**: Copy from README.md
5. Add screenshots from `assets/images/claudit/`
6. Publish

### 3. Update Portfolio Website

Update the download URL in:
- `rshankras.github.io/_pages/apps/claudit.md` (2 places)
- `rshankras.github.io/_pages/portfolio.md` (1 place)

Replace:
```
https://rshankar.com/downloads/claudit
```

With your actual Gumroad link:
```
https://yourusername.gumroad.com/l/claudit
```

## Troubleshooting

### Archive Build Fails

If the archive step fails:
1. Open Xcode and build manually to see detailed errors
2. Ensure all dependencies are resolved
3. Check code signing settings in Xcode

### Notarization Fails

Common issues:
1. **Invalid signature**: Re-sign the app with `--options runtime`
2. **Hardened runtime missing**: Add hardened runtime in Xcode build settings
3. **Invalid entitlements**: Check entitlements file

View detailed notarization log:
```bash
xcrun notarytool log <submission-id> \
  --keychain-profile "claudit-notary-profile"
```

### DMG Won't Mount on User's Mac

1. Verify stapling: `xcrun stapler validate build/Claudit-signed.dmg`
2. Check if Gatekeeper accepts it: `spctl -a -vv -t install build/Claudit-signed.dmg`
3. Test on a clean Mac (not your development machine)

## Version Updates

When releasing a new version:

1. Update version in Xcode project
2. Run `./scripts/build-installer.sh`
3. Sign, notarize, and staple (steps 2-5 above)
4. Rename DMG with version number
5. Upload to Gumroad
6. Update release notes on portfolio website

## Quick Reference

```bash
# Build DMG
./scripts/build-installer.sh

# Sign
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Ravi Shankar (TEAM_ID)" \
  --options runtime \
  "build/Export/Claudit.app"

# Notarize
xcrun notarytool submit "build/Claudit.dmg" \
  --keychain-profile "claudit-notary-profile" \
  --wait

# Staple
xcrun stapler staple "build/Claudit.dmg"

# Verify
spctl -a -vv -t install "build/Claudit.dmg"
```

## Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Gumroad Seller Guide](https://help.gumroad.com/article/93-gumroad-101)
