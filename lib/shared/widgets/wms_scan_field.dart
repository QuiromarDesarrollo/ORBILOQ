import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'feedback_banner.dart';
import 'wms_camera_scanner.dart';
import 'wms_loader.dart';

/// Captura el lector como teclado sin pintar el contenido parcial del QR.
/// Se procesa únicamente al recibir Enter, igual que los formularios originales.
class WmsScanField extends StatefulWidget {
  const WmsScanField(
      {super.key,
      required this.controller,
      required this.onSubmitted,
      this.onCameraSubmitted,
      this.focusNode,
      this.autofocus = false,
      this.enabled = true,
      this.decoration = const InputDecoration(),
      this.permiteManual = false});
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus, enabled, permiteManual;
  final InputDecoration decoration;
  final FutureOr<void> Function(String) onSubmitted;
  final FutureOr<FeedbackMessage> Function(String)? onCameraSubmitted;
  @override
  State<WmsScanField> createState() => _WmsScanFieldState();
}

class _WmsScanFieldState extends State<WmsScanField> {
  late final FocusNode _propio = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _propio;
  bool _manual = false, _procesando = false, _camaraAbierta = false;

  Future<void> _abrirCamara() async {
    if (_camaraAbierta || _procesando || !widget.enabled) return;
    _focus.unfocus();
    widget.controller.clear();
    setState(() => _camaraAbierta = true);
    try {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WmsCameraScanner(onRead: (codigo) async {
                if (!mounted || !widget.enabled) {
                  return const FeedbackMessage.error(
                      'El formulario no está disponible para escanear.');
                }
                final resultado = await widget.onCameraSubmitted!(codigo);
                if (mounted) _focus.unfocus();
                return resultado;
              }));
    } finally {
      if (mounted) setState(() => _camaraAbierta = false);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_actualizar);
    _focus.addListener(_actualizar);
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant WmsScanField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_actualizar);
      widget.controller.addListener(_actualizar);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _propio).removeListener(_actualizar);
      _focus.addListener(_actualizar);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_actualizar);
    _focus.removeListener(_actualizar);
    _propio.dispose();
    super.dispose();
  }

  Future<void> _enviar(String valor) async {
    if (_procesando || !widget.enabled || valor.trim().isEmpty) return;
    final devolverFoco = !_manual && _focus.hasFocus;
    setState(() => _procesando = true);
    try {
      await widget.onSubmitted(valor);
    } finally {
      if (mounted) {
        if (!_manual && widget.controller.text == valor) {
          widget.controller.clear();
        }
        setState(() => _procesando = false);
        if (devolverFoco) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.enabled && !_manual) _focus.requestFocus();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leyendo = !_manual && widget.controller.text.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.onCameraSubmitted != null &&
          (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS))
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: widget.enabled && !_procesando && !_camaraAbierta
                  ? _abrirCamara
                  : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Escanear con cámara'),
            )),
      if (_manual)
        TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled && !_procesando,
            decoration: widget.decoration,
            onSubmitted: _enviar)
      else
        Stack(alignment: Alignment.center, children: [
          ExcludeSemantics(
              child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled && !_procesando,
                    keyboardType: TextInputType.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    onSubmitted: _enviar,
                  ))),
          Semantics(
              button: true,
              liveRegion: true,
              child: InkWell(
                onTap: widget.enabled && !_procesando
                    ? () => _focus.requestFocus()
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .045),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _focus.hasFocus
                                ? scheme.primary
                                : scheme.outlineVariant)),
                    child: Row(children: [
                      if (leyendo || _procesando)
                        const WmsLoader()
                      else
                        Icon(Icons.qr_code_scanner_rounded,
                            size: 24, color: scheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                _procesando
                                    ? 'Procesando lectura…'
                                    : leyendo
                                        ? 'Leyendo código…'
                                        : _focus.hasFocus
                                            ? 'Lector listo para escanear'
                                            : 'Activar lector',
                                style: Theme.of(context).textTheme.titleSmall),
                            if (!leyendo && !_procesando)
                              Text(
                                  'Escanea la etiqueta con el lector. El contenido del QR permanece oculto.',
                                  style: Theme.of(context).textTheme.bodySmall),
                          ])),
                      if (leyendo && !_procesando)
                        IconButton(
                            tooltip: 'Cancelar lectura',
                            onPressed: widget.controller.clear,
                            icon: const Icon(Icons.close, size: 18)),
                    ])),
              )),
        ]),
      if (_manual && _procesando)
        const WmsLoadingStrip(label: 'Procesando lectura…'),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: widget.enabled && !_procesando
                  ? () {
                      widget.controller.clear();
                      setState(() => _manual = !_manual);
                      _focus.requestFocus();
                    }
                  : null,
              icon: Icon(
                  _manual ? Icons.qr_code_scanner : Icons.keyboard_outlined,
                  size: 16),
              label: Text(_manual
                  ? 'Usar lector'
                  : widget.permiteManual
                      ? 'Ingresar OP o código'
                      : 'Ingresar código manualmente'))),
    ]);
  }
}
