import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'feedback_banner.dart';
import 'wms_loader.dart';

/// Una sesión de cámara no guarda movimientos: reutiliza la validación y las
/// tarjetas del formulario que la abrió. El resultado viene de ese formulario.
class WmsCameraScanner extends StatefulWidget {
  const WmsCameraScanner(
      {super.key, required this.onRead, this.previewBuilder});

  final FutureOr<FeedbackMessage> Function(String) onRead;

  /// Permite comprobar detecciones sin depender de una cámara física.
  final Widget Function(BuildContext, ValueChanged<List<String>>)?
      previewBuilder;

  @override
  State<WmsCameraScanner> createState() => _WmsCameraScannerState();
}

class _WmsCameraScannerState extends State<WmsCameraScanner> {
  final _leidos = <String>{};
  String? _ultimo;
  FeedbackMessage? _mensaje;
  bool _ocupado = false, _pausado = false;
  int _aceptados = 0, _intento = 0;

  Future<void> _detectar(List<String> valores) async {
    if (_ocupado || _pausado || !mounted) return;
    final codigos =
        valores.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
    if (codigos.isEmpty) return;
    if (codigos.length > 1) {
      setState(() => _mensaje = const FeedbackMessage.error(
          'Hay varias etiquetas en la imagen. Enfoca solo una para continuar.'));
      return;
    }
    final codigo = codigos.single;
    if (_leidos.contains(codigo)) return;
    _leidos.add(codigo);
    setState(() {
      _ultimo = codigo;
      _ocupado = true;
    });
    FeedbackMessage resultado;
    try {
      resultado = await widget.onRead(codigo);
    } catch (_) {
      resultado = const FeedbackMessage.error(
          'No se pudo procesar la lectura. Revisa las tarjetas antes de reintentar.');
    }
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _mensaje = resultado;
      if (!resultado.isError) _aceptados++;
    });
  }

  Widget _errorCamara(BuildContext context, MobileScannerException error) {
    final mensaje = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Permite el acceso a la cámara en los ajustes del navegador y vuelve a intentar.',
      MobileScannerErrorCode.unsupported =>
        'Este dispositivo o navegador no tiene una cámara disponible. Puedes usar el ingreso manual.',
      _ =>
        'No se pudo abrir la cámara. Comprueba que la página use HTTPS, cierra otras aplicaciones que usen la cámara y vuelve a intentar.',
    };
    return Center(
        child: SingleChildScrollView(
            child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.no_photography_outlined,
            color: Colors.white, size: 32),
        const SizedBox(height: 12),
        Text(mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => setState(() => _intento++),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar cámara')),
      ]),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_ocupado,
      child: Dialog.fullscreen(
          child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Escaneo continuo', style: TextStyle(fontSize: 18)),
          actions: [
            IconButton(
                tooltip: 'Volver a las tarjetas',
                onPressed: _ocupado ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close))
          ],
        ),
        body: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('$_aceptados lectura(s) aceptada(s)',
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 6),
                      if (_ocupado)
                        const WmsLoadingStrip(label: 'Actualizando tarjeta…')
                      else if (_mensaje != null)
                        Semantics(
                            liveRegion: true,
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 100),
                                child: SingleChildScrollView(
                                    child: FeedbackBanner(message: _mensaje!))))
                      else
                        const Text(
                            'Enfoca una etiqueta. Las lecturas aparecerán aquí.'),
                    ],
                  )),
              Expanded(
                  child: ClipRect(
                      child: ColoredBox(
                color: Colors.black,
                child: _pausado
                    ? const Center(
                        child: Text('Cámara pausada',
                            style: TextStyle(color: Colors.white)))
                    : widget.previewBuilder?.call(context, _detectar) ??
                        MobileScanner(
                          key: ValueKey(_intento),
                          onDetect: (capture) => _detectar([
                            for (final barcode in capture.barcodes)
                              if (barcode.rawValue != null) barcode.rawValue!,
                          ]),
                          errorBuilder: _errorCamara,
                          placeholderBuilder: (_) => const Center(
                              child: WmsLoader(color: Colors.white)),
                        ),
              ))),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(
                        'Cada código se lee una vez; usa «Releer» para repetirlo. Confirma el movimiento al volver a las tarjetas.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center),
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                              onPressed: _ocupado
                                  ? null
                                  : () => setState(() => _pausado = !_pausado),
                              icon: Icon(
                                  _pausado ? Icons.play_arrow : Icons.pause),
                              label: Text(_pausado ? 'Continuar' : 'Pausar')),
                          TextButton.icon(
                              onPressed: _ocupado || _ultimo == null || _pausado
                                  ? null
                                  : () => setState(() {
                                        _leidos.remove(_ultimo);
                                        _mensaje = const FeedbackMessage.ok(
                                            'Listo para volver a leer el mismo código.');
                                      }),
                              icon: const Icon(Icons.replay),
                              label: const Text('Releer mismo código')),
                          FilledButton.icon(
                              onPressed: _ocupado
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.view_agenda_outlined),
                              label: const Text('Ver tarjetas')),
                        ]),
                  ])),
            ])),
      )),
    );
  }
}
