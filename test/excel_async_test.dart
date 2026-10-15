import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_ordenes_async.dart';
import 'package:orbiloq_wms/data/excel_operativo_async.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/excel_fechas_parser.dart';
import 'package:orbiloq_wms/data/excel_kardex.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:excel/excel.dart';

void main() {
  test('lectores asíncronos conservan todas las filas y fechas', () async {
    final libro = Excel.createExcel();
    libro['Orden'].appendRow([
      TextCellValue('Identificador'),
      TextCellValue('Cliente'),
      TextCellValue('FECHA PROD'),
    ]);
    libro['Tallas'].appendRow([
      TextCellValue('Identificador orden'),
      TextCellValue('Codigo'),
      TextCellValue('Tallas nombre'),
      TextCellValue('Cantidad'),
    ]);
    for (var i = 0; i < 1000; i++) {
      libro['Orden'].appendRow([
        TextCellValue('00$i'),
        TextCellValue('Cliente'),
        DateCellValue(year: 2026, month: 10, day: 15),
      ]);
      libro['Tallas'].appendRow([
        TextCellValue('00$i'),
        TextCellValue('C01'),
        TextCellValue('M'),
        IntCellValue(i + 1),
      ]);
    }
      libro.delete('Sheet1');
      final bytes = Uint8List.fromList(libro.encode()!);
    final ordenes = await leerOrdenesAsync(bytes);
    final esperado = ExcelOrdenesParser.parsear(bytes);
    expect(ordenes.ordenes, esperado.ordenes);
    expect(ordenes.tallas, esperado.tallas);
    expect(ordenes.ordenes.length, 1000);
    expect(await leerFechasAsync(bytes), ExcelFechasParser.parsear(bytes));
  });
  test('Kardex conserva versión y rechaza otra vista', () async {
    final bytes = ExcelKardex.generar(
      ArchivoKardex(Rol.produccion, 'v1', [
        {
          'numero_op': '001',
          'codigo': 'C01',
          'talla': 'M',
          'descripcion': 'Camisa',
          'cliente': 'Cliente',
          'cantidad_pedida': 100,
          'producido': 10,
          'pendiente_reproceso': 0,
        },
      ]),
    );
    final archivo = await leerKardexAsync(bytes, Rol.produccion);
    expect(archivo.version, 'v1');
    expect(archivo.filas, ExcelKardex.leer(bytes, Rol.produccion).filas);
    await expectLater(
      leerKardexAsync(bytes, Rol.logistica),
      throwsFormatException,
    );
  });
  test('archivos corruptos producen errores recuperables', () async {
    final bytes = Uint8List.fromList([1, 2]);
    await expectLater(
      leerOrdenesAsync(bytes),
      throwsA(isA<ExcelOrdenesParseException>()),
    );
    await expectLater(
      leerFechasAsync(bytes),
      throwsA(isA<ExcelFechasParseException>()),
    );
  });
}
