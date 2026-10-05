import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

const corAbertura = Color(0xFF0E1621);

class TelaCarregando extends StatefulWidget {
  const TelaCarregando({super.key});

  static bool _jaAbriu = false;
  static final _fimDaAbertura = Completer<void>();

  static const _camadas = [
    'assets/abertura/simbolo.png',
    'assets/abertura/texto.png',
    'assets/abertura/check.png',
  ];

  static Future<void> prepararImagens() async {
    final carregadas = [
      for (final arquivo in _camadas)
        () {
          final pronta = Completer<void>();
          AssetImage(arquivo)
              .resolve(ImageConfiguration.empty)
              .addListener(
                ImageStreamListener((_, _) => pronta.isCompleted ? null : pronta.complete(), onError: (_, _) => pronta.isCompleted ? null : pronta.complete()),
              );
          return pronta.future;
        }(),
    ];
    await Future.wait(carregadas).timeout(const Duration(seconds: 2), onTimeout: () => []);
  }

  static Future<void> get aberturaConcluida => _fimDaAbertura.future.timeout(const Duration(seconds: 8), onTimeout: () {});

  @override
  State<TelaCarregando> createState() => _TelaCarregandoState();
}

class _TelaCarregandoState extends State<TelaCarregando> with TickerProviderStateMixin {
  static const _largura = 250.0;
  static const _altura = _largura * 394 / 1106;
  static const _alturaSimboloNaAbertura = 144.0;
  static const _centroSimbolo = FractionalOffset(.1942, .5);
  static const _quadrados = [
    ('assets/abertura/check.png', FractionalOffset(.2029, .4211)),
  ];

