import 'dart:io';

final _coordenadas = RegExp(r'https?://\S*?[?&](?:q|ll)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\S*');

typedef Localizacao = ({String lugar, double? latitude, double? longitude});

Localizacao lerLocalizacao(String conteudo) {
  final m = _coordenadas.firstMatch(conteudo);
  final lugar = conteudo.replaceAll(_coordenadas, '').trim();
  if (m == null) {
    return (lugar: lugar, latitude: null, longitude: null);
  }
  return (lugar: lugar, latitude: double.tryParse(m[1]!), longitude: double.tryParse(m[2]!));
}

List<Uri> enderecosDoMapa(Localizacao l) {
  final ponto = '${l.latitude},${l.longitude}';
  final rotulo = l.lugar.isEmpty ? 'Localização do cliente' : l.lugar.replaceAll('\n', ' ');
  final google = Uri.https('maps.google.com', '/', {'q': ponto});
  if (Platform.isIOS) {
    return [Uri.https('maps.apple.com', '/', {'ll': ponto, 'q': rotulo}), google];
  }
  return [Uri.parse('geo:$ponto?q=$ponto(${Uri.encodeComponent(rotulo)})'), google];
}
