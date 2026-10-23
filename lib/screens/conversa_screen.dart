import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../audio_pendente.dart';
import '../localizacao.dart';
import '../rascunhos.dart';
import '../models.dart';
import '../texto_rico.dart';
import '../theme.dart';
import '../widgets.dart';

class ConversaScreen extends StatefulWidget {
  const ConversaScreen({super.key, required this.conversaId, required this.titulo, required this.perfil, this.interna = false});

  final int conversaId;
  final bool interna;
  final String titulo;
  final Perfil perfil;

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen> with WidgetsBindingObserver {
  final _mensagens = <Mensagem>[];
  final _texto = TextEditingController();
  final _busca = TextEditingController();
  final _rolagem = ScrollController();
  final _gravador = AudioRecorder();
  Conversa? _conversa;
  Timer? _atualizacao;
  Timer? _cronometro;
  bool _consultando = false;
  bool _ativo = true;
  bool _novasMensagens = false;
  String? _audioPendente;
  late final String _chaveRascunho;
  bool _rascunhoPronto = false;
  Timer? _salvarAtrasado;
  bool _erroRascunhoAvisado = false;
  bool _carregou = false;
  bool _enviando = false;
  bool _modoNota = false;
  bool _buscando = false;
  DateTime? _gravandoDesde;
  String? _erro;
  Mensagem? _respondendo;
  int? _destacada;
  final _chavesBaloes = <int, GlobalKey>{};

  int get _ultimoId => _mensagens.isEmpty ? 0 : _mensagens.last.id;
  bool get _gravando => _gravandoDesde != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chaveRascunho = '${EcoApi.instancia.baseRascunhos}|${widget.perfil.usuario.id}|${widget.interna}|${widget.conversaId}';
    _restaurarRascunho();
    _texto.addListener(() {
      setState(() {});
      _salvarAtrasado?.cancel();
      _salvarAtrasado = Timer(const Duration(milliseconds: 300), _salvarRascunho);
    });
    _rolagem.addListener(() {
      if (_novasMensagens && _rolagem.position.extentAfter < 80) {
        setState(() => _novasMensagens = false);
      }
    });
    _buscar();
    _atualizacao = Timer.periodic(const Duration(seconds: 3), (_) => _buscar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _salvarAtrasado?.cancel();
    _salvarRascunho();
    _atualizacao?.cancel();
    _cronometro?.cancel();
    _gravador.dispose();
    _texto.dispose();
    _busca.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _restaurarRascunho() async {
    Map<String, dynamic> r;
    try {
      r = await Rascunhos.ler(_chaveRascunho);
    } catch (_) {
      if (mounted) {
        setState(() => _rascunhoPronto = true);
        mostrarAviso(context, 'Não foi possível recuperar o rascunho.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_texto.text.isEmpty) _texto.text = r['texto'] as String? ?? '';
      _modoNota = r['nota'] == true;
      _audioPendente = r['audio'] as String?;
      _rascunhoPronto = true;
    });
  }

  void _salvarRascunho() {
    if (!_rascunhoPronto) return;
    unawaited(
      Rascunhos.salvar(_chaveRascunho, {'texto': _texto.text, 'nota': _modoNota, 'audio': _audioPendente}).catchError((Object e) {
        if (mounted && !_erroRascunhoAvisado) {
          _erroRascunhoAvisado = true;
          mostrarAviso(context, 'Não foi possível salvar o rascunho neste aparelho.');
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ativo = state == AppLifecycleState.resumed;
    if (_ativo) {
      _buscar();
    } else {
      _salvarRascunho();
    }
  }

  Future<void> _buscar() async {
    if (_consultando || !_ativo || !mounted) return;
    _consultando = true;
    try {
      final detalhe = widget.interna
          ? await EcoApi.instancia.mensagensInternas(widget.conversaId, desde: _ultimoId)
          : await EcoApi.instancia.mensagens(widget.conversaId, desde: _ultimoId);
      if (!mounted) {
        return;
      }
      final acompanhar = !_carregou || !_rolagem.hasClients || _rolagem.position.extentAfter < 100;
      final novas = detalhe.mensagens.where((m) => m.id > _ultimoId).toList();
      setState(() {
        _conversa = detalhe.conversa;
        detalhe.aplicarEm(_mensagens);
        _mensagens.addAll(novas);
        _carregou = true;
        _erro = null;
      });
      if (novas.isNotEmpty && !_buscando) {
        if (acompanhar) {
          _descer();
        } else {
          setState(() => _novasMensagens = true);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    } finally {
      _consultando = false;
    }
  }

  void _descer() {
    if (mounted) setState(() => _novasMensagens = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rolagem.hasClients) {
        _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _executar(Future<String?> Function() acao) async {
    if (_enviando) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final aviso = await acao();
      await _buscar();
      if (aviso != null && aviso.isNotEmpty && mounted) {
        mostrarAviso(context, aviso);
      }
    } on ApiException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.mensagem);
      }
    } on FileSystemException {
      if (mounted) {
        mostrarAviso(context, 'N?o foi poss?vel ler o ?udio. Voc? pode tentar novamente ou descart?-lo.');
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Future<void> _enviarTexto() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty) {
      return;
    }
    await _executar(() async {
      if (widget.interna) {
        await EcoApi.instancia.enviarInterno(widget.conversaId, texto);
        _texto.clear();
        return null;
      }
      if (_modoNota) {
        await EcoApi.instancia.comentar(widget.conversaId, texto);
        _texto.clear();
        setState(() => _modoNota = false);
        return null;
      }
      final entregue = await EcoApi.instancia.enviar(widget.conversaId, texto, citaWaId: _respondendo?.waMessageId ?? '');
      _texto.clear();
      if (mounted) setState(() => _respondendo = null);
      return entregue ? null : 'A mensagem foi salva, mas o WhatsApp não confirmou o envio.';
    });
  }

  Future<void> _enviarArquivo(List<int> bytes, String nome, {bool audio = false}) async {
    await _executar(() async {
      final legenda = audio ? '' : _texto.text.trim();
      final r = await EcoApi.instancia.anexar(
        widget.conversaId,
        bytes: bytes,
        nomeArquivo: nome,
        audio: audio,
        legenda: legenda,
        interno: widget.interna,
        citaWaId: _respondendo?.waMessageId ?? '',
      );
      if (legenda.isNotEmpty) {
        _texto.clear();
      }
      if (mounted) setState(() => _respondendo = null);
      return r.entregue ? (r.aviso.isEmpty ? null : r.aviso) : (r.aviso.isEmpty ? 'O arquivo foi salvo, mas o WhatsApp não confirmou o envio.' : r.aviso);
    });
  }

  Future<void> _menuMais() async {
    FocusScope.of(context).unfocus();
    final opcoes = [
      (chave: 'galeria', rotulo: 'Galeria', icone: Icons.photo_library_outlined, cor: const Color(0xFF7C5CD6)),
      (chave: 'camera', rotulo: 'Câmera', icone: Icons.photo_camera_outlined, cor: const Color(0xFFE0556B)),
      (chave: 'arquivo', rotulo: 'Documento', icone: Icons.description_outlined, cor: const Color(0xFF3F7DE0)),
      if (!widget.interna) (chave: 'rapidas', rotulo: 'Respostas\nrápidas', icone: Icons.bolt, cor: context.cores.destaque),
      if (!widget.interna)
        (chave: 'nota', rotulo: _modoNota ? 'Voltar ao\ncliente' : 'Nota\ninterna', icone: Icons.sticky_note_2_outlined, cor: const Color(0xFFD9A21B)),
    ];
    final opcao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final o in opcoes)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(contexto, o.chave),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: o.cor.withValues(alpha: .14), shape: BoxShape.circle),
                            child: Icon(o.icone, color: o.cor, size: 27),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            o.rotulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (opcao == null || !mounted) {
      return;
    }
    if (opcao == 'rapidas') {
      await _respostasRapidas();
      return;
    }
    if (opcao == 'nota') {
      setState(() {
        _modoNota = !_modoNota;
        if (_modoNota) _respondendo = null;
      });
      _salvarRascunho();
      return;
    }
    try {
      if (opcao == 'arquivo') {
        final arquivos = await FilePicker.pickFiles();
        if (arquivos.isNotEmpty) {
          await _enviarArquivo(await arquivos.first.readAsBytes(), arquivos.first.name);
        }
        return;
      }
      final foto = await ImagePicker().pickImage(source: opcao == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
      if (foto != null) {
        await _enviarArquivo(await foto.readAsBytes(), foto.name);
      }
    } catch (_) {
      if (mounted) {
        mostrarAviso(context, 'Não foi possível abrir o arquivo.');
      }
    }
  }

  Future<void> _respostasRapidas() async {
    List<RespostaRapida> rapidas;
    try {
      rapidas = await EcoApi.instancia.respostasRapidas();
    } on ApiException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.mensagem);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final escolhida = await showModalBottomSheet<RespostaRapida>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PainelRapidas(rapidas: rapidas),
    );
    if (escolhida != null) {
      _texto.text = escolhida.conteudo;
      _texto.selection = TextSelection.collapsed(offset: _texto.text.length);
    }
  }

  Future<void> _iniciarGravacao() async {
    if (!await _gravador.hasPermission()) {
      if (mounted) {
        mostrarAviso(context, 'Permita o uso do microfone nas configurações do celular.');
      }
      return;
    }
    final opus = Platform.isAndroid && await _gravador.isEncoderSupported(AudioEncoder.opus);
    final pasta = await getApplicationSupportDirectory();
    final caminho = '${pasta.path}/audio_${DateTime.now().millisecondsSinceEpoch}.${opus ? 'ogg' : 'm4a'}';
    await _gravador.start(RecordConfig(encoder: opus ? AudioEncoder.opus : AudioEncoder.aacLc, numChannels: 1, bitRate: 48000), path: caminho);
    setState(() => _gravandoDesde = DateTime.now());
    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _terminarGravacao({required bool enviar}) async {
    _cronometro?.cancel();
    final duracao = _gravandoDesde == null ? Duration.zero : DateTime.now().difference(_gravandoDesde!);
    setState(() => _gravandoDesde = null);
    if (!enviar) {
      await _gravador.cancel();
      return;
    }
    final caminho = await _gravador.stop();
    if (caminho == null) {
      return;
    }
    final arquivo = File(caminho);
    if (duracao < const Duration(seconds: 1)) {
      await arquivo.delete().catchError((_) => arquivo);
      if (mounted) {
        mostrarAviso(context, 'Áudio muito curto.');
      }
      return;
    }
    setState(() => _audioPendente = caminho);
    _salvarRascunho();
    await _reenviarAudio();
  }

  Future<void> _reenviarAudio() async {
    final caminho = _audioPendente;
    if (caminho == null) return;
    final citaWaId = _respondendo?.waMessageId ?? '';
    await _executar(() async {
      final arquivo = File(caminho);
      final r = await enviarAudioPreservado(
        arquivo,
        (bytes) => EcoApi.instancia.anexar(
          widget.conversaId,
          bytes: bytes,
          nomeArquivo: caminho.split('/').last,
          audio: true,
          legenda: '',
          interno: widget.interna,
          citaWaId: citaWaId,
        ),
      );
      _audioPendente = null;
      _respondendo = null;
      if (mounted) {
        setState(() {});
        _salvarRascunho();
      } else {
        final rascunho = await Rascunhos.ler(_chaveRascunho);
        rascunho['audio'] = null;
        await Rascunhos.salvar(_chaveRascunho, rascunho);
      }
      return r.entregue ? null : '?udio salvo no servidor; WhatsApp ainda n?o confirmou o envio.';
    });
  }

  Future<void> _descartarAudio() async {
    final caminho = _audioPendente;
    if (caminho == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Descartar ?udio n?o enviado?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Manter')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _audioPendente = null);
    _salvarRascunho();
    final arquivo = File(caminho);
    if (await arquivo.exists()) await arquivo.delete();
  }

  Future<void> _transferir() async {
    ({List<Opcao> atendentes, List<Opcao> departamentos}) opcoes;
    try {
      opcoes = await EcoApi.instancia.opcoesTransferencia();
    } on ApiException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.mensagem);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final destino = await showModalBottomSheet<({int? atendente, int? departamento, String nome})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * .75),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Transferir conversa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const _Rotulo('Para um atendente'),
              for (final a in opcoes.atendentes)
                ListTile(
                  leading: AvatarContato(nome: a.nome, tamanho: 36),
                  title: Text(a.nome + (a.id == widget.perfil.usuario.id ? ' (você)' : '')),
                  onTap: () => Navigator.pop(contexto, (atendente: a.id, departamento: null, nome: a.nome)),
                ),
              const _Rotulo('Para a fila de um departamento'),
              for (final d in opcoes.departamentos)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(d.nome),
                  onTap: () => Navigator.pop(contexto, (atendente: null, departamento: d.id, nome: d.nome)),
                ),
            ],
          ),
        ),
      ),
    );
    if (destino == null) {
      return;
    }
    await _executar(() async {
      await EcoApi.instancia.transferir(widget.conversaId, atendenteId: destino.atendente, departamentoId: destino.departamento);
      return 'Conversa transferida para ${destino.nome}.';
    });
  }

  Future<void> _encerrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Encerrar atendimento?'),
        content: const Text('A conversa sai da sua lista. Se o cliente mandar mensagem de novo, ela volta para a fila.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Encerrar')),
        ],
      ),
    );
    if (confirmado != true) {
      return;
    }
    try {
      await EcoApi.instancia.encerrar(widget.conversaId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.mensagem);
      }
    }
  }

  bool _podeResponder(Mensagem m) => !widget.interna && !m.interna && !m.apagada && m.waMessageId.isNotEmpty;

  String get _nomeContato {
    final conversa = _conversa;
    if (conversa == null) return widget.titulo;
    return conversa.contatoNome.isNotEmpty ? conversa.contatoNome : telefoneFormatado(conversa.telefone);
  }

  String _autorDe(Mensagem m) {
    if (m.autor == 'bot' || m.autor == 'ia') return 'Assistente';
    if (m.enviada) return m.autorNome.isNotEmpty ? m.autorNome : 'Atendente';
    return _nomeContato;
  }

  String _autorDaCitacao(Mensagem m) {
    switch (m.citaDe) {
      case '':
      case 'cliente':
        return _nomeContato;
      case 'atendente':
        return 'Atendente';
      case 'bot':
      case 'ia':
        return 'Assistente';
      default:
        return m.citaDe;
    }
  }

  void _responder(Mensagem m) {
    HapticFeedback.selectionClick();
    setState(() {
      _respondendo = m;
      _modoNota = false;
    });
  }

  Future<void> _menuMensagem(Mensagem m) async {
    final texto = m.conteudo.isNotEmpty ? m.conteudo : m.transcricao;
    final podeResponder = _podeResponder(m);
    if (!podeResponder && texto.isEmpty) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    final opcao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(m.resumo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: contexto.cores.textoSuave)),
            ),
            if (podeResponder)
              ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Responder'), onTap: () => Navigator.pop(contexto, 'responder')),
            if (texto.isNotEmpty)
              ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copiar texto'), onTap: () => Navigator.pop(contexto, 'copiar')),
          ],
        ),
      ),
    );
    if (!mounted || opcao == null) return;
    if (opcao == 'responder') {
      _responder(m);
    } else {
      await Clipboard.setData(ClipboardData(text: texto));
      if (mounted) mostrarAviso(context, 'Texto copiado.');
    }
  }

  Future<void> _irParaOriginal(String waId) async {
    final i = _mensagens.indexWhere((m) => m.waMessageId.isNotEmpty && (m.waMessageId == waId || m.waMessageId.endsWith(waId)));
    if (i < 0) {
      mostrarAviso(context, 'A mensagem original não está carregada nesta conversa.');
      return;
    }
    final alvo = _mensagens[i];
    if (_buscando) _alternarBusca();
    var contexto = _chavesBaloes[alvo.id]?.currentContext;
    if (contexto == null && _rolagem.hasClients) {
      _rolagem.jumpTo(_rolagem.position.maxScrollExtent * i / _mensagens.length);
      await WidgetsBinding.instance.endOfFrame;
      contexto = _chavesBaloes[alvo.id]?.currentContext;
    }
    if (contexto == null || !contexto.mounted) return;
    await Scrollable.ensureVisible(contexto, alignment: .3, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    if (!mounted) return;
    setState(() => _destacada = alvo.id);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted && _destacada == alvo.id) setState(() => _destacada = null);
  }

  void _alternarBusca() {
    setState(() {
      _buscando = !_buscando;
      _busca.clear();
    });
    if (!_buscando) {
      _descer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buscando ? _barraBusca() : _barraConversa(),
      body: Column(
        children: [
          if (_erro != null && _carregou)
            MaterialBanner(
              content: const Text('Reconectando? As mensagens podem estar desatualizadas.'),
              actions: [TextButton(onPressed: _buscar, child: const Text('Tentar agora'))],
            ),
          Expanded(child: _corpo()),
          if (_novasMensagens) TextButton.icon(onPressed: _descer, icon: const Icon(Icons.arrow_downward), label: const Text('Novas mensagens')),
          if (_audioPendente != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const Text('?udio pendente. Se houve timeout, confira a conversa antes de reenviar.'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _enviando ? null : _descartarAudio, child: const Text('Descartar')),
                      TextButton(onPressed: _enviando ? null : _reenviarAudio, child: const Text('Tentar novamente')),
                    ],
                  ),
                ],
              ),
            ),
          _compositor(),
        ],
      ),
    );
  }

  PreferredSizeWidget _barraConversa() {
    final conversa = _conversa;
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          AvatarContato(nome: widget.titulo, fotoUrl: conversa?.fotoUrl ?? '', tamanho: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversa?.contatoNome ?? widget.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                if (widget.interna)
                  const Text('Chat interno da equipe', style: TextStyle(fontSize: 12, color: Colors.white70))
                else if (conversa != null && conversa.telefone.isNotEmpty)
                  Text(telefoneFormatado(conversa.telefone), style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(tooltip: 'Buscar na conversa', icon: const Icon(Icons.search), onPressed: _alternarBusca),
        if (!widget.interna) ...[
          IconButton(tooltip: 'Transferir', icon: const Icon(Icons.swap_horiz), onPressed: _enviando ? null : _transferir),
          IconButton(
            tooltip: 'Encerrar atendimento',
            icon: const Icon(Icons.phone_disabled_outlined, color: Color(0xFFFF8A80)),
            onPressed: _encerrar,
          ),
        ],
      ],
    );
  }

  PreferredSizeWidget _barraBusca() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _alternarBusca),
      title: TextField(
        controller: _busca,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: 'Buscar na conversa',
          hintStyle: TextStyle(color: Colors.white70),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _corpo() {
    if (!_carregou) {
      return Center(
        child: _erro != null
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_erro!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      );
    }
    final termo = _busca.text.trim().toLowerCase();
    final visiveis = _buscando && termo.isNotEmpty
        ? _mensagens.where((m) => '${m.conteudo} ${m.transcricao}'.toLowerCase().contains(termo)).toList()
        : _mensagens;
    if (visiveis.isEmpty) {
      return Center(child: Text(_buscando && termo.isNotEmpty ? 'Nada encontrado para "${_busca.text.trim()}".' : 'Nenhuma mensagem ainda.'));
    }
    return ListView.builder(
      controller: _rolagem,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: visiveis.length,
      itemBuilder: (_, i) {
        final m = visiveis[i];
        final anterior = i > 0 ? visiveis[i - 1] : null;
        final novoDia = m.criadoEm != null && (anterior?.criadoEm == null || !_mesmoDia(anterior!.criadoEm!, m.criadoEm!));
        return Column(
          children: [
            if (novoDia) _SeparadorDia(data: m.criadoEm!),
            if (m.evento)
              _Evento(mensagem: m)
            else
              _ArrastarParaResponder(
                key: _chavesBaloes.putIfAbsent(m.id, GlobalKey.new),
                ativo: _podeResponder(m),
                aoResponder: () => _responder(m),
                aoSegurar: () => _menuMensagem(m),
                child: _Balao(
                  mensagem: m,
                  autorCitacao: _autorDaCitacao(m),
                  destacada: _destacada == m.id,
                  aoTocarCitacao: m.citaWaId.isEmpty ? null : () => _irParaOriginal(m.citaWaId),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _barraResposta(Mensagem m) {
    final c = context.cores;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: BoxDecoration(
        color: c.cartao,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: c.destaque, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18, color: c.destaque),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Respondendo a ${_autorDe(m)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.destaque),
                ),
                Text(m.resumo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textoSuave)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancelar resposta',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: c.textoSuave),
            onPressed: () => setState(() => _respondendo = null),
          ),
        ],
      ),
    );
  }

  Widget _compositor() {
    final tema = Theme.of(context);
    final c = context.cores;
    final temTexto = _texto.text.trim().isNotEmpty;
    final verde = const Color(0xFF25D366);
    Widget botaoRedondo({required Color cor, required IconData icone, required VoidCallback? aoTocar, String? dica}) => Material(
      color: aoTocar == null ? cor.withValues(alpha: .5) : cor,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: cor.withValues(alpha: .5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: aoTocar,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: _enviando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(icone, color: Colors.white, size: 23, semanticLabel: dica),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_respondendo != null && !_modoNota && !_gravando) _barraResposta(_respondendo!),
            if (_modoNota && !_gravando)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 16, color: const Color(0xFFD9A21B)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Nota interna: só a equipe vê, não vai pro cliente.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _modoNota = false);
                        _salvarRascunho();
                      },
                      child: Icon(Icons.close, size: 18, color: c.textoSuave),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _modoNota ? c.nota : c.cartao,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _modoNota ? const Color(0xFFD9A21B).withValues(alpha: .6) : c.linha),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: _gravando
                        ? Row(
                            children: [
                              IconButton(
                                tooltip: 'Descartar áudio',
                                icon: Icon(Icons.delete_outline, color: tema.colorScheme.error),
                                onPressed: () => _terminarGravacao(enviar: false),
                              ),
                              const _PontoPulsante(),
                              const SizedBox(width: 8),
                              Text('Gravando  ${_duracao(DateTime.now().difference(_gravandoDesde!))}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Material(
                                  color: c.destaque.withValues(alpha: .14),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _enviando ? null : _menuMais,
                                    child: SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: Icon(Icons.add, color: c.destaque, semanticLabel: 'Mais opções'),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _texto,
                                  readOnly: _enviando || !_rascunhoPronto,
                                  minLines: 1,
                                  maxLines: 5,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: widget.interna ? 'Mensagem para a equipe' : (_modoNota ? 'Escreva a nota interna…' : 'Escreva sua resposta…'),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.fromLTRB(10, 15, 8, 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_gravando)
                  botaoRedondo(cor: verde, icone: Icons.send_rounded, aoTocar: () => _terminarGravacao(enviar: true), dica: 'Enviar áudio')
                else if (temTexto || _modoNota)
                  botaoRedondo(
                    cor: _modoNota ? const Color(0xFFD9A21B) : c.marca,
                    icone: Icons.send_rounded,
                    aoTocar: _enviando || !temTexto ? null : _enviarTexto,
                    dica: 'Enviar',
                  )
                else
                  botaoRedondo(
                    cor: verde,
                    icone: Icons.mic_none_rounded,
                    aoTocar: _enviando || _audioPendente != null || !_rascunhoPronto ? null : _iniciarGravacao,
                    dica: 'Gravar áudio',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PontoPulsante extends StatefulWidget {
  const _PontoPulsante();

  @override
  State<_PontoPulsante> createState() => _PontoPulsanteState();
}

class _PontoPulsanteState extends State<_PontoPulsante> with SingleTickerProviderStateMixin {
  late final AnimationController _animacao = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .3, end: 1.0).animate(_animacao),
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
    );
  }
}

String _duracao(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: .6)),
    );
  }
}