  late final _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _movimento = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(.12, .68, curve: Curves.easeInOutCubic),
  );
  late final _texto = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(.45, 1, curve: Curves.easeOutCubic),
  );
  late final _pulsos = [
    for (var i = 0; i < _quadrados.length; i++)
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOutBack)), weight: 55),
      ]).animate(CurvedAnimation(parent: _pulso, curve: Interval(i * .08, i * .08 + .26))),
  ];

  @override
  void initState() {
    super.initState();
    if (TelaCarregando._jaAbriu) {
      _entrada.value = 1;
      _pulso.repeat();
      return;
    }
    TelaCarregando._jaAbriu = true;
    _abrir();
  }

  Future<void> _abrir() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      await _entrada.forward();
    }
    if (mounted) {
      _pulso.repeat();
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    TelaCarregando._fimDaAbertura.complete();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    super.dispose();
  }

  Widget _camada(String arquivo) => Positioned.fill(child: Image.asset(arquivo, fit: BoxFit.fill, gaplessPlayback: true));

  @override
  Widget build(BuildContext context) {
    final escalaInicial = _alturaSimboloNaAbertura / _altura;
    final deslocamentoInicial = (.5 - _centroSimbolo.dx) * _largura;
    return Scaffold(
      backgroundColor: corAbertura,
      body: Center(
        child: SizedBox(
          width: _largura,
          height: _altura,
          child: AnimatedBuilder(
            animation: Listenable.merge([_entrada, _pulso]),
            builder: (context, _) {
              final t = _movimento.value;
              final escala = escalaInicial + (1 - escalaInicial) * t;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (area) {
                        final corte = .33 + .75 * _texto.value;
                        return LinearGradient(
                          colors: const [Colors.white, Colors.white, Colors.transparent],
                          stops: [0, (corte - .08).clamp(0, 1), corte.clamp(0, 1)],
                        ).createShader(area);
                      },
                      child: Opacity(
                        opacity: _texto.value,
                        child: Transform.translate(
                          offset: Offset(-14 * (1 - _texto.value), 0),
                          child: Image.asset('assets/abertura/texto.png', fit: BoxFit.fill, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(deslocamentoInicial * (1 - t), 0),
                      child: Transform.scale(
                        scale: escala,
                        alignment: _centroSimbolo,
                        child: Stack(
                          children: [
                            _camada('assets/abertura/simbolo.png'),
                            for (var i = 0; i < _quadrados.length; i++)
                              Positioned.fill(
                                child: Transform.scale(
                                  scale: _pulsos[i].value,
                                  alignment: _quadrados[i].$2,
                                  child: Image.asset(_quadrados[i].$1, fit: BoxFit.fill, gaplessPlayback: true),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LogoProduto extends StatelessWidget {
  const LogoProduto({super.key, this.largura = 230});

  final double largura;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(escuro ? 'assets/marca/logo_escuro.png' : 'assets/marca/logo_claro.png', width: largura);
  }
}

class TelaBloqueio extends StatelessWidget {
  const TelaBloqueio({super.key, required this.aoDesbloquear});

  final VoidCallback aoDesbloquear;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.cores.marca.withValues(alpha: .08)),
                child: Icon(Icons.lock_outline, size: 44, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text('App bloqueado', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Use a digital, o rosto ou a senha do celular para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cores.textoSuave),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(onPressed: aoDesbloquear, icon: const Icon(Icons.fingerprint), label: const Text('Desbloquear')),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaErro extends StatelessWidget {
  const TelaErro({super.key, required this.mensagem, required this.aoTentarDeNovo, required this.aoSair});

  final String mensagem;
  final VoidCallback aoTentarDeNovo;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 56, color: context.cores.textoSuave),
              const SizedBox(height: 16),
              Text(mensagem, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: aoTentarDeNovo, child: const Text('Tentar de novo')),
              TextButton(onPressed: aoSair, child: const Text('Desconectar este celular')),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoEscritorio extends StatelessWidget {
  const LogoEscritorio({super.key, required this.escritorio, this.altura = 56});

  final Escritorio escritorio;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final url = escuro && escritorio.logoEscuro.isNotEmpty ? escritorio.logoEscuro : escritorio.logo;
    final alternativa = LogoProduto(largura: altura * 1106 / 401);
    if (url.isEmpty) {
      return alternativa;
    }
    if (Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false) {
      return SvgPicture.network(
        url,
        height: altura,
        placeholderBuilder: (_) => SizedBox(height: altura),
        errorBuilder: (_, _, _) => alternativa,
      );
    }
    return Image.network(url, height: altura, errorBuilder: (_, _, _) => alternativa);
  }
}

String iniciais(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p[0])).toList();
  if (partes.isEmpty) {
    return '#';
  }
  return (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();
}

class AvatarContato extends StatelessWidget {
  const AvatarContato({super.key, required this.nome, this.fotoUrl = '', this.tamanho = 44, this.anel, this.fundo, this.corTexto});

  final String nome;
  final String fotoUrl;
  final double tamanho;
  final Color? anel;
  final Color? fundo;
  final Color? corTexto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final letras = Center(
      child: Text(
        iniciais(nome),
        style: TextStyle(color: corTexto ?? cores.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: tamanho * .36),
      ),
    );
    final circulo = Container(
      width: tamanho,
      height: tamanho,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fundo ?? cores.primaryContainer),
      child: fotoUrl.isEmpty ? letras : Image.network(EcoApi.instancia.urlAbsoluta(fotoUrl), fit: BoxFit.cover, errorBuilder: (_, _, _) => letras),
    );
    if (anel == null) {
      return circulo;
    }
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: anel!, width: 2),
      ),
      child: circulo,
    );
  }
}

void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

String cargoDe(Usuario u) {
  if (u.admin) {
    return 'Administrador(a)';
  }
  return 'Atendimento';
}

class CabecalhoApp extends StatelessWidget implements PreferredSizeWidget {
  const CabecalhoApp({
    super.key,
    required this.usuario,
    required this.titulo,
    required this.escuro,
    required this.aoAlternarTema,
    this.naoLidas = 0,
    this.aoAbrirNotificacoes,
  });

  final Usuario usuario;
  final String titulo;
  final bool escuro;
  final VoidCallback aoAlternarTema;
  final int naoLidas;
  final VoidCallback? aoAbrirNotificacoes;

  @override
  Size get preferredSize => const Size.fromHeight(118);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarContato(nome: usuario.nome, fotoUrl: usuario.avatar ?? '', tamanho: 42, fundo: c.destaque, corTexto: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.exibicao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(cargoDe(usuario), style: TextStyle(fontSize: 12.5, color: c.textoSuave)),
                    ],
                  ),
                ),
                AlternadorTema(escuro: escuro, aoAlternar: aoAlternarTema),
                if (aoAbrirNotificacoes != null) ...[const SizedBox(width: 8), _BotaoSino(naoLidas: naoLidas, aoTocar: aoAbrirNotificacoes!)],
              ],
            ),
            const SizedBox(height: 14),
            Text(titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3)),
          ],
        ),
      ),
    );
  }
}

