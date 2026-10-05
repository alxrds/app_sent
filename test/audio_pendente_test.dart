import 'dart:io';

import 'package:sent/audio_pendente.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('falha preserva a gravação; aceite do servidor libera o arquivo', () async {
    final dir = await Directory.systemTemp.createTemp('audio-test');
    try {
      final audio = await File('${dir.path}/teste.m4a').writeAsBytes([1, 2, 3]);
      await expectLater(enviarAudioPreservado(audio, (_) async => throw const SocketException('offline')), throwsA(isA<SocketException>()));
      expect(await audio.readAsBytes(), [1, 2, 3]);
      final aceitoComGatewayPendente = await enviarAudioPreservado(audio, (_) async => false);
      expect(aceitoComGatewayPendente, false);
      expect(await audio.exists(), false);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
