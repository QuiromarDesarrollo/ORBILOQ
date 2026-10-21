import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../domain/models.dart';
import 'excel_fechas_parser.dart';
import 'excel_kardex.dart';

Future<Map> _leer(Uint8List bytes, String tipo, [String? vista]) async {
  final worker = web.Worker(
    Uri.parse(
      web.document.baseURI,
    ).resolve('operativo_excel_worker.js?v=20261019-3').toString().toJS,
  );
  final resultado = Completer<Map>();
  void fallar(String mensaje) {
    if (!resultado.isCompleted) {
      resultado.completeError(FormatException(mensaje));
    }
  }

  worker.onmessage =
      ((web.MessageEvent event) {
        if (resultado.isCompleted) return;
        try {
          final dato = event.data.dartify() as Map;
          if (dato['error'] != null) {
            fallar('${dato['error']}');
          } else {
            resultado.complete(dato);
          }
        } catch (e, st) {
          resultado.completeError(e, st);
        }
      }).toJS;
  worker.onerror =
      ((web.Event event) {
        event.preventDefault();
        fallar(
          'No se pudo iniciar el lector. Recarga la página y verifica que el despliegue incluya operativo_excel_worker.js.',
        );
      }).toJS;
  worker.onmessageerror =
      ((web.Event event) {
        fallar('No se pudo recibir el resultado de lectura del Excel.');
      }).toJS;
  try {
    worker.postMessage({'bytes': bytes, 'tipo': tipo, 'vista': vista}.jsify());
    return await resultado.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        throw const FormatException(
          'La lectura superó 2 minutos. No se enviaron datos al servidor.',
        );
      },
    );
  } finally {
    worker.terminate();
  }
}

Future<List<FilaFechaEsperada>> leerFechasAsync(Uint8List bytes) async {
  final dato = await _leer(bytes, 'fechas');
  return [
    for (final r in dato['filas'] as List) Map<String, String?>.from(r as Map),
  ];
}

Future<ArchivoKardex> leerKardexAsync(Uint8List bytes, Rol vista) async {
  final dato = await _leer(bytes, 'kardex', vista.name);
  return ArchivoKardex(vista, dato['version'] as String, [
    for (final r in dato['filas'] as List) Map<String, dynamic>.from(r as Map),
  ]);
}

Future<Map<String, dynamic>> leerInventarioAsync(Uint8List bytes) async =>
    Map<String, dynamic>.from(await _leer(bytes, 'inventario'));
