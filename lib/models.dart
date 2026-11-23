import 'dart:ui';

DateTime? dataDoServidor(Object? valor) {
  final texto = valor?.toString() ?? '';
  if (texto.isEmpty) {
    return null;
  }
  return DateTime.tryParse('${texto.replaceFirst(' ', 'T')}-03:00')?.toLocal();
}

String telefoneFormatado(String telefone) {
  final m = RegExp(r'^55(\d{2})(\d{4,5})(\d{4})$').firstMatch(telefone.replaceAll(RegExp(r'\D'), ''));
  return m == null ? telefone : '+55 (${m[1]}) ${m[2]}-${m[3]}';
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String _texto(Object? v) => v == null ? '' : '$v';

Color? corHex(String hex) {
  final limpo = hex.replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(limpo)) {
    return null;
  }
  return Color(int.parse('FF$limpo', radix: 16));
}

class Escritorio {
  Escritorio({required this.nome, required this.url, required this.logo, required this.logoEscuro, this.corPrimaria, this.corSecundaria});

  factory Escritorio.deJson(Map<String, dynamic> j) => Escritorio(
    nome: _texto(j['nome']),
    url: _texto(j['url']),
    logo: _texto(j['logo']),
    logoEscuro: _texto(j['logo_escuro']),
    corPrimaria: corHex(_texto(j['cor_primaria'])),
    corSecundaria: corHex(_texto(j['cor_secundaria'])),
  );

  final String nome;
  final String url;
  final String logo;
  final String logoEscuro;
  final Color? corPrimaria;
  final Color? corSecundaria;
}

class Usuario {
  Usuario({
    required this.id,
    required this.nome,
    required this.apelido,
    required this.email,
    required this.admin,
    required this.avatar,
    required this.sac,
  });

