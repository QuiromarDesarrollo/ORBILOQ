import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'excel_ordenes_parser.dart';

Future<ExcelOrdenesParseado> leerOrdenesAsync(Uint8List bytes) async {
  final worker = web.Worker(
    Uri.parse(
      web.document.baseURI,
    ).resolve('ordenes_excel_worker.js?v=20261022-sin-codigo-1').toString().toJS,
  );
  final resultado = Completer<ExcelOrdenesParseado>();
  void fallar(String mensaje) {
    if (!resultado.isCompleted) {
      resultado.completeError(ExcelOrdenesParseException(mensaje));
    }
  }

  worker.onmessage =
      ((web.MessageEvent event) {
        if (resultado.isCompleted) return;
        try {
          final dato = event.data.dartify() as Map;
          if (dato['error'] != null) {
            fallar('${dato['error']}');
            return;
          }
          List<Map<String, String?>> filas(String clave) => [
            for (final r in dato[clave] as List)
              Map<String, String?>.from(r as Map),
          ];
          resultado.complete(
            ExcelOrdenesParseado(
              ordenes: filas('ordenes'),
              tallas: filas('tallas'),
            ),
          );
        } catch (e, st) {
          resultado.completeError(e, st);
        }
      }).toJS;
  worker.onerror =
      ((web.Event event) {
        event.preventDefault();
        fallar(
          'No se pudo iniciar el lector ERP. Recarga la página y verifica que el despliegue incluya ordenes_excel_worker.js.',
        );
      }).toJS;
  worker.onmessageerror =
      ((web.Event event) {
        fallar('No se pudo recibir el resultado de lectura del Excel.');
      }).toJS;
  try {
    worker.postMessage(bytes.toJS);
    return await resultado.future.timeout(
      const Duration(minutes: 2),
      onTimeout:
          () =>
              throw ExcelOrdenesParseException(
                'La lectura superó 2 minutos. No se han enviado datos a la base.',
              ),
    );
  } finally {
    worker.terminate();
  }
}
