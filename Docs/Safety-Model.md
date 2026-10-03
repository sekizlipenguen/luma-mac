# Safety Model

## Rules

1. **Allowlist-first:** Only registered `CleanupRule` paths are cleaned in Cleaner / Developer.
2. **Denylist:** `/System`, `/usr`, `/bin`, `/sbin`, keychains, Mail, Messages, `.ssh`, etc. (`PathSafety`).
3. **Default mutation:** Move to Trash (Undo while in Trash).
4. **Dry Run** never mutates the filesystem.
5. **No fake RAM clean.**
6. **No root helper** in v1.
7. **Operation log:** `~/Library/Application Support/Luma/Operations/operations.jsonl`
8. **App uninstall:** Every related path is listed and individually selectable before Trash.
9. **Startup:** System LaunchDaemons are reveal-only; user LaunchAgents may toggle.
10. **Privacy:** Local only. No analytics SDK. No network requirement.
11. **CPU groups:** Normal AppKit quit for owned regular apps only; self and host system services are read-only. Process identity is rechecked at confirmation.
12. **Emulators:** Shutdown only confirmed device IDs via simctl / adb. Physical phones are excluded. Never erase device data or kill CoreSimulator/audio services; running device tests are interrupted.

## FDA

Full Disk Access improves coverage; without it Luma degrades honestly.
