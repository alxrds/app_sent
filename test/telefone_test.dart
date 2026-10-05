import 'package:sent/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata celular e fixo brasileiros', () {
    expect(telefoneFormatado('5562900000001'), '+55 (62) 90000-0001');
    expect(telefoneFormatado('556232120000'), '+55 (62) 3212-0000');
  });

  test('mantém o que não reconhece', () {
    expect(telefoneFormatado('269449168965694@lid'), '269449168965694@lid');
    expect(telefoneFormatado(''), '');
  });
}
