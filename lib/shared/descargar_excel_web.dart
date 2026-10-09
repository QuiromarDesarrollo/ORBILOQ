import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// FilePicker no implementa saveFile en web: la descarga usa un Blob local.
Future<void> descargarExcel(Uint8List bytes, String nombre, {String titulo = 'Guardar Excel'}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  try {
    web.document.body!.appendChild(enlace);
    enlace.click();
  } finally {
    enlace.remove();
    Timer(const Duration(seconds: 60), () => web.URL.revokeObjectURL(url));
  }
}
