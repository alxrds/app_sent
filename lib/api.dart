import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.mensagem, [this.status = 0]);

  final String mensagem;
  final int status;

  @override
  String toString() => mensagem;
}

class EcoApi {
  EcoApi._();

  static final EcoApi instancia = EcoApi._();

  static const _armazenamento = FlutterSecureStorage();
  static const _chaveToken = 'token';
  static const _chaveBase = 'base_url';
  static const _timeout = Duration(seconds: 20);

  String? _token;
  String? _base;
  void Function()? aoPerderAcesso;

  bool get conectado => _token != null && _base != null;
  String get baseRascunhos => _base ?? '';

  Future<void> carregar() async {
    _token = await _armazenamento.read(key: _chaveToken);
    _base = await _armazenamento.read(key: _chaveBase);
  }

  Future<void> _esquecer() async {
    _token = null;
    _base = null;
    await _armazenamento.delete(key: _chaveToken);
    await _armazenamento.delete(key: _chaveBase);
  }

  static ({String base, String codigo})? lerQr(String conteudo) {
    final uri = Uri.tryParse(conteudo.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    final codigo = uri.queryParameters['c'] ?? '';
    if (!uri.path.endsWith('/app/conectar') || !RegExp(r'^[a-f0-9]{48}$').hasMatch(codigo)) {
      return null;
    }
    final prefixo = uri.path.substring(0, uri.path.length - '/app/conectar'.length);
    return (base: '${uri.scheme}://${uri.authority}$prefixo', codigo: codigo);
  }

  static String? baseDoEscritorio(String digitado) {
    var endereco = digitado.trim().toLowerCase().replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/+$'), '');
    if (!RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*(/[a-z0-9._~/-]*)?$').hasMatch(endereco)) {
      return null;
    }
    if (!endereco.split('/').first.contains('.')) {
      endereco = '$endereco.sent.app.br';
    }
    return 'https://$endereco';
  }

  static String? codigoDigitado(String digitado) {
    final codigo = digitado.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(codigo) ? codigo : null;
  }

  Future<Perfil> parear(String base, String codigo) async {
    final aparelho = await _nomeDoAparelho();
    final resposta = await _executar(
      () => http.post(
        Uri.parse('$base/api/app/parear'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'codigo': codigo, 'nome': aparelho, 'plataforma': Platform.operatingSystem}),
      ),
    );
    final dados = _decodificar(resposta, exigirSessao: false);
    _token = dados['token'] as String;
    _base = base;
    await _armazenamento.write(key: _chaveToken, value: _token);
    await _armazenamento.write(key: _chaveBase, value: _base);
    return Perfil.deJson(dados);
  }

  Future<Perfil> eu() async => Perfil.deJson(await _get('/api/app/eu'));

  Future<void> registrarPush(String token) async {
    await _post('/api/app/push-token', {'token': token});
  }

  Future<void> sair() async {
    try {
      await _post('/api/app/sair');
    } catch (_) {}
    await _esquecer();
  }

  Future<ListaConversas> conversas(String filtro, {int offset = 0, String busca = ''}) async {
    final dados = await _get('/sac/api/lista?filtro=$filtro&offset=$offset&q=${Uri.encodeQueryComponent(busca)}');
    final itens = (dados['conversas'] as List? ?? []).map((c) => Conversa.deJson(c as Map<String, dynamic>)).toList();
    return ListaConversas(itens, dados['temMais'] == true, (dados['filaTotal'] as num?)?.toInt() ?? 0);
  }

  Future<DetalheConversa> mensagens(int conversaId, {int desde = 0}) async {
    final dados = await _get('/sac/api/mensagens/$conversaId?desde=$desde');
    return DetalheConversa.deJson(dados);
  }

  Future<bool> enviar(int conversaId, String texto, {String citaWaId = ''}) async {
    final dados = await _post('/sac/api/enviar/$conversaId', {'texto': texto, if (citaWaId.isNotEmpty) 'cita_wa_id': citaWaId});
    return dados['gateway_ok'] != false;
  }

  Future<DetalheConversa> mensagensInternas(int colegaId, {int desde = 0}) async {
    final dados = await _get('/sac/api/interno/mensagens/$colegaId?desde=$desde');
    return DetalheConversa.deJson(dados);
  }

  Future<void> enviarInterno(int colegaId, String texto) => _post('/sac/api/interno/enviar/$colegaId', {'texto': texto});

  Future<({List<Opcao> atendentes, List<Opcao> departamentos})> opcoesTransferencia() async {
    final dados = await _get('/sac/api/transferir-opcoes');
    List<Opcao> lista(String chave) => (dados[chave] as List? ?? []).map((o) => Opcao.deJson((o as Map).cast<String, dynamic>())).toList();
    return (atendentes: lista('atendentes'), departamentos: lista('departamentos'));
  }