class _PainelRapidas extends StatefulWidget {
  const _PainelRapidas({required this.rapidas});

  final List<RespostaRapida> rapidas;

  @override
  State<_PainelRapidas> createState() => _PainelRapidasState();
}

class _PainelRapidasState extends State<_PainelRapidas> {
  String _termo = '';

  @override
  Widget build(BuildContext context) {
    final lista = widget.rapidas.where((r) => _termo.isEmpty || r.combina(_termo)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar resposta rápida'),
                  onChanged: (v) => setState(() => _termo = v.trim()),
                ),
              ),
              Flexible(
                child: lista.isEmpty
                    ? const Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma resposta rápida encontrada. Elas são criadas no painel.'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(lista[i].titulo.isNotEmpty ? lista[i].titulo : lista[i].atalho),
                          subtitle: Text(lista[i].conteudo, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, lista[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Text(DateFormat("d 'de' MMMM", 'pt_BR').format(data), style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento({required this.mensagem});

  final Mensagem mensagem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          mensagem.conteudo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class _ArrastarParaResponder extends StatefulWidget {
  const _ArrastarParaResponder({super.key, required this.ativo, required this.aoResponder, required this.aoSegurar, required this.child});

  final bool ativo;
  final VoidCallback aoResponder;
  final VoidCallback aoSegurar;
  final Widget child;

  @override
  State<_ArrastarParaResponder> createState() => _ArrastarParaResponderState();
}

class _ArrastarParaResponderState extends State<_ArrastarParaResponder> {
  static const _limite = 64.0;
  double _deslocamento = 0;
  bool _arrastando = false;

  void _soltar() {
    if (_deslocamento >= _limite) widget.aoResponder();
    setState(() {
      _deslocamento = 0;
      _arrastando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ativo) {
      return GestureDetector(onLongPress: widget.aoSegurar, child: widget.child);
    }
    final c = context.cores;
    final progresso = (_deslocamento / _limite).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: widget.aoSegurar,
      onHorizontalDragStart: (_) => setState(() => _arrastando = true),
      onHorizontalDragUpdate: (d) {
        final antes = _deslocamento;
        setState(() => _deslocamento = (_deslocamento + d.delta.dx).clamp(0.0, _limite * 1.3));
        if (antes < _limite && _deslocamento >= _limite) HapticFeedback.lightImpact();
      },
      onHorizontalDragEnd: (_) => _soltar(),
      onHorizontalDragCancel: _soltar,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progresso,
                child: Transform.scale(
                  scale: .6 + .4 * progresso,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: c.destaque.withValues(alpha: .18),
                    child: Icon(Icons.reply_rounded, size: 20, color: c.destaque),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _arrastando ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_deslocamento, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _Balao extends StatelessWidget {
  const _Balao({required this.mensagem, this.autorCitacao = '', this.destacada = false, this.aoTocarCitacao});

  final Mensagem mensagem;
  final String autorCitacao;
  final bool destacada;
  final VoidCallback? aoTocarCitacao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final tema = Theme.of(context);
    final minha = mensagem.enviada;
    final bot = mensagem.autor == 'bot' || mensagem.autor == 'ia';
    final escuroNoBalao = minha && !mensagem.interna && !bot;
    final cor = mensagem.interna
        ? c.nota
        : bot
        ? c.balaoBot
        : minha
        ? c.balaoEnviado
        : c.balaoRecebido;
    final corTexto = escuroNoBalao ? Colors.white : tema.textTheme.bodyMedium?.color;
    final corRodape = escuroNoBalao ? Colors.white70 : c.textoSuave;
    final rodape = [
      if (minha && !bot && mensagem.autorNome.isNotEmpty) mensagem.autorNome,
      if (bot) 'Assistente',
      if (mensagem.criadoEm != null) DateFormat.Hm('pt_BR').format(mensagem.criadoEm!),
    ].join(' · ');
    const raio = Radius.circular(18);
    const ponta = Radius.circular(5);

    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          foregroundDecoration: BoxDecoration(
            color: c.destaque.withValues(alpha: destacada ? .22 : 0),
            borderRadius: BorderRadius.only(topLeft: raio, topRight: raio, bottomLeft: minha ? raio : ponta, bottomRight: minha ? ponta : raio),
          ),
          margin: EdgeInsets.only(top: 3, bottom: 3, left: minha ? 40 : 0, right: minha ? 0 : 40),
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.only(topLeft: raio, topRight: raio, bottomLeft: minha ? raio : ponta, bottomRight: minha ? ponta : raio),
            border: mensagem.interna ? Border.all(color: const Color(0xFFD9A21B).withValues(alpha: .45)) : null,
            boxShadow: [if (!minha) BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: corTexto, fontSize: 15, height: 1.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mensagem.interna)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.sticky_note_2_outlined, size: 13, color: Color(0xFFB07F0E)),
                        SizedBox(width: 4),
                        Text(
                          'Nota interna',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB07F0E)),
                        ),
                      ],
                    ),
                  ),
                if (mensagem.citaPrevia.isNotEmpty)
                  GestureDetector(
                    onTap: aoTocarCitacao,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: c.destaque, width: 3)),
                        color: (escuroNoBalao ? Colors.white : Colors.black).withValues(alpha: .07),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (autorCitacao.isNotEmpty)
                            Text(
                              autorCitacao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: escuroNoBalao ? Colors.white : c.destaque),
                            ),
                          Text(
                            mensagem.citaPrevia,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: corRodape),
                          ),
                        ],
                      ),
                    ),
                  ),
                _conteudo(context, escuroNoBalao),
                if (mensagem.reacao.isNotEmpty && !mensagem.apagada)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (escuroNoBalao ? Colors.white : Colors.black).withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(mensagem.reacao, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(rodape, style: TextStyle(fontSize: 11, color: corRodape)),
                    ),
                    if (minha && !mensagem.interna && !bot) ...[
                      const SizedBox(width: 4),
                      Icon(
                        mensagem.status == 'erro' ? Icons.error_outline : (mensagem.status == 'lido' ? Icons.done_all : Icons.done),
                        size: 14,
                        color: mensagem.status == 'erro' ? const Color(0xFFFF8A80) : (mensagem.status == 'lido' ? const Color(0xFF7FD6FF) : corRodape),
                      ),
                    ],
                  ],
                ),
                if (minha && mensagem.status == 'erro')
                  const Text(
                    'não enviada',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFF8A80), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context, bool claroSobreEscuro) {
    if (mensagem.apagada) {
      return const Text('Mensagem apagada', style: TextStyle(fontStyle: FontStyle.italic));
    }
    if (mensagem.direcao == 'entrada' && mensagem.status == 'erro' && mensagem.midiaUrl.isEmpty) {
      const naoBaixou = {
        'imagem': 'Esta foto não pôde ser baixada',
        'sticker': 'Esta figurinha não pôde ser baixada',
        'audio': 'Este áudio não pôde ser baixado',
        'video': 'Este vídeo não pôde ser baixado',
        'documento': 'Este documento não pôde ser baixado',
      };
      final aviso = naoBaixou[mensagem.tipo];
      if (aviso != null) {
        return _Anexo(icone: Icons.error_outline, texto: '$aviso do WhatsApp. Peça para o cliente enviar de novo.');
      }
    }
    final url = mensagem.midiaUrl.isEmpty ? '' : EcoApi.instancia.urlAbsoluta(mensagem.midiaUrl);
    final corLink = claroSobreEscuro ? Colors.white : context.cores.destaque;
    final legenda = mensagem.conteudo.isNotEmpty
        ? Padding(padding: const EdgeInsets.only(top: 6), child: TextoRico(mensagem.conteudo, corLink: corLink))
        : null;
    switch (mensagem.tipo) {
      case 'imagem':
      case 'sticker':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FotoCheia(url: url))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: mensagem.tipo == 'sticker' ? 120 : 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _Anexo(icone: Icons.broken_image_outlined, texto: 'Imagem indisponível'),
                  ),
                ),
              ),
            ?legenda,
          ],
        );
      case 'audio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            url.isNotEmpty ? _TocadorAudio(url: url, claro: claroSobreEscuro) : const _Anexo(icone: Icons.mic_none, texto: 'Áudio'),
            if (mensagem.transcricao.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('“${mensagem.transcricao}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
              ),
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Anexo(icone: Icons.videocam_outlined, texto: 'Vídeo', url: url),
            ?legenda,
          ],
        );
      case 'documento':
        return _Anexo(icone: Icons.description_outlined, texto: mensagem.conteudo.isNotEmpty ? mensagem.conteudo : 'Documento', url: url);
      case 'localizacao':
        return _CartaoLocalizacao(localizacao: lerLocalizacao(mensagem.conteudo), claro: claroSobreEscuro);
      case 'contato':
        return _CartaoContato(conteudo: mensagem.conteudo, claro: claroSobreEscuro);
      default:
        return TextoRico(mensagem.conteudo, corLink: corLink);
    }
  }
}

