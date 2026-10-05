import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Lembretes {
  Lembretes._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final toque = ValueNotifier<String?>(null);
  static bool _pronto = false;

  static const _corMarca = Color(0xFF3D8FD1);
  static const _canalMensagens = AndroidNotificationChannel(
    'mensagens',
    'Mensagens',
    description: 'Mensagens de clientes, transferências e chat interno da equipe',
    importance: Importance.high,
  );

  static NotificationDetails _detalhesDo(AndroidNotificationChannel canal) => NotificationDetails(
    android: AndroidNotificationDetails(
      canal.id,
      canal.name,
      channelDescription: canal.description,
      importance: Importance.high,
      priority: Priority.high,
      color: _corMarca,
    ),
    iOS: const DarwinNotificationDetails(presentSound: true),
  );

  static Future<void> iniciar() async {
    if (_pronto) {
      return;
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notificacao'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (resposta) => toque.value = resposta.payload,
    );
    final android = Platform.isAndroid ? _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>() : null;
    await android?.createNotificationChannel(_canalMensagens);
    final abertura = await _plugin.getNotificationAppLaunchDetails();
    if (abertura?.didNotificationLaunchApp == true) {
      toque.value = abertura!.notificationResponse?.payload;
    }
    _pronto = true;
  }

  static Future<void> pedirPermissao() async {
    await iniciar();
    if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> mostrar(String titulo, String corpo, {String? payload}) async {
    await iniciar();
    await _plugin.show(
      1000000000 + DateTime.now().millisecondsSinceEpoch % 100000000,
      titulo,
      corpo,
      _detalhesDo(_canalMensagens),
      payload: payload,
    );
  }

  static Future<void> limpar() async {
    if (_pronto) {
      await _plugin.cancelAll();
    }
  }
}
