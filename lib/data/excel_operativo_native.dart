import 'excel_inventario.dart';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'excel_fechas_parser.dart';
import 'excel_kardex.dart';

Future<List<FilaFechaEsperada>> leerFechasAsync(Uint8List bytes) =>
    compute(ExcelFechasParser.parsear, bytes);

Future<ArchivoKardex> leerKardexAsync(Uint8List bytes, Rol vista) =>
    compute(_leerKardex, (bytes, vista));

ArchivoKardex _leerKardex((Uint8List, Rol) entrada) =>
    ExcelKardex.leer(entrada.$1, entrada.$2);

Future<Map<String, dynamic>> leerInventarioAsync(Uint8List bytes) =>
    compute(ExcelInventario.leer, bytes);