class _TocadorAudio extends StatefulWidget {
  const _TocadorAudio({required this.url, required this.claro});

  final String url;
  final bool claro;

  @override
  State<_TocadorAudio> createState() => _TocadorAudioState();
}

class _TocadorAudioState extends State<_TocadorAudio> {
  AudioPlayer? _player;
  bool _carregando = false;
  late final List<double> _barras = _gerarBarras(widget.url);

  static List<double> _gerarBarras(String semente) {
    var h = semente.hashCode;
    return List.generate(30, (i) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final onda = (i % 7 < 4 ? .55 : .35) + (h % 100) / 180;
      return onda.clamp(.18, 1.0);
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _alternar() async {
    final player = _player;
    if (player == null) {
      setState(() => _carregando = true);
      final novo = AudioPlayer();
      try {
        await novo.setUrl(widget.url);
        _player = novo;
        novo.playerStateStream.listen((estado) {
          if (estado.processingState == ProcessingState.completed) {
            novo.pause();
            novo.seek(Duration.zero);
          }
          if (mounted) {
            setState(() {});
          }
        });
        novo.play();
      } catch (_) {
        await novo.dispose();
        if (mounted) {
          mostrarAviso(context, 'Não foi possível tocar este áudio.');
        }
      } finally {
        if (mounted) {
          setState(() => _carregando = false);
        }
      }
      return;
    }
    player.playing ? await player.pause() : await player.play();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final player = _player;
    final corAtiva = widget.claro ? Colors.white : c.destaque;
    final corInativa = widget.claro ? Colors.white38 : c.textoSuave.withValues(alpha: .35);
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Material(
            color: widget.claro ? Colors.white : c.destaque,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _carregando ? null : _alternar,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: _carregando
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.claro ? c.marca : Colors.white))
                      : Icon(player?.playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.claro ? c.marca : Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player?.positionStream ?? const Stream.empty(),
              builder: (_, snap) {
                final total = player?.duration ?? Duration.zero;
                final atual = snap.data ?? Duration.zero;
                final progresso = total.inMilliseconds == 0 ? 0.0 : (atual.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _barras.length; i++)
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 3,
                                  height: 26 * _barras[i],
                                  decoration: BoxDecoration(
                                    color: i / _barras.length <= progresso && progresso > 0 ? corAtiva : corInativa,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player == null ? 'Áudio' : '${_duracao(atual)} / ${_duracao(total)}',
                      style: TextStyle(fontSize: 11, color: widget.claro ? Colors.white70 : c.textoSuave),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Anexo extends StatelessWidget {
  const _Anexo({required this.icone, required this.texto, this.url = ''});

  final IconData icone;
  final String texto;
  final String url;

  @override
  Widget build(BuildContext context) {
    final linha = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 20),
        const SizedBox(width: 6),
        Flexible(child: Text(texto)),
        if (url.isNotEmpty) ...[const SizedBox(width: 6), Icon(Icons.open_in_new, size: 16, color: context.cores.textoSuave)],
      ],
    );
    if (url.isEmpty) {
      return linha;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final aberto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!aberto && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum aplicativo para abrir este arquivo.')));
        }
      },
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: linha),
    );
  }
}

