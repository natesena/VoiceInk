# VoiceInk Development Notes

## Code Signing Issues (December 2025)

### Known Problem: Duplicate Certificates
There are two "Apple Development: natesena@icloud.com (SQH7D9UNX3)" certificates in keychain:
- **REVOKED**: `175B875456A0D2CE72B3A592975826BC5652FDB8` - Delete this from Keychain Access
- **VALID**: `F6FDB0752FAD3B894D8F4D2B130AFFC3374EE36E` - Expires Nov 2026

This causes "ambiguous" errors when signing. **Fix**: Delete the revoked certificate from Keychain Access.

### Building for Development
```bash
xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug -allowProvisioningUpdates build
```
Note: The Makefile uses `CODE_SIGN_IDENTITY=""` which disables signing - avoid this for signed builds.

### Building for Distribution (Perpetual)
Development certificates only work from Xcode's DerivedData location. For apps that work anywhere:

1. **Get Developer ID Application certificate** from [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. **Notarize** using `xcrun notarytool`
3. Developer ID signed + notarized apps work indefinitely, even after certificate expires

### Error Reference
- "Launchd job spawn failed" error 163 = Usually code signing or provisioning issue
- "CSSMERR_TP_CERT_REVOKED" = Using a revoked certificate
