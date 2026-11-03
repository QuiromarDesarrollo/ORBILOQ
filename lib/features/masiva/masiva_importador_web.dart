import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'masiva_importador_modelo.dart';

Future<MasivaImportacion> leerMasivaExcel(
  Uint8List bytes, {
  required String tipo,
}) async {
  final worker = web.Worker(
    Uri.parse(
      web.document.baseURI,
    ).resolve('masiva_excel_worker.js?v=20261103-consolidado').toString().toJS,
  );
  final respuesta = Completer<MasivaImportacion>();
  worker.onmessage =
      ((web.MessageEvent event) {
        if (respuesta.isCompleted) return;
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode((event.data as JSString).toDart) as Map,
          );
          if (data['error'] != null) throw FormatException('${data['error']}');
          respuesta.complete(MasivaImportacion.fromJson(data));
        } catch (error, stack) {
          respuesta.completeError(error, stack);
        }
      }).toJS;
  worker.onerror =
      ((web.Event event) {
        event.preventDefault();
        if (!respuesta.isCompleted) {
          respuesta.completeError(
            StateError(
              'No se pudo abrir el lector de Excel. Recarga la página e inténtalo de nuevo.',
            ),
          );
        }
      }).toJS;
  worker.onmessageerror =
      ((web.Event event) {
        if (!respuesta.isCompleted) {
          respuesta.completeError(
            StateError('No se pudo recibir la lectura del Excel.'),
          );
        }
      }).toJS;
  try {
    worker.postMessage([tipo.toJS, bytes.toJS].toJS);
    return await respuesta.future.timeout(const Duration(minutes: 3));
  } finally {
    worker.terminate();
  }
}