class _FotoCheia extends StatelessWidget {
  const _FotoCheia({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Abrir fora do app',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            loadingBuilder: (_, filho, progresso) => progresso == null ? filho : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (_, _, _) => const Text('Imagem indisponível', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}

class _CartaoLocalizacao extends StatelessWidget {
  const _CartaoLocalizacao({required this.localizacao, required this.claro});

  final Localizacao localizacao;
  final bool claro;

  Future<void> _abrir(BuildContext context) async {
    for (final destino in enderecosDoMapa(localizacao)) {
      try {
        if (await launchUrl(destino, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
    if (context.mounted) {
      mostrarAviso(context, 'Nenhum aplicativo de mapa para abrir a localização.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final temPonto = localizacao.latitude != null && localizacao.longitude != null;
    final suave = claro ? Colors.white70 : c.textoSuave;
    final destaque = claro ? Colors.white : c.destaque;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: temPonto ? () => _abrir(context) : null,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (claro ? Colors.white : Colors.black).withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: destaque.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.location_on, color: destaque),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizacao.lugar.isNotEmpty ? localizacao.lugar : 'Localização',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    temPonto ? 'Toque para abrir no mapa' : 'O ponto no mapa não chegou. Peça para reenviar.',
                    style: TextStyle(fontSize: 12, color: suave),
                  ),
                ],
              ),
            ),
            if (temPonto) Icon(Icons.open_in_new, size: 18, color: suave),
          ],
        ),
      ),
    );
  }
}

