import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'lembretes.dart';

class Push {
  Push._();

  static bool _iniciado = false;
  static bool _registrado = false;
  static StreamSubscription<String>? _renovacao;

  static bool get ativo => _registrado;

  static Future<bool> _iniciar() async {
    if (_iniciado) {
      return true;
    }
    const iosConfigurado = bool.fromEnvironment('IOS_PUSH_ENABLED');
    if (!Platform.isAndroid && !(Platform.isIOS && iosConfigurado)) {
      return false;
    }
    try {
      await Firebase.initializeApp();
    } catch (_) {
      return false;
    }
    _iniciado = true;
    FirebaseMessaging.onMessage.listen((mensagem) {
      final aviso = mensagem.notification;
      if (aviso == null) {
        return;
      }
      Lembretes.mostrar(
        aviso.title ?? '',
        aviso.body ?? '',
        payload: _destino(mensagem),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((mensagem) => Lembretes.toque.value = _destino(mensagem));
    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) {
      Lembretes.toque.value = _destino(inicial);
    }
    return true;
  }

  static Future<bool> registrar() async {
    if (_registrado) {
      return true;
    }
    if (!await _iniciar()) {
      return false;
    }
    try {
      if (Platform.isIOS) {
        final permissoes = await FirebaseMessaging.instance.requestPermission();
        if (permissoes.authorizationStatus == AuthorizationStatus.denied) {
          return false;
        }
        if (await FirebaseMessaging.instance.getAPNSToken() == null) {
          return false;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return false;
      }
      await EcoApi.instancia.registrarPush(token);
      _renovacao ??= FirebaseMessaging.instance.onTokenRefresh.listen((novo) => EcoApi.instancia.registrarPush(novo).catchError((_) {}));
      _registrado = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> esquecer() async {
    _registrado = false;
    await _renovacao?.cancel();
    _renovacao = null;
    if (_iniciado) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  static String? _destino(RemoteMessage mensagem) {
    final dados = mensagem.data;
    final titulo = (mensagem.notification?.title ?? '').replaceFirst('Chat interno · ', '');
    return switch (dados['tipo']) {
      'conversa' => 'conversa:${dados['conversa_id']}|$titulo',
      'interno' => 'interno:${dados['colega_id']}|$titulo',
      'tarefa' => 'tarefa:${dados['tarefa_id']}',
      _ => null,
    };
  }
}
