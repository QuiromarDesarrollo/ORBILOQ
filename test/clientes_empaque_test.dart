import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/clientes_empaque_excel.dart';

Uint8List archivo({bool formula = false, bool mal = false}) {
  final x = Excel.createExcel();
  final s = x['Clientes'];
  final headers = [
    '',
    'NIT',
    'QUIEN RECIBE',
    'CIUDAD',
    'DIRECCION',
    'TELEFONO',
    'CELULAR',
  ];
  for (var i = 0; i < headers.length; i++) {
    s
        .cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: 0))
        .value = TextCellValue(headers[i]);
  }
  s.cell(CellIndex.indexByString('B2')).value = TextCellValue('CLIENTE TEST');
  s.cell(CellIndex.indexByString('C2')).value = TextCellValue('00123');
  s.cell(CellIndex.indexByString('D2')).value =
      formula ? FormulaCellValue('1+1') : TextCellValue('ANA');
  if (mal) {
    s.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'COLUMNA DISTINTA',
    );
  }
  return Uint8List.fromList(x.encode()!);
}

void main() {
  test('Clientes conserva NIT con ceros y deja campos vacíos', () {
    final rows = leerClientesEmpaque(archivo());
    expect(rows.length, 1);
    expect(rows.single['nit'], '00123');
    expect(rows.single['telefono'], '');
    expect(rows.single['contacto'], 'ANA');
  });
  test('Rechaza columnas ajenas a la plantilla', () {
    expect(
      () => leerClientesEmpaque(archivo(mal: true)),
      throwsFormatException,
    );
  });
  test('No evalúa fórmulas', () {
    expect(
      () => leerClientesEmpaque(archivo(formula: true)),
      throwsFormatException,
    );
  });
}
