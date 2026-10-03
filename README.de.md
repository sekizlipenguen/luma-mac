<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# Luma für macOS

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**Deinen Mac verstehen. Speicherfresser finden. Aufräumen mit Kontrolle.**

Luma ist eine native SwiftUI-App für Systemüberwachung, Speicheranalyse und Mac-Wartung. Sie arbeitet lokal, ohne Konto, Abonnement, Werbung oder Telemetrie.

**Private und gewerbliche Nutzung sind kostenlos und unbegrenzt:** keine Geräte-, Nutzer-, Funktions- oder Zeitlimits. Quellcode darf eingesehen und unverändert kompiliert werden. Änderungen, auch an der eigenen Kopie, und abgeleitete Versionen erfordern schriftliche Erlaubnis. [Lizenz](LICENSE).

## Funktionen

- **Systemübersicht und Arbeitsspeicher:** CPU, Speicherdruck, komprimierter Speicher, Swap, Festplattenplatz, Netzwerk, Akku und Prozessenergie. Keine künstliche RAM-Bereinigung.
- **CPU-Prozesse:** Apps mit Hilfsprozessen gruppieren, suchen und aufklappen; reguläres Beenden nur nach Bestätigung.
- **Speicher und Finder:** Laufwerke, Ordnergrößen und große Dateien untersuchen; Ordnergröße über Finder oder Dienste in Luma messen.
- **Duplikate:** Dateiinhalte mit SHA-256 vergleichen und Treffer vor dem Entfernen prüfen.
- **Bereinigung und Entwicklerwerkzeuge:** freigegebene Regeln und unterstützte Entwicklungs-Caches prüfen; Speicher schätzen, bestätigen und standardmäßig in den Papierkorb verschieben.
- **Apps und Autostart:** installierte Apps, einzeln auswählbare zugehörige Dateien, Anmeldeobjekte und LaunchAgents. System-LaunchDaemons bleiben schreibgeschützt.
- **Simulatoren:** iOS-Simulatoren und Android-Emulatoren nach Bestätigung herunterfahren; physische Geräte sind ausgeschlossen, Gerätedaten werden nicht gelöscht.
- **Festplatte und Sicherheit:** SMART, sofern verfügbar; FileVault, Firewall, Gatekeeper, SIP und Berechtigungen mit Links zu macOS-Einstellungen. Kein Virenscanner.
- **Wartung, Zeitplanung und Verlauf:** unterstützte Wartungsaktionen und lokale Protokolle. Zeitpläne öffnen Luma und löschen keine Dateien unbemerkt.

## 12 Oberflächensprachen

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

Wähle die Sprache in Luma unter Einstellungen → Sprache oder folge der Systemsprache. Manche technischen oder noch nicht übersetzten Texte erscheinen auf Englisch.

## Sicherheit und Datenschutz

Bereinigungen müssen `CleanupRule` und `PathSafety` passieren. Systembereiche, Schlüsselbund, Mail, Messages und SSH-Schlüssel sind ausgeschlossen. Probeläufe ändern keine Dateien. Papierkorb-Dateien können über Finder wiederhergestellt werden, solange sie dort liegen.

Kerndaten bleiben lokal. Fehlende Messwerte werden kenntlich gemacht: Temperatur benötigt eine unterstützte öffentliche API, Akkuwerte können auf Desktop-Macs fehlen und SMART hängt vom Laufwerk ab. [Sicherheitsmodell](Docs/Safety-Model.md).

## Installation und Voraussetzungen

**macOS 15 oder neuer.** Offizielle App-Pakete erscheinen, sobald veröffentlicht, unter [Releases](https://github.com/sekizlipenguen/luma-mac/releases). Prüfe dort Architektur, Signatur und Apple-Notarisierung. Ein Quellcode-ZIP ist keine installierbare App. Entpacke ein App-ZIP und verschiebe `Luma.app` nach Programme.

Für geschützte Library-Ordner: Systemeinstellungen → Datenschutz & Sicherheit → Festplattenvollzugriff. Ohne diese Berechtigung überspringt Luma unzugängliche Orte. Die Finder-Erweiterung kann in den macOS-Erweiterungseinstellungen aktiviert werden. iOS benötigt Xcode-Kommandozeilenwerkzeuge; Android benötigt SDK-Werkzeuge einschließlich `adb`.

## Unveränderten Quellcode bauen

Xcode mit Swift 6 und macOS-15-SDK oder neuer sowie XcodeGen sind erforderlich. Die folgenden Einstellungen erzeugen einen lokal ad-hoc signierten Build, keine Developer-ID-Signatur oder Notarisierung.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Ausgabe: `build/Build/Products/Release/Luma.app`.

## Screenshots

Echte App-Aufnahmen mit türkischer Oberfläche; Messwerte ändern sich mit dem Mac und seiner Auslastung.

![Systemübersicht](Docs/Images/dashboard.png)

<details>
<summary>Weitere Screenshots</summary>

![Bereinigung](Docs/Images/cleanup.png)

![Entwicklerwerkzeuge](Docs/Images/developer.png)

![Simulatoren](Docs/Images/simulators.png)

</details>

## Lizenz und Rückmeldungen

Die **Luma Free Use, No Modification License 1.0** erlaubt unbegrenzte private und gewerbliche Nutzung, Einsicht, unverändertes Kompilieren und Weitergabe unveränderter Kopien mit Lizenz und Hinweisen. Änderungen, abgeleitete Werke und Umbenennung erfordern schriftliche Erlaubnis.

Luma ist **source available**, nicht OSI-Open-Source. GitHub-Rechte zum Anzeigen und Forken bleiben bestehen; sie erteilen keine zusätzliche Änderungsberechtigung. Frühere Lizenzrechte werden nicht widerrufen. Der englische [LICENSE](LICENSE)-Text ist maßgeblich; diese README erläutert ihn nur.

[Fehler und Ideen](https://github.com/sekizlipenguen/luma-mac/issues) · [Beitragspolitik](Docs/Contributing.md) · [Sicherheitsmeldungen](SECURITY.md) · [Architektur](Docs/Architecture.md) · [Ausführliche englische Anleitung](README.md)
