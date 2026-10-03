#!/bin/bash
# Packages an already-built app; keeps signing separate from archive creation.
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 APP_PATH preview|notarized [OUTPUT_DIRECTORY]" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$1"
release_mode="$2"
case "$release_mode" in
  preview|notarized) ;;
  *) echo "Release mode must be preview or notarized." >&2; exit 1 ;;
esac

[[ -d "$app_path/Contents" ]] || { echo "App bundle not found." >&2; exit 1; }
app_path="$(cd "$app_path" && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Expected a numeric three-part app version." >&2; exit 1; }

extension="$app_path/Contents/PlugIns/LumaFinderSync.appex"
for bundle in "$app_path" "$extension"; do
  /usr/bin/codesign --verify --strict "$bundle"
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")"
  architectures=" $(/usr/bin/lipo -archs "$bundle/Contents/MacOS/$executable") "
  [[ "$architectures" == *" arm64 "* && "$architectures" == *" x86_64 "* ]] || {
    echo "Both arm64 and x86_64 are required: $bundle" >&2; exit 1;
  }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")" == "$version" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$bundle/Contents/Info.plist")" == "$build_number" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$bundle/Contents/Info.plist")" == "15.0" ]]
done
/usr/bin/codesign --verify --deep --strict "$app_path"
/usr/bin/cmp "$repo_root/LICENSE" "$app_path/Contents/Resources/LICENSE"

if [[ "$release_mode" == notarized ]]; then
  signature="$(/usr/bin/codesign -dv --verbose=2 "$app_path" 2>&1)"
  [[ "$signature" == *"Authority=Developer ID Application:"* ]] || {
    echo "A Developer ID Application signature is required." >&2; exit 1;
  }
  /usr/bin/xcrun stapler validate "$app_path"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$app_path"
  signing_status="Developer ID signed; Apple notarization ticket stapled and Gatekeeper assessment passed."
  signing_status_tr="Apple Developer ID ile imzalanmış; noter onayı uygulamaya eklenmiş ve Gatekeeper kontrolü geçmiştir."
else
  signing_status="Preview distribution: Developer ID signing and Apple notarization are not certified by this package. macOS may block the first launch."
  signing_status_tr="Önizleme sürümünde Apple dağıtım imzası ve noter onayı doğrulanmış değildir. macOS ilk açılışı engelleyebilir."
fi

output_dir="${3:-$repo_root/dist/$version-$release_mode}"
[[ ! -e "$output_dir" ]] || { echo "Output directory already exists; choose a fresh path." >&2; exit 1; }
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
stage_dir="$(mktemp -d "$output_dir/.package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT

/usr/bin/ditto --norsrc --noextattr "$app_path" "$stage_dir/Luma.app"
/usr/bin/codesign --verify --deep --strict "$stage_dir/Luma.app"
cp "$repo_root/LICENSE" "$stage_dir/LICENSE.txt"
ln -s /Applications "$stage_dir/Applications"
cat > "$stage_dir/INSTALL.txt" <<EOF
Luma $version (build $build_number)
macOS 15 or later / macOS 15 veya üzeri
Apple Silicon + Intel (universal)

ENGLISH
Drag Luma.app to Applications, then open it from Applications.
If using the ZIP instead, extract it and move Luma.app to Applications.
$signing_status
If macOS blocks this preview and you trust its source, see Apple's per-app
approval instructions: https://support.apple.com/en-us/102445
Managed Macs may not allow an exception. Do not disable Gatekeeper globally.

TÜRKÇE
Luma.app dosyasını Applications / Uygulamalar klasörüne sürükleyin ve oradan açın.
ZIP kullanıyorsanız önce arşivi açıp Luma.app dosyasını Uygulamalar'a taşıyın.
$signing_status_tr
macOS engellerse ve kaynağa güveniyorsanız Apple'ın uygulamaya özel onay
adımlarını izleyin: https://support.apple.com/tr-tr/102445
Yönetilen Mac'lerde izin verilmeyebilir. Gatekeeper'ı genel olarak kapatmayın.

12 interface languages / 12 arayüz dili:
English, Türkçe, Deutsch, Français, Español, Italiano, Português (Brasil),
日本語, 한국어, 简体中文, Русский, العربية

Free unlimited personal and commercial use. Modification requires permission.
Kişisel ve ticari kullanım ücretsiz ve sınırsızdır. Değişiklik için izin gerekir.
See LICENSE.txt and Luma.app/Contents/Resources/LICENSE.
https://github.com/sekizlipenguen/luma-mac
EOF

asset_name="Luma-$version-macOS-universal"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$stage_dir/Luma.app" "$output_dir/$asset_name.zip"
/usr/bin/hdiutil create -volname "Luma $version" -srcfolder "$stage_dir" -format UDZO -ov "$output_dir/$asset_name.dmg"
/usr/bin/hdiutil verify "$output_dir/$asset_name.dmg"
cp "$stage_dir/INSTALL.txt" "$output_dir/INSTALL.txt"
cat > "$output_dir/RELEASE-INFO.txt" <<EOF
Version: $version
Build: $build_number
Architectures: arm64 x86_64 (application and Finder extension)
Minimum macOS: 15.0
Package mode: $release_mode
Signing status: $signing_status
EOF
(
  cd "$output_dir"
  /usr/bin/shasum -a 256 "$asset_name.dmg" "$asset_name.zip" INSTALL.txt RELEASE-INFO.txt > SHA256SUMS.txt
)
echo "Packages created: $output_dir"
