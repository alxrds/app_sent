import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'conversa_screen.dart';

Color corDaSituacao(BuildContext context, String situacao) => switch (situacao) {
  'pre_reserva' => corAlerta,
  'concluido' => corOk,
  'cancelado' || 'faltou' => corCritica,
  _ => Theme.of(context).colorScheme.primary,
};

final _compacto = FilledButton.styleFrom(minimumSize: const Size(0, 44));

String _dia(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

void _avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.perfil, required this.abrirAgendamento});

  final Perfil perfil;
  final ValueNotifier<int?> abrirAgendamento;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _selecionado = _soData(DateTime.now());
  bool _proximos = false;
  DadosDaAgenda? _dados;
  String? _erro;
  bool _carregando = false;

  DateTime get _inicioDaSemana => _selecionado.subtract(Duration(days: _selecionado.weekday % 7));

  @override
  void initState() {
    super.initState();
    widget.abrirAgendamento.addListener(_abrirPedido);
    _carregar();
    _abrirPedido();
  }

  @override
  void dispose() {
    widget.abrirAgendamento.removeListener(_abrirPedido);
    super.dispose();
  }

  void _abrirPedido() {
    final id = widget.abrirAgendamento.value;
    if (id == null) {
      return;
    }
    widget.abrirAgendamento.value = null;
    _abrirPorId(id);
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final de = _proximos ? _soData(DateTime.now()) : _inicioDaSemana;
    final ate = de.add(Duration(days: _proximos ? 30 : 7));
    try {
      final dados = await EcoApi.instancia.agenda(de, ate);
      if (mounted) {
        setState(() {
          _dados = dados;
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _mudarSemana(int semanas) {
    setState(() => _selecionado = _selecionado.add(Duration(days: 7 * semanas)));
    _carregar();
  }

  void _escolherDia(DateTime dia) {
    final mesmaSemana = _mesmoDia(_soData(dia).subtract(Duration(days: dia.weekday % 7)), _inicioDaSemana);
    setState(() => _selecionado = _soData(dia));
    if (!mesmaSemana) {
      _carregar();
    }
  }

  Future<void> _abrirPorId(int id) async {
    try {
      final agendamento = await EcoApi.instancia.agendamento(id);
      if (mounted) {
        await _abrir(agendamento);
      }
    } on ApiException catch (e) {
      if (mounted) {
        _avisar(context, e.mensagem);
      }
    }
  }

  Future<void> _abrir(Agendamento agendamento) async {
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DetalheDoAgendamento(agendamento: agendamento, perfil: widget.perfil, dados: _dados),
    );
    if (mudou == true) {
      _carregar();
    }
  }

  Future<void> _novo() async {
    final salvo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormularioDeAgendamento(dados: _dados, dataInicial: _selecionado)),
    );
    if (salvo == true) {
      _carregar();
    }
  }

  Future<void> _verPreReservas() async {
    final dados = _dados;
    if (dados == null) {
      return;
    }
    final escolhida = await showModalBottomSheet<PreReserva>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Aguardando confirmação', style: Theme.of(contexto).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final p in dados.preReservas)
              ListTile(
                leading: CircleAvatar(backgroundColor: corAlerta.withValues(alpha: .14), child: const Icon(Icons.schedule, color: corAlerta)),
                title: Text(p.contato, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([DateFormat("EEE, dd/MM 'às' HH:mm", 'pt_BR').format(p.inicio), if (p.servicos.isNotEmpty) p.servicos].join(' · ')),
                onTap: () => Navigator.pop(contexto, p),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (escolhida != null) {
      _abrirPorId(escolhida.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final dados = _dados;
    final itens = dados == null
        ? <Agendamento>[]
        : _proximos
        ? dados.agendamentos
        : dados.agendamentos.where((a) => _mesmoDia(a.inicio, _selecionado)).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(onPressed: _dados == null ? null : _novo, icon: const Icon(Icons.add), label: const Text('Agendar')),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Semana'), icon: Icon(Icons.view_week_outlined)),
                    ButtonSegment(value: true, label: Text('Próximos 30 dias'), icon: Icon(Icons.view_agenda_outlined)),
                  ],
                  selected: {_proximos},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _proximos = s.first);
                    _carregar();
                  },
                ),
              ),
            ),
            if (!_proximos) SliverToBoxAdapter(child: _faixaDaSemana(dados)),
            if (dados != null && dados.preReservas.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    color: corAlerta.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: const Icon(Icons.pending_actions_outlined, color: corAlerta),
                      title: Text(
                        dados.preReservas.length == 1 ? '1 pré-reserva para confirmar' : '${dados.preReservas.length} pré-reservas para confirmar',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _verPreReservas,
                    ),
                  ),
                ),
              ),
            if (_carregando && dados == null)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_erro != null && dados == null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_erro!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
                      ],
                    ),
                  ),
                ),
              )
            else if (itens.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 140),
                    child: Text(_proximos ? 'Nenhum horário marcado nos próximos 30 dias.' : 'Dia livre.', style: TextStyle(color: c.textoSuave)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 160),
                sliver: SliverList.builder(
                  itemCount: itens.length,
                  itemBuilder: (_, i) {
                    final a = itens[i];
                    final novoDia = _proximos && (i == 0 || !_mesmoDia(itens[i - 1].inicio, a.inicio));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (novoDia)
                          Padding(
                            padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 10, 4, 6),
                            child: Text(
                              toBeginningOfSentenceCase(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(a.inicio)),
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.textoSuave),
                            ),
                          ),
                        _CartaoDoAgendamento(agendamento: a, aoTocar: () => _abrir(a)),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _faixaDaSemana(DadosDaAgenda? dados) {
    final c = context.cores;
    final hoje = _soData(DateTime.now());
    final inicio = _inicioDaSemana;
    final titulo = toBeginningOfSentenceCase(DateFormat("MMMM 'de' y", 'pt_BR').format(_selecionado));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(tooltip: 'Semana anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _mudarSemana(-1)),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final escolhido = await showDatePicker(
                      context: context,
                      initialDate: _selecionado,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (escolhido != null) {
                      _escolherDia(escolhido);
                    }
                  },
                  child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              if (!_mesmoDia(_selecionado, hoje)) TextButton(onPressed: () => _escolherDia(hoje), child: const Text('Hoje')),
              IconButton(tooltip: 'Próxima semana', icon: const Icon(Icons.chevron_right), onPressed: () => _mudarSemana(1)),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final dia = inicio.add(Duration(days: i));
                      final escolhido = _mesmoDia(dia, _selecionado);
                      final total = dados?.agendamentos.where((a) => _mesmoDia(a.inicio, dia) && !a.encerrado).length ?? 0;
                      final primaria = Theme.of(context).colorScheme.primary;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _escolherDia(dia),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: escolhido ? primaria : c.cartao,
                            borderRadius: BorderRadius.circular(14),
                            border: _mesmoDia(dia, hoje) && !escolhido ? Border.all(color: primaria, width: 1.5) : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat.E('pt_BR').format(dia).replaceAll('.', ''),
                                style: TextStyle(fontSize: 11.5, color: escolhido ? Colors.white70 : c.textoSuave),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dia.day}',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: escolhido ? Colors.white : null),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: total == 0 ? Colors.transparent : (escolhido ? Colors.white : primaria),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaoDoAgendamento extends StatelessWidget {
  const _CartaoDoAgendamento({required this.agendamento, required this.aoTocar});

  final Agendamento agendamento;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final a = agendamento;
    final cor = corDaSituacao(context, a.situacao);
    final detalhe = [if (a.servicos.isNotEmpty) a.servicos, if (a.profissional.isNotEmpty) a.profissional].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.cartao,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: aoTocar,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: cor, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_hora(a.inicio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(_hora(a.fim), style: TextStyle(fontSize: 12, color: c.textoSuave)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.contato,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: a.encerrado ? TextDecoration.lineThrough : null,
                                color: a.encerrado ? c.textoSuave : null,
                              ),
                            ),
                          ),
                          if (a.naSerie) ...[const SizedBox(width: 6), Icon(Icons.repeat, size: 15, color: c.textoSuave)],
                        ],
                      ),
                      if (detalhe.isNotEmpty)
                        Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textoSuave)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                  child: Text(a.situacaoNome, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetalheDoAgendamento extends StatefulWidget {
  const DetalheDoAgendamento({super.key, required this.agendamento, required this.perfil, required this.dados});

  final Agendamento agendamento;
  final Perfil perfil;
  final DadosDaAgenda? dados;

  @override
  State<DetalheDoAgendamento> createState() => _DetalheDoAgendamentoState();
}

class _DetalheDoAgendamentoState extends State<DetalheDoAgendamento> {
  bool _ocupado = false;

  Agendamento get _a => widget.agendamento;

  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (mounted) {
        _avisar(context, sucesso);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        _avisar(context, e.mensagem);
      }
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _situacao(String situacao) async {
    var proximos = false;
    if (situacao == 'cancelado') {
      final escolha = await showDialog<String>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Cancelar horário'),
          content: Text(_a.naSerie ? 'Este horário se repete. O que deseja cancelar?' : 'Cancelar o horário de ${_a.contato}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Voltar')),
            if (_a.naSerie) TextButton(onPressed: () => Navigator.pop(contexto, 'proximos'), child: const Text('Este e os próximos')),
            FilledButton(style: _compacto, onPressed: () => Navigator.pop(contexto, 'este'), child: Text(_a.naSerie ? 'Só este' : 'Cancelar horário')),
          ],
        ),
      );
      if (escolha == null) {
        return;
      }
      proximos = escolha == 'proximos';
    }
    if (!mounted) {
      return;
    }
    if (situacao == 'faltou') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Cliente faltou'),
          content: Text('Marcar que ${_a.contato} faltou?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Voltar')),
            FilledButton(style: _compacto, onPressed: () => Navigator.pop(contexto, true), child: const Text('Marcar falta')),
          ],
        ),
      );
      if (ok != true) {
        return;
      }
    }
    await _executar(
      () => EcoApi.instancia.mudarSituacaoDoAgendamento(_a.id, situacao, esteEProximos: proximos),
      switch (situacao) {
        'concluido' => 'Marcado como concluído.',
        'faltou' => 'Falta registrada.',
        'cancelado' => proximos ? 'Este e os próximos foram cancelados.' : 'Horário cancelado.',
        _ => 'Situação atualizada.',
      },
    );
  }

  Future<void> _confirmar() async {
    setState(() => _ocupado = true);
    String texto;
    try {
      texto = await EcoApi.instancia.mensagemDeConfirmacao(_a.id);
    } on ApiException catch (e) {
      if (mounted) {
        _avisar(context, e.mensagem);
        setState(() => _ocupado = false);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _ocupado = false);
    final controlador = TextEditingController(text: texto);
    var avisar = true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, atualizar) => AlertDialog(
          title: const Text('Confirmar horário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: avisar,
                  onChanged: (v) => atualizar(() => avisar = v),
                  title: const Text('Avisar o cliente pelo WhatsApp'),
                ),
                if (avisar) TextField(controller: controlador, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Mensagem que vai para o cliente')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Voltar')),
            FilledButton(style: _compacto, onPressed: () => Navigator.pop(contexto, true), child: Text(avisar ? 'Confirmar e enviar' : 'Confirmar')),
          ],
        ),
      ),
    );
    if (confirmar != true) {
      return;
    }
    await _executar(
      () => EcoApi.instancia.confirmarAgendamento(_a.id, avisar: avisar, texto: controlador.text.trim()),
      avisar ? 'Confirmado e cliente avisado.' : 'Horário confirmado.',
    );
  }

  Future<void> _editar() async {
    final salvo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormularioDeAgendamento(dados: widget.dados, agendamento: _a)),
    );
    if (salvo == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _abrirConversa() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversaScreen(conversaId: _a.conversaId, titulo: _a.contato, perfil: widget.perfil)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final cor = corDaSituacao(context, _a.situacao);
    final quando = toBeginningOfSentenceCase(DateFormat("EEEE, dd/MM", 'pt_BR').format(_a.inicio));
    Widget linha(IconData icone, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: c.textoSuave),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_a.contato, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                  child: Text(_a.situacaoNome, style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
                ),
              ],
            ),
            if (_a.telefone.isNotEmpty) Text(telefoneFormatado(_a.telefone), style: TextStyle(color: c.textoSuave)),
            const SizedBox(height: 16),
            linha(Icons.event_outlined, '$quando, das ${_hora(_a.inicio)} às ${_hora(_a.fim)}'),
            if (_a.naSerie) linha(Icons.repeat, _a.serie),
            if (_a.servicos.isNotEmpty) linha(Icons.design_services_outlined, _a.servicos),
            if (_a.profissional.isNotEmpty) linha(Icons.person_outline, _a.profissional),
            if (_a.local.isNotEmpty) linha(Icons.place_outlined, _a.local),
            if (_a.observacoes.isNotEmpty) linha(Icons.notes_outlined, _a.observacoes),
            if (_a.origem == 'ia') linha(Icons.smart_toy_outlined, 'Marcado pela IA na conversa'),
            const SizedBox(height: 8),
            if (_ocupado) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            if (_a.preReserva)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: _ocupado ? null : _confirmar, icon: const Icon(Icons.check), label: const Text('Confirmar horário')),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_a.conversaId > 0)
                  OutlinedButton.icon(onPressed: _ocupado ? null : _abrirConversa, icon: const Icon(Icons.chat_bubble_outline), label: const Text('Abrir conversa')),
                OutlinedButton.icon(onPressed: _ocupado ? null : _editar, icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
                if (_a.situacao != 'concluido')
                  OutlinedButton.icon(onPressed: _ocupado ? null : () => _situacao('concluido'), icon: const Icon(Icons.task_alt), label: const Text('Concluído')),
                if (_a.situacao != 'faltou')
                  OutlinedButton.icon(onPressed: _ocupado ? null : () => _situacao('faltou'), icon: const Icon(Icons.error_outline), label: const Text('Faltou')),
                if (_a.situacao != 'cancelado')
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : () => _situacao('cancelado'),
                    icon: const Icon(Icons.block, color: corCritica),
                    label: const Text('Cancelar', style: TextStyle(color: corCritica)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FormularioDeAgendamento extends StatefulWidget {
  const FormularioDeAgendamento({super.key, this.dados, this.agendamento, this.dataInicial, this.conversaId = 0, this.nomeDoContato = ''});

  final DadosDaAgenda? dados;
  final Agendamento? agendamento;
  final DateTime? dataInicial;
  final int conversaId;
  final String nomeDoContato;

  @override
  State<FormularioDeAgendamento> createState() => _FormularioDeAgendamentoState();
}

class _FormularioDeAgendamentoState extends State<FormularioDeAgendamento> {
  final _busca = TextEditingController();
  final _local = TextEditingController();
  final _observacoes = TextEditingController();
  final _vezes = TextEditingController(text: '4');
  DadosDaAgenda? _dados;
  ContatoDaAgenda? _contato;
  List<ContatoDaAgenda> _resultados = [];
  Timer? _espera;
  final Set<int> _servicos = {};
  int _profissionalId = 0;
  late DateTime _data;
  TimeOfDay? _inicio;
  TimeOfDay? _fim;
  String _situacao = 'confirmado';
  String _repeticao = 'nao';
  bool _terminaPorVezes = false;
  DateTime? _repetirAte;
  bool _esteEProximos = false;
  bool _salvando = false;
  String? _erro;

  Agendamento? get _editando => widget.agendamento;

  @override
  void initState() {
    super.initState();
    _dados = widget.dados;
    final a = _editando;
    _data = _soData(a?.inicio ?? widget.dataInicial ?? DateTime.now());
    if (a != null) {
      _contato = ContatoDaAgenda(contatoId: a.contatoId, conversaId: a.conversaId, nome: a.contato, telefone: a.telefone);
      _servicos.addAll(a.servicoIds);
      _profissionalId = a.profissionalId;
      _inicio = TimeOfDay.fromDateTime(a.inicio);
      _fim = TimeOfDay.fromDateTime(a.fim);
      _local.text = a.local;
      _observacoes.text = a.observacoes;
      _situacao = a.situacao;
    } else if (widget.conversaId > 0) {
      _contato = ContatoDaAgenda(contatoId: 0, conversaId: widget.conversaId, nome: widget.nomeDoContato, telefone: '');
    }
    if (_dados == null) {
      _carregarOpcoes();
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busca.dispose();
    _local.dispose();
    _observacoes.dispose();
    _vezes.dispose();
    super.dispose();
  }

  Future<void> _carregarOpcoes() async {
    try {
      final hoje = _soData(DateTime.now());
      final dados = await EcoApi.instancia.agenda(hoje, hoje.add(const Duration(days: 1)));
      if (mounted) {
        setState(() => _dados = dados);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    }
  }

  void _buscar(String texto) {
    _espera?.cancel();
    if (texto.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 300), () async {
      try {
        final achados = await EcoApi.instancia.contatosParaAgenda(texto.trim());
        if (mounted) {
          setState(() => _resultados = achados);
        }
      } on ApiException {
        return;
      }
    });
  }

  int get _duracao {
    final servicos = _dados?.servicos ?? const [];
    final soma = servicos.where((s) => _servicos.contains(s.id)).fold<int>(0, (t, s) => t + s.duracaoMin);
    return soma > 0 ? soma : 60;
  }

  void _ajustarTermino() {
    final inicio = _inicio;
    if (inicio == null) {
      return;
    }
    final total = inicio.hour * 60 + inicio.minute + _duracao;
    if (total < 24 * 60) {
      _fim = TimeOfDay(hour: total ~/ 60, minute: total % 60);
    }
  }

  String _textoDaHora(TimeOfDay? h) => h == null ? 'Escolher' : '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

  Future<void> _salvar() async {
    final contato = _contato;
    if (contato == null) {
      setState(() => _erro = 'Escolha o cliente.');
      return;
    }
    if (_inicio == null) {
      setState(() => _erro = 'Escolha o horário de início.');
      return;
    }
    final repete = _editando?.naSerie != true && _repeticao != 'nao';
    if (repete && !_terminaPorVezes && _repetirAte == null) {
      setState(() => _erro = 'Diga até quando o horário se repete.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final campos = <String, String>{
      if (contato.contatoId > 0) 'contato_id': '${contato.contatoId}',
      if (contato.conversaId > 0) 'conversa_id': '${contato.conversaId}',
      'servicos': _servicos.join(','),
      'profissional_id': _profissionalId > 0 ? '$_profissionalId' : '',
      'data': _dia(_data),
      'hora_inicio': _textoDaHora(_inicio),
      'hora_fim': _fim == null ? '' : _textoDaHora(_fim),
      'local': _local.text.trim(),
      'observacoes': _observacoes.text.trim(),
      'situacao': _situacao,
      if (repete) 'repeticao': _repeticao,
      if (repete && _terminaPorVezes) 'repetir_vezes': _vezes.text.trim(),
      if (repete && !_terminaPorVezes && _repetirAte != null) 'repetir_ate': _dia(_repetirAte!),
      if (_editando?.naSerie == true) 'aplicar': _esteEProximos ? 'proximos' : 'este',
    };
    try {
      final resultado = await EcoApi.instancia.salvarAgendamento(_editando?.id ?? 0, campos);
      if (!mounted) {
        return;
      }
      _avisar(context, resultado.criados > 1 ? '${resultado.criados} horários marcados.' : 'Horário salvo.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final dados = _dados;
    final editando = _editando;
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(texto.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: .5, fontWeight: FontWeight.w800, color: c.textoSuave)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(editando == null ? 'Novo horário' : 'Editar horário'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _salvando || dados == null ? null : _salvar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: dados == null && _erro == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                if (_salvando) const LinearProgressIndicator(),
                titulo('Cliente'),
                if (_contato != null)
                  Material(
                    color: c.cartao,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(_contato!.nome.isEmpty ? 'Cliente da conversa' : _contato!.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: _contato!.telefone.isEmpty ? null : Text(telefoneFormatado(_contato!.telefone)),
                      trailing: editando == null && widget.conversaId == 0
                          ? IconButton(tooltip: 'Trocar cliente', icon: const Icon(Icons.close), onPressed: () => setState(() => _contato = null))
                          : null,
                    ),
                  )
                else ...[
                  TextField(
                    controller: _busca,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar contato por nome ou número'),
                    onChanged: _buscar,
                  ),
                  for (final r in _resultados)
                    ListTile(
                      title: Text(r.nome),
                      subtitle: r.telefone.isEmpty ? null : Text(telefoneFormatado(r.telefone)),
                      onTap: () => setState(() {
                        _contato = r;
                        _resultados = [];
                        _busca.clear();
                      }),
                    ),
                ],
                if (dados != null && dados.servicos.isNotEmpty) ...[
                  titulo('Serviços'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in dados.servicos)
                        FilterChip(
                          label: Text('${s.nome} · ${s.duracaoMin} min'),
                          selected: _servicos.contains(s.id),
                          onSelected: (marcado) => setState(() {
                            marcado ? _servicos.add(s.id) : _servicos.remove(s.id);
                            _ajustarTermino();
                          }),
                        ),
                    ],
                  ),
                ],
                if (dados != null && dados.profissionais.isNotEmpty) ...[
                  titulo('Profissional'),
                  DropdownButtonFormField<int>(
                    initialValue: dados.profissionais.any((p) => p.id == _profissionalId) ? _profissionalId : 0,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Qualquer um')),
                      for (final p in dados.profissionais) DropdownMenuItem(value: p.id, child: Text(p.nome)),
                    ],
                    onChanged: (v) => setState(() => _profissionalId = v ?? 0),
                  ),
                ],
                titulo('Quando'),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(DateFormat('EEE, dd/MM/y', 'pt_BR').format(_data)),
                        onPressed: () async {
                          final escolhido = await showDatePicker(context: context, initialDate: _data, firstDate: DateTime(2024), lastDate: DateTime(2035));
                          if (escolhido != null) {
                            setState(() => _data = escolhido);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('Início ${_textoDaHora(_inicio)}'),
                        onPressed: () async {
                          final escolhido = await showTimePicker(context: context, initialTime: _inicio ?? const TimeOfDay(hour: 9, minute: 0));
                          if (escolhido != null) {
                            setState(() {
                              _inicio = escolhido;
                              _ajustarTermino();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.timelapse),
                        label: Text('Fim ${_textoDaHora(_fim)}'),
                        onPressed: () async {
                          final escolhido = await showTimePicker(context: context, initialTime: _fim ?? _inicio ?? const TimeOfDay(hour: 10, minute: 0));
                          if (escolhido != null) {
                            setState(() => _fim = escolhido);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (dados != null && dados.situacoes.isNotEmpty) ...[
                  titulo('Situação'),
                  DropdownButtonFormField<String>(
                    initialValue: dados.situacoes.containsKey(_situacao) ? _situacao : 'confirmado',
                    items: [for (final e in dados.situacoes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setState(() => _situacao = v ?? 'confirmado'),
                  ),
                ],
                if (editando?.naSerie == true) ...[
                  titulo('Este horário se repete (${editando!.serie})'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Só este')),
                      ButtonSegment(value: true, label: Text('Este e os próximos')),
                    ],
                    selected: {_esteEProximos},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _esteEProximos = s.first),
                  ),
                ] else if (dados != null && dados.repeticoes.isNotEmpty) ...[
                  titulo('Repetir'),
                  DropdownButtonFormField<String>(
                    initialValue: _repeticao,
                    items: [for (final e in dados.repeticoes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setState(() => _repeticao = v ?? 'nao'),
                  ),
                  if (_repeticao != 'nao') ...[
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Até uma data')),
                        ButtonSegment(value: true, label: Text('Quantas vezes')),
                      ],
                      selected: {_terminaPorVezes},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _terminaPorVezes = s.first),
                    ),
                    const SizedBox(height: 10),
                    if (_terminaPorVezes)
                      TextField(
                        controller: _vezes,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantas vezes (com este)'),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_repeat),
                        label: Text(_repetirAte == null ? 'Escolher a data final' : 'Até ${DateFormat('dd/MM/y').format(_repetirAte!)}'),
                        onPressed: () async {
                          final escolhido = await showDatePicker(
                            context: context,
                            initialDate: _repetirAte ?? _data.add(const Duration(days: 28)),
                            firstDate: _data.add(const Duration(days: 1)),
                            lastDate: _data.add(const Duration(days: 730)),
                          );
                          if (escolhido != null) {
                            setState(() => _repetirAte = escolhido);
                          }
                        },
                      ),
                  ],
                ],
                titulo('Endereço ou local'),
                TextField(controller: _local, decoration: const InputDecoration(hintText: 'Opcional')),
                titulo('Observações'),
                TextField(controller: _observacoes, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'Opcional')),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_erro!, style: const TextStyle(color: corCritica, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
    );
  }
}
