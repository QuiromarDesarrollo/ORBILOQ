import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conductor/borrador_local.dart';
import 'borrador_texto_native.dart'
    if (dart.library.js_interop) 'borrador_texto_web.dart';

/// Borradores separados por entorno, usuario y proceso. Nunca ejecuta movimientos.
mixin BorradorOperativo<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String get borradorProceso;
  Map<String, dynamic> capturarBorrador();
  void recuperarBorrador(Map<String, dynamic> datos);
  Iterable<TextEditingController> get controlesBorrador => const [];
  bool get operacionEnCurso => false;
  Future<void> alRecuperarBorrador() async {}
  bool borradorCargando = true, borradorIncierto = false;
  String? borradorError;
  String? _clave, _ultimo;
  bool _restaurando = false, _disposed = false;
  final Set<TextEditingController> _observados = {};
  Future<void> _escritura = Future.value();
  BorradorLocalStore? _almacen;

  @override
  void initState() {
    super.initState();
    Future.microtask(cargarBorrador);
  }

  Future<void> cargarBorrador() async {
    _restaurando = true;
    try {
      final user = ref.read(transporteBorradorUsuarioProvider);
      if (user != null) {
        _clave = jsonEncode([user, 'operativo-v1', borradorProceso]);
        _almacen = ref.read(transporteBorradorStoreProvider);
        final raw = kIsWeb ? leerTextoBorrador(_clave!) : null;
        final guardado =
            kIsWeb
                ? (raw == null
                    ? null
                    : Map<String, dynamic>.from(jsonDecode(raw)))
                : await _almacen!.leer(_clave!);
        if (!mounted) return;
        if (guardado != null && guardado['completo'] != true) {
          if (guardado['version'] != 1 || guardado['datos'] is! Map) {
            throw const FormatException('Borrador incompatible');
          }
          recuperarBorrador(Map<String, dynamic>.from(guardado['datos']));
          borradorIncierto = guardado['enCurso'] == true;
        }
      }
      borradorCargando = false;
      borradorError = null;
      _observar();
    } catch (_) {
      borradorError =
          'No se pudo recuperar el avance. Reintenta antes de continuar.';
    } finally {
      _restaurando = false;
      if (mounted) super.setState(() {});
    }
    if (mounted && !borradorCargando) await alRecuperarBorrador();
  }

  void _observar() {
    final actuales = controlesBorrador.toSet();
    // Los controladores retirados pueden estar ya disposed; su dispose elimina listeners.
    _observados.removeWhere((c) => !actuales.contains(c));
    for (final c in actuales) {
      if (_observados.add(c)) c.addListener(guardarBorrador);
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_restaurando && !borradorCargando) {
      _observar();
      guardarBorrador();
    }
  }

  void guardarBorrador() {
    if (_disposed || _restaurando || borradorCargando || _clave == null) return;
    final raw = jsonEncode({
      'version': 1,
      'datos': capturarBorrador(),
      'enCurso': operacionEnCurso || borradorIncierto,
    });
    if (raw == _ultimo) return;
    _ultimo = raw;
    final clave = _clave!, almacen = _almacen!;
    if (kIsWeb) {
      final errorAnterior = borradorError;
      try {
        // Escritura sin debounce: termina en el mismo evento de teclado/escáner.
        escribirTextoBorrador(clave, raw);
        borradorError = null;
      } catch (_) {
        _ultimo = null;
        borradorError =
            'No se pudo guardar el avance. No actualices la página; reintenta.';
      }
      if (errorAnterior != borradorError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_disposed) super.setState(() {});
        });
      }
      return;
    }
    _escritura = _escritura.then((_) async {
      try {
        await almacen.guardar(
          clave,
          Map<String, dynamic>.from(jsonDecode(raw)),
        );
        if (!_disposed) borradorError = null;
      } catch (_) {
        _ultimo = null;
        if (!_disposed) {
          borradorError =
              'No se pudo guardar el avance. No actualices la página; reintenta.';
        }
      }
      if (mounted && !_disposed) super.setState(() {});
    });
  }

  Future<bool> asegurarBorrador() async {
    guardarBorrador();
    await _escritura;
    return !borradorCargando && borradorError == null;
  }

  Future<void> finalizarBorrador() async {
    await _escritura;
    if (_clave == null) return;
    final datos = <String, dynamic>{'version': 1, 'completo': true};
    try {
      if (kIsWeb) {
        escribirTextoBorrador(_clave!, jsonEncode(datos));
      } else {
        await _almacen!.guardar(_clave!, datos);
      }
    } catch (_) {
      // La escritura operativa ya fue confirmada. No presentarla como fallida.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Operación registrada. No se pudo limpiar el borrador; revisa el historial si vuelve a aparecer.',
            ),
          ),
        );
      }
    } finally {
      // No dejar que el finally del envío vuelva a guardar lo ya confirmado.
      _clave = null;
    }
  }

  Widget estadoBorrador() =>
      !borradorCargando && borradorError == null && !borradorIncierto
          ? const SizedBox.shrink()
          : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  borradorError ??
                      (borradorCargando
                          ? 'Recuperando avance…'
                          : borradorIncierto
                          ? 'Había un envío en curso. Revisa el historial antes de repetirlo.'
                          : _clave == null
                          ? 'Modo demostración · Sin guardado local'
                          : 'Guardado automático en este dispositivo'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (borradorError != null)
                  TextButton(
                    onPressed: () {
                      if (borradorCargando) {
                        cargarBorrador();
                      } else {
                        guardarBorrador();
                      }
                    },
                    child: const Text('Reintentar'),
                  ),
                if (borradorIncierto)
                  TextButton(
                    onPressed: () async {
                      final continuar = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text('Revisar envío anterior'),
                              content: const Text(
                                'Comprueba el historial y las cantidades actuales. Continúa solo si estas prendas todavía están pendientes; el envío anterior pudo haberse registrado.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Ya revisé el historial'),
                                ),
                              ],
                            ),
                      );
                      if (continuar == true && mounted) {
                        setState(() => borradorIncierto = false);
                      }
                    },
                    child: const Text('Revisar antes de continuar'),
                  ),
              ],
            ),
          );

  bool get borradorBloqueado =>
      borradorCargando || borradorIncierto || borradorError != null;

  Widget envolverBorrador(Widget child) => Column(
    children: [
      estadoBorrador(),
      Expanded(
        child: AbsorbPointer(absorbing: borradorBloqueado, child: child),
      ),
    ],
  );

  @override
  void dispose() {
    _disposed = true;
    // Los propietarios eliminan los controladores junto con sus listeners.
    super.dispose();
  }
}
