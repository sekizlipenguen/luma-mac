<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# macOS용 Luma

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**Mac의 상태를 파악하고, 공간을 차지하는 항목을 찾고, 확인하면서 정리하세요.**

Luma는 시스템 모니터링, 저장 공간 분석, Mac 유지 관리를 위한 네이티브 SwiftUI 앱입니다. 계정, 구독, 광고, 원격 측정 없이 로컬에서 작동합니다.

**개인 및 상업적 용도로 무료이며 무제한입니다.** 기기, 사용자, 기능, 사용 기간의 제한이 없습니다. 소스 코드를 열람하고 변경 없이 컴파일할 수 있습니다. 자신의 사본을 수정하거나 파생 버전을 만들려면 서면 허가가 필요합니다. [라이선스](LICENSE).

## 주요 기능

- **요약 및 메모리:** CPU, 메모리 압력, 압축 메모리, 스왑, 디스크, 네트워크, 배터리, 프로세스 에너지 카운터를 표시합니다. 허위 RAM 정리를 하지 않습니다.
- **CPU 프로세스:** 앱과 보조 프로세스를 그룹화하고 검색 및 상세 보기를 제공하며, 확인 후 정상 종료합니다.
- **저장 공간 및 Finder:** 볼륨, 폴더 크기, 대용량 파일을 확인합니다. Finder 또는 서비스에서 Luma로 폴더 크기를 측정합니다.
- **중복 파일:** SHA-256으로 내용을 비교하고 삭제 전에 결과를 검토합니다.
- **정리 및 개발 도구:** 허용된 규칙과 지원되는 개발 캐시의 용량 추정, 검토, 확인을 제공합니다. 기본적으로 휴지통으로 이동합니다.
- **앱 및 시작 항목:** 설치된 앱, 개별 선택 가능한 관련 파일, 로그인 항목, LaunchAgents를 표시합니다. 시스템 LaunchDaemons는 보기 전용입니다.
- **시뮬레이터:** 확인 후 iOS 시뮬레이터와 Android 에뮬레이터를 종료합니다. 실제 기기는 제외하며 기기 데이터를 지우지 않습니다.
- **디스크 및 보안:** 가능한 경우 SMART, FileVault, 방화벽, Gatekeeper, SIP, 권한을 설정 링크와 함께 표시합니다. 백신 프로그램은 아닙니다.
- **유지 관리, 예약 및 기록:** 지원되는 작업과 로컬 기록을 제공합니다. 예약은 Luma를 열며 파일을 몰래 삭제하지 않습니다.

## 인터페이스 12개 언어 지원

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

설정 → 언어에서 선택하거나 시스템 언어를 따를 수 있습니다. 일부 기술 문구나 아직 번역되지 않은 텍스트는 영어로 표시될 수 있습니다.

## 안전 및 개인정보 보호

정리는 `CleanupRule`과 `PathSafety`를 통과해야 합니다. 시스템 영역, 키체인, Mail, Messages, SSH 키는 제외됩니다. 모의 실행은 파일을 변경하지 않습니다. 휴지통에 남아 있는 파일은 Finder에서 복원할 수 있습니다.

주요 기능은 로컬에서 작동합니다. 지원되는 공개 API가 없는 온도, 데스크톱 Mac의 배터리 부재, 드라이브에 따른 SMART 지원 등 정보의 한계를 명시합니다. [안전 모델](Docs/Safety-Model.md).

## 설치 및 요구 사항

**macOS 15 이상.** 공식 앱 패키지는 게시 후 [Releases](https://github.com/sekizlipenguen/luma-mac/releases)에서 제공됩니다. 각 버전의 아키텍처, 서명, Apple 공증 상태를 확인하세요. 소스 코드 ZIP은 설치용 앱이 아닙니다. 앱 ZIP을 풀고 `Luma.app`을 응용 프로그램으로 옮기세요.

보호된 Library 폴더에는 시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한이 필요합니다. 권한이 없으면 접근 불가능한 위치를 건너뜁니다. Finder 확장은 macOS 확장 설정에서 활성화할 수 있습니다. iOS에는 Xcode 명령줄 도구, Android에는 `adb`를 포함한 SDK 도구가 필요합니다.

## 소스 변경 없이 빌드

Swift 6과 macOS 15 이상 SDK를 지원하는 Xcode, XcodeGen이 필요합니다. 아래 명령은 로컬 사용을 위한 임시 서명 빌드를 만들며, Developer ID 서명이나 공증을 제공하지 않습니다.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

출력: `build/Build/Products/Release/Luma.app`.

## 스크린샷

터키어 인터페이스의 실제 앱 화면입니다. 수치는 Mac과 작업 부하에 따라 달라집니다.

![요약](Docs/Images/dashboard.png)

<details>
<summary>추가 화면</summary>

![정리](Docs/Images/cleanup.png)

![개발 도구](Docs/Images/developer.png)

![시뮬레이터](Docs/Images/simulators.png)

</details>

## 라이선스 및 의견

**Luma Free Use, No Modification License 1.0**은 무제한 개인 및 상업적 사용, 열람, 변경 없는 컴파일, 라이선스와 고지 사항을 유지한 원본 사본 공유를 허용합니다. 수정, 파생물, 브랜드 변경에는 서면 허가가 필요합니다.

Luma는 **source available**이며 OSI 정의의 오픈 소스는 아닙니다. GitHub에서 보기 및 포크할 권리는 유지되지만 추가 수정 권한을 부여하지는 않습니다. 이전에 부여된 라이선스 권리는 철회되지 않습니다. 영어 [LICENSE](LICENSE)가 우선하며 이 README는 설명용입니다.

[오류 및 제안](https://github.com/sekizlipenguen/luma-mac/issues) · [기여 정책](Docs/Contributing.md) · [보안 보고](SECURITY.md) · [아키텍처](Docs/Architecture.md) · [자세한 영어 안내](README.md)
