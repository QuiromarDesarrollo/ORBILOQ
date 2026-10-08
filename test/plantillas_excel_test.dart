import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/plantillas_excel.dart';
import 'package:orbiloq_wms/data/excel_ordenes_parser.dart';
import 'package:orbiloq_wms/data/excel_fechas_parser.dart';
import 'package:orbiloq_wms/data/excel_ciclos.dart';
import 'package:orbiloq_wms/data/clientes_empaque_excel.dart';

void fila(Excel libro, String hoja, Map<String, String> valores) {
  final h = libro[hoja];
  final headers = h.rows.first;
  h.appendRow([for (final c in headers) TextCellValue(valores['${c?.value}'] ?? '')]);
}
Uint8List bytes(Excel e) => Uint8List.fromList(e.save()!);
void main() {
  for (final tipo in PlantillaExcel.values) {
    test('plantilla ${tipo.name} vacía con instrucciones y encabezados únicos', () {
      final e = Excel.decodeBytes(PlantillasExcel.generar(tipo));
      expect(e.tables.containsKey('Instrucciones'), isTrue);
      for (final h in e.tables.values.where((h) => h.sheetName != 'Instrucciones')) {
        expect(h.rows.length, 1);
        final columnas = h.rows.first.map((c) => '${c?.value}');
        expect(columnas.toSet().length, columnas.length);
      }
    });
  }
  test('órdenes completa acepta ambas hojas y conserva identificadores', () {
    final e = Excel.decodeBytes(PlantillasExcel.generar(PlantillaExcel.ordenes));
    fila(e, 'Orden', {'IDENTIFICADOR':'0001', 'CLIENTE':'Cliente', 'NO. OC':'OC1'});
    fila(e, 'Tallas', {'IDENTIFICADOR ORDEN':'0001','CODIGO':'P1','DESCRIPCION':'Camisa','TALLAS NOMBRE':'M','CANTIDAD':'10'});
    final r = ExcelOrdenesParser.parsear(bytes(e));
    expect(r.ordenes.single['identificador'], '0001');
    expect(r.tallas.single['oc'], 'OC1');
    expect(r.tallas.single['cantidad'], '10');
  });
  test('fechas acepta formato ISO', () {
    final e = Excel.decodeBytes(PlantillasExcel.generar(PlantillaExcel.fechas));
    fila(e, 'Fechas', {'N° DE ORDEN':'0001','FECHA PROD':'2026-10-07','FECHA LOG':'2026-10-09'});
    expect(ExcelFechasParser.parsear(bytes(e)).single['fecha_esperada_logistica'], '2026-10-09');
  });
  test('ciclos acepta fechas y procesos pendientes vacíos', () {
    final e = Excel.decodeBytes(PlantillasExcel.generar(PlantillaExcel.ciclos));
    fila(e, 'Historicos', {'N° DE ORDEN':'0001','CLIENTE':'Cliente','CANTIDAD':'10','FECHA DE INICIO':'2026-10-07','COMPRAS':'2026-10-08'});
    final r = ExcelCiclos.leer(bytes(e)).single;
    expect(r['cantidad'], 10);
    expect(r['fines']['compras'], '2026-10-08');
  });
  test('clientes respeta B:H y conserva ceros del NIT y teléfono', () {
    final e = Excel.decodeBytes(PlantillasExcel.generar(PlantillaExcel.clientes));
    fila(e, 'Clientes', {'NOMBRE':'Cliente','NIT':'00123','QUIEN RECIBE':'Ana','CIUDAD':'Bogotá','DIRECCION':'Calle 1','TELEFONO':'001234','CELULAR':'3000000000'});
    final r = leerClientesEmpaque(bytes(e)).single;
    expect(r['nombre'], 'Cliente');
    expect(r['nit'], '00123');
    expect(r['telefono'], '001234');
  });
}
