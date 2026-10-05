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
  );

  final int id;
  final String waMessageId;
  final String direcao;
  final String autor;
  final String autorNome;
  final String tipo;
  final String conteudo;
  final String midiaUrl;
  final String midiaMime;
  final String citaPrevia;
  final String citaDe;
  final String citaWaId;
  final String transcricao;
  final bool interna;
  final bool apagada;
  final String status;
  final DateTime? criadoEm;

  bool get enviada => direcao == 'saida';
  bool get evento => tipo == 'evento';

  String get resumo {
    if (conteudo.isNotEmpty) return conteudo;
    const rotulos = {'imagem': 'Imagem', 'audio': 'Áudio', 'video': 'Vídeo', 'documento': 'Documento', 'sticker': 'Figurinha'};
    return rotulos[tipo] ?? 'Mídia';
  }
}

class DetalheConversa {
  DetalheConversa({required this.conversa, required this.mensagens});

  factory DetalheConversa.deJson(Map<String, dynamic> j) => DetalheConversa(
    conversa: Conversa.deJson((j['conversa'] as Map).cast<String, dynamic>()),
    mensagens: (j['mensagens'] as List? ?? []).map((m) => Mensagem.deJson((m as Map).cast<String, dynamic>())).toList(),
  );

  final Conversa conversa;
  final List<Mensagem> mensagens;
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
