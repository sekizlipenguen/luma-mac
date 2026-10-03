# Feedback and contribution policy

Luma uses the [Luma Free Use, No Modification License](../LICENSE).
Maintainers control development. Modifying your own copy or submitting code or
documentation changes requires prior written permission. Unsolicited pull
requests are not accepted.

## Reports and suggestions

Use [GitHub Issues](https://github.com/sekizlipenguen/luma-mac/issues). Include the
Luma version, macOS version, reproduction steps, and expected and actual result.
Remove private paths, credentials, IP addresses, and private file names from
screenshots. See [SECURITY.md](../SECURITY.md) for vulnerability reports.

## Authorized development

Maintainers and expressly authorized contributors follow these existing rules:

1. Keep metrics honest — no placeholders for system values.
2. New cleanup paths must go through `CleanupRule` + `PathSafety`.
3. Prefer Trash over permanent delete.
4. Add unit tests for classifiers, safety, and dry-run behavior.
5. Run `xcodegen generate` after structural changes.
