import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:orbiloq_wms/data/excel_ciclos.dart';

@JS('self')
external DedicatedWorkerGlobalScope get worker;

void main() {
  worker.onmessage =
      ((MessageEvent event) {
        try {
          final filas = ExcelCiclos.leer((event.data as JSUint8Array).toDart);
          worker.postMessage(jsonEncode({'filas': filas}).toJS);
        } catch (e) {
          worker.postMessage(jsonEncode({'error': '$e'}).toJS);
        }
      }).toJS;
}
