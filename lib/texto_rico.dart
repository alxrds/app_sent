import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _link = RegExp(r'''(https?://[^\s<>"']+|www\.[^\s<>"']+\.[^\s<>"']+|[\w.+-]+@[\w-]+\.[\w.-]+)''', caseSensitive: false);
final _formato = RegExp(r'(```[\s\S]+?```|\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~)');
final _pontuacaoFinal = RegExp(r'[.,;:!?)\]]+$');

typedef Trecho = ({String texto, String? link, bool negrito, bool italico, bool riscado, bool mono});

List<Trecho> dividirTexto(String texto) {
  final trechos = <Trecho>[];
  var inicio = 0;
  for (final m in _link.allMatches(texto)) {
    final bruto = m[0]!;
    final limpo = bruto.replaceFirst(_pontuacaoFinal, '');
    if (m.start > inicio) {
      trechos.addAll(_formatar(texto.substring(inicio, m.start)));
    }
    trechos.add((texto: limpo, link: _destino(limpo), negrito: false, italico: false, riscado: false, mono: false));
    inicio = m.start + limpo.length;
  }
  if (inicio < texto.length) {
    trechos.addAll(_formatar(texto.substring(inicio)));
  }
  return trechos;
}

String _destino(String link) {
  if (link.contains('@') && !link.contains('://')) {
    return 'mailto:$link';
  }
  return link.toLowerCase().startsWith('www.') ? 'https://$link' : link;
}

List<Trecho> _formatar(String texto) {
  final trechos = <Trecho>[];
  var inicio = 0;
  for (final m in _formato.allMatches(texto)) {
    final bruto = m[0]!;
    final antes = m.start == 0 ? '' : texto[m.start - 1];
    final depois = m.end >= texto.length ? '' : texto[m.end];
    if (!bruto.startsWith('```') && (RegExp(r'\w').hasMatch(antes) || RegExp(r'\w').hasMatch(depois))) {
      continue;
    }
    if (m.start > inicio) {
      trechos.add(_simples(texto.substring(inicio, m.start)));
    }
    final mono = bruto.startsWith('```');
    final miolo = mono ? bruto.substring(3, bruto.length - 3) : bruto.substring(1, bruto.length - 1);
    final marca = bruto[0];
    trechos.add((texto: miolo, link: null, negrito: marca == '*', italico: marca == '_', riscado: marca == '~', mono: mono));
    inicio = m.end;
  }
  if (inicio < texto.length) {
    trechos.add(_simples(texto.substring(inicio)));
  }
  return trechos;
}

Trecho _simples(String texto) => (texto: texto, link: null, negrito: false, italico: false, riscado: false, mono: false);

class TextoRico extends StatefulWidget {
  const TextoRico(this.texto, {super.key, this.corLink, this.estilo});

  final String texto;
  final Color? corLink;
  final TextStyle? estilo;

  @override
  State<TextoRico> createState() => _TextoRicoState();
}

class _TextoRicoState extends State<TextoRico> {
  final List<TapGestureRecognizer> _toques = [];

  @override
  void dispose() {
    _limpar();
    super.dispose();
  }

  void _limpar() {
    for (final t in _toques) {
      t.dispose();
    }
    _toques.clear();
  }

  Future<void> _abrir(String destino) async {
    final uri = Uri.tryParse(destino);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _limpar();
    final corLink = widget.corLink ?? Theme.of(context).colorScheme.primary;
    return Text.rich(
      TextSpan(
        style: widget.estilo,
        children: [
          for (final t in dividirTexto(widget.texto))
            if (t.link != null)
              TextSpan(
                text: t.texto,
                style: TextStyle(color: corLink, decoration: TextDecoration.underline, decorationColor: corLink),
                recognizer: (TapGestureRecognizer()..onTap = () => _abrir(t.link!)).also(_toques.add),
              )
            else
              TextSpan(
                text: t.texto,
                style: TextStyle(
                  fontWeight: t.negrito ? FontWeight.w700 : null,
                  fontStyle: t.italico ? FontStyle.italic : null,
                  decoration: t.riscado ? TextDecoration.lineThrough : null,
                  fontFamily: t.mono ? 'monospace' : null,
                ),
              ),
        ],
      ),
    );
  }
}

extension _Tambem<T> on T {
  T also(void Function(T) acao) {
    acao(this);
    return this;
  }
}
