import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/trazabilidad_op_exportador.dart';

void main() {
  test('OP con varias LE conserva fechas, texto y resumen sin duplicados', () {
    final f = <String, dynamic>{
      'item_id': 'i1',
      'op': '001',
      'codigo': '0003',
      'cantidad': 20,
      'produccion_completa': true,
      'recepcion_completa': false,
      'fecha_produccion': '2026-10-09T03:00:00Z',
      'despacho_id': 'd1',
      'fase': 'despachado',
      'fecha_despachado': '2026-10-09T15:00:00Z',
      'fecha_liberado': '2026-10-09T16:00:00Z',
      'numero_guia': '000123',
      'placa': 'ABC123',
      'piezas': 2,
      'cantidad_le': 5,
      'placa_guia_historica': 'ANTERIOR',
    };
    final h = hojasTrazabilidadOp([
      f,
      {...f, 'despacho_id': 'd2', 'fase': 'empacado', 'fecha_despachado': null},
    ]);
    final a = h['Trazabilidad OP']![1];
    expect(a[0], '001');
    expect(a[6], 20);
    expect(a[7], '08/10/2026 22:00');
    expect(a[8], 'Parcial');
    expect(a[9], '09/10/2026 10:00');
    expect(a[10], '09/10/2026 11:00');
    expect(a[12], '000123');
    expect(a[13], 'ABC123');
    expect(a[14], 2);
    expect(a[18], 'ANTERIOR');
    expect(h['Trazabilidad OP']![2][9], 'Sin registro');
    expect(h['Trazabilidad OP']![2][10], 'Pendiente');
    expect(h['Resumen sin duplicados']!.length, 2);
  });
  test('OP sin despacho y entrega incompleta', () {
    final a =
        hojasTrazabilidadOp([
          {'item_id': 'i2', 'produccion_completa': false},
        ])['Trazabilidad OP']![1];
    expect(a[7], 'Parcial');
    expect(a[9], 'Pendiente');
    expect(a[19], 'Sin empaque');
  });
}
