import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'conversa_screen.dart';

class ConversasScreen extends StatefulWidget {
  const ConversasScreen({super.key, required this.perfil, required this.aoMudarFila});

  final Perfil perfil;
  final ValueChanged<int> aoMudarFila;

  @override
  State<ConversasScreen> createState() => _ConversasScreenState();
}

class _ConversasScreenState extends State<ConversasScreen> with WidgetsBindingObserver {
  static const _filtros = [
    (chave: 'minhas', rotulo: 'Minhas', icone: Icons.person_outline),
    (chave: 'fila', rotulo: 'Fila', icone: Icons.schedule),
    (chave: 'todas', rotulo: 'Todas', icone: Icons.format_list_bulleted),
    (chave: 'interno', rotulo: 'Interno', icone: Icons.people_outline),
  ];

  final Map<String, List<Conversa>> _listas = {};
  final _busca = TextEditingController();
  String _filtro = 'minhas';
  int _filaTotal = 0;
  String? _erro;
  Timer? _atualizacao;
  Timer? _atrasoBusca;
  bool _consultando = false;
  bool _ativo = true;
  bool _conversaAberta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
    _atualizacao = Timer.periodic(const Duration(seconds: 5), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _atualizacao?.cancel();
    _atrasoBusca?.cancel();
    _busca.dispose();
    super.dispose();
  }

