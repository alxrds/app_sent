import 'package:flutter/material.dart';

const corMarcaPadrao = Color(0xFF3D8FD1);
const corDestaquePadrao = Color(0xFF54A9EB);
const corOk = Color(0xFF1F9D6B);
const corAlerta = Color(0xFFE08A1E);
const corCritica = Color(0xFFC6483B);

class CoresEco extends ThemeExtension<CoresEco> {
  const CoresEco({
    required this.marca,
    required this.destaque,
    required this.fundo,
    required this.cartao,
    required this.linha,
    required this.textoSuave,
    required this.balaoEnviado,
    required this.balaoRecebido,
    required this.balaoBot,
    required this.nota,
  });

  final Color marca;
  final Color destaque;
  final Color fundo;
  final Color cartao;
  final Color linha;
  final Color textoSuave;
  final Color balaoEnviado;
  final Color balaoRecebido;
  final Color balaoBot;
  final Color nota;

  @override
  CoresEco copyWith() => this;

  @override
  CoresEco lerp(ThemeExtension<CoresEco>? outro, double t) => this;
}

extension TemaEco on BuildContext {
  CoresEco get cores => Theme.of(this).extension<CoresEco>()!;
}

ThemeData temaEco(Brightness brilho, {Color? primaria, Color? destaque}) {
  final escuro = brilho == Brightness.dark;
  final marca = primaria ?? corMarcaPadrao;
  final ouro = destaque ?? corDestaquePadrao;
  final marcaVisivel = escuro ? Color.lerp(marca, Colors.white, .5)! : marca;
  final fundo = escuro ? const Color(0xFF0E1621) : const Color(0xFFF3F5F8);
  final cartao = escuro ? const Color(0xFF17212B) : Colors.white;
  final linha = escuro ? const Color(0xFF223140) : const Color(0xFFE6ECF1);
  final esquema = ColorScheme.fromSeed(seedColor: marca, brightness: brilho, primary: marcaVisivel, secondary: ouro, surface: cartao);

  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    scaffoldBackgroundColor: fundo,
    dividerColor: linha,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      CoresEco(
        marca: marca,
        destaque: ouro,
        fundo: fundo,
        cartao: cartao,
        linha: linha,
        textoSuave: escuro ? const Color(0xFF8B9AA8) : const Color(0xFF6B7A8C),
        balaoEnviado: escuro ? Color.lerp(marca, Colors.white, .12)! : marca,
        balaoRecebido: cartao,
        balaoBot: escuro ? const Color(0xFF1C2733) : const Color(0xFFE3EEF2),
        nota: escuro ? const Color(0xFF3A3320) : const Color(0xFFFFF4D6),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: escuro ? const Color(0xFF17212B) : marca,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: cartao,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: linha),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: marca,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cartao,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: escuro ? const Color(0xFF232325) : const Color(0xFFF3F5F8),
      hintStyle: TextStyle(color: escuro ? const Color(0xFF8A8A8A) : const Color(0xFF8695A6)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: marcaVisivel.withValues(alpha: .5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
