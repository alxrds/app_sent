import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key, required this.perfil, required this.aoSair});

  final Perfil perfil;
  final Future<void> Function() aoSair;

  Future<void> _confirmarSaida(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Desconectar este celular?'),
        content: const Text('Para entrar de novo, será preciso ler um novo QR Code no painel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Desconectar')),
        ],
      ),
    );
    if (confirmado == true) {
      await aoSair();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final u = perfil.usuario;
    final areas = [if (u.admin) 'Administrador(a)', if (u.sac) 'Atendimento'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [c.marca, Color.lerp(c.marca, Colors.black, .35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: c.marca.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              AvatarContato(
                nome: u.nome,
                fotoUrl: u.avatar ?? '',
                tamanho: 64,
                fundo: c.destaque,
                corTexto: Colors.white,
                anel: Colors.white.withValues(alpha: .6),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.nome,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(u.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in areas)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              a,
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Secao(
          titulo: 'Empresa',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              children: [
                LogoEscritorio(escritorio: perfil.escritorio, altura: 48),
                const SizedBox(height: 8),
                Text(perfil.escritorio.url.replaceFirst('https://', ''), style: TextStyle(color: c.textoSuave, fontSize: 12.5)),
              ],
            ),
          ),
        ),
        _Secao(
          titulo: 'Segurança',
          child: Column(
            children: [
              if (perfil.dispositivo != null)
                ListTile(leading: const Icon(Icons.smartphone), title: const Text('Este celular'), subtitle: Text(perfil.dispositivo!)),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Permissões'),
                subtitle: const Text('As mesmas do painel. Mudam na hora se o administrador alterar.'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: corCritica),
                title: const Text(
                  'Desconectar este celular',
                  style: TextStyle(color: corCritica, fontWeight: FontWeight.w600),
                ),
                onTap: () => _confirmarSaida(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, info) => Text(
              info.hasData ? 'Versão ${info.data!.version}' : '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: c.textoSuave),
            ),
          ),
          // Material (e não Container com cor) pra o toque do ListTile aparecer.
          Material(
            color: c.cartao,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: double.infinity, child: child),
          ),
        ],
      ),
    );
  }
}
