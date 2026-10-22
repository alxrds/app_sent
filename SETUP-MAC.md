# Sent no iOS — tarefas para o Claude do Mac

O Sent é um produto separado do Ecossistema Jurídico (app do escritório). **Nada é
compartilhado entre os dois**: repositório, projeto Firebase, chave APNs, app no App Store
Connect, textos e capturas são próprios do Sent. Se algo daqui parecer igual ao
`app_ecossistema`, é cópia — não aponte um para o outro.

Lições do app do escritório (não repetir):
- **Só iPhone desde o primeiro build.** O 1.0.10 do escritório saiu com iPad e perdemos um
  dia na revisão. Aqui já está `TARGETED_DEVICE_FAMILY = 1` e sem orientações de iPad no
  `Info.plist`; confira antes de cada envio.
- Push e permissões só valem se o `scripts/ipa.sh` gravar o `Runner.entitlements` no
  archive — sempre gerar pelo script, nunca pelo Xcode direto.

## PRÓXIMO (22/10, do Windows): primeiro build do iOS com push

```bash
ECO="$HOME/dev/ECOSSISTEMAS"
git clone https://github.com/alxrds/app_sent.git "$ECO/_SENT/app_sent"
cd "$ECO/_SENT/app_sent" && flutter pub get && flutter analyze && flutter test
```

Já pronto no código (commit 7bb0f99): Firebase próprio **`sent-f3fb8`** com o app iOS
`br.app.sent` cadastrado, `ios/Runner/GoogleService-Info.plist` no target,
`Runner.entitlements` só com `aps-environment`, `UIBackgroundModes` remote-notification,
só iPhone e `scripts/ipa.sh` (liga `IOS_PUSH_ENABLED=true`). Versão 1.0.3+4.

1. **Chave APNs própria do Sent** (não usar a `HT4RSBKU7H`, que é do app do escritório):
   developer.apple.com → Certificates, IDs & Profiles → **Keys** → `+` → nome "Sent APNs",
   marcar **Apple Push Notifications service (APNs)** → baixar o `.p8` (só baixa uma vez) e
   anotar o Key ID. Guardar o `.p8` em `_SENT/app_sent/_firebase/` (fora do git) e uma cópia
   segura no OneDrive pessoal do Alexandre.
2. **Enviar a chave ao Firebase do Sent**: console.firebase.google.com → projeto **Sent** →
   engrenagem → Configurações do projeto → **Cloud Messaging** → app iOS `br.app.sent` →
   Chave de autenticação de APNs → Enviar (`.p8`, Key ID, Team ID `SK456QD2XZ`).
3. **App Store Connect**: criar o app **Sent** (bundle `br.app.sent`). Se o App ID ainda não
   existir, a primeira exportação do `ipa.sh` cria e ativa o push sozinha.
4. `./scripts/ipa.sh` → conferir no IPA: `aps-environment=production`, o
   `GoogleService-Info.plist` com `sent-f3fb8` e `UIDeviceFamily` só `1` → Transporter →
   TestFlight (grupo interno).
5. **Testar push no iPhone**: conectar o app num tenant do Sent (Meu perfil → Aplicativo no
   celular → código) e pedir ao Windows uma notificação de teste pelo servidor. O demo do
   Sent não tem WhatsApp ligado.

Depois do TestFlight: textos, capturas e privacidade próprios do Sent na App Store
(política em `https://sent.app.br/politica-de-privacidade.html`).

## Regras

- Código só pelo GitHub: `git pull` antes, commit e `git push` depois.
- Registre cada etapa no "Registro" abaixo (commit + push): é assim que o Windows fica sabendo.

## Registro

- **2026-10-22 (Windows)** — Firebase próprio `sent-f3fb8` (criado pelo Alexandre); apps Android e iOS
  `br.app.sent` cadastrados pela API. Android 1.0.3 com push na UAU Store. iOS preparado (7bb0f99).
  Decisão do Alexandre: Sent e ejur separados em tudo, inclusive a chave APNs.
- **2026-10-22 (Mac)** — Passos 1, 2 e 4 do PRÓXIMO. Chave APNs própria "Push Sent" criada
  (Sandbox & Production, Team Scoped) e enviada ao Firebase `sent-f3fb8`; o `.p8` e o Key ID
  ficam só no Mac, em `_firebase/` (fora do git — ver `_firebase/LEIA-ME.txt`). `flutter analyze`
  limpo, 18 testes ok. IPA **1.0.4 (5)** gerado com `./scripts/ipa.sh` (a exportação registrou o
  App ID `br.app.sent` com push). Conferido no IPA: `aps-environment=production`,
  `GoogleService-Info.plist` do `sent-f3fb8`, `UIDeviceFamily` só `1`. Falta: criar o app no
  App Store Connect (passo 3), enviar pelo Transporter e liberar no grupo interno; depois
  testar push no iPhone (passo 5). Cópia do `.p8` no OneDrive pessoal: a fazer pelo Alexandre.
