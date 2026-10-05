import 'package:sent/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codigo = '0123456789abcdef0123456789abcdef0123456789abcdef';

  test('QR do painel vira base do escritório + código', () {
    final qr = EcoApi.lerQr('https://empresa.sent.app.br/app/conectar?c=$codigo');
    expect(qr, isNotNull);
    expect(qr!.base, 'https://empresa.sent.app.br');
    expect(qr.codigo, codigo);
  });

  test('instalação em subpasta mantém o prefixo', () {
    final qr = EcoApi.lerQr('https://exemplo.com.br/painel/app/conectar?c=$codigo');
    expect(qr?.base, 'https://exemplo.com.br/painel');
  });

  test('recusa QR que não é de conexão', () {
    expect(EcoApi.lerQr('http://empresa.sent.app.br/app/conectar?c=$codigo'), isNull);
    expect(EcoApi.lerQr('https://empresa.sent.app.br/outra/rota?c=$codigo'), isNull);
    expect(EcoApi.lerQr('https://empresa.sent.app.br/app/conectar?c=curto'), isNull);
    expect(EcoApi.lerQr('00020126580014BR.GOV.BCB.PIX'), isNull);
    expect(EcoApi.lerQr(''), isNull);
  });

  test('escritório digitado vira base https', () {
    expect(EcoApi.baseDoEscritorio('empresa'), 'https://empresa.sent.app.br');
    expect(EcoApi.baseDoEscritorio(' Segati.adv.br/ '), 'https://segati.adv.br');
    expect(EcoApi.baseDoEscritorio('https://exemplo.com.br/painel'), 'https://exemplo.com.br/painel');
    expect(EcoApi.baseDoEscritorio(''), isNull);
    expect(EcoApi.baseDoEscritorio('meu escritorio'), isNull);
  });

  test('código digitado ignora traço e caixa', () {
    expect(EcoApi.codigoDigitado('k7p2-9xmq'), 'K7P29XMQ');
    expect(EcoApi.codigoDigitado('K7P2 9XMQ'), 'K7P29XMQ');
    expect(EcoApi.codigoDigitado('K7P2-9XM'), isNull);
    expect(EcoApi.codigoDigitado('O1P2-9XMQ'), isNull);
  });
}
