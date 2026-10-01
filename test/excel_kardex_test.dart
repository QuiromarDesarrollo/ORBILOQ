import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/excel_kardex.dart';
import 'package:orbiloq_wms/domain/models.dart';

Map<String, dynamic> fila() => {
      'item_orden_id': '11111111-1111-1111-1111-111111111111',
      'numero_op': '00012',
      'descripcion': 'Camisa',
      'codigo': '0003',
      'talla': 'M',
      'cliente': 'Cliente',
      'oc': '0009',
      'observacion_op': 'Urgente',
      'cantidad_pedida': 20,
      'producido': 10,
      'recibido': 8,
      'despachado': 2,
      'pendiente_reproceso': 0,
      'fecha_ultima_entrega': '2026-10-01',
      'fecha_esperada_produccion': null,
      'fecha_esperada_logistica': '2026-10-05',
      'ubicacion_ajuste': '',
    };
void main() {
  for (final vista in Rol.values) {
    test('Excel de ${vista.name} conserva identidades, cantidades y fechas',
        () {
      final bytes =
          ExcelKardex.generar(ArchivoKardex(vista, 'version', [fila()]));
      final res = ExcelKardex.leer(bytes, vista);
      expect(res.version, 'version');
      expect(res.filas.single['numero_op'], '00012');
      expect(res.filas.single['codigo'], '0003');
      expect(res.filas.single['cantidad_pedida'], 20);
      expect(res.filas.single['fecha_ultima_entrega'], '2026-10-01');
      expect(res.filas.single.containsKey('estado'), isFalse);
      expect(res.filas.single.containsKey('recibido'), vista == Rol.logistica);
    });
  }
  test('rechaza vista incorrecta, vacíos, duplicados y cantidades negativas',
      () {
    final bytes =
        ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', [fila()]));
    expect(() => ExcelKardex.leer(bytes, Rol.logistica), throwsFormatException);
    for (final filas in <List<Map<String, dynamic>>>[
      [],
      [fila(), fila()],
      [
        {...fila(), 'producido': -1}
      ]
    ]) {
      expect(
          () => ExcelKardex.leer(
              ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', filas)),
              Rol.produccion),
          throwsFormatException);
    }
  });
  test('rechaza fechas inexistentes y fórmulas en entradas', () {
    expect(
        () => ExcelKardex.leer(
            ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', [
              {...fila(), 'fecha_ultima_entrega': '2026-02-30'}
            ])),
            Rol.produccion),
        throwsFormatException);
    final libro = Excel.decodeBytes(
        ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', [fila()])));
    final c = ExcelKardex.columnas(Rol.produccion)
        .keys
        .toList()
        .indexOf('cantidad_pedida');
    libro['Kardex']
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
        .value = FormulaCellValue('10+10');
    expect(
        () =>
            ExcelKardex.leer(Uint8List.fromList(libro.save()!), Rol.produccion),
        throwsFormatException);
  });
  test('acepta fecha nativa de Excel', () {
    final libro = Excel.decodeBytes(
        ExcelKardex.generar(ArchivoKardex(Rol.produccion, 'v', [fila()])));
    final c = ExcelKardex.columnas(Rol.produccion)
        .keys
        .toList()
        .indexOf('fecha_ultima_entrega');
    libro['Kardex']
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
        .value = DateCellValue(year: 2026, month: 10, day: 2);
    final res =
        ExcelKardex.leer(Uint8List.fromList(libro.save()!), Rol.produccion);
    expect(res.filas.single['fecha_ultima_entrega'], '2026-10-02');
  });
}
