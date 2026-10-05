import 'package:sent/rascunhos.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('rascunhos isolados por escritório, usuário e conversa', () async {
    await Rascunhos.salvar('escritorio-a|1|false|10', {'texto': 'Cliente A', 'nota': true, 'audio': '/audio.m4a'});
    expect(await Rascunhos.ler('escritorio-b|1|false|10'), isEmpty);
    expect(await Rascunhos.ler('escritorio-a|2|false|10'), isEmpty);
    expect(await Rascunhos.ler('escritorio-a|1|true|10'), isEmpty);
    expect((await Rascunhos.ler('escritorio-a|1|false|10'))['audio'], '/audio.m4a');
    expect((await Rascunhos.ler('escritorio-a|1|false|10'))['nota'], true);
  });

  test('salvamentos concorrentes preservam a última edição e a limpeza', () async {
    await Future.wait([
      Rascunhos.salvar('a', {'texto': 'primeiro'}),
      Rascunhos.salvar('a', {'texto': 'último'}),
    ]);
    expect((await Rascunhos.ler('a'))['texto'], 'último');
    await Rascunhos.salvar('a', {'texto': '', 'nota': false, 'audio': null});
    expect((await Rascunhos.ler('a'))['texto'], '');
  });
}
