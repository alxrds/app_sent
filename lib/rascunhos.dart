import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Rascunhos {
  static const _storage = FlutterSecureStorage();
  static Future<void> _fila = Future.value();
  static String _chave(String escopo) => 'rascunho_${base64Url.encode(utf8.encode(escopo))}';

  static Future<Map<String, dynamic>> ler(String escopo) async {
    await _fila;
    final texto = await _storage.read(key: _chave(escopo));
    return texto == null ? {} : jsonDecode(texto) as Map<String, dynamic>;
  }

  static Future<void> salvar(String escopo, Map<String, dynamic> dados) {
    final json = jsonEncode(dados);
    _fila = _fila.catchError((_) {}).then((_) => _storage.write(key: _chave(escopo), value: json));
    return _fila;
  }
}
