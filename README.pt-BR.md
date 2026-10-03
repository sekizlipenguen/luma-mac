<p align="center">
  <img src="Luma/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="112" alt="Luma">
</p>

# Luma para macOS

[English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Italiano](README.it.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · [Русский](README.ru.md) · [العربية](README.ar.md)

**Entenda seu Mac. Descubra o que ocupa espaço. Limpe mantendo o controle.**

Luma é um aplicativo nativo em SwiftUI para monitorar o sistema, analisar o armazenamento e cuidar do Mac. Funciona localmente, sem conta, assinatura, anúncios ou telemetria.

**Uso pessoal e comercial gratuito e ilimitado:** sem limites de dispositivos, usuários, recursos ou duração. O código pode ser consultado e compilado sem alterações. Modificar sua própria cópia ou criar versões derivadas exige autorização por escrito. [Licença](LICENSE).

## Recursos

- **Visão geral e memória:** CPU, pressão de memória, memória comprimida, swap, disco, rede, bateria e contadores de energia dos processos. Sem limpeza falsa de RAM.
- **Processos CPU:** agrupa apps e processos auxiliares; busca, detalhes expansíveis e encerramento normal com confirmação.
- **Armazenamento e Finder:** examina volumes, tamanhos de pastas e arquivos grandes; mede pastas no Luma pelo Finder ou Serviços.
- **Duplicados:** compara conteúdos com SHA-256 e permite revisar resultados antes da remoção.
- **Limpeza e desenvolvimento:** regras permitidas e caches compatíveis; estimativa, revisão e confirmação, com envio para a Lixeira por padrão.
- **Apps e inicialização:** inventário, arquivos associados selecionáveis individualmente, itens de início de sessão e LaunchAgents. LaunchDaemons do sistema são somente para consulta.
- **Simuladores:** encerra simuladores iOS e emuladores Android com confirmação; exclui dispositivos físicos e não apaga dados dos dispositivos.
- **Disco e segurança:** SMART quando disponível; FileVault, firewall, Gatekeeper, SIP e permissões com links para Ajustes. Não é antivírus.
- **Manutenção, agendamento e histórico:** ações compatíveis e registros locais. O agendamento abre o Luma; não exclui arquivos silenciosamente.

## 12 idiomas de interface

English · Türkçe · Deutsch · Français · Español · Italiano · Português (Brasil) · 日本語 · 한국어 · 简体中文 · Русский · العربية

Escolha em Ajustes → Idioma ou use o idioma do sistema. Alguns textos técnicos ou ainda não traduzidos podem aparecer em inglês.

## Segurança e privacidade

As limpezas passam por `CleanupRule` e `PathSafety`. Áreas do sistema, chaves, Mail, Messages e chaves SSH são excluídas. Simulações não alteram arquivos. É possível recuperar pelo Finder arquivos que ainda estejam na Lixeira.

Os recursos principais são locais. Dados indisponíveis são indicados: temperatura sem API pública compatível, bateria eventualmente ausente em Macs de mesa e SMART dependente do disco. [Modelo de segurança](Docs/Safety-Model.md).

## Instalação e requisitos

**macOS 15 ou posterior.** Os pacotes oficiais, quando publicados, ficam em [Releases](https://github.com/sekizlipenguen/luma-mac/releases). Confira arquitetura, assinatura e notarização Apple em cada versão. Um ZIP de código-fonte não é um app instalável. Extraia o ZIP do aplicativo e mova `Luma.app` para Aplicativos.

Para pastas Library protegidas: Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco. Sem permissão, o Luma ignora locais inacessíveis. Ative a extensão Finder nos ajustes de extensões do macOS se necessário. iOS precisa das ferramentas de linha de comando Xcode; Android precisa das ferramentas SDK, incluindo `adb`.

## Compilar o código sem alterações

São necessários Xcode com Swift 6, SDK macOS 15 ou mais recente e XcodeGen. O comando gera um app com assinatura ad hoc para uso local, sem assinatura Developer ID ou notarização.

```bash
git clone https://github.com/sekizlipenguen/luma-mac.git
cd luma-mac
brew install xcodegen
xcodegen generate
xcodebuild -project Luma.xcodeproj -scheme Luma -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Saída: `build/Build/Products/Release/Luma.app`.

## Capturas de tela

Capturas reais com interface em turco; os valores variam conforme o Mac e a carga de trabalho.

![Visão geral](Docs/Images/dashboard.png)

<details>
<summary>Mais capturas</summary>

![Limpeza](Docs/Images/cleanup.png)

![Ferramentas de desenvolvimento](Docs/Images/developer.png)

![Simuladores](Docs/Images/simulators.png)

</details>

## Licença e comentários

A **Luma Free Use, No Modification License 1.0** permite uso pessoal e comercial ilimitado, consulta, compilação sem alterações e compartilhamento de cópias intactas mantendo licença e avisos. Alterações, derivados e mudança de marca exigem autorização por escrito.

Luma é **source available**, não código aberto pela definição da OSI. Os direitos GitHub de visualizar e criar forks permanecem, sem autorização adicional para modificar. Direitos concedidos anteriormente não são revogados. O texto inglês de [LICENSE](LICENSE) prevalece; este README é explicativo.

[Erros e ideias](https://github.com/sekizlipenguen/luma-mac/issues) · [Política de contribuição](Docs/Contributing.md) · [Relatos de segurança](SECURITY.md) · [Arquitetura](Docs/Architecture.md) · [Guia detalhado em inglês](README.md)
