# Sent — app Flutter dos atendentes

App nativo (Android + iOS, um código só) pra **equipe de atendimento** das
empresas que assinam o **Sent** (atendimento multiusuário no WhatsApp com
IA, `ECOSSISTEMAS/_SENT/sent/`, contas em `https://<empresa>.sent.app.br`). Não é
pro cliente final da empresa.

## De onde veio

Cópia do `app_ecossistema` (app do Ecossistema Jurídico) no commit
`a7e5231`, trocando a marca. O backend do Sent é uma cópia do `ejurapp`,
então as rotas, o login por QR/código e o token Bearer são os mesmos — ler
o `CLAUDE.md` do `app_ecossistema` pra arquitetura (api, models, telas,
pareamento). Correção feita num dos dois apps **não** vai sozinha pro outro.

## O que muda em relação ao app do ejur

- **Identidade**: pacote/bundle `br.app.sent`, nome "Sent", domínio do
  código digitado `<nome>.sent.app.br` (`EcoApi.baseDoEscritorio`), link
  do QR `*.sent.app.br/app/conectar` no `AndroidManifest`.
- **Marca**: cores padrão `#3D8FD1`/`#54A9EB` e tema escuro azul-noite
  (`#0E1621`/`#17212B`) em `lib/theme.dart`; depois de conectar, valem as
  cores da conta (`/api/app/eu`). Ícones, splash e logos gerados da logo do
  Sent (`assets/marca/`); abertura animada com 3 camadas em
  `assets/abertura/` (balão, palavra "Sent" e o ✓ que pulsa) —
  `TelaCarregando` em `lib/widgets.dart`. Pra regerar ícone/splash:
  `dart run flutter_launcher_icons` e `dart run flutter_native_splash:create`.
- **Só atendimento e admin**: o Sent não tem Gestão nem Financeiro, então o
  app **não tem** Agenda, Ficha do cliente nem lembretes de tarefa (telas,
  modelos `Tarefa`/`Processo`/`Andamento`/`FichaCliente`, chamadas
  `/gestao/agenda`/`ficha360` e as libs de fuso horário foram removidas). O
  `Usuario` só tem `admin` e `sac`. Abas: Conversas e Perfil. **Nunca**
  chamar rota `/gestao/*`: no Sent ela devolve 401 e o app desconecta o
  celular — a única exceção é `/gestao/notificacoes/json` (sininho), que o
  servidor do Sent libera pra área de atendimento.
- **Push (Firebase, desde 2026-10-22, Android)**: projeto Firebase próprio **`sent-f3fb8`** (conta
  Google da UAU; separado do `ecossistema-juridico-644f5` do app do escritório, a pedido do usuário).
  Apps cadastrados pela API com a conta de serviço: Android `br.app.sent` e iOS `br.app.sent`.
  `android/app/google-services.json` versionado (não é segredo) e plugin `com.google.gms.google-services`
  de volta no `build.gradle.kts`. Chave da conta de serviço: `_firebase/sent-firebase.json` (fora do git) e
  `storage/firebase-servico.json` (600, `sentsac`) no servidor do Sent — vale para todos os tenants; o
  `Notificador` já obtém o token de acesso do FCM. **iOS** (7bb0f99, 22/10): `GoogleService-Info.plist` no target, `Runner.entitlements` só com
  `aps-environment`, `UIBackgroundModes` remote-notification, só iPhone e `scripts/ipa.sh` (liga
  `IOS_PUSH_ENABLED=true`) — iguais ao app do escritório. Falta, no Mac: chave APNs **própria do Sent** (nunca a do app do escritório) no
  Firebase do Sent, app no App Store Connect e o primeiro IPA (ver `SETUP-MAC.md` deste repositório).

## Testar

- `flutter analyze` e `flutter test` limpos; `flutter build apk --debug`
  compila (Flutter do Windows em `C:\src\flutter`).
- Conta de teste: `demo.sent.app.br` (dados fictícios). Gerar o código em
  Meu perfil → Aplicativo no celular e usar **Digitar código** (empresa
  `demo.sent.app.br`). O demo **ainda não tem** o código fixo de revisão das
  lojas (`APP_REVISAO_CODIGO`/`APP_REVISAO_EMAIL` no `tenants/demo.env`) —
  configurar antes de mandar pra revisão da Apple/Google.
- iOS: compila no Mac mini, mesmo roteiro do `SETUP-MAC.md` do
  `app_ecossistema`.

## Distribuição

- **Android, fora da loja**: `https://uau.dev.br/apk/sent` (UAU Store;
  catálogo em `UAU/uau/config/apps.php`, APK em `UAU/uau/public/apks/sent.apk`,
  fora do git). Build: `flutter build apk --release --target-platform
  android-arm,android-arm64`, subir o `app-release.apk` como `sent.apk` e
  atualizar `versao`/`atualizado` no catálogo.
- **Assinatura**: chave própria do Sent em `ECOSSISTEMAS/.chave_app/sent.jks`
  (alias `sent`), senha no `android/key.properties` (fora do git) e cópia em
  `.chave_app/key-sent.properties`. **Perder a chave = não dá pra atualizar
  o app nos celulares** — manter backup. Não usar a chave do Ecossistema.
- Versão 1.0.0 (03/10/2026) é a primeira; incrementar `version:` no
  `pubspec.yaml` a cada APK novo.
- **1.0.4 (22/10/2026)**: APK sem as bibliotecas de emulador (`packaging.jniLibs.excludes` x86/x86_64 no
  `build.gradle.kts` — o `abiFilters` não funciona, o plugin do Flutter ignora), 55,5 → 49,3 MB. O resto do
  tamanho é o motor do Flutter + código em 2 arquiteturas (~36 MB) e o leitor de QR do ML Kit embutido (~8 MB).
- **1.0.3 (22/10/2026)**: notificações (Firebase `sent-f3fb8`). Assinatura conferida igual; 1.0.2 guardado em
  /root/backups/sent-app-1.0.3-2026-10-22/.
- **1.0.2 (21/10/2026)**: trouxe do app do escritório os links, localização, contato e reações no
  balão da conversa (`texto_rico.dart`, `localizacao.dart`) e a lista sem anel nas não lidas. Assinatura
  conferida igual à do 1.0.1 (apksigner) antes de publicar; 1.0.1 guardado em /root/backups/sent-app-1.0.2-2026-10-21/.

## Padrão de código

Mesmo do `app_ecossistema`: nomes em português, claros, sem comentários.
