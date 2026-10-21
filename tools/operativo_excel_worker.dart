import 'package:orbiloq_wms/data/excel_inventario.dart';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';
import 'package:orbiloq_wms/data/excel_fechas_parser.dart';
import 'package:orbiloq_wms/data/excel_kardex.dart';
import 'package:orbiloq_wms/domain/models.dart';

@JS('self')
external DedicatedWorkerGlobalScope get worker;
void main() {
  worker.onmessage =
      ((MessageEvent event) {
        try {
          final entrada = event.data.dartify() as Map;
          final bytes = entrada['bytes'] as Uint8List;
          if (entrada['tipo'] == 'inventario') {
            worker.postMessage(ExcelInventario.leer(bytes).jsify());
          } else if (entrada['tipo'] == 'fechas') {
            worker.postMessage(
              {'filas': ExcelFechasParser.parsear(bytes)}.jsify(),
            );
          } else if (entrada['tipo'] == 'kardex') {
            final datos = ExcelKardex.leer(
              bytes,
              Rol.values.byName(entrada['vista'] as String),
            );
            worker.postMessage(
              {'filas': datos.filas, 'version': datos.version}.jsify(),
            );
          } else {
            throw const FormatException('Tipo de importación desconocido.');
          }
        } catch (e) {
          worker.postMessage({'error': '$e'}.jsify());
        }
      }).toJS;
}