  factory Usuario.deJson(Map<String, dynamic> j) {
    final areas = (j['areas'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Usuario(
      id: _int(j['id']),
      nome: _texto(j['nome']),
      apelido: _texto(j['apelido']),
      email: _texto(j['email']),
      admin: j['admin'] == true,
      avatar: j['avatar'] as String?,
      sac: areas['sac'] == true,
    );
  }

  final int id;
  final String nome;
  final String apelido;
  final String email;
  final bool admin;
  final String? avatar;
  final bool sac;

  String get exibicao => apelido.isNotEmpty ? apelido : nome;
}

class Perfil {
  Perfil({required this.usuario, required this.escritorio, required this.dispositivo});

  factory Perfil.deJson(Map<String, dynamic> j) => Perfil(
    usuario: Usuario.deJson((j['usuario'] as Map).cast<String, dynamic>()),
    escritorio: Escritorio.deJson((j['escritorio'] as Map).cast<String, dynamic>()),
    dispositivo: j['dispositivo'] as String?,
  );

  final Usuario usuario;
  final Escritorio escritorio;
  final String? dispositivo;
}

class Conversa {
  Conversa({
    required this.id,
    required this.interna,
    required this.status,
    required this.contatoNome,
    required this.telefone,
    required this.canal,
    required this.fotoUrl,
    required this.departamento,
    required this.atendenteNome,
    required this.naoLidas,
    required this.ultima,
    required this.ultimaEm,
  });

  factory Conversa.deJson(Map<String, dynamic> j) {
    final interna = _int(j['is_interno']) == 1 || j['is_interno'] == true;
    return Conversa(
      id: interna ? _int(j['contato_id']) : _int(j['id']),
      interna: interna,
      status: _texto(j['status']),
      contatoNome: _texto(j['contato_nome']).isNotEmpty ? _texto(j['contato_nome']) : _texto(j['telefone']),
      telefone: _texto(j['telefone']),
      canal: _texto(j['canal']).isNotEmpty ? _texto(j['canal']) : 'whatsapp',
      fotoUrl: _texto(j['foto_url']),
      departamento: _texto(j['departamento']),
      atendenteNome: _texto(j['atendente_nome']),
      naoLidas: _int(j['nao_lidas']),
      ultima: _texto(j['ultima']),
      ultimaEm: dataDoServidor(j['ultima_mensagem_em']),
    );
  }

  final int id;
  final bool interna;
  final String status;
  final String contatoNome;
  final String telefone;
  final String canal;
  final String fotoUrl;
  final String departamento;
  final String atendenteNome;
  final int naoLidas;
  final String ultima;
  final DateTime? ultimaEm;

  bool get encerrada => status == 'encerrada';
  bool get online => interna && status == 'online';
  bool get ausente => interna && status == 'ausente';
}

class ListaConversas {
  ListaConversas(this.conversas, this.temMais, this.filaTotal);

  final List<Conversa> conversas;
  final bool temMais;
  final int filaTotal;
}

class Mensagem {
  Mensagem({
    required this.id,
    required this.waMessageId,
    required this.direcao,
    required this.autor,
    required this.autorNome,
    required this.tipo,
    required this.conteudo,
    required this.midiaUrl,
    required this.midiaMime,
    required this.citaPrevia,
    required this.citaDe,
    required this.citaWaId,
    required this.transcricao,
    required this.interna,
    required this.apagada,
    required this.status,
    required this.criadoEm,
    this.reacao = '',
    this.editadaEm,
    this.textoOriginal,
    this.editadaPor,
    this.apagadaPor,
  });

  factory Mensagem.deJson(Map<String, dynamic> j) => Mensagem(
    id: _int(j['id']),
    waMessageId: _texto(j['wa_message_id']),
    direcao: _texto(j['direcao']),
    autor: _texto(j['autor']),
    autorNome: _texto(j['autor_nome']).isNotEmpty ? _texto(j['autor_nome']) : _texto(j['atendente_nome']),
    tipo: _texto(j['tipo']),
    conteudo: _texto(j['conteudo']),
    midiaUrl: _texto(j['midia_url']),
    midiaMime: _texto(j['midia_mime']),
    citaPrevia: _texto(j['cita_previa']),
    citaDe: _texto(j['cita_de']),
    citaWaId: _texto(j['cita_wa_id']),
    transcricao: _texto(j['transcricao']),
    interna: _int(j['interna']) == 1,
    apagada: j['apagada_em'] != null,
    status: _texto(j['status']),
    criadoEm: dataDoServidor(j['criado_em']),
    reacao: _texto(j['reacao']),
    editadaEm: dataDoServidor(j['editada_em']),
    textoOriginal: _texto(j['texto_original']).isNotEmpty ? _texto(j['texto_original']) : null,
    editadaPor: _texto(j['editada_por']).isNotEmpty ? _texto(j['editada_por']) : null,
    apagadaPor: _texto(j['apagada_por']).isNotEmpty ? _texto(j['apagada_por']) : null,
  );

  final int id;
  final String waMessageId;
  final String direcao;
  final String autor;
  final String autorNome;
  final String tipo;
  String conteudo;
  String midiaUrl;
  String midiaMime;
  final String citaPrevia;
  final String citaDe;
  final String citaWaId;
  String transcricao;
  final bool interna;
  bool apagada;
  String status;
  final DateTime? criadoEm;
  String reacao;
  DateTime? editadaEm;
  String? textoOriginal;
  String? editadaPor;
  String? apagadaPor;

  bool get editada => editadaEm != null;
  bool get enviada => direcao == 'saida';
  bool get evento => tipo == 'evento';

  String get resumo {
    if (conteudo.isNotEmpty) return conteudo;
    const rotulos = {'imagem': 'Imagem', 'audio': 'Áudio', 'video': 'Vídeo', 'documento': 'Documento', 'sticker': 'Figurinha'};
    return rotulos[tipo] ?? 'Mídia';
  }
}

class DetalheConversa {
  DetalheConversa({required this.conversa, required this.mensagens, this.atualizacoes = const {}});

  factory DetalheConversa.deJson(Map<String, dynamic> j) => DetalheConversa(
    conversa: Conversa.deJson((j['conversa'] as Map).cast<String, dynamic>()),
    mensagens: (j['mensagens'] as List? ?? []).map((m) => Mensagem.deJson((m as Map).cast<String, dynamic>())).toList(),
    atualizacoes: {
      for (final chave in const ['recentesStatus', 'midiaRecente', 'reacoesRecentes', 'apagadasRecentes', 'transcricoesRecentes'])
        chave: (j[chave] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(),
    },
  );

  final Conversa conversa;
  final List<Mensagem> mensagens;
  final Map<String, List<Map<String, dynamic>>> atualizacoes;

  bool aplicarEm(List<Mensagem> lista) {
    final porId = {for (final m in lista) m.id: m};
    final porWa = {for (final m in lista) if (m.waMessageId.isNotEmpty) m.waMessageId: m};
    var mudou = false;
    void trocar<T>(T atual, T novo, void Function(T) gravar) {
      if (atual != novo) {
        gravar(novo);
        mudou = true;
      }
    }

    for (final a in atualizacoes['recentesStatus'] ?? const <Map<String, dynamic>>[]) {
      final m = porWa[_texto(a['wa_message_id'])];
      if (m != null && _texto(a['status']).isNotEmpty) trocar(m.status, _texto(a['status']), (v) => m.status = v);
    }
    for (final a in atualizacoes['midiaRecente'] ?? const <Map<String, dynamic>>[]) {
      final m = porId[_int(a['id'])];
      if (m == null) continue;
      trocar(m.midiaUrl, _texto(a['midia_url']), (v) => m.midiaUrl = v);
      trocar(m.midiaMime, _texto(a['midia_mime']), (v) => m.midiaMime = v);
      if (_texto(a['status']).isNotEmpty) trocar(m.status, _texto(a['status']), (v) => m.status = v);
    }
    for (final a in atualizacoes['reacoesRecentes'] ?? const <Map<String, dynamic>>[]) {
      final m = porId[_int(a['id'])];
      if (m != null) trocar(m.reacao, _texto(a['reacao']), (v) => m.reacao = v);
    }
    for (final a in atualizacoes['apagadasRecentes'] ?? const <Map<String, dynamic>>[]) {
      final m = porId[_int(a['id'])];
      if (m != null) trocar(m.apagada, true, (v) => m.apagada = v);
    }
    for (final a in atualizacoes['transcricoesRecentes'] ?? const <Map<String, dynamic>>[]) {
      final m = porId[_int(a['id'])];
      if (m != null && _texto(a['transcricao']).isNotEmpty) trocar(m.transcricao, _texto(a['transcricao']), (v) => m.transcricao = v);
    }
    return mudou;
  }
}

class Opcao {
  Opcao({required this.id, required this.nome});

  factory Opcao.deJson(Map<String, dynamic> j) => Opcao(id: _int(j['id']), nome: _texto(j['nome']));

  final int id;
  final String nome;
}

class RespostaRapida {
  RespostaRapida({required this.titulo, required this.atalho, required this.conteudo});

  factory RespostaRapida.deJson(Map<String, dynamic> j) =>
      RespostaRapida(titulo: _texto(j['titulo']), atalho: _texto(j['atalho']), conteudo: _texto(j['conteudo']));

  final String titulo;
  final String atalho;
  final String conteudo;

  bool combina(String termo) => '$titulo $atalho $conteudo'.toLowerCase().contains(termo.toLowerCase());
}

class Notificacao {
  Notificacao({
    required this.tipo,
    required this.titulo,
    required this.sub,
    required this.quando,
    required this.atrasada,
    required this.conversaId,
    required this.colegaId,
  });

  factory Notificacao.deJson(Map<String, dynamic> j) {
    final alvo = Uri.tryParse(_texto(j['url']))?.queryParameters['c'] ?? '';
    return Notificacao(
      tipo: _texto(j['tipo']),
      titulo: _texto(j['titulo']),
      sub: _texto(j['sub']),
      quando: dataDoServidor(j['quando']),
      atrasada: j['atrasada'] == true,
      conversaId: alvo.startsWith('int_') ? null : int.tryParse(alvo),
      colegaId: alvo.startsWith('int_') ? int.tryParse(alvo.substring(4)) : null,
    );
  }

  final String tipo;
  final String titulo;
  final String sub;
  final DateTime? quando;
  final bool atrasada;
  final int? conversaId;
  final int? colegaId;
}

DateTime? horarioDaAgenda(Object? valor) => DateTime.tryParse(_texto(valor).replaceFirst(' ', 'T'));

class OpcaoAgenda {
  OpcaoAgenda({required this.id, required this.nome, this.duracaoMin = 0});

  factory OpcaoAgenda.deJson(Map<String, dynamic> j) => OpcaoAgenda(id: _int(j['id']), nome: _texto(j['nome']), duracaoMin: _int(j['duracao_min']));

  final int id;
  final String nome;
  final int duracaoMin;
}

class Agendamento {
  Agendamento({
    required this.id,
    required this.contatoId,
    required this.conversaId,
    required this.contato,
    required this.telefone,
    required this.servicos,
    required this.servicoIds,
    required this.profissionalId,
    required this.profissional,
    required this.responsavelIds,
    required this.responsaveis,
    required this.inicio,
    required this.fim,
    required this.local,
    required this.observacoes,
    required this.situacao,
    required this.situacaoNome,
    required this.origem,
    required this.serieId,
    required this.serie,
  });

  factory Agendamento.deJson(Map<String, dynamic> j) => Agendamento(
    id: _int(j['id']),
    contatoId: _int(j['contato_id']),
    conversaId: _int(j['conversa_id']),
    contato: _texto(j['contato']),
    telefone: _texto(j['telefone']),
    servicos: _texto(j['servicos']),
    servicoIds: [for (final s in (j['servico_ids'] as List? ?? const [])) _int(s)],
    profissionalId: _int(j['profissional_id']),
    profissional: _texto(j['profissional']),
    responsavelIds: [for (final r in (j['responsavel_ids'] as List? ?? const [])) _int(r)],
    responsaveis: _texto(j['responsaveis']).isNotEmpty ? _texto(j['responsaveis']) : _texto(j['profissional']),
    inicio: horarioDaAgenda(j['inicio']) ?? DateTime.now(),
    fim: horarioDaAgenda(j['fim']) ?? DateTime.now(),
    local: _texto(j['local']),
    observacoes: _texto(j['observacoes']),
    situacao: _texto(j['situacao']),
    situacaoNome: _texto(j['situacao_nome']),
    origem: _texto(j['origem']),
    serieId: _int(j['serie_id']),
    serie: _texto(j['serie']),
  );

  final int id;
  final int contatoId;
  final int conversaId;
  final String contato;
  final String telefone;
  final String servicos;
  final List<int> servicoIds;
  final int profissionalId;
  final String profissional;
  final List<int> responsavelIds;
  final String responsaveis;
  final DateTime inicio;
  final DateTime fim;
  final String local;
  final String observacoes;
  final String situacao;
  final String situacaoNome;
  final String origem;
  final int serieId;
  final String serie;

  bool get naSerie => serieId > 0;
  bool get preReserva => situacao == 'pre_reserva';
  bool get encerrado => situacao == 'cancelado' || situacao == 'faltou';
}

class Bloqueio {
  Bloqueio({required this.titulo, required this.inicio, required this.fim, required this.responsavel});

  factory Bloqueio.deJson(Map<String, dynamic> j) {
    final dia = _texto(j['data']);
    return Bloqueio(
      titulo: _texto(j['titulo']),
      inicio: DateTime.tryParse('${dia}T${_texto(j['inicio'])}') ?? DateTime.now(),
      fim: DateTime.tryParse('${dia}T${_texto(j['fim'])}') ?? DateTime.now(),
      responsavel: _texto(j['profissional_nome']),
    );
  }

  final String titulo;
  final DateTime inicio;
  final DateTime fim;
  final String responsavel;
}

class PreReserva {
  PreReserva({required this.id, required this.inicio, required this.contato, required this.servicos});

  factory PreReserva.deJson(Map<String, dynamic> j) => PreReserva(
    id: _int(j['id']),
    inicio: horarioDaAgenda(j['inicio']) ?? DateTime.now(),
    contato: _texto(j['contato']),
    servicos: _texto(j['servicos']),
  );

  final int id;
  final DateTime inicio;
  final String contato;
  final String servicos;
}

class DadosDaAgenda {
  DadosDaAgenda({
    required this.agendamentos,
    required this.bloqueios,
    required this.preReservas,
    required this.servicos,
    required this.profissionais,
    required this.responsaveis,
    required this.situacoes,
    required this.repeticoes,
  });

  factory DadosDaAgenda.deJson(Map<String, dynamic> j) {
    Map<String, String> mapa(Object? v) => v is Map ? {for (final e in v.entries) '${e.key}': _texto(e.value)} : const {};
    List<Map<String, dynamic>> lista(Object? v) => [for (final i in (v as List? ?? const [])) if (i is Map<String, dynamic>) i];
    return DadosDaAgenda(
      agendamentos: [for (final a in lista(j['agendamentos'])) Agendamento.deJson(a)],
      bloqueios: [for (final b in lista(j['indisponiveis'])) Bloqueio.deJson(b)],
      preReservas: [for (final p in lista(j['pre_reservas'])) PreReserva.deJson(p)],
      servicos: [for (final s in lista(j['servicos'])) OpcaoAgenda.deJson(s)],
      profissionais: [for (final p in lista(j['profissionais'])) OpcaoAgenda.deJson(p)],
      responsaveis: [for (final p in lista(j['responsaveis'])) OpcaoAgenda.deJson(p)],
      situacoes: mapa(j['situacoes']),
      repeticoes: mapa(j['repeticoes']),
    );
  }

  final List<Agendamento> agendamentos;
  final List<Bloqueio> bloqueios;
  final List<PreReserva> preReservas;
  final List<OpcaoAgenda> servicos;
  final List<OpcaoAgenda> profissionais;
  final List<OpcaoAgenda> responsaveis;
  final Map<String, String> situacoes;
  final Map<String, String> repeticoes;
}

class ContatoDaAgenda {
  ContatoDaAgenda({required this.contatoId, required this.conversaId, required this.nome, required this.telefone});

  factory ContatoDaAgenda.deJson(Map<String, dynamic> j) => ContatoDaAgenda(
    contatoId: _int(j['contato_id']),
    conversaId: _int(j['conversa_id']),
    nome: _texto(j['nome']),
    telefone: _texto(j['telefone']),
  );

  final int contatoId;
  final int conversaId;
  final String nome;
  final String telefone;
}
