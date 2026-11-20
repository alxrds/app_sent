import 'package:sent/models.dart';
import 'package:sent/screens/agenda_screen.dart';
import 'package:sent/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _json = <String, dynamic>{
  'ok': true,
  'agendamentos': [
    {
      'id': 103,
      'contato_id': 36,
      'conversa_id': 12,
      'contato': 'Beatriz Nunes',
      'telefone': '55629000009909',
      'servicos': 'Avaliação + Retorno',
      'servico_ids': [2, 3],
      'profissional_id': 5,
      'profissional': 'Mariana Souza',
      'inicio': '2026-11-16 07:00:00',
      'fim': '2026-11-16 07:40:00',
      'local': 'Rua das Flores, 120',
      'observacoes': 'Trazer exames',
      'situacao': 'pre_reserva',
      'situacao_nome': 'Pré-reserva',
      'origem': 'ia',
      'serie_id': 6,
      'serie': 'Toda semana, 6 vezes',
    },
    {
      'id': 104,
      'contato_id': 37,
      'conversa_id': 0,
      'contato': 'Roberto Lima com um nome bem comprido para testar',
      'telefone': '',
      'servicos': '',
      'servico_ids': [],
      'profissional_id': 0,
      'profissional': '',
      'inicio': '2026-11-16 10:00:00',
      'fim': '2026-11-16 11:00:00',
      'local': '',
      'observacoes': '',
      'situacao': 'cancelado',
      'situacao_nome': 'Cancelado',
      'origem': 'equipe',
      'serie_id': 0,
      'serie': '',
    },
  ],
  'pre_reservas': [
    {'id': 103, 'inicio': '2026-11-16 07:00:00', 'contato': 'Beatriz Nunes', 'servicos': 'Avaliação'},
  ],
  'servicos': [
    {'id': 1, 'nome': 'Atendimento', 'duracao_min': 60},
    {'id': 2, 'nome': 'Avaliação', 'duracao_min': 30},
    {'id': 3, 'nome': 'Retorno', 'duracao_min': 30},
    {'id': 4, 'nome': 'Visita técnica', 'duracao_min': 90},
  ],
  'profissionais': [
    {'id': 5, 'nome': 'Mariana Souza'},
  ],
  'situacoes': {'pre_reserva': 'Pré-reserva', 'confirmado': 'Confirmado', 'concluido': 'Concluído', 'cancelado': 'Cancelado', 'faltou': 'Faltou'},
  'repeticoes': {'nao': 'Não repete', 'semanal': 'Toda semana', 'quinzenal': 'A cada 2 semanas', 'mensal': 'Todo mês'},
};

Perfil _perfil() => Perfil.deJson({
  'usuario': {'id': 1, 'nome': 'Teste', 'admin': true, 'sac': true},
  'escritorio': {'nome': 'Demo', 'url': 'https://demo.sent.app.br'},
});

Widget _app(Widget filho) => MaterialApp(
  theme: temaEco(Brightness.light),
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: filho,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('lê a agenda como o servidor manda', () {
    final dados = DadosDaAgenda.deJson(_json);
    expect(dados.agendamentos.length, 2);
    final a = dados.agendamentos.first;
    expect(a.inicio, DateTime(2026, 11, 16, 7));
    expect(a.servicoIds, [2, 3]);
    expect(a.naSerie, isTrue);
    expect(a.preReserva, isTrue);
    expect(dados.agendamentos.last.encerrado, isTrue);
    expect(dados.repeticoes['quinzenal'], 'A cada 2 semanas');
    expect(dados.preReservas.single.id, 103);
  });

  testWidgets('detalhe cabe no celular', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dados = DadosDaAgenda.deJson(_json);
    await tester.pumpWidget(_app(Scaffold(body: DetalheDoAgendamento(agendamento: dados.agendamentos.first, perfil: _perfil(), dados: dados))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar horário'), findsOneWidget);
    expect(find.text('Toda semana, 6 vezes'), findsOneWidget);
  });

  testWidgets('formulário cabe no celular e mostra a repetição', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dados = DadosDaAgenda.deJson(_json);
    await tester.pumpWidget(_app(FormularioDeAgendamento(dados: dados, dataInicial: DateTime(2026, 11, 16))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não repete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toda semana').last);
    await tester.pumpAndSettle();
    expect(find.text('Até uma data'), findsOneWidget);
  });

  testWidgets('editar horário da série pergunta só este ou próximos', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dados = DadosDaAgenda.deJson(_json);
    await tester.pumpWidget(_app(FormularioDeAgendamento(dados: dados, agendamento: dados.agendamentos.first)));
    await tester.pumpAndSettle();
    expect(find.text('Este e os próximos'), findsOneWidget);
    expect(find.text('Beatriz Nunes'), findsOneWidget);
  });
}
