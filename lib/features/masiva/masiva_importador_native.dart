import 'package:flutter/foundation.dart';
import 'masiva_importador_modelo.dart';
import 'masiva_importador_parser.dart';

Future<MasivaImportacion> leerMasivaExcel(
  Uint8List bytes, {
  required String tipo,
}) => compute(_leer, (bytes, tipo));

MasivaImportacion _leer((Uint8List, String) entrada) =>
    parsearMasivaExcel(entrada.$1, tipo: entrada.$2);
