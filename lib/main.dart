import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';

import 'api.dart';
import 'lembretes.dart';
import 'models.dart';
import 'push.dart';
import 'screens/conectar_screen.dart';
import 'screens/inicio_screen.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([initializeDateFormatting('pt_BR'), TelaCarregando.prepararImagens()]);
  runApp(const EcoApp());
}

enum _Etapa { carregando, desconectado, bloqueado, pronto, erro }

class EcoApp extends StatefulWidget {
  const EcoApp({super.key});

  @override
  State<EcoApp> createState() => _EcoAppState();
}

class _EcoAppState extends State<EcoApp> with WidgetsBindingObserver {
  static const _tempoParaBloquear = Duration(minutes: 1);

  final _api = EcoApi.instancia;
  final _biometria = LocalAuthentication();
  final _navegador = GlobalKey<NavigatorState>();
  final _mensageiro = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _links;
  bool _iniciado = false;
  Uri? _linkPendente;
  String? _codigoProcessado;

  _Etapa _etapa = _Etapa.carregando;
  Perfil? _perfil;
  String _erro = '';
  DateTime? _foiParaSegundoPlano;
  bool _desbloqueando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api.aoPerderAcesso = () {
      _navegador.currentState?.popUntil((rota) => rota.isFirst);
      if (mounted) {
        setState(() {
          _perfil = null;
          _etapa = _Etapa.desconectado;
        });
      }
    };
    _links = AppLinks().uriLinkStream.listen(_linkRecebido);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_modoTema == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.paused) {
      _foiParaSegundoPlano = DateTime.now();
    } else if (estado == AppLifecycleState.resumed) {
      final desde = _foiParaSegundoPlano;
      _foiParaSegundoPlano = null;
      if (_etapa == _Etapa.pronto && desde != null && DateTime.now().difference(desde) > _tempoParaBloquear) {
        setState(() => _etapa = _Etapa.bloqueado);
        _desbloquear();
      }
    }
  }

  static const _armazenamento = FlutterSecureStorage();
  ThemeMode _modoTema = ThemeMode.system;

  bool get _escuroEfetivo =>
      _modoTema == ThemeMode.dark || (_modoTema == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  Future<void> _definirTema(ThemeMode modo) async {
    setState(() => _modoTema = modo);
    await _armazenamento.write(key: 'tema', value: modo.name);
  }

  Future<void> _iniciar() async {
    final temaSalvo = await _armazenamento.read(key: 'tema');
    _modoTema = ThemeMode.values.firstWhere((m) => m.name == temaSalvo, orElse: () => ThemeMode.system);
    await Future.wait([_api.carregar(), TelaCarregando.aberturaConcluida]);
    _iniciado = true;
    final pendente = _linkPendente;
    _linkPendente = null;
    if (!_api.conectado) {
      setState(() => _etapa = _Etapa.desconectado);
      if (pendente != null) {
        _processarLink(pendente);
      }
      return;
    }
    if (pendente != null) {
      _processarLink(pendente);
    }
    setState(() => _etapa = _Etapa.bloqueado);
    await _desbloquear();
  }

  void _linkRecebido(Uri link) {
    if (!_iniciado) {
      _linkPendente = link;
      return;
    }
    _processarLink(link);
  }

  Future<void> _processarLink(Uri link) async {
    final qr = EcoApi.lerQr(link.toString());
    if (qr == null || qr.codigo == _codigoProcessado) {
      return;
    }
    _codigoProcessado = qr.codigo;
    if (_api.conectado) {
      _avisar('Este celular já está conectado a uma conta. Para trocar, desconecte em Perfil.');
      return;
    }
    setState(() => _etapa = _Etapa.carregando);
    try {
      _conectado(await _api.parear(qr.base, qr.codigo));
    } on ApiException catch (e) {
      setState(() => _etapa = _Etapa.desconectado);
      _avisar(e.mensagem);
    }
  }

  void _avisar(String texto) {
    _mensageiro.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
  }

  Future<void> _desbloquear() async {
    if (_desbloqueando) {
      return;
    }
    _desbloqueando = true;
    try {
      var liberado = true;
      if (await _biometria.isDeviceSupported()) {
        try {
          liberado = await _biometria.authenticate(localizedReason: 'Desbloqueie para abrir o Sent');
        } on LocalAuthException catch (e) {
          liberado = e.code == LocalAuthExceptionCode.noCredentialsSet || e.code == LocalAuthExceptionCode.noBiometricHardware;
        }
      }
      if (!liberado || !mounted) {
        return;
      }
      if (_perfil == null) {
        await _carregarPerfil();
      } else {
        setState(() => _etapa = _Etapa.pronto);
      }
    } finally {
      _desbloqueando = false;
    }
  }

  Future<void> _carregarPerfil() async {
    setState(() => _etapa = _Etapa.carregando);
    try {
      final perfil = await _api.eu();
      setState(() {
        _perfil = perfil;
        _etapa = _Etapa.pronto;
      });
    } on ApiException catch (e) {
      if (!_api.conectado) {
        setState(() => _etapa = _Etapa.desconectado);
        return;
      }
      setState(() {
        _erro = e.mensagem;
        _etapa = _Etapa.erro;
      });
    }
  }

  void _conectado(Perfil perfil) {
    setState(() {
      _perfil = perfil;
      _etapa = _Etapa.pronto;
    });
  }

  Future<void> _sair() async {
    await Lembretes.limpar();
    await Push.esquecer();
    await _api.sair();
    setState(() {
      _perfil = null;
      _etapa = _Etapa.desconectado;
    });
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = _perfil?.escritorio;
    return MaterialApp(
      title: 'Sent',
      navigatorKey: _navegador,
      scaffoldMessengerKey: _mensageiro,
      debugShowCheckedModeBanner: false,
      theme: temaEco(Brightness.light, primaria: escritorio?.corPrimaria, destaque: escritorio?.corSecundaria),
      darkTheme: temaEco(Brightness.dark, primaria: escritorio?.corPrimaria, destaque: escritorio?.corSecundaria),
      themeMode: _modoTema,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: switch (_etapa) {
        _Etapa.carregando => const TelaCarregando(),
        _Etapa.desconectado => ConectarScreen(aoConectar: _conectado),
        _Etapa.bloqueado => TelaBloqueio(aoDesbloquear: _desbloquear),
        _Etapa.erro => TelaErro(mensagem: _erro, aoTentarDeNovo: _carregarPerfil, aoSair: _sair),
        _Etapa.pronto => InicioScreen(perfil: _perfil!, aoSair: _sair, escuro: _escuroEfetivo, aoDefinirTema: _definirTema),
      },
    );
  }
}
