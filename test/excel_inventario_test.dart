import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_inventario.dart';

Uint8List archivo(List<List<CellValue?>> filas, {bool estante = true}) {
  final x = Excel.createExcel();
  final s = x[x.getDefaultSheet()!];
  s.appendRow(
    ExcelInventario.columnas
        .where((c) => estante || c != 'ESTANTE')
        .map(TextCellValue.new)
        .toList(),
  );
  for (final f in filas) {
    s.appendRow(f);
  }
  return Uint8List.fromList(x.encode()!);
}

List<CellValue?> fila({
  String ficha = 'LOGCOEAGCCA2025 V0',
  String cliente = 'L OREAL GROUP COLOMBIA',
  String talla = '30',
  String estante = 'RACK C3',
  CellValue? cantidad,
}) => [
  TextCellValue(ficha),
  TextCellValue(cliente),
  TextCellValue('0002026689028'),
  TextCellValue('OVEROL ENTERIZO'),
  TextCellValue(talla),
  cantidad ?? IntCellValue(14),
  TextCellValue(estante),
];
void main() {
  test(
    'Suma repetidas y conserva cliente, versión, talla, estante y ceros del código',
    () {
      final r = ExcelInventario.leer(
        archivo([
          fila(),
          fila(ficha: ' logcoeagcca2025   v0 ', cantidad: IntCellValue(6)),
          fila(talla: '32'),
          fila(cliente: 'OTRO'),
          fila(ficha: 'LOGCOEAGCCA2025 V1'),
          fila(estante: 'RACK C4'),
        ]),
      );
      final filas = r['filas'] as List;
      expect(filas.length, 5);
      expect(filas.where((e) => e['cantidad'] == 20).length, 1);
      expect(filas.every((e) => e['codigo'] == '0002026689028'), isTrue);
    },
  );
  test(
    'Rechaza faltantes y cantidades inválidas sin importar parcialmente',
    () {
      for (final n in [
        IntCellValue(0),
        IntCellValue(-1),
        DoubleCellValue(1.5),
        TextCellValue('1.000'),
        FormulaCellValue('2+2'),
      ]) {
        expect(
          () => ExcelInventario.leer(archivo([fila(), fila(cantidad: n)])),
          throwsFormatException,
        );
      }
      expect(
        (ExcelInventario.leer(archivo([fila()], estante: false))['filas']
                as List)
            .single['estante'],
        '',
      );
      expect(
        (ExcelInventario.leer(archivo([fila(estante: '')]))['filas'] as List)
            .single['estante'],
        '',
      );
    },
  );
  test('Rechaza dos hojas compatibles para evitar importar la equivocada', () {
    final x = Excel.decodeBytes(archivo([fila()]));
    x.copy(x.getDefaultSheet()!, 'Otra');
    expect(
      () => ExcelInventario.leer(Uint8List.fromList(x.encode()!)),
      throwsFormatException,
    );
  });
  test('Plantilla tiene las siete columnas y no añade datos de ejemplo', () {
    final x = Excel.decodeBytes(ExcelInventario.plantilla());
    expect(
      x['Inventario'].rows.single.map((e) => e?.value.toString()).toList(),
      ExcelInventario.columnas,
    );
  });
}
