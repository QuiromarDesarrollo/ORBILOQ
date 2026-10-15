import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<List<Map<String, dynamic>>> leerCiclosAsync(Uint8List bytes) async {
  final worker = web.Worker(
    Uri.parse(
      web.document.baseURI,
    ).resolve('ciclos_excel_worker.js?v=20261014-1').toString().toJS,
  );
  final resultado = Completer<List<Map<String, dynamic>>>();
  void error(String mensaje) {
    if (!resultado.isCompleted) resultado.completeError(StateError(mensaje));
  }

  worker.onmessage =
      ((web.MessageEvent event) {
        if (resultado.isCompleted) return;
        try {
          final respuesta = jsonDecode((event.data as JSString).toDart) as Map;
          if (respuesta['error'] != null) {
            resultado.completeError(FormatException('${respuesta['error']}'));
          } else {
            resultado.complete([
              for (final r in respuesta['filas'] as List)
                Map<String, dynamic>.from(r as Map),
            ]);
          }
        } catch (e, st) {
          resultado.completeError(e, st);
        }
      }).toJS;
  worker.onerror =
      ((web.Event event) {
        event.preventDefault();
        error(
          'No se pudo iniciar el lector de Excel. Recarga la página; si persiste, verifica que la versión publicada incluya el lector en segundo plano.',
        );
      }).toJS;
  worker.onmessageerror =
      ((web.Event event) {
        error('No se pudo recibir el resultado de lectura del Excel.');
      }).toJS;
  try {
    worker.postMessage(bytes.toJS);
    return await resultado.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        throw TimeoutException(
          'La lectura del Excel superó 2 minutos. No se enviaron datos al servidor.',
        );
      },
    );
  } finally {
    worker.terminate();
  }
}
