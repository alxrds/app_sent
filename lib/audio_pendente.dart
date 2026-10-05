import 'dart:io';

Future<T> enviarAudioPreservado<T>(File arquivo, Future<T> Function(List<int> bytes) enviar) async {
  final resultado = await enviar(await arquivo.readAsBytes());
  try {
    await arquivo.delete();
  } on FileSystemException {
    return resultado;
  }
  return resultado;
}
