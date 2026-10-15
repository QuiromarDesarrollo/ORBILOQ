import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_flujo_acumulado.dart';
import 'dashboard_atencion_test.dart' show lineaAtencion;

void main() {
  test('Porcentajes usan la base correspondiente sin ocultar excesos', () {
    expect(porcentajeFlujo(50, 100), '50 %');
    expect(porcentajeFlujo(30, 50), '60 %');
    expect(porcentajeFlujo(28, 30), '93,3 %');
    expect(porcentajeFlujo(5, 0), '—');
    expect(porcentajeFlujo(56, 55), '101,8 %');
  });
  test('Pendiente por línea no compensa faltantes con excedentes', () {
    final flujo = FlujoAcumulado([
      lineaAtencion('1', producido: 20),
      lineaAtencion('1', id: 'otra-talla', producido: 4),
      lineaAtencion('2', producido: 0),
      lineaAtencion('3', eliminada: true),
    ]);
    expect(flujo.pedidas, 30);
    expect(flujo.entregado, 24);
    expect(flujo.pendienteEntrega, 16);
  });
  test('Compara saldos de las mismas OP y excluye líneas eliminadas', () {
    final flujo = FlujoAcumulado([
      lineaAtencion('1', producido: 150, recibido: 130, despachado: 102),
      lineaAtencion('2', producido: 20, recibido: 10),
      lineaAtencion('3', producido: 999, recibido: 999, eliminada: true),
    ]);
    expect(flujo.entregado, 170);
    expect(flujo.recibido, 140);
    expect(flujo.despachado, 102);
    expect(flujo.ordenes, {'1', '2'});
    expect(flujo.inconsistencias, isEmpty);
  });

  test(
    'Un saldo positivo de otra talla no oculta un despacho sin recepción',
    () {
      final flujo = FlujoAcumulado([
        lineaAtencion('1', id: 'M', recibido: 5, despachado: 8),
        lineaAtencion('1', id: 'L', recibido: 100),
        lineaAtencion('2', recibido: 0, despachado: 3),
      ]);
      expect(flujo.inconsistencias.map((k) => k.item.id), ['M', '2']);
      expect(flujo.recibido, 105);
      expect(flujo.despachado, 11);
    },
  );
}
