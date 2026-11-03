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

## ➡️ PRÓXIMO (03/11, do Windows): iOS 1.0.5 (6) — sugestão de resposta com IA

> **São DOIS builds hoje, não um.** A mesma melhoria entrou nos dois apps, que são produtos
> separados (código, Firebase, APNs e App Store Connect próprios), então cada um precisa da
> sua versão nova na Apple:
> - **Sent 1.0.5 (6)** — este arquivo, abaixo.
> - **Ecossistema Jurídico 1.0.11 (13)** — `_ECOSSISTEMA/app_ecossistema/SETUP-MAC.md`
>   (`git pull` lá também; tarefa no topo).
>
> Por que os dois: os clientes atendiam o WhatsApp pelo celular e pediam texto a uma IA de
> fora (ChatGPT) para colar no cliente. O "Sugerir resposta" só existia no painel web. Agora,
> nos dois apps, há um botão acima da caixa de escrever: com a caixa vazia a IA escreve a
> próxima mensagem; com texto vira "Melhorar meu texto" e reescreve o rascunho. O servidor
> de todos (Sent, Segati, DIOGO, ejur e UAU) já está pronto; os Androids já estão na UAU
> Store. Só falta o iPhone. O atendimento da UAU passou a usar o app do Sent (empresa
> `uau.dev.br`), por isso o Sent também vale para a UAU.

O que mudou desde o 1.0.4: na conversa, acima da caixa de escrever, um botão "Sugerir resposta"
(caixa vazia: a IA escreve a próxima mensagem) que vira "Melhorar meu texto" quando há texto
(a IA reescreve o rascunho no tom da empresa). Nada é enviado sozinho. Também entram os textos de
permissão do `Info.plist` com "empresa" (22/10). Android 1.0.5 já está na UAU Store.

```bash
cd "$HOME/dev/ECOSSISTEMAS/_SENT/app_sent" && git pull
flutter pub get && flutter analyze && flutter test   # tudo limpo
grep -n "^version" pubspec.yaml                       # 1.0.5+6
```

1. Simulador (iPhone 17 Pro), conectado no **demo do Sent** (nunca empresa real): Meu perfil não
   precisa — no app, Digitar código → Empresa `demo.sent.app.br` + código pedido ao Windows (o
   código vale 2 min; o Windows gera pelo servidor). Abrir "Cliente Teste VIP", tocar em
   **Sugerir resposta** (leva uns segundos; o demo tem IA desde 03/11), apagar, escrever
   "reservado ja manda o pix q entrego sabado de manha" e tocar em **Melhorar meu texto**.
   Conferir que a faixa não fica por baixo do teclado nem da barra de baixo do iPhone.
2. `./scripts/ipa.sh` (nunca pelo Xcode direto) → conferir no IPA `aps-environment=production`,
   `UIDeviceFamily` só `1` → Transporter.
3. App Store Connect → Sent → **+ Versão** 1.0.5 → selecionar o build 1.0.5 (6) → "Novidades
   desta versão":
   > Sugestão de resposta com IA: na conversa, toque em "Sugerir resposta" e a mensagem vem
   > pronta para revisar e enviar. Prefere escrever do seu jeito? Escreva e toque em "Melhorar
   > meu texto".
   → Enviar para revisão. A informação de revisão (código do demo) é a mesma do 1.0.4; se o
   código antigo tiver vencido, pedir um novo ao Windows antes de enviar.
4. Registrar abaixo (commit + push).

## (feito) Primeiro build do iOS com push (22/10)

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

## (feito) Capturas de tela da App Store (22/10)

Textos da loja já prontos em `design/app-store/textos.md` (o Windows cola no App Store Connect).
Falta só o que o Simulador faz:

1. `git pull`. Rodar o app no Simulador **iPhone 17 Pro** (tela 6,3", 1206×2622 — foi o tamanho
   aceito no app do escritório; 1320×2868 foi recusado no quadro "Dynamic Island").