class _CartaoContato extends StatelessWidget {
  const _CartaoContato({required this.conteudo, required this.claro});

  final String conteudo;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final linhas = conteudo.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final telefones = linhas.where((l) => RegExp(r'\d').allMatches(l).length >= 8 && RegExp(r'^[\d\s()+.-]+$').hasMatch(l)).toList();
    final nomes = linhas.where((l) => !telefones.contains(l)).toList();
    final suave = claro ? Colors.white70 : c.textoSuave;
    final destaque = claro ? Colors.white : c.destaque;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (claro ? Colors.white : Colors.black).withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, size: 34, color: destaque),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nomes.isNotEmpty ? nomes.join(' · ') : 'Contato compartilhado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (final telefone in telefones)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final numero = telefone.replaceAll(RegExp(r'[^\d+]'), '');
                if (!await launchUrl(Uri(scheme: 'tel', path: numero)) && context.mounted) {
                  mostrarAviso(context, 'Não foi possível abrir o discador.');
                }
              },
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: telefone));
                mostrarAviso(context, 'Número copiado.');
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.call, size: 18, color: destaque),
                    const SizedBox(width: 8),
                    Expanded(child: Text(telefone, style: TextStyle(color: destaque, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          if (telefones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Toque para ligar · segure para copiar', style: TextStyle(fontSize: 11.5, color: suave)),
            ),
        ],
      ),
    );
  }
}
