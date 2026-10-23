import 'dart:typed_data';
import '../../../shared/widgets/wms_alert.dart';
import 'package:flutter/material.dart';

Future<Uint8List?> tomarFotoConductor(BuildContext context) async {
  await mostrarAviso(
    context,
    'Abre el portal en el navegador del dispositivo para usar la cámara, o selecciona una foto guardada.',
  );
  return null;
}