  Future<void> transferir(int conversaId, {int? atendenteId, int? departamentoId}) => _post('/sac/api/transferir/$conversaId', {
    if (atendenteId != null) 'atendente_id': '$atendenteId',
    if (departamentoId != null) 'departamento_id': '$departamentoId',
  });

  Future<void> comentar(int conversaId, String texto) => _post('/sac/api/comentar/$conversaId', {'texto': texto});

  Future<List<RespostaRapida>> respostasRapidas() async {
    final dados = await _get('/sac/api/rapidas');
    return (dados['rapidas'] as List? ?? []).map((r) => RespostaRapida.deJson((r as Map).cast<String, dynamic>())).toList();
  }

  Future<({bool entregue, String aviso})> anexar(
    int conversaId, {
    required List<int> bytes,
    required String nomeArquivo,
    bool audio = false,
    String legenda = '',
    bool interno = false,
    String citaWaId = '',
  }) async {
    final rota = interno ? '/sac/api/interno/anexar/$conversaId' : '/sac/api/anexar/$conversaId';
    final requisicao = http.MultipartRequest('POST', Uri.parse('$_base$rota'))
      ..headers.addAll({...cabecalhosAutenticados, 'Accept': 'application/json'})
      ..files.add(http.MultipartFile.fromBytes('arquivo', bytes, filename: nomeArquivo));
    if (audio) {
      requisicao.fields['kind'] = 'audio';
    }
    if (legenda.isNotEmpty) {
      requisicao.fields['texto'] = legenda;
    }
    if (citaWaId.isNotEmpty) {
      requisicao.fields['cita_wa_id'] = citaWaId;
    }
    final resposta = await _executar(() async => http.Response.fromStream(await requisicao.send()), limite: const Duration(minutes: 2));
    final dados = _decodificar(resposta);
    return (entregue: dados['gateway_ok'] != false, aviso: '${dados['message'] ?? ''}');
  }

  Future<({int total, List<Notificacao> itens})> notificacoes() async {
    final dados = await _get('/gestao/notificacoes/json');
    final itens = (dados['itens'] as List? ?? []).map((n) => Notificacao.deJson((n as Map).cast<String, dynamic>())).toList();
    return (total: (dados['count'] as num?)?.toInt() ?? itens.length, itens: itens);
  }

  Future<void> assumir(int conversaId) => _post('/sac/api/assumir/$conversaId');

  Future<void> encerrar(int conversaId) => _post('/sac/api/encerrar/$conversaId');

  Future<void> heartbeat() async {
    try {
      await _post('/sac/api/heartbeat');
    } catch (_) {}
  }

  String urlAbsoluta(String caminho) {
    if (caminho.startsWith('http')) {
      return caminho;
    }
    return '${_base ?? ''}/${caminho.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Map<String, String> get cabecalhosAutenticados => {'Authorization': 'Bearer ${_token ?? ''}'};

  Future<Map<String, dynamic>> _get(String caminho) async {
    final resposta = await _executar(() => http.get(Uri.parse('$_base$caminho'), headers: {...cabecalhosAutenticados, 'Accept': 'application/json'}));
    return _decodificar(resposta);
  }

  Future<Map<String, dynamic>> _post(String caminho, [Map<String, String>? campos]) async {
    final resposta = await _executar(
      () => http.post(Uri.parse('$_base$caminho'), headers: {...cabecalhosAutenticados, 'Accept': 'application/json'}, body: campos ?? const {}),
    );
    return _decodificar(resposta);
  }

  Future<http.Response> _executar(Future<http.Response> Function() chamada, {Duration limite = _timeout}) async {
    try {
      return await chamada().timeout(limite);
    } on SocketException {
      throw ApiException('Sem conexão com a internet.');
    } on HandshakeException {
      throw ApiException('Não foi possível estabelecer uma conexão segura com a empresa.');
    } on Exception {
      throw ApiException('O servidor da empresa não respondeu. Tente de novo.');
    }
  }

  Map<String, dynamic> _decodificar(http.Response resposta, {bool exigirSessao = true}) {
    Map<String, dynamic> dados;
    try {
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      dados = corpo is Map<String, dynamic> ? corpo : <String, dynamic>{};
    } catch (_) {
      dados = <String, dynamic>{};
    }
    if (resposta.statusCode == 401 && exigirSessao) {
      _esquecer();
      aoPerderAcesso?.call();
      throw ApiException('Seu acesso por este celular foi encerrado. Conecte de novo pelo painel.', 401);
    }
    if (resposta.statusCode >= 400 || dados['ok'] == false) {
      final erro = dados['error'];
      final detalhe = dados['message'];
      final texto = detalhe is String && detalhe.isNotEmpty ? detalhe : erro;
      throw ApiException(texto is String && texto.contains(' ') ? texto : 'Erro ${resposta.statusCode} no servidor.', resposta.statusCode);
    }
    return dados;
  }

  Future<String> _nomeDoAparelho() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ${a.model}';
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.name.isNotEmpty ? i.name : i.utsname.machine;
      }
    } catch (_) {}
    return 'Celular';
  }
}
