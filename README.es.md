<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# Luma para macOS

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**[Descargar DMG — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

**Entiende tu Mac. Encuentra qué ocupa espacio. Limpia manteniendo el control.**

Luma es una aplicación nativa de SwiftUI para supervisar el sistema, analizar el almacenamiento y mantener tu Mac. Funciona localmente, sin cuenta, suscripción, anuncios ni telemetría.

**Uso personal y comercial gratuito e ilimitado:** sin límites de dispositivos, usuarios, funciones ni tiempo. Puedes consultar y compilar el código sin modificarlo. Modificar tu propia copia o crear versiones derivadas requiere permiso por escrito. [Licencia](LICENSE).

## Funciones

- **Resumen y memoria:** CPU, presión de memoria, memoria comprimida, swap, disco, red, batería y contadores de energía de procesos. Sin limpieza ficticia de RAM.
- **Procesos CPU:** agrupa aplicaciones y procesos auxiliares; búsqueda, detalles desplegables y cierre normal con confirmación.
- **Almacenamiento y Finder:** inspecciona volúmenes, tamaños de carpetas y archivos grandes; mide carpetas en Luma desde Finder o Servicios.
- **Duplicados:** compara contenidos mediante SHA-256 y revisa coincidencias antes de eliminarlas.
- **Limpieza y desarrollo:** reglas permitidas y cachés compatibles; estimación, revisión y confirmación, con traslado a la Papelera por defecto.
- **Aplicaciones e inicio:** inventario, archivos asociados seleccionables, elementos de inicio de sesión y LaunchAgents. Los LaunchDaemons del sistema solo se consultan.
- **Simuladores:** apaga simuladores iOS y emuladores Android con confirmación; excluye dispositivos físicos y no borra datos del dispositivo.
- **Disco y seguridad:** SMART cuando está disponible; FileVault, cortafuegos, Gatekeeper, SIP y permisos con enlaces a Ajustes. No es un antivirus.
- **Mantenimiento, programación e historial:** acciones compatibles y registros locales. La programación abre Luma; no borra archivos silenciosamente.

## 12 idiomas de interfaz

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

Elige el idioma en Ajustes → Idioma o utiliza el idioma del sistema. Algunos textos técnicos o aún sin traducir pueden aparecer en inglés.

## Seguridad y privacidad

La limpieza pasa por `CleanupRule` y `PathSafety`. Se excluyen áreas del sistema, llaveros, Mail, Messages y claves SSH. Las simulaciones no modifican archivos. Puedes recuperar archivos desde Finder mientras permanezcan en la Papelera.

Las funciones principales son locales. Se indican los datos no disponibles: temperatura sin API pública compatible, posible ausencia de batería en equipos de escritorio y SMART según el disco. [Modelo de seguridad](Docs/Safety-Model.md).

## Instalación y requisitos

**macOS 15 o posterior · Apple Silicon e Intel.** Abre el DMG y arrastra `Luma.app` a Aplicaciones. También puedes extraer el ZIP de la app. Los archivos de código fuente no incluyen la app compilada.

**[Descargar DMG — v0.1.0](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.dmg)** · [ZIP](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/Luma-0.1.0-macOS-universal.zip) · [SHA-256](https://github.com/sekizlipenguen/luma-mac/releases/download/v0.1.0/SHA256SUMS.txt)

**Vista previa 0.1.0:** firma ad hoc, sin Developer ID ni notarización de Apple. macOS puede bloquear el primer inicio. Si confías en el origen, sigue las instrucciones de Apple para autorizar esta app. Los Mac administrados pueden impedirlo. [Apple](https://support.apple.com/en-us/102445).

Para carpetas Library protegidas: Ajustes del Sistema → Privacidad y seguridad → Acceso total al disco. Sin permiso, Luma omite ubicaciones inaccesibles. Activa la extensión Finder en los ajustes de extensiones de macOS si la necesitas. iOS requiere herramientas de línea de comandos Xcode; Android requiere herramientas SDK, incluido `adb`.

## Compilar el código sin modificar

Necesitas Xcode con Swift 6, SDK macOS 15 o más reciente y XcodeGen. El comando genera una aplicación con firma ad hoc para uso local, sin firma Developer ID ni notarización.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Resultado: `build/Build/Products/Release/Luma.app`.

## Capturas de pantalla

Capturas reales con interfaz en inglés; las métricas varían según el Mac y su carga.

![Resumen](Docs/Images/dashboard.png)

<details>
<summary>Más capturas</summary>

![Limpieza](Docs/Images/cleanup.png)

![Herramientas de desarrollo](Docs/Images/developer.png)

![Simuladores](Docs/Images/simulators.png)

</details>

## Licencia y comentarios

La **Luma Free Use, No Modification License 1.0** permite uso personal y comercial ilimitado, inspección, compilación sin cambios y compartir copias intactas conservando licencia y avisos. Modificaciones, derivados y cambios de marca requieren permiso por escrito.

Luma es **source available**, no código abierto según la definición de OSI. Se mantienen los derechos de GitHub para ver y hacer fork, sin permiso adicional de modificación. No se revocan derechos concedidos anteriormente. El texto inglés de [LICENSE](LICENSE) prevalece; este README es explicativo.

[Errores e ideas](https://github.com/sekizlipenguen/luma-mac/issues) · [Política de contribución](Docs/Contributing.md) · [Informes de seguridad](SECURITY.md) · [Arquitectura](Docs/Architecture.md) · [Guía detallada en inglés](README.md)
