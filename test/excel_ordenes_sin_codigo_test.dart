import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';

ExcelOrdenesParseado leer(
  List<List<String>> filas, {
  bool columnaCodigo = true,
}) {
  final x = Excel.createExcel();
  x['Orden'].appendRow(
    ['Identificador', 'No. OC'].map(TextCellValue.new).toList(),
  );
  x['Orden'].appendRow(
    ['25309', '366 y 366-1'].map(TextCellValue.new).toList(),
  );
  x['Tallas'].appendRow(
    [
      'Identificador orden',
      if (columnaCodigo) 'Código',
      'Tallas nombre',
      'Cantidad',
      'Descripción',
      'Observación',
    ].map(TextCellValue.new).toList(),
  );
  for (final fila in filas) {
    x['Tallas'].appendRow(
      [
        fila[0],
        if (columnaCodigo) fila[1],
        ...fila.skip(2),
      ].map(TextCellValue.new).toList(),
    );
  }
  return ExcelOrdenesParser.parsear(Uint8List.fromList(x.encode()!));
}

void main() {
  final especial = [
    '25309',
    '',
    'ESPECIAL',
    '2',
    'Pantalón especial',
    'Medidas particulares',
  ];
  test(
    'Acepta todas las tallas sin código y conserva datos y códigos originales',
    () {
      final resultado = leer([
        especial,
        ['25309', '2026356930', '34', '4', 'Pantalón', ''],
        ['25309', '  ', 'M', '3', 'Camisa', ''],
      ]);
      expect(resultado.tallas[0]['codigo'], startsWith('SIN-COD-ERP-'));
      expect(resultado.tallas[0]['cantidad'], '2');
      expect(resultado.tallas[0]['oc'], '366 y 366-1');
      expect(resultado.tallas[0]['observacion'], 'Medidas particulares');
      expect(resultado.tallas[1]['codigo'], '2026356930');
      expect(resultado.tallas[2]['codigo'], startsWith('SIN-COD-ERP-'));
      expect(resultado.tallas.map((r) => r['codigo']).toSet().length, 3);
    },
  );
  test('Columna código ausente también es válida', () {
    expect(
      leer([especial], columnaCodigo: false).tallas.single['codigo'],
      startsWith('SIN-COD-ERP-'),
    );
  });
  test('Identidad estable entre cargas y al cambiar orden o cantidad', () {
    final otra = ['25309', '', 'M', '5', 'Camisa', ''];
    final a = leer([especial, otra]);
    final b = leer([
      otra,
      [...especial]..[3] = '7',
    ]);
    expect(a.tallas[0]['codigo'], b.tallas[1]['codigo']);
    expect(a.tallas[1]['codigo'], b.tallas[0]['codigo']);
  });
  test('Filas repetidas sin código no se pierden por conflicto', () {
    final r = leer([especial, especial]);
    expect(r.tallas[0]['codigo'], isNot(r.tallas[1]['codigo']));
    expect(r.tallas.fold<int>(0, (s, r) => s + int.parse(r['cantidad']!)), 4);
  });
}
