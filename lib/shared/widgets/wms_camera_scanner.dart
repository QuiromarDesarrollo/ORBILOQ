import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'feedback_banner.dart';
import 'wms_loader.dart';

/// Una sesión de cámara no guarda movimientos: reutiliza la validación y las
/// tarjetas del formulario que la abrió. El resultado viene de ese formulario.
class WmsCameraScanner extends StatefulWidget {
  const WmsCameraScanner({
    super.key,
    required this.onRead,
    this.previewBuilder,
    this.produccion = false,
    this.onManual,
  });

  final FutureOr<FeedbackMessage> Function(String) onRead;
  final bool produccion;
  final VoidCallback? onManual;

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
  bool _sinCamara = false;

  Future<void> _detectar(List<String> valores) async {
    if (_ocupado || _pausado || !mounted) return;
    final codigos =
        valores.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
    if (codigos.isEmpty) return;
    if (codigos.length > 1) {
      setState(
        () =>
            _mensaje = const FeedbackMessage.error(
              'Hay varias etiquetas en la imagen. Enfoca solo una para continuar.',
            ),
      );
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
        'No se pudo procesar la lectura. Revisa las tarjetas antes de reintentar.',
      );
    }
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _mensaje = resultado;
      if (!resultado.isError) _aceptados++;
    });
  }

  Widget _errorCamara(BuildContext context, MobileScannerException error) {
    if (widget.produccion && !_sinCamara) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sinCamara = true);
      });
    }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              if (widget.produccion)
                const Text(
                  'No hay cámara disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    () => setState(() {
                      _sinCamara = false;
                      _intento++;
                    }),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar cámara'),
              ),
              if (widget.onManual != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onManual!();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Ingresar código manualmente'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaProduccion(BuildContext context) {
    const petrol = Color(0xFF093E52);
    const lima = Color(0xFFE7EEA1);
    void volver() => Navigator.pop(context);
    final preview =
        _pausado
            ? const Center(
              child: Text(
                'Cámara pausada',
                style: TextStyle(color: Colors.white),
              ),
            )
            : widget.previewBuilder?.call(context, _detectar) ??
                MobileScanner(
                  key: ValueKey(_intento),
                  onDetect:
                      (capture) => _detectar([
                        for (final b in capture.barcodes)
                          if (b.rawValue != null) b.rawValue!,
                      ]),
                  errorBuilder: _errorCamara,
                  placeholderBuilder: (_) => const Center(child: WmsLoader()),
                );
    return PopScope(
      canPop: !_ocupado,
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF111C20),
          appBar: AppBar(
            backgroundColor: petrol,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escaneo continuo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text('Entregas de Producción', style: TextStyle(fontSize: 11)),
              ],
            ),
            actions: [
              Chip(
                backgroundColor:
                    _aceptados == 0 ? const Color(0xFF315B6A) : lima,
                side: BorderSide.none,
                label: Text(
                  '$_aceptados leídas',
                  style: TextStyle(
                    fontSize: 11,
                    color: _aceptados == 0 ? Colors.white : petrol,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Volver al lote',
                onPressed: _ocupado ? null : volver,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview,
                      if (!_sinCamara && !_pausado)
                        IgnorePointer(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final lado = (c.maxWidth * .64)
                                  .clamp(80.0, 260.0)
                                  .clamp(0.0, c.maxHeight * .60);
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: lado,
                                      height: lado,
                                      child: CustomPaint(
                                        painter: _MarcoEscaneo(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Enfoca la etiqueta dentro del recuadro',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      if (_mensaje != null && !_ocupado)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 10,
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    _mensaje!.isError
                                        ? const Color(0xFFFFE9E7)
                                        : const Color(0xFFE6F4EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _mensaje!.isError
                                        ? Icons.error_outline
                                        : Icons.check_circle,
                                    color:
                                        _mensaje!.isError
                                            ? Colors.red.shade700
                                            : const Color(0xFF299D64),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _mensaje!.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: petrol,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ocupado)
                        const WmsLoadingStrip(label: 'Actualizando lote…'),
                      Text(
                        _sinCamara
                            ? 'Todavía no hay nuevas lecturas. Las prendas escaneadas permanecen en el lote.'
                            : 'Cada código se lee una sola vez. Para contar la misma etiqueta otra vez, usa Releer.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF57707C),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_sinCamara) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _ocupado
                                        ? null
                                        : () => setState(
                                          () => _pausado = !_pausado,
                                        ),
                                icon: Icon(
                                  _pausado ? Icons.play_arrow : Icons.pause,
                                  size: 16,
                                ),
                                label: Text(_pausado ? 'Continuar' : 'Pausar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _ocupado || _ultimo == null || _pausado
                                        ? null
                                        : () => setState(() {
                                          _leidos.remove(_ultimo);
                                          _mensaje = const FeedbackMessage.ok(
                                            'Listo para volver a leer el mismo código.',
                                          );
                                        }),
                                icon: const Icon(Icons.replay, size: 16),
                                label: const Text('Releer'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        onPressed: _ocupado ? null : volver,
                        style: FilledButton.styleFrom(
                          backgroundColor: petrol,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _aceptados == 0
                              ? 'Volver al lote  →'
                              : 'Revisar lote · $_aceptados lecturas  →',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Confirmas el movimiento al volver al lote.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF57707C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.produccion) return _vistaProduccion(context);
    return PopScope(
      canPop: !_ocupado,
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(
              'Escaneo continuo',
              style: TextStyle(fontSize: 18),
            ),
            actions: [
              IconButton(
                tooltip: 'Volver a las tarjetas',
                onPressed: _ocupado ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
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
                      Text(
                        '$_aceptados lectura(s) aceptada(s)',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      if (_ocupado)
                        const WmsLoadingStrip(label: 'Actualizando tarjeta…')
                      else
                        const Text(
                          'Enfoca una etiqueta. Las lecturas aparecerán aquí.',
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _pausado
                              ? const Center(
                                child: Text(
                                  'Cámara pausada',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                              : widget.previewBuilder?.call(
                                    context,
                                    _detectar,
                                  ) ??
                                  MobileScanner(
                                    key: ValueKey(_intento),
                                    onDetect:
                                        (capture) => _detectar([
                                          for (final barcode
                                              in capture.barcodes)
                                            if (barcode.rawValue != null)
                                              barcode.rawValue!,
                                        ]),
                                    errorBuilder: _errorCamara,
                                    placeholderBuilder:
                                        (_) => const Center(
                                          child: WmsLoader(color: Colors.white),
                                        ),
                                  ),
                          if (_mensaje != null && !_ocupado)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                    maxHeight: 220,
                                  ),
                                  child: Card(
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _mensaje!.isError
                                                  ? Icons.error_outline
                                                  : Icons.check_circle_outline,
                                              color:
                                                  _mensaje!.isError
                                                      ? theme.colorScheme.error
                                                      : theme
                                                          .colorScheme
                                                          .primary,
                                            ),
                                            const SizedBox(height: 8),
                                            Semantics(
                                              liveRegion: true,
                                              child: Text(
                                                _mensaje!.text,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => setState(
                                                    () => _mensaje = null,
                                                  ),
                                              child: const Text('Cerrar aviso'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Cada código se lee una vez; usa «Releer» para repetirlo. Confirma el movimiento al volver a las tarjetas.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed:
                                _ocupado
                                    ? null
                                    : () =>
                                        setState(() => _pausado = !_pausado),
                            icon: Icon(
                              _pausado ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(_pausado ? 'Continuar' : 'Pausar'),
                          ),
                          TextButton.icon(
                            onPressed:
                                _ocupado || _ultimo == null || _pausado
                                    ? null
                                    : () => setState(() {
                                      _leidos.remove(_ultimo);
                                      _mensaje = const FeedbackMessage.ok(
                                        'Listo para volver a leer el mismo código.',
                                      );
                                    }),
                            icon: const Icon(Icons.replay),
                            label: const Text('Releer mismo código'),
                          ),
                          FilledButton.icon(
                            onPressed:
                                _ocupado ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.view_agenda_outlined),
                            label: const Text('Ver tarjetas'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarcoEscaneo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = const Color(0xFFE7EEA1)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
    const tramo = 24.0;
    final w = size.width, h = size.height;
    for (final punto in [
      Offset.zero,
      Offset(w, 0),
      Offset(0, h),
      Offset(w, h),
    ]) {
      final dx = punto.dx == 0 ? tramo : -tramo;
      final dy = punto.dy == 0 ? tramo : -tramo;
      canvas.drawPath(
        Path()
          ..moveTo(punto.dx + dx, punto.dy)
          ..lineTo(punto.dx, punto.dy)
          ..lineTo(punto.dx, punto.dy + dy),
        p,
      );
    }
    canvas.drawLine(
      Offset(10, h / 2),
      Offset(w - 10, h / 2),
      p..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
