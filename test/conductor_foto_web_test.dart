@TestOn('browser')
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:orbiloq_wms/features/conductor/evidencia_conductor.dart';
import 'package:orbiloq_wms/features/conductor/optimizar_foto_native.dart'
    as anterior;

void main() {
  test(
    'Foto web conserva orientación, limita dimensiones y elimina EXIF',
    () async {
      final imagen = img.Image(width: 2000, height: 1000);
      imagen.exif.imageIfd.orientation = 6;
      final bytes = Uint8List.fromList(img.encodeJpg(imagen));
      final salida = await prepararEvidencia('movil.jpg', bytes);
      final jpg = img.decodeJpg(salida.bytes)!;
      expect(jpg.width, 800);
      expect(jpg.height, 1600);
      expect(jpg.exif.imageIfd.orientation, isNull);
      expect(salida.mime, 'image/jpeg');
      await expectLater(
        prepararEvidencia('roto.jpg', Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    },
  );
  test('Comparación local de preparación de foto de 12 megapíxeles', () async {
    final entrada = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4000, height: 3000)),
    );
    final reloj = Stopwatch()..start();
    final vieja = await anterior.optimizarFoto(entrada);
    final antes = reloj.elapsedMilliseconds;
    reloj.reset();
    final nueva = await prepararEvidencia('foto.jpg', entrada);
    final despues = reloj.elapsedMilliseconds;
    expect(img.decodeJpg(nueva.bytes)!.width, 1600);
    expect(img.decodeJpg(vieja)!.width, 1600);
    // Medición orientativa; no imponer un umbral que dependa del equipo.
    // ignore: avoid_print
    print(
      'Preparación WEB 12 MP: Dart anterior ${antes}ms; navegador ${despues}ms.',
    );
  });
}
