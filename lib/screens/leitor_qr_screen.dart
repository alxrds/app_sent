import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LeitorQrScreen extends StatefulWidget {
  const LeitorQrScreen({super.key});

  @override
  State<LeitorQrScreen> createState() => _LeitorQrScreenState();
}

class _LeitorQrScreenState extends State<LeitorQrScreen> {
  final _controle = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _lido = false;

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  void _detectou(BarcodeCapture captura) {
    if (_lido) {
      return;
    }
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue;
      if (valor != null && valor.isNotEmpty) {
        _lido = true;
        Navigator.of(context).pop(valor);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Ler QR Code'), backgroundColor: Colors.black),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controle,
            onDetect: _detectou,
            errorBuilder: (context, erro) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  erro.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Permita o acesso à câmera nas configurações do celular para ler o QR Code.'
                      : 'Não foi possível abrir a câmera.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'Aponte para o QR Code que aparece em Meu perfil → Aplicativo no celular',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
