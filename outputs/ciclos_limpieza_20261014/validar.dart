import 'dart:io';
import '../../lib/data/excel_ciclos.dart';
void main() {
 final reloj = Stopwatch()..start();
 final rows = ExcelCiclos.leer(File('outputs/ciclos_limpieza_20261014/plantilla_ciclos_reorganizada.xlsx').readAsBytesSync());
 if (rows.length != 7739 || rows.map((r)=>r['op']).toSet().length != 7739) throw StateError('Conteo incorrecto');
 print('IMPORTADOR REAL OK: 7739 OP unicas; ${reloj.elapsedMilliseconds} ms');
}