class AlternadorTema extends StatelessWidget {
  const AlternadorTema({super.key, required this.escuro, required this.aoAlternar});

  final bool escuro;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget opcao(IconData icone, bool ativo) => AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 30,
      height: 30,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ativo ? c.marca : Colors.transparent),
      child: Icon(icone, size: 17, color: ativo ? Colors.white : c.textoSuave),
    );
    return Semantics(
      button: true,
      label: escuro ? 'Mudar para tema claro' : 'Mudar para tema escuro',
      child: GestureDetector(
        onTap: aoAlternar,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.cartao,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.linha),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [opcao(Icons.light_mode_outlined, !escuro), opcao(Icons.dark_mode_outlined, escuro)]),
        ),
      ),
    );
  }
}

class _BotaoSino extends StatelessWidget {
  const _BotaoSino({required this.naoLidas, required this.aoTocar});

  final int naoLidas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Material(
      color: c.cartao,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.linha),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Badge(
              isLabelVisible: naoLidas > 0,
              label: Text(naoLidas > 99 ? '99+' : '$naoLidas'),
              child: const Icon(Icons.notifications_none_rounded, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}

class ItemBarra {
  const ItemBarra(this.icone, this.rotulo);

  final IconData icone;
  final String rotulo;
}

class BarraCurva extends StatelessWidget {
  const BarraCurva({super.key, required this.itens, required this.indice, required this.aoSelecionar, this.contadores = const {}});

  final List<ItemBarra> itens;
  final int indice;
  final ValueChanged<int> aoSelecionar;
  final Map<int, int> contadores;

  static const _alturaBarra = 66.0;
  static const _diametro = 56.0;
  static const _sobra = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corBarra = escuro ? const Color(0xFF17212B) : c.marca;
    final inferior = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, limites) {
        final largura = limites.maxWidth;
        final larguraItem = largura / itens.length;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: larguraItem * (indice + .5)),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (context, x, _) => SizedBox(
            height: _alturaBarra + _sobra + inferior,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: _sobra,
                  child: CustomPaint(
                    painter: _PintorBarra(x: x, cor: corBarra),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: inferior,
                  height: _alturaBarra,
                  child: Row(
                    children: [
                      for (var i = 0; i < itens.length; i++)
                        Expanded(
                          child: InkWell(
                            onTap: () => aoSelecionar(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (i != indice)
                                  Badge(
                                    isLabelVisible: (contadores[i] ?? 0) > 0,
                                    label: Text('${contadores[i] ?? 0}'),
                                    child: Icon(itens[i].icone, color: Colors.white70, size: 25),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  itens[i].rotulo,
                                  style: TextStyle(
                                    color: i == indice ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: i == indice ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: x - _diametro / 2,
                  top: 0,
                  child: Container(
                    width: _diametro,
                    height: _diametro,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.destaque,
                      boxShadow: [BoxShadow(color: c.destaque.withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: Badge(
                      isLabelVisible: (contadores[indice] ?? 0) > 0,
                      label: Text('${contadores[indice] ?? 0}'),
                      offset: const Offset(-6, 6),
                      child: Center(child: Icon(itens[indice].icone, color: Colors.white, size: 26)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PintorBarra extends CustomPainter {
  _PintorBarra({required this.x, required this.cor});

  final double x;
  final Color cor;

  @override
  void paint(Canvas canvas, Size tamanho) {
    const abertura = 46.0;
    const profundidade = 34.0;
    final caminho = Path()
      ..moveTo(0, 0)
      ..lineTo(x - abertura - 8, 0)
      ..cubicTo(x - abertura + 8, 0, x - 30, profundidade, x, profundidade)
      ..cubicTo(x + 30, profundidade, x + abertura - 8, 0, x + abertura + 8, 0)
      ..lineTo(tamanho.width, 0)
      ..lineTo(tamanho.width, tamanho.height)
      ..lineTo(0, tamanho.height)
      ..close();
    canvas.drawShadow(caminho, Colors.black, 6, false);
    canvas.drawPath(caminho, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_PintorBarra antigo) => antigo.x != x || antigo.cor != cor;
}
