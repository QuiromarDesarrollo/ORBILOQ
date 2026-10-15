import 'package:flutter/foundation.dart';
import 'excel_ciclos.dart';

Future<List<Map<String, dynamic>>> leerCiclosAsync(Uint8List bytes) =>
    compute(ExcelCiclos.leer, bytes);
