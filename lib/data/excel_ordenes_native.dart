import 'package:flutter/foundation.dart';
import 'excel_ordenes_parser.dart';

Future<ExcelOrdenesParseado> leerOrdenesAsync(Uint8List bytes) =>
    compute(ExcelOrdenesParser.parsear, bytes);
