import 'package:sent/localizacao.dart';
import 'package:sent/texto_rico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dividirTexto', () {
    test('link no meio do texto vira trecho clicável sem a pontuação final', () {
      final t = dividirTexto('Reunião pelo zoom: https://zoom.us/j/123?pwd=abc. Até lá');
      expect(t.map((x) => x.texto).join(), 'Reunião pelo zoom: https://zoom.us/j/123?pwd=abc. Até lá');
      final link = t.firstWhere((x) => x.link != null);
      expect(link.texto, 'https://zoom.us/j/123?pwd=abc');
      expect(link.link, 'https://zoom.us/j/123?pwd=abc');
    });

    test('www e e-mail também abrem', () {
      final t = dividirTexto('veja www.segati.adv.br ou escreva para contato@segati.adv.br');
      final links = t.where((x) => x.link != null).map((x) => x.link).toList();
      expect(links, ['https://www.segati.adv.br', 'mailto:contato@segati.adv.br']);
    });

    test('negrito, itálico e riscado do WhatsApp', () {
      final t = dividirTexto('*Atenção*: prazo _amanhã_, valor ~R\$ 200~');
      expect(t.firstWhere((x) => x.negrito).texto, 'Atenção');
      expect(t.firstWhere((x) => x.italico).texto, 'amanhã');
      expect(t.firstWhere((x) => x.riscado).texto, r'R$ 200');
      expect(t.map((x) => x.texto).join(), r'Atenção: prazo amanhã, valor R$ 200');
    });

    test('asterisco e sublinhado dentro de palavra não formatam', () {
      final t = dividirTexto('arquivo_final_v2.pdf e 2*3*4');
      expect(t.every((x) => !x.negrito && !x.italico), isTrue);
      expect(t.map((x) => x.texto).join(), 'arquivo_final_v2.pdf e 2*3*4');
    });

    test('sublinhado dentro de link não vira itálico', () {
      final t = dividirTexto('https://site.com/a_b_c');
      expect(t.single.link, 'https://site.com/a_b_c');
    });
  });

  group('lerLocalizacao', () {
    test('só o ponto no mapa', () {
      final l = lerLocalizacao('https://maps.google.com/?q=-16.7872614,-49.2213207');
      expect(l.lugar, '');
      expect(l.latitude, -16.7872614);
      expect(l.longitude, -49.2213207);
    });

    test('lugar com nome e link', () {
      final l = lerLocalizacao('Fórum de Goiânia Rua 10\nhttps://maps.google.com/?q=-16.68,-49.25');
      expect(l.lugar, 'Fórum de Goiânia Rua 10');
      expect(l.latitude, -16.68);
    });

    test('mensagem antiga sem coordenada', () {
      final l = lerLocalizacao('');
      expect(l.latitude, isNull);
      expect(l.lugar, '');
    });
  });
}
