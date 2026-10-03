<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# macOS 版 Luma

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**了解 Mac 的运行状态，找出占用空间的内容，确认后再清理。**

Luma 是原生 SwiftUI 应用，用于系统监控、存储分析和 Mac 维护。它在本地运行，无需账户、订阅，没有广告或遥测。

**个人和商业使用均免费且不限量。** 不限制设备、用户、功能或使用时长。可以查看源代码并在不修改的情况下编译。修改自己的副本或创建衍生版本需要书面许可。[许可证](LICENSE)。

## 功能

- **概览与内存：** CPU、内存压力、压缩内存、交换空间、磁盘、网络、电池和进程能耗计数。不进行虚假的 RAM 清理。
- **CPU 进程：** 将应用与辅助进程分组，支持搜索、展开详情，以及确认后正常退出应用。
- **存储与 Finder：** 查看卷、文件夹大小和大文件；通过 Finder 或“服务”在 Luma 中测量文件夹大小。
- **重复文件：** 使用 SHA-256 比较内容，删除前可检查匹配结果。
- **清理与开发工具：** 对允许的规则和受支持的开发缓存进行估算、检查和确认；默认移到废纸篓。
- **应用与启动项：** 已安装应用、可单独选择的关联文件、登录项和 LaunchAgents。系统 LaunchDaemons 仅供查看。
- **模拟器：** 确认后关闭 iOS 模拟器和 Android 模拟器；不操作实体设备，也不擦除设备数据。
- **磁盘与安全：** 可用时显示 SMART、FileVault、防火墙、Gatekeeper、SIP 和权限信息，并链接到设置。不是杀毒软件。
- **维护、计划与历史：** 受支持的维护操作和本地记录。计划任务会打开 Luma，不会静默删除文件。

## 支持 12 种界面语言

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

在 Luma 的“设置 → 语言”中选择，或跟随系统语言。部分技术文字或尚未翻译的内容可能显示为英语。

## 安全与隐私

清理必须通过 `CleanupRule` 和 `PathSafety` 检查。系统区域、钥匙串、Mail、Messages 和 SSH 密钥不在清理范围内。试运行不修改文件。文件仍在废纸篓中时，可通过 Finder 恢复。

核心功能在本地运行。无法获取的信息会明确标注，例如没有受支持公开 API 的温度、台式 Mac 上可能不存在的电池数据，以及取决于驱动器的 SMART 支持。[安全模型](Docs/Safety-Model.md)。

## 安装与要求

**需要 macOS 15 或更高版本。** 官方应用包发布后可在 [Releases](https://github.com/sekizlipenguen/luma-mac/releases) 获取。请检查每个版本的架构、签名和 Apple 公证状态。源代码 ZIP 不是可安装的应用。解压应用 ZIP，将 `Luma.app` 移到“应用程序”。

访问受保护的 Library 文件夹需要在“系统设置 → 隐私与安全性 → 完全磁盘访问权限”中授权。未授权时会跳过无法访问的位置。Finder 扩展可在 macOS 扩展设置中启用。iOS 需要 Xcode 命令行工具，Android 需要包含 `adb` 的 SDK 工具。

## 编译未修改的源代码

需要支持 Swift 6、macOS 15 或更新 SDK 的 Xcode，以及 XcodeGen。以下命令生成供本地使用的临时签名应用，不提供 Developer ID 签名或公证。

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

输出：`build/Build/Products/Release/Luma.app`。

## 屏幕截图

截图来自实际应用，界面语言为土耳其语。数值随 Mac 和工作负载变化。

![概览](Docs/Images/dashboard.png)

<details>
<summary>更多截图</summary>

![清理](Docs/Images/cleanup.png)

![开发工具](Docs/Images/developer.png)

![模拟器](Docs/Images/simulators.png)

</details>

## 许可证与反馈

**Luma Free Use, No Modification License 1.0** 允许不限量的个人和商业使用、查看、未修改编译，以及保留许可证和声明后分享未修改的副本。修改、衍生作品和重新品牌化需要书面许可。

Luma 属于 **source available（源码可见）**，不属于 OSI 定义的开源软件。GitHub 上查看和 fork 的权利仍然有效，但不额外授予修改许可。以前已授予的许可证权利不会撤销。英文 [LICENSE](LICENSE) 为准，本 README 仅作说明。

[问题与建议](https://github.com/sekizlipenguen/luma-mac/issues) · [贡献政策](Docs/Contributing.md) · [安全报告](SECURITY.md) · [架构](Docs/Architecture.md) · [详细英文指南](README.md)
