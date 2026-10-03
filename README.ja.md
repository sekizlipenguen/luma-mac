<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# macOS 用 Luma

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**[DMG をダウンロード — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

**Mac の状態を知り、容量を使っているものを見つけ、確認して整理。**

Luma は、システム監視、ストレージ分析、Mac のメンテナンスのためのネイティブ SwiftUI アプリです。ローカルで動作し、アカウント、サブスクリプション、広告、テレメトリはありません。

**個人・商用とも無料で無制限に利用できます。** デバイス数、ユーザー数、機能、利用期間に制限はありません。ソースコードの閲覧と変更せずにコンパイルすることが可能です。自分のコピーの変更や派生版の作成には書面による許可が必要です。[ライセンス](LICENSE)。

## 主な機能

- **概要とメモリ:** CPU、メモリプレッシャー、圧縮メモリ、スワップ、ディスク、ネットワーク、バッテリー、プロセスのエネルギーカウンター。見せかけの RAM クリーニングは行いません。
- **CPU プロセス:** アプリと補助プロセスをグループ化し、検索・詳細表示・確認後の通常終了に対応します。
- **ストレージと Finder:** ボリューム、フォルダサイズ、大容量ファイルを確認。Finder またはサービスから Luma でフォルダサイズを測定できます。
- **重複ファイル:** SHA-256 で内容を比較し、削除前に一致結果を確認できます。
- **クリーニングと開発ツール:** 許可されたルールと対応する開発キャッシュの見積もり、確認、実行。標準ではゴミ箱へ移動します。
- **アプリと起動項目:** インストール済みアプリ、個別に選択できる関連ファイル、ログイン項目、LaunchAgents。システムの LaunchDaemons は閲覧のみです。
- **シミュレータ:** 確認後に iOS シミュレータと Android エミュレータを停止。物理デバイスは対象外で、デバイスのデータは消去しません。
- **ディスクとセキュリティ:** 利用可能な SMART 情報、FileVault、ファイアウォール、Gatekeeper、SIP、権限を設定へのリンクとともに表示。ウイルス対策ソフトではありません。
- **メンテナンス・スケジュール・履歴:** 対応する操作とローカル履歴。スケジュールは Luma を開き、ファイルを自動的に削除しません。

## 12 言語のインターフェース

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

Luma の設定 → 言語で選択するか、システムの言語に従う設定を使えます。一部の技術的な表示や未翻訳のテキストは英語になります。

## 安全性とプライバシー

クリーニングには `CleanupRule` と `PathSafety` の検証が必要です。システム領域、キーチェーン、Mail、Messages、SSH キーは対象外です。試行実行はファイルを変更しません。ファイルがゴミ箱に残っている間は Finder から復元できます。

主要機能はローカルで動作します。対応する公開 API がない温度情報、デスクトップ Mac のバッテリー情報、ドライブに依存する SMART 情報など、取得できない情報は明示します。[安全性モデル](Docs/Safety-Model.md)。

## インストールと必要環境

**macOS 15 以降 · Apple Silicon と Intel。** DMG を開き、`Luma.app` をアプリケーションへドラッグします。アプリ ZIP の展開でもインストールできます。ソースコードのアーカイブにはビルド済みアプリは含まれません。

**[DMG をダウンロード — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

**プレビュー 0.1.0:** アドホック署名のみで、Developer ID 署名と Apple 公証はありません。初回起動が macOS にブロックされる場合があります。配布元を信頼できる場合は Apple の手順に従ってこのアプリを許可してください。管理された Mac では許可されない場合があります。 [Apple](https://support.apple.com/en-us/102445).

保護された Library フォルダには、システム設定 → プライバシーとセキュリティ → フルディスクアクセスから権限を付与します。権限がなければアクセスできない場所をスキップします。Finder 拡張は macOS の拡張設定で有効化できます。iOS には Xcode コマンドラインツール、Android には `adb` を含む SDK ツールが必要です。

## 変更せずにビルド

Swift 6 と macOS 15 以降の SDK に対応した Xcode、および XcodeGen が必要です。以下はローカル利用向けのアドホック署名ビルドであり、Developer ID 署名や公証は行いません。

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

出力: `build/Build/Products/Release/Luma.app`。

## スクリーンショット

実際のアプリを英語表示で撮影しています。数値は Mac と負荷によって変わります。

![概要](Docs/Images/dashboard.png)

<details>
<summary>その他の画面</summary>

![クリーニング](Docs/Images/cleanup.png)

![開発ツール](Docs/Images/developer.png)

![シミュレータ](Docs/Images/simulators.png)

</details>

## ライセンスとフィードバック

**Luma Free Use, No Modification License 1.0** は、無制限の個人・商用利用、閲覧、変更せずにコンパイルすること、およびライセンスと通知を保持した未変更コピーの共有を認めます。変更、派生物、ブランド変更には書面による許可が必要です。

Luma は **source available** であり、OSI の定義によるオープンソースではありません。GitHub 上での閲覧・フォークの権利は維持されますが、追加の変更許可にはなりません。以前に付与されたライセンスの権利は取り消されません。英語の [LICENSE](LICENSE) が優先され、この README は説明資料です。

[不具合・提案](https://github.com/sekizlipenguen/luma-mac/issues) · [貢献方針](Docs/Contributing.md) · [セキュリティ報告](SECURITY.md) · [設計](Docs/Architecture.md) · [詳しい英語ガイド](README.md)
