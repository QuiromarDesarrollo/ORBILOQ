import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';

@JS('self')
external DedicatedWorkerGlobalScope get worker;
void main() {
  worker.onmessage =
      ((MessageEvent event) {
        try {
          final datos = ExcelOrdenesParser.parsear(
            (event.data as JSUint8Array).toDart,
          );
          worker.postMessage(
            {'ordenes': datos.ordenes, 'tallas': datos.tallas}.jsify(),
          );
        } catch (e) {
          worker.postMessage({'error': '$e'}.jsify());
        }
      }).toJS;
}
