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

## Para o Windows: publicar na App Store (22/10)

Todo build enviado pelo Transporter cai no TestFlight. Não há como evitar isso, mas não é
obrigatório liberar para testadores: dá para escolher o build direto na versão da App Store
e enviar para revisão. O Windows conduz esta parte com o Alexandre no App Store Connect
(navegador), como foi no app do escritório:

1. **Página do Sent na loja**, tudo próprio do Sent (nada copiado do ejur):
   - descrição, palavras-chave, categoria (Negócios) e URL de suporte;
   - política de privacidade `https://sent.app.br/politica-de-privacidade.html` e o
     questionário de privacidade do app;
   - classificação etária, preço (grátis) e países;
   - "Informação de revisão": no app, **Digitar código** → Empresa `demo.sent.app.br`, código
     **`ZYZB9DQ6`** (próprio do Sent, criado em 22/10; entra como o admin fictício do demo).
2. **Capturas de iPhone 6,9"** (1320×2868), tiradas do Simulador logado no **demo do Sent**,
   nunca em cliente real. O Simulador só existe no Mac: o Windows prepara o demo e anota aqui
   quais telas quer; o Mac tira e faz commit em `design/app-store/iphone-6.9/`.
3. **Teste em iPhone real (recomendado, não obrigatório):** push e leitor de QR do Sent
   nunca rodaram num iPhone e o Simulador não testa nenhum dos dois. Enquanto os itens 1 e 2
   são preenchidos, liberar o build num grupo do TestFlight com um cliente do Sent que use
   iPhone (como foi com a Dra. Daniella no ejur). Se o Alexandre preferir pular, enviar
   direto: o push do ejur, feito do mesmo jeito, passou na revisão.
4. Selecionar o build **1.0.4 (5)** na versão 1.0.4 e enviar para revisão. Registrar aqui.

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
- **2026-10-22 (Windows)** — Código de revisão próprio do Sent criado no demo (`APP_REVISAO_CODIGO=ZYZB9DQ6`,
  `APP_REVISAO_EMAIL=admin@demo.sent.app.br`, só dados fictícios) e testado. Próximo: o Alexandre cria o app
  no App Store Connect (passo 3); depois o Mac envia o 1.0.4 (5) pelo Transporter.
- **2026-10-22 (Windows)** — App **Sent** criado no App Store Connect pelo Alexandre (aparece como "iOS 1.0
  Preparar para envio"). **Mac: enviar o IPA 1.0.4 (5) pelo Transporter** e liberar no grupo interno do
  TestFlight; registrar aqui. A versão da loja foi criada como 1.0 — o Windows pede ao Alexandre para trocar
  para 1.0.4 (precisa bater com o build). Países: só Brasil (evita a exigência de comerciante da UE).
