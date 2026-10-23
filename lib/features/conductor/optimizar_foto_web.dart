import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

/// En web, compute no crea un isolate. El navegador decodifica y codifica
/// la foto nativamente; el canvas exportado no conserva metadatos EXIF.
Future<Uint8List> optimizarFoto(Uint8List bytes) async {
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Foto no compatible o demasiado grande (máximo 40 megapíxeles).',
    );
  }
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final foto = web.HTMLImageElement()..src = url;
  final canvas = web.HTMLCanvasElement();
  try {
    // El decodificador del navegador aplica la orientación EXIF.
    await foto.decode().toDart.timeout(const Duration(seconds: 30));
    final ancho = foto.naturalWidth, alto = foto.naturalHeight;
    if (ancho <= 0 || alto <= 0 || ancho * alto > 40000000) {
      throw const FormatException('La foto no tiene dimensiones válidas.');
    }
    final escala = math.min(1.0, 1600 / math.max(ancho, alto));
    canvas.width = math.max(1, (ancho * escala).round());
    canvas.height = math.max(1, (alto * escala).round());
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(
      foto,
      0,
      0,
      canvas.width.toDouble(),
      canvas.height.toDouble(),
    );
    final resultado = Completer<web.Blob>();
    canvas.toBlob(
      ((web.Blob? salida) {
        if (salida == null) {
          resultado.completeError(
            const FormatException('No se pudo preparar la foto.'),
          );
        } else {
          resultado.complete(salida);
        }
      }).toJS,
      'image/jpeg',
      0.82.toJS,
    );
    final jpg = await resultado.future.timeout(const Duration(seconds: 30));
    return (await jpg.arrayBuffer().toDart).toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
    foto.src = '';
    canvas.width = 0;
    canvas.height = 0;
  }
}
