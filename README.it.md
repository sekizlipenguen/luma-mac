<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# Luma per macOS

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**Capisci il tuo Mac. Scopri cosa occupa spazio. Pulisci mantenendo il controllo.**

Luma è un’app nativa SwiftUI per monitorare il sistema, analizzare lo spazio e gestire la manutenzione del Mac. Funziona localmente, senza account, abbonamenti, pubblicità o telemetria.

**Uso personale e commerciale gratuito e illimitato:** nessun limite di dispositivi, utenti, funzioni o durata. Puoi consultare e compilare il codice senza modificarlo. Modificare la tua copia o creare versioni derivate richiede un’autorizzazione scritta. [Licenza](LICENSE).

## Funzioni

- **Panoramica e memoria:** CPU, pressione della memoria, memoria compressa, swap, disco, rete, batteria e contatori energetici dei processi. Nessuna falsa pulizia della RAM.
- **Processi CPU:** raggruppa app e processi ausiliari; ricerca, dettagli espandibili e chiusura normale con conferma.
- **Spazio e Finder:** esamina volumi, dimensioni delle cartelle e file grandi; misura le cartelle in Luma da Finder o Servizi.
- **Duplicati:** confronta i contenuti con SHA-256 e verifica le corrispondenze prima di rimuoverle.
- **Pulizia e sviluppo:** regole consentite e cache supportate; stima, revisione e conferma, con spostamento nel Cestino come impostazione predefinita.
- **App e avvio:** inventario, file associati selezionabili singolarmente, elementi di login e LaunchAgents. I LaunchDaemons di sistema sono solo consultabili.
- **Simulatori:** arresta simulatori iOS ed emulatori Android previa conferma; esclude i dispositivi fisici e non cancella i dati dei dispositivi.
- **Disco e sicurezza:** SMART se disponibile; FileVault, firewall, Gatekeeper, SIP e autorizzazioni con collegamenti alle Impostazioni. Non è un antivirus.
- **Manutenzione, pianificazione e cronologia:** azioni supportate e registri locali. La pianificazione apre Luma e non elimina file silenziosamente.

## 12 lingue dell’interfaccia

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

Scegli la lingua in Impostazioni → Lingua oppure segui quella del sistema. Alcuni testi tecnici o non ancora tradotti possono apparire in inglese.

## Sicurezza e privacy

La pulizia passa attraverso `CleanupRule` e `PathSafety`. Aree di sistema, portachiavi, Mail, Messages e chiavi SSH sono esclusi. Le simulazioni non modificano file. I file sono recuperabili tramite Finder finché restano nel Cestino.

Le funzioni principali sono locali. Le informazioni non disponibili vengono indicate: temperatura senza API pubblica supportata, batteria eventualmente assente sui Mac desktop e SMART dipendente dal disco. [Modello di sicurezza](Docs/Safety-Model.md).

## Installazione e requisiti

**macOS 15 o successivo.** I pacchetti ufficiali, quando pubblicati, saranno su [Releases](https://github.com/sekizlipenguen/luma-mac/releases). Controlla architettura, firma e notarizzazione Apple di ogni versione. Un ZIP del codice sorgente non è un’app installabile. Estrai lo ZIP dell’app e sposta `Luma.app` in Applicazioni.

Per le cartelle Library protette: Impostazioni di Sistema → Privacy e Sicurezza → Accesso completo al disco. Senza autorizzazione, Luma salta i percorsi inaccessibili. Attiva l’estensione Finder nelle impostazioni delle estensioni macOS se necessaria. iOS richiede strumenti da riga di comando Xcode; Android richiede strumenti SDK, incluso `adb`.

## Compilare il codice senza modificarlo

Servono Xcode con Swift 6, SDK macOS 15 o più recente e XcodeGen. Il comando genera una firma ad hoc per uso locale, senza firma Developer ID o notarizzazione.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Risultato: `build/Build/Products/Release/Luma.app`.

## Schermate

Schermate reali con interfaccia turca; i valori variano in base al Mac e al carico.

![Panoramica](Docs/Images/dashboard.png)

<details>
<summary>Altre schermate</summary>

![Pulizia](Docs/Images/cleanup.png)

![Strumenti di sviluppo](Docs/Images/developer.png)

![Simulatori](Docs/Images/simulators.png)

</details>

## Licenza e feedback

La **Luma Free Use, No Modification License 1.0** consente uso personale e commerciale illimitato, consultazione, compilazione senza modifiche e condivisione di copie inalterate con licenza e avvisi integri. Modifiche, opere derivate e cambio di marchio richiedono autorizzazione scritta.

Luma è **source available**, non open source secondo OSI. I diritti GitHub di consultazione e fork restano validi, senza ulteriore permesso di modifica. I diritti concessi in precedenza non vengono revocati. Fa fede il testo inglese di [LICENSE](LICENSE); questo README è una spiegazione.

[Errori e idee](https://github.com/sekizlipenguen/luma-mac/issues) · [Politica di contribuzione](Docs/Contributing.md) · [Segnalazioni di sicurezza](SECURITY.md) · [Architettura](Docs/Architecture.md) · [Guida completa in inglese](README.md)
