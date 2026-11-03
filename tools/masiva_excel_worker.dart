import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:orbiloq_wms/features/masiva/masiva_importador_parser.dart';

@JS('self')
external DedicatedWorkerGlobalScope get worker;

void main() {
  worker.onmessage =
      ((MessageEvent event) {
        try {
          final data = (event.data as JSArray<JSAny?>).toDart;
          final resultado = parsearMasivaExcel(
            (data[1] as JSUint8Array).toDart,
            tipo: (data[0] as JSString).toDart,
          );
          worker.postMessage(jsonEncode(resultado.toJson()).toJS);
        } catch (e) {
          worker.postMessage(jsonEncode({'error': '$e'}).toJS);
        }
      }).toJS;
}
