// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart' as nuevo;
import 'dart:io';
import 'dart:convert';
import 'package:orbiloq_wms/data/excel_fechas_parser.dart';
import 'package:orbiloq_wms/data/excel_kardex.dart';
import 'package:orbiloq_wms/domain/models.dart';

void main() {
  final kardex = ExcelKardex.generar(
    ArchivoKardex(Rol.produccion, 'v-test', [
      {
        'numero_op': '00012',
        'codigo': 'C01',
        'talla': 'M',
        'cliente': 'Cliente',
        'descripcion': 'Camisa',
        'cantidad_pedida': 20,
        'producido': 10,
        'pendiente_reproceso': 0,
      },
    ]),
  );
  final leido = ExcelKardex.leer(kardex, Rol.produccion);
  File('.dart_tool/kardex-benchmark.xlsx').writeAsBytesSync(kardex);
  File('.dart_tool/kardex-benchmark.json').writeAsStringSync(
    jsonEncode({'filas': leido.filas, 'version': leido.version}),
  );

  for (final n in [200, 1000, 2500]) {
    final x = Excel.createExcel();
    x['Orden'].appendRow([
      TextCellValue('Identificador'),
      TextCellValue('Cliente'),
      TextCellValue('No. OC'),
      TextCellValue('FECHA PROD'),
    ]);
    x['Tallas'].appendRow([
      TextCellValue('Identificador orden'),
      TextCellValue('Codigo'),
      TextCellValue('Tallas nombre'),
      TextCellValue('Cantidad'),
    ]);
    x.delete('Sheet1');
    for (var i = 0; i < n; i++) {
      x['Orden'].appendRow([
        TextCellValue('$i'),
        TextCellValue('CLIENTE'),
        TextCellValue('OC-$i'),
        TextCellValue('2026-10-15'),
      ]);
      x['Tallas'].appendRow([
        TextCellValue('$i'),
        TextCellValue('COD'),
        TextCellValue('M'),
        IntCellValue(10),
      ]);
    }
    final bytes = Uint8List.fromList(x.encode()!);
    final t = Stopwatch()..start();
    final b = nuevo.ExcelOrdenesParser.parsear(bytes);
    t.stop();
    if (b.ordenes.length != n || b.tallas.length != n) {
      throw StateError('Cantidad inesperada');
    }
    File('.dart_tool/erp-benchmark.xlsx').writeAsBytesSync(bytes);
    File(
      '.dart_tool/erp-benchmark.json',
    ).writeAsStringSync(jsonEncode({'ordenes': b.ordenes, 'tallas': b.tallas}));
    File('.dart_tool/fechas-benchmark.json').writeAsStringSync(
      jsonEncode({'filas': ExcelFechasParser.parsear(bytes)}),
    );
    print('$n OP + $n tallas: ${t.elapsedMilliseconds}ms');
  }
}
