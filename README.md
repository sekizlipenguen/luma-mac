<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma app icon">
</p>

# Luma for macOS

**See what your Mac is doing. Find what takes up space. Clean up with control.**

**12 interface languages · Native macOS · Free unlimited use**

Luma is a native SwiftUI utility for system monitoring, storage inspection, and Mac maintenance. It runs locally, with no account, subscription, ads, or telemetry.

**Free for personal and commercial use, with no device, user, feature, or time limits.** Source code is available to inspect and build; modifying it or creating derivative versions requires written permission. See [LICENSE](LICENSE).

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

[Releases](https://github.com/sekizlipenguen/luma-mac/releases) · [Report a bug](https://github.com/sekizlipenguen/luma-mac/issues) · [License](LICENSE)

**[Download DMG — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip)

## A look inside

Real screenshots of Luma on macOS, with the interface set to English. Metrics vary with your Mac and workload.

![Dashboard: CPU, memory, storage, network and battery](Docs/Images/dashboard.png)

<details>
<summary>More screenshots: cleanup, developer tools, and simulators</summary>

### Cleanup

![Allowlisted cleanup rules](Docs/Images/cleanup.png)

### Developer tools

![Developer cleanup options](Docs/Images/developer.png)

### Simulators

![iOS simulator and Android emulator management](Docs/Images/simulators.png)

</details>

## What Luma does

### Monitor your Mac

- **Dashboard:** CPU activity, memory pressure, compressed memory, swap, disk space, network rates, battery status, and process energy counters.
- **CPU processes:** groups applications and helpers, with live totals, search, expandable rows, and confirmation before a normal app quit.
- **Memory:** explains actual memory use and pressure. macOS manages caches; Luma does not promise artificial RAM boosts.
- **Network:** Wi-Fi/Ethernet activity and local connection information. Per-app byte rates are not invented when the API cannot provide them.
- **Disk health:** SMART information when macOS and the drive expose it.

### Understand your storage

- **Storage browser:** inspect volume usage and folder sizes with quick or home-wide scans.
- **Finder integration:** request a folder-size measurement from Finder or Services, shown in a Luma panel.
- **Large files:** locate files above a chosen size threshold.
- **Duplicates:** compare file content using SHA-256 and review matches before removal.

### Maintain with control

- **Cleanup:** estimates for registered cleanup rules, review, confirmation, and Move to Trash by default.
- **Developer cleanup:** inspect supported development caches and build artifacts; options depend on installed tools.
- **Applications:** app inventory and individually selectable related files for uninstalling.
- **Startup:** inspect login items and LaunchAgents; system LaunchDaemons remain reveal-only.
- **Simulators:** inspect iOS simulators and Android emulators and confirm shutdown of selected or listed virtual devices. Physical devices are excluded and device data is not erased.
- **Security:** review FileVault, firewall, Gatekeeper, SIP, and permission status, with macOS settings links. This is a status overview, not antivirus software.
- **Mac care, scheduling, and history:** supported maintenance actions and local operation records. A schedule opens Luma; it does not silently delete files.

## Languages

**12 interface languages:** English, Turkish, German, French, Spanish, Italian, Brazilian Portuguese, Japanese, Korean, Simplified Chinese, Russian, and Arabic.

Choose a language in **Settings → Language**, or follow the system language. System Default is a selection mode, not a thirteenth language. Some technical or untranslated labels may appear in English. Each supported language has a README linked at the top of this page.

## Safety and privacy

Cleanup paths must pass `CleanupRule` and `PathSafety`. Protected system paths and sensitive areas such as keychains, Mail, Messages, and SSH keys are excluded from cleanup. Dry runs do not modify files. Review estimates and selections before confirming; Trash recovery is available while the files remain in Trash.

Core features work locally without a network connection. There is no analytics SDK. Operation history stays on your Mac at `~/Library/Application Support/Luma/Operations/operations.jsonl`.

Unavailable information is labeled honestly: temperature may have no supported public API, battery data may be absent on desktops, and SMART depends on the drive. See the [safety model](Docs/Safety-Model.md) and [API matrix](Docs/API-Matrix.md).

## Get Luma

**Requires macOS 15 or later. Apple Silicon and Intel are supported.**

**[Download DMG — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [Application ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256 checksums](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

Open the DMG, drag `Luma.app` to **Applications**, eject the disk image, and open Luma from Applications. Alternatively, extract the application ZIP and move `Luma.app` to Applications. GitHub's automatic source-code archives do not contain an installable app.

**First public preview (0.1.0): ad-hoc signed, without Developer ID signing or Apple notarization.** macOS may block the first launch. If you trust this repository and the downloaded app, try opening Luma, then use **System Settings → Privacy & Security → Open Anyway**, and confirm Open. Managed Macs may prevent an exception. [Apple's instructions](https://support.apple.com/en-us/102445).

### Permissions and optional tools

- **Full Disk Access:** grant access in System Settings → Privacy & Security → Full Disk Access for protected user Library locations. Without it, Luma skips inaccessible locations and reports the limitation.
- **Finder:** enable the bundled Finder extension in macOS extension settings for its context menu; the folder-size Service is another entry point.
- **Simulators:** iOS features require Xcode command-line tools; Android features require Android SDK tools, including `adb`.

Luma disables App Sandbox to inspect and maintain supported user areas. Distribution is through GitHub Releases; check the specific release for signing status. The [release guide](Docs/Releasing.md) documents packaging and future Developer ID distribution.

## Build the unmodified source

Use Xcode with Swift 6 support and the macOS 15 SDK or newer, plus [XcodeGen](https://github.com/yonaskolb/XcodeGen). The license permits generated project files and local signing settings, without permission to change application code.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
open Luma.xcodeproj
```

For a local Release build without a Developer ID certificate:

```bash
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Output: `build/Build/Products/Release/Luma.app`. This uses ad-hoc signing for local use; it does not create a Developer ID signed or notarized release.

Run local package tests:

```bash
for package in Packages/*; do
  swift test --package-path "$package" || exit 1
done
```

## Architecture and documentation

The existing architecture uses MVVM, Observation, actor services, and protocol-based dependency injection through `AppEnvironment`:

```text
Views → ViewModels → Services (local Swift packages) → macOS APIs
```

Eight local packages provide models and contracts (`LumaCore`), permissions and file access (`LumaSupport`), metrics and controls (`LumaSystem`), scanning (`LumaStorage`), rules and history (`LumaCleanup`), inventory (`LumaApps`), startup items (`LumaStartup`), and shared components (`LumaUI`).

- [Architecture](Docs/Architecture.md)
- [Safety model](Docs/Safety-Model.md)
- [API matrix](Docs/API-Matrix.md)
- [Feedback policy](Docs/Contributing.md)
- [Security reports](SECURITY.md)
- [Licensing explained](Docs/Licensing.md)

## Feedback and ownership

Bug reports and feature suggestions are welcome through [Issues](https://github.com/sekizlipenguen/luma-mac/issues). Include the app version, macOS version, steps, expected result, and actual result; remove private information from attachments.

Maintainers control official development. Third-party code or documentation changes require prior written permission; unsolicited pull requests are not accepted. Public visibility does not grant permission to modify your own copy.

## License

**Luma Free Use, No Modification License 1.0** — [full terms](LICENSE).

Use Luma for any purpose, including commercial work, on any number of devices, without fees or usage limits. Inspect and compile the unmodified source, or share unchanged copies with the license and copyright notices intact. Modification, derivative works, rebranding, and incorporating code into another product require written permission.

This is **source-available software**, not OSI open source: the [Open Source Definition](https://opensource.org/osd) requires permission for modifications and derived works. GitHub's rights to view and fork public repositories still apply; they do not by themselves grant a modification license. Previously granted licenses, if any, are not revoked. See [licensing details](Docs/Licensing.md).
