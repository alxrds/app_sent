import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';
import 'leitor_qr_screen.dart';

class ConectarScreen extends StatefulWidget {
  const ConectarScreen({super.key, required this.aoConectar});

  final void Function(Perfil perfil) aoConectar;

  @override
  State<ConectarScreen> createState() => _ConectarScreenState();
}

class _ConectarScreenState extends State<ConectarScreen> {
  bool _conectando = false;

  Future<void> _lerQr() async {
    final conteudo = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const LeitorQrScreen()));
    if (conteudo == null || !mounted) {
      return;
    }
    final qr = EcoApi.lerQr(conteudo);
    if (qr == null) {
      mostrarAviso(context, 'Este QR Code não é de conexão do Sent.');
      return;
    }
    await _conectar(qr.base, qr.codigo);
  }

  Future<void> _digitarCodigo() async {
    final digitado = await showModalBottomSheet<({String base, String codigo})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormularioCodigo(),
    );
    if (digitado == null || !mounted) {
      return;
    }
    await _conectar(digitado.base, digitado.codigo);
  }

  Future<void> _conectar(String base, String codigo) async {
    setState(() => _conectando = true);
    try {
      final perfil = await EcoApi.instancia.parear(base, codigo);
      widget.aoConectar(perfil);
    } on ApiException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.mensagem);
      }
    } finally {
      if (mounted) {
        setState(() => _conectando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoProduto()),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Conecte este celular à sua conta', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          const _Passo(numero: 1, texto: 'No computador, entre no painel do Sent.'),
                          const _Passo(numero: 2, texto: 'Abra Meu perfil → Aplicativo no celular → Gerar código.'),
                          const _Passo(numero: 3, texto: 'Leia o QR Code com a câmera ou digite o código que aparece embaixo dele.'),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _conectando ? null : _lerQr,
                            icon: _conectando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.qr_code_scanner),
                            label: Text(_conectando ? 'Conectando...' : 'Ler QR Code'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _conectando ? null : _digitarCodigo,
                            icon: const Icon(Icons.keyboard_outlined),
                            label: const Text('Digitar código'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Você entra com as mesmas permissões que tem no painel. O código vale por 2 minutos e só uma vez.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: cores.primaryContainer,
            child: Text('$numero', style: TextStyle(fontSize: 12, color: cores.onPrimaryContainer)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _FormularioCodigo extends StatefulWidget {
  const _FormularioCodigo();

  @override
  State<_FormularioCodigo> createState() => _FormularioCodigoState();
}

class _FormularioCodigoState extends State<_FormularioCodigo> {
  final _escritorio = TextEditingController();
  final _codigo = TextEditingController();
  String? _erroEscritorio;
  String? _erroCodigo;

  @override
  void dispose() {
    _escritorio.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final base = EcoApi.baseDoEscritorio(_escritorio.text);
    final codigo = EcoApi.codigoDigitado(_codigo.text);
    setState(() {
      _erroEscritorio = base == null ? 'Digite o endereço que aparece no painel.' : null;
      _erroCodigo = codigo == null ? 'O código tem 8 letras e números.' : null;
    });
    if (base != null && codigo != null) {
      Navigator.of(context).pop((base: base, codigo: codigo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Digitar código', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Use a empresa e o código que aparecem embaixo do QR no painel.', style: tema.textTheme.bodySmall),
          const SizedBox(height: 18),
          TextField(
            controller: _escritorio,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Empresa', hintText: 'ex.: suaempresa.sent.app.br', errorText: _erroEscritorio),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmar(),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18),
            decoration: InputDecoration(labelText: 'Código', hintText: 'XXXX-XXXX', errorText: _erroCodigo),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _confirmar, child: const Text('Conectar')),
        ],
      ),
    );
  }
}