2. Conectar no **demo do Sent** (dados fictícios): Digitar código → Empresa `demo.sent.app.br`,
   código `ZYZB9DQ6`. Nunca em empresa real.
3. Tirar, nesta ordem, e salvar em `design/app-store/iphone-6.3/01.png` … `06.png`:
   1. Lista de conversas (aba Fila ou Todas, com várias conversas).
   2. Conversa aberta com troca de mensagens (texto e uma foto ou documento).
   3. Respostas rápidas abertas sobre a conversa.
   4. Transferir conversa (lista de atendentes e setores).
   5. Chat Interno da equipe.
   6. Tela de conexão (ler QR Code / digitar código) — desconectar antes, conectar de novo depois.
4. Conferir que nenhuma captura mostra iPad, barra de depuração ("DEBUG") ou dado real.
5. Commit + push e registrar abaixo.

Também mudou (22/10, Windows): textos de permissão do `Info.plist` falam em "empresa" (antes
"escritório"). Só valem no próximo build — **não gerar build novo agora**, o 1.0.4 (5) já está na
revisão; entra junto na próxima versão.

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
- **2026-10-22 (Windows)** — Build 1.0.4 (5) no TestFlight, revisão beta do grupo externo "Clientes" pendente
  (o interno "Equipe UAU" já instala). Textos da loja em `design/app-store/textos.md`; permissões do
  `Info.plist` trocadas para "empresa" (próximo build). Mac: capturas (seção PRÓXIMO acima).
- **2026-10-22 (Mac)** — Capturas tiradas em `design/app-store/iphone-6.3/01.png`…`06.png` (Simulador iPhone 17 Pro,
  1206×2622, barra de status 9:41, demo do Sent pelo código `ZYZB9DQ6`, sem "DEBUG" e sem iPad). Ressalvas para o
  Windows: **01** usa a aba Fila (só 2 conversas), porque a Todas mostra duas conversas de teste reais, "uau"
  ("teste") e "alexandre" ("ou"), de 21/10 — foram encerradas pelo app, mas a Todas lista encerradas também; apagar
  no demo e refazer a 01 com a Todas se quiser mais conversas. **02** (Mariana Souza) não tem foto nem documento:
  nenhuma conversa do demo tem anexo. **03**: as respostas rápidas do demo falam em "escritório" e têm o marcador
  "[endereço]" — vale corrigir no demo e refazer. Simulator.app não está instalado; o app foi guiado por um teste de
  integração temporário (não versionado) e as capturas saem de `xcrun simctl io ... screenshot`.
- **2026-10-22 (Windows)** — Alexandre envia a 1.0.4 com as 6 capturas como estão. Para a próxima versão: refazer a
  **03** (o demo agora tem "Endereço da loja", sem "escritório") junto com o build que leva as permissões novas.
- **2026-10-23 (Windows)** — Conversa mostra "Este vídeo/áudio/foto não pôde ser baixado do WhatsApp. Peça para o cliente
  enviar de novo." quando o servidor marca a mídia recebida com erro (já no ar nos 5 painéis). Só código: entra no
  próximo build, sem gerar build só por isso.
- **2026-10-22 (Windows)** — 1.0.4 (5) enviado para revisão da App Store pelo Alexandre (~23:13). Login da revisão:
  usuário `demo.sent.app.br`, senha `ZYZB9DQ6`.
- **2026-10-27 (Windows)** — **1.0.4 aprovado e publicado na App Store**: https://apps.apple.com/br/app/sent/id6825603485 (id 6825603485). Links atualizados no site do Sent, na UAU Store (`config/apps.php` → `ios`), na home da UAU e na Ajuda do Sent.
- **2026-11-03 (Windows)** — 1.0.5 (6): sugestão de resposta / melhorar meu texto na conversa (servidor
  do Sent 80d9971). Android 1.0.5 na UAU Store (assinatura conferida, 1.0.4 em
  /root/backups/sent-app-1.0.5-2026-11-03/). iOS: tarefa no topo deste arquivo.