  String get _chaveAtual => _busca.text.trim().isEmpty ? _filtro : 'busca';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ativo = state == AppLifecycleState.resumed;
    if (_ativo) _carregar(silencioso: true);
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (_consultando || !_ativo || _conversaAberta || !mounted) return;
    _consultando = true;
    final filtro = _filtro;
    final termo = _busca.text.trim();
    final chave = _chaveAtual;
    try {
      final resultado = await EcoApi.instancia.conversas(filtro, busca: termo);
      if (!mounted || filtro != _filtro || termo != _busca.text.trim()) {
        return;
      }
      setState(() {
        _listas[chave] = resultado.conversas;
        _erro = null;
        if (_filaTotal != resultado.filaTotal) {
          _filaTotal = resultado.filaTotal;
          widget.aoMudarFila(_filaTotal);
        }
      });
    } on ApiException catch (e) {
      if (mounted && filtro == _filtro && termo == _busca.text.trim()) {
        setState(() => _erro = e.mensagem);
      }
    } finally {
      _consultando = false;
      if (mounted && (filtro != _filtro || termo != _busca.text.trim())) {
        _carregar();
      }
    }
  }

  void _escolherFiltro(String chave) {
    setState(() {
      _filtro = chave;
      _busca.clear();
    });
    _carregar();
  }

  void _buscou(String _) {
    _atrasoBusca?.cancel();
    _atrasoBusca = Timer(const Duration(milliseconds: 350), () {
      setState(() {});
      _carregar();
    });
  }

  Future<void> _abrir(Conversa conversa) async {
    _conversaAberta = true;
    _atualizacao?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversaScreen(conversaId: conversa.id, titulo: conversa.contatoNome, perfil: widget.perfil, interna: conversa.interna),
      ),
    );
    if (!mounted) return;
    _conversaAberta = false;
    _carregar(silencioso: true);
    _atualizacao = Timer.periodic(const Duration(seconds: 5), (_) => _carregar(silencioso: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      children: [
        if (_erro != null && _listas[_chaveAtual] != null)
          const Padding(padding: EdgeInsets.all(8), child: Text('Reconectando? A lista pode estar desatualizada.')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < _filtros.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < _filtros.length - 1 ? 8 : 0),
                    child: _Pilula(
                      rotulo: _filtros[i].rotulo,
                      icone: _filtros[i].icone,
                      ativa: _filtro == _filtros[i].chave && _busca.text.trim().isEmpty,
                      contador: _filtros[i].chave == 'fila' ? _filaTotal : 0,
                      aoTocar: () => _escolherFiltro(_filtros[i].chave),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _busca,
            onChanged: _buscou,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar conversa',
              fillColor: c.cartao,
              suffixIcon: _busca.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busca.clear();
                        setState(() {});
                        _carregar();
                      },
                    ),
            ),
          ),
        ),
        Expanded(child: _lista()),
      ],
    );
  }

  Widget _lista() {
    final conversas = _listas[_chaveAtual];
    if (conversas == null) {
      return _erro != null ? _Aviso(texto: _erro!, aoTentar: _carregar) : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: conversas.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 90),
                Icon(_busca.text.isNotEmpty ? Icons.search_off : Icons.forum_outlined, size: 56, color: context.cores.textoSuave.withValues(alpha: .5)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _busca.text.isNotEmpty
                        ? 'Nada encontrado.'
                        : switch (_filtro) {
                            'fila' => 'Ninguém esperando na fila.',
                            'interno' => 'Nenhum colega com acesso ao atendimento.',
                            _ => 'Nenhuma conversa aqui.',
                          },
                    style: TextStyle(color: context.cores.textoSuave),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
              itemCount: conversas.length,
              itemBuilder: (_, i) => _ItemConversa(conversa: conversas[i], aoTocar: () => _abrir(conversas[i])),
            ),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.rotulo, required this.icone, required this.ativa, required this.aoTocar, this.contador = 0});

  final String rotulo;
  final IconData icone;
  final bool ativa;
  final int contador;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final fundoAtivo = escuro ? Theme.of(context).colorScheme.primary : c.marca;
    final corTexto = ativa ? (escuro ? Colors.black : Colors.white) : Theme.of(context).textTheme.bodyMedium?.color;
    return Material(
      color: ativa ? fundoAtivo : c.cartao,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ativa ? fundoAtivo : c.linha),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: contador > 0,
                label: Text('$contador'),
                backgroundColor: corCritica,
                child: Icon(icone, size: 21, color: corTexto),
              ),
              const SizedBox(height: 4),
              Text(
                rotulo,
                maxLines: 1,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: corTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemConversa extends StatelessWidget {
  const _ItemConversa({required this.conversa, required this.aoTocar});

  final Conversa conversa;
  final VoidCallback aoTocar;

  String _quando(DateTime? d) {
    if (d == null) {
      return '';
    }
    final agora = DateTime.now();
    if (d.year == agora.year && d.month == agora.month && d.day == agora.day) {
      return DateFormat.Hm('pt_BR').format(d);
    }
    final ontem = agora.subtract(const Duration(days: 1));
    if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
      return 'Ontem';
    }
    return DateFormat('dd/MM', 'pt_BR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final naoLida = conversa.naoLidas > 0;
    final presenca = conversa.online ? corOk : (conversa.ausente ? corAlerta : Colors.grey);
    final detalhe = conversa.interna
        ? (conversa.online
              ? 'Online'
              : conversa.ausente
              ? 'Ausente'
              : 'Offline')
        : [if (conversa.departamento.isNotEmpty) conversa.departamento, if (conversa.atendenteNome.isNotEmpty) conversa.atendenteNome].join(' · ');
    final previa = conversa.ultima.isNotEmpty ? conversa.ultima : (conversa.interna ? 'Sem mensagens ainda' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.cartao,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarContato(nome: conversa.contatoNome, fotoUrl: conversa.fotoUrl, tamanho: 50),
                    if (conversa.interna)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: presenca,
                            border: Border.all(color: c.cartao, width: 2.5),
                          ),
                        ),
                      )
                    else 
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: conversa.canal.toLowerCase().contains('whatsapp') ? const Color(0xFF25D366) : 
                                   conversa.canal.toLowerCase().contains('telegram') ? const Color(0xFF0088cc) :
                                   conversa.canal.toLowerCase().contains('instagram') ? const Color(0xFFE1306C) :
                                   const Color(0xFF0084FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: c.cartao, width: 2),
                          ),
                          child: FaIcon(
                            conversa.canal.toLowerCase().contains('whatsapp') ? FontAwesomeIcons.whatsapp :
                            conversa.canal.toLowerCase().contains('telegram') ? FontAwesomeIcons.telegram :
                            conversa.canal.toLowerCase().contains('instagram') ? FontAwesomeIcons.instagram :
                            FontAwesomeIcons.facebookMessenger,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversa.contatoNome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _quando(conversa.ultimaEm),
                            style: TextStyle(fontSize: 12, color: naoLida ? c.destaque : c.textoSuave, fontWeight: naoLida ? FontWeight.w700 : FontWeight.w400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              previa,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: naoLida ? Theme.of(context).textTheme.bodyMedium?.color : c.textoSuave,
                                fontWeight: naoLida ? FontWeight.w500 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (naoLida)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(minWidth: 22),
                              height: 22,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(color: c.destaque, borderRadius: BorderRadius.circular(11)),
                              child: Center(
                                child: Text(
                                  '${conversa.naoLidas}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (detalhe.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detalhe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textoSuave),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.aoTentar});

  final String texto;
  final Future<void> Function() aoTentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
