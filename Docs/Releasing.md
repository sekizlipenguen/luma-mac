# Application releases

The GitHub source archives do not contain an installable application. Publish a
universal `Luma.app` as a DMG and ZIP, together with checksums and accurate signing
status. Build and package outputs are ignored by Git.

## Local preview packages

```bash
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release \
  -derivedDataPath build/release CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
bash Scripts/package-release.sh build/release/Build/Products/Release/Luma.app preview
```

This produces `dist/<version>-preview/`. The app and Finder extension must have
matching versions and support both architectures. The package script checks
their signatures and the bundled license before creating either archive. It
never signs the app and refuses to overwrite an existing output directory.

Preview packages are not certified as Developer ID signed or notarized. State
their actual status prominently in release notes and label public preview
releases as prereleases. macOS can block first launch; Apple's [per-app approval
instructions](https://support.apple.com/en-us/102445) may apply. Do not instruct
users to disable Gatekeeper globally or remove quarantine attributes.

## Developer ID distribution

Use the maintainer's authorized Developer ID Application identity, or the
authorized publisher organization's identity. Do not use unrelated development
certificates. Apple's [Developer ID guide](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
explains certificate requirements.

1. Build for both architectures with Developer ID signing, secure timestamps,
   hardened runtime, and the app's existing entitlements. Include the embedded
   Finder extension in signing and verification.
2. Submit the signed app for [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
   Use a locally stored Keychain profile; never put credentials in the repository
   or release assets.
3. After Apple accepts it, staple and validate the ticket on `Luma.app`. Verify
   Gatekeeper assessment and launch on a separate Mac with a downloaded package.
4. Run `bash Scripts/package-release.sh /path/to/Luma.app notarized`. This mode
   requires a Developer ID Application signature, a stapled ticket, and a passing
   Gatekeeper assessment before packaging.
5. If distributing a signed/notarized DMG as well, sign and notarize the final
   DMG, staple its ticket, then regenerate checksums after those final changes.

## Validate and publish

- Extract the ZIP into an empty directory and verify the app's deep signature.
- Mount the DMG read-only; verify the bundled app and the `/Applications` link,
  then eject it. Launch the extracted app for a local smoke check.
- Verify `SHA256SUMS.txt`. Local launch of an ad-hoc app does not prove that a
  quarantined download will pass Gatekeeper on another Mac.
- Put DMG, ZIP, `INSTALL.txt`, `RELEASE-INFO.txt`, and `SHA256SUMS.txt` on a draft
  release first. Check version, source commit, architecture, minimum OS, license,
  language count, and signing notes before publishing.
- Update installation links in the localized READMEs after the application
  assets are publicly available. Confirm uploaded checksums match local assets.

Personal and commercial use remain free and unlimited under [LICENSE](../LICENSE).
Publishing an app does not grant modification rights.