- **2026-11-03 (Mac)** — iOS **1.0.5 (6)** gerado pelo `scripts/ipa.sh`: IPA conferido (br.app.sent, Apple
  Distribution SK456QD2XZ, `aps-environment=production`, `UIDeviceFamily` só `1`). Testado no Simulador (iPhone 17
  Pro) no `demo.sent.app.br` com o código fixo `ZYZB9DQ6`, conversa "Cliente Teste VIP": **Sugerir resposta** e
  **Melhorar meu texto** funcionam ("reservado ja manda o pix q entrego sabado de manha" → "Mariana, já deixei a
  geladeira reservada. Você prefere pagar por Pix, cartão em até 10x sem juros ou boleto? A entrega fica para
  sábado de manhã."). Faixa com código idêntico ao do ejur, conferida lá acima do teclado. Falta o Alexandre enviar
  pelo Transporter e mandar a versão 1.0.5 para revisão. No ejur o "Melhorar meu texto" mudou um fato do rascunho
  (detalhes no `SETUP-MAC.md` de lá) — vale conferir o prompt do copiloto do Sent também. **Caminhos no Mac
  mudaram**: `~/dev/_apps/sent_app` (este) e `~/dev/_apps/ejur_app`.
- **2026-11-03 (Windows)** — Corrigido no servidor o "Melhorar meu texto" que trocava fato do rascunho pela
  conversa (achado do Mac no ejur): agora o rascunho é a verdade e a conversa só dá o tom e o nome. No ar em Sent
  3f876dd, Segati c7729ba, DIOGO dcac7ce, ejur f543aec e UAU 279c5f9; testado no demo com "o processo ta parado
  esperando o juiz…" → "Mariana, o processo está parado, aguardando o juiz. Assim que sair a decisão, te aviso.".
  **Não precisa de build novo**: os IPAs 1.0.5 (6) e 1.0.11 (13) já gerados valem. Caminhos novos no Mac anotados.
- **2026-11-03 (Mac)** — Capturas para a 1.0.5 em `design/app-store/iphone-6.3/` (1206×2622, 9:41, demo pelo
  `ZYZB9DQ6`): **03 refeita** (respostas rápidas agora mostram "Endereço da loja — Av. Brasil, 1500, Centro" e
  "Horário de atendimento") e **07 nova, opcional**: conversa com "Melhorar meu texto" e a sugestão da IA na
  caixa, para mostrar a novidade na loja. As outras (01, 02, 04–06) seguem iguais. Atenção: a conversa da Mariana
  agora se chama **"Cliente Teste VIP"** no demo (aparece no topo da 03 e da 07); se preferir "Mariana Souza" na
  loja, renomear no demo e pedir as duas de novo. O aviso de notificação do iOS foi respondido pelo próprio teste
  temporário (mock do canal do `flutter_local_notifications`), por isso não aparece.
- **2026-11-03 (Windows)** — Demo do Sent acertado: a cliente voltou a se chamar **"Mariana Souza"** (estava
  "Cliente Teste VIP") e saiu a mensagem de teste "não enviada" de hoje da conversa dela. **Pedido ao Mac:**
  refazer as capturas **03 e 07** (mesmo roteiro; na 07, apagar a sugestão anterior antes e gerar de novo) e
  conferir que o nome no topo é "Mariana Souza". As demais ficam como estão.
- **2026-11-03 (Mac)** — Capturas **03 e 07 refeitas** com o demo acertado: topo "Mariana Souza" nas duas. 03 =
  respostas rápidas ("Endereço da loja", "Horário de atendimento"); 07 = sugestão gerada de novo ("Mariana, você
  pode pagar via Pix, cartão em até 10x sem juros ou boleto. Qual forma prefere?") com "Melhorar meu texto". A
  sugestão ficou só na caixa (apagada no fim, nada enviado). Demais capturas inalteradas.
