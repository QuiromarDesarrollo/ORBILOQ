import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<Uint8List?> tomarFotoConductor(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Abre el portal en el navegador del dispositivo para usar la cámara, o selecciona una foto guardada.',
      ),
    ),
  );
  return null;
}
