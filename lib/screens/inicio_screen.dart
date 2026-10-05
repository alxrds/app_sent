import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../lembretes.dart';
import '../models.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets.dart';
import 'conversa_screen.dart';
import 'conversas_screen.dart';
import 'perfil_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key, required this.perfil, required this.aoSair, required this.escuro, required this.aoDefinirTema});

  final Perfil perfil;
  final Future<void> Function() aoSair;
  final bool escuro;
  final ValueChanged<ThemeMode> aoDefinirTema;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

enum _Aba { conversas, perfil }

class _InicioScreenState extends State<InicioScreen> with WidgetsBindingObserver {
  late final List<_Aba> _abas = [if (widget.perfil.usuario.sac) _Aba.conversas, _Aba.perfil];
  int _indice = 0;
  Timer? _presenca;
  Timer? _sino;
  List<Notificacao> _notificacoes = [];
  int _naoLidas = 0;
  int _filaTotal = 0;

  Usuario get _usuario => widget.perfil.usuario;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Lembretes.toque.addListener(_tocouLembrete);
    _prepararLembretes();
    _iniciarRotinas();
  }

  Future<void> _prepararLembretes() async {
    await Lembretes.pedirPermissao();
    _tocouLembrete();
    await Push.registrar();
  }

  void _tocouLembrete() {
    final payload = Lembretes.toque.value;
    if (payload == null || !mounted) {
      return;
    }
    Lembretes.toque.value = null;
    final conversa = RegExp(r'^(conversa|interno):(\d+)\|(.*)$').firstMatch(payload);
    if (conversa != null && _abas.contains(_Aba.conversas)) {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
      setState(() => _indice = _abas.indexOf(_Aba.conversas));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversaScreen(
            conversaId: int.parse(conversa.group(2)!),
            titulo: conversa.group(3)!,
            perfil: widget.perfil,
            interna: conversa.group(1) == 'interno',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Lembretes.toque.removeListener(_tocouLembrete);
    _presenca?.cancel();
    _sino?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _iniciarRotinas();
      _prepararLembretes();
    } else if (estado == AppLifecycleState.paused) {
      _presenca?.cancel();
      _sino?.cancel();
    }
  }

  void _iniciarRotinas() {
    _presenca?.cancel();
    _sino?.cancel();
    if (_usuario.sac) {
      EcoApi.instancia.heartbeat();
      _presenca = Timer.periodic(const Duration(seconds: 20), (_) => EcoApi.instancia.heartbeat());
    }
    if (_usuario.sac) {
      _atualizarNotificacoes();
      _sino = Timer.periodic(const Duration(seconds: 30), (_) => _atualizarNotificacoes());
    }
  }

  Future<void> _atualizarNotificacoes() async {
    try {
      final r = await EcoApi.instancia.notificacoes();
      if (mounted) {
        setState(() {
          _notificacoes = r.itens;
          _naoLidas = r.total;
        });
      }
    } on ApiException {
      return;
    }
  }

  String _titulo(_Aba aba) => switch (aba) {
    _Aba.conversas => 'Conversas',
    _Aba.perfil => 'Perfil',
  };

  Future<void> _abrirNotificacoes() async {
    await _atualizarNotificacoes();
    if (!mounted) {
      return;
    }
    final escolhida = await showModalBottomSheet<Notificacao>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PainelNotificacoes(itens: _notificacoes),
    );
    if (escolhida == null || !mounted) {
      return;
    }
    final id = escolhida.colegaId ?? escolhida.conversaId;
    if (id != null && _usuario.sac) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversaScreen(conversaId: id, titulo: escolhida.sub, perfil: widget.perfil, interna: escolhida.colegaId != null),
        ),
      );
      _atualizarNotificacoes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final atual = _abas[_indice.clamp(0, _abas.length - 1)];
    return Scaffold(
      extendBody: true,
      appBar: CabecalhoApp(
        usuario: _usuario,
        titulo: _titulo(atual),
        escuro: widget.escuro,
        aoAlternarTema: () => widget.aoDefinirTema(widget.escuro ? ThemeMode.light : ThemeMode.dark),
        naoLidas: _naoLidas,
        aoAbrirNotificacoes: _usuario.sac ? _abrirNotificacoes : null,
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          for (final aba in _abas)
            switch (aba) {
              _Aba.conversas => ConversasScreen(perfil: widget.perfil, aoMudarFila: (n) => setState(() => _filaTotal = n)),
              _Aba.perfil => PerfilScreen(perfil: widget.perfil, aoSair: widget.aoSair),
            },
        ],
      ),
      bottomNavigationBar: _abas.length < 2
          ? null
          : BarraCurva(
              indice: _indice,
              aoSelecionar: (i) => setState(() => _indice = i),
              contadores: {if (_abas.contains(_Aba.conversas)) _abas.indexOf(_Aba.conversas): _filaTotal},
              itens: [
                for (final aba in _abas)
                  switch (aba) {
                    _Aba.conversas => const ItemBarra(Icons.forum_outlined, 'Conversas'),
                    _Aba.perfil => const ItemBarra(Icons.person_outline, 'Perfil'),
                  },
              ],
            ),
    );
  }
}

class _PainelNotificacoes extends StatelessWidget {
  const _PainelNotificacoes({required this.itens});

  final List<Notificacao> itens;

  String _quando(DateTime? d) {
    if (d == null) {
      return '';
    }
    final agora = DateTime.now();
    final mesmoDia = d.year == agora.year && d.month == agora.month && d.day == agora.day;
    return mesmoDia ? DateFormat.Hm('pt_BR').format(d) : DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Notificações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (itens.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: corOk),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Tudo em dia. Nenhuma pendência pra você agora.')),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: itens.length,
                  itemBuilder: (_, i) {
                    final n = itens[i];
                    final tarefa = n.tipo == 'tarefa';
                    final cor = n.atrasada ? corCritica : (tarefa ? c.destaque : Theme.of(context).colorScheme.primary);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cor.withValues(alpha: .12),
                        child: Icon(tarefa ? Icons.event_note_outlined : Icons.chat_bubble_outline, color: cor, size: 20),
                      ),
                      title: Text(
                        n.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(n.sub, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        n.atrasada ? 'Atrasada' : _quando(n.quando),
                        style: TextStyle(fontSize: 12, color: n.atrasada ? corCritica : c.textoSuave),
                      ),
                      onTap: () => Navigator.pop(context, n),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
