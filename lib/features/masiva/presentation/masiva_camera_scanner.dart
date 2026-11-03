import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/feedback_banner.dart';

/// Cámara de Masivas: una lectura por armado, validada por el formulario.
class MasivaCameraScanner extends StatefulWidget {
  const MasivaCameraScanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.instruction,
    required this.onRead,
    this.closeOnSuccess = false,
    this.onManual,
    this.previewBuilder,
  });

  final String title;
  final String subtitle;
  final String instruction;
  final Future<FeedbackMessage> Function(String) onRead;
  final bool closeOnSuccess;
  final VoidCallback? onManual;
  final Widget Function(BuildContext, ValueChanged<List<String>>)?
  previewBuilder;

  @override
  State<MasivaCameraScanner> createState() => _MasivaCameraScannerState();
}

class _MasivaCameraScannerState extends State<MasivaCameraScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _busy = false;
  bool _paused = false;
  FeedbackMessage? _feedback;
  String? _lastCode;
  int _accepted = 0;
  bool _foreground = true;
  Future<void> _lifecycleAction = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.previewBuilder == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Serialize stop/start when the browser or device changes visibility quickly.
    _lifecycleAction = _lifecycleAction.then((_) async {
      if (!mounted ||
          _controller == null ||
          !_controller!.value.hasCameraPermission) {
        return;
      }
      await _cameraAction(() async {
        if (_foreground && !_paused && !_busy) {
          await _controller!.start();
        } else {
          await _controller!.stop();
        }
      });
    });
  }

  Future<void> _detect(List<String> values) async {
    if (!mounted || !_foreground || _busy || _paused) return;
    final codes =
        values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
    if (codes.isEmpty) return;
    setState(() {
      _paused = true;
      _busy = true;
      _feedback = null;
    });
    // Gate detections synchronously before stopping the native camera.
    try {
      await _controller?.stop();
    } catch (_) {
      // The logical gate remains closed even if the device cannot stop.
    }
    if (!mounted) return;
    FeedbackMessage result;
    if (codes.length > 1) {
      result = const FeedbackMessage.error(
        'Hay varias etiquetas. Enfoca solo una y vuelve a escanear.',
      );
    } else {
      _lastCode = codes.single;
      try {
        result = await widget.onRead(codes.single);
      } catch (_) {
        result = const FeedbackMessage.error(
          'No se pudo confirmar la lectura. Revisa el registro antes de reintentar.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = result;
      if (!result.isError) _accepted++;
    });
    if (!result.isError && widget.closeOnSuccess) {
      // PopScope must rebuild with canPop before the successful route exit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(_lastCode);
      });
    }
  }

  Future<void> _rearm() async {
    if (_busy) return;
    setState(() {
      _paused = false;
      _feedback = null;
    });
    await _cameraAction(() async => _controller?.start());
  }

  Future<void> _cameraAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paused = true;
        _feedback = const FeedbackMessage.error(
          'No se pudo activar la cámara. Reintenta o usa la entrada manual.',
        );
      });
    }
  }

  void _manual() {
    Navigator.of(context).pop();
    widget.onManual?.call();
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final message =
        error.errorCode == MobileScannerErrorCode.permissionDenied
            ? 'Permite el acceso a la cámara en los ajustes del navegador o dispositivo.'
            : 'No se pudo abrir la cámara. Comprueba su disponibilidad y el acceso seguro (HTTPS).';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _rearm,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar cámara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.previewBuilder?.call(context, _detect) ??
            MobileScanner(
              controller: _controller,
              onDetect:
                  (capture) => _detect([
                    for (final barcode in capture.barcodes)
                      if (barcode.rawValue != null) barcode.rawValue!,
                  ]),
              errorBuilder: _cameraError,
            ),
        if (_paused)
          ColoredBox(
            color: AppColors.petroleo,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _busy ? Icons.hourglass_top : Icons.pause_circle_outline,
                      color: AppColors.lima,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _busy ? 'Validando lectura…' : 'Lectura pausada',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    if (!_busy) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Retira la etiqueta antes de continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        // Frame stays clear of error UI and does not intercept camera controls.
        if (widget.previewBuilder != null)
          const SizedBox.shrink()
        else
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller!,
            builder:
                (context, state, _) =>
                    !_paused && state.isRunning && state.error == null
                        ? IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 240,
                              height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.lima,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _controls() {
    if (_controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller!,
      builder:
          (context, state, _) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              if ((state.availableCameras ?? 0) > 1)
                TextButton.icon(
                  onPressed:
                      _busy || _paused
                          ? null
                          : () =>
                              _cameraAction(() => _controller!.switchCamera()),
                  icon: const Icon(Icons.cameraswitch_outlined),
                  label: const Text('Cambiar cámara'),
                ),
              if (state.torchState != TorchState.unavailable)
                TextButton.icon(
                  onPressed:
                      _busy || _paused
                          ? null
                          : () =>
                              _cameraAction(() => _controller!.toggleTorch()),
                  icon: Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                  ),
                  label: const Text('Linterna'),
                ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: AppColors.petroleo,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: Text(widget.title, style: const TextStyle(fontSize: 18)),
            actions: [
              IconButton(
                tooltip: 'Cerrar cámara',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cameraHeight = (constraints.maxHeight * .48).clamp(
                  180.0,
                  460.0,
                );
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.subtitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(widget.instruction),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: cameraHeight,
                                child: ColoredBox(
                                  color: AppColors.petroleo,
                                  child: _preview(),
                                ),
                              ),
                            ),
                            _controls(),
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _busy
                                    ? 'Procesando… Espera la confirmación.'
                                    : _paused
                                    ? 'Escaneo pausado · $_accepted aceptadas'
                                    : 'Cámara lista · Enfoca una etiqueta',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (_lastCode != null) ...[
                              const SizedBox(height: 8),
                              Text('Última lectura: $_lastCode'),
                            ],
                            if (_feedback != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        _feedback!.isError
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.errorContainer
                                            : AppColors.greenChipBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _feedback!.isError
                                            ? Icons.error_outline
                                            : Icons.check_circle_outline,
                                        color:
                                            _feedback!.isError
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.onErrorContainer
                                                : AppColors.actionGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _feedback!.text,
                                          style: TextStyle(
                                            color:
                                                _feedback!.isError
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer
                                                    : AppColors.petroleo,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (_paused)
                              FilledButton.icon(
                                onPressed: _busy ? null : _rearm,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.lima,
                                  foregroundColor: AppColors.petroleo,
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Escanear siguiente'),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _manual,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              icon: const Icon(Icons.keyboard_outlined),
                              label: const Text('Ingresar código manualmente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
