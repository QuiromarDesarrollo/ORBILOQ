import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Descarga en navegador sin depender del registro de plugins de impresión.
Future<void> descargarPdf(Uint8List bytes, String nombre) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final enlace =
      web.HTMLAnchorElement()
        ..href = url
        ..download = nombre
        ..style.display = 'none';
  try {
    web.document.body!.appendChild(enlace);
    enlace.click();
  } finally {
    enlace.remove();
    // El navegador necesita conservar el Blob mientras inicia la descarga.
    Timer(const Duration(seconds: 60), () => web.URL.revokeObjectURL(url));
  }
}
