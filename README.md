# Azura Store

iOS app for the Azura store at https://azuramall.shop/.

- Bundle ID: `tz.azurastore.app`
- Version: 1.1 (build 1)
- Minimum OS: iOS 16

## Requirements

- Mac
- Xcode 15 or newer
- iOS 16 or newer
- A paid Apple Developer account

## Open and sign

1. Open `AzuraStore.xcodeproj`.
2. Select the AzuraStore target.
3. Open Signing & Capabilities.
4. Choose your Team. Signing is automatic, and `DEVELOPMENT_TEAM` is intentionally unset.

## Archive and upload

Archive the app in Xcode and upload it with Organizer to App Store Connect for bundle ID `tz.azurastore.app`.

## Store API

The app calls `{store URL}api/` and defaults the store URL to https://azuramall.shop/.
