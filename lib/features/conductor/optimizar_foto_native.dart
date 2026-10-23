import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> optimizarFoto(Uint8List bytes) =>
    compute(optimizarFotoSync, bytes);

Uint8List optimizarFotoSync(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Foto no compatible o demasiado grande (máximo 40 megapíxeles).',
    );
  }
  var foto = decoder!.decodeFrame(0)!;
  foto = img.bakeOrientation(foto);
  if (foto.width > 1600 || foto.height > 1600) {
    foto = img.copyResize(
      foto,
      width: foto.width >= foto.height ? 1600 : null,
      height: foto.height > foto.width ? 1600 : null,
    );
  }
  foto.exif.clear();
  return Uint8List.fromList(img.encodeJpg(foto, quality: 82));
}
