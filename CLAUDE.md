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
- **Push desligado**: ainda não existe projeto Firebase do Sent. O plugin
  `com.google.gms.google-services` foi tirado do `android/app/build.gradle.kts`
  (sem `google-services.json` o build falha) e no iOS o push só liga com
  `--dart-define=IOS_PUSH_ENABLED=true`. `lib/push.dart` cai fora sozinho
  quando o Firebase não inicializa. Pra ligar: criar o app `br.app.sent` no
  Firebase, pôr o `google-services.json`/`GoogleService-Info.plist`,
  voltar o plugin e configurar o envio no servidor do Sent.

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

## Padrão de código

Mesmo do `app_ecossistema`: nomes em português, claros, sem comentários.
