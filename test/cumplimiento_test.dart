import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/cumplimiento.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/application/kardex_columnas.dart';
import 'package:orbiloq_wms/application/kardex_filters.dart';

void main() {
  final esperada = DateTime(2026, 9, 30);
  test('Entrega completa no sigue venciendo con el paso del tiempo', () {
    for (final caso in [
      (DateTime(2026, 9, 28), -2, ResultadoCumplimiento.aTiempo, 'Entregado 2 días antes'),
      (DateTime(2026, 9, 30, 23, 59), 0, ResultadoCumplimiento.aTiempo, 'Entregado en fecha'),
      (DateTime(2026, 10, 5), 5, ResultadoCumplimiento.conRetraso, 'Entregado 5 días tarde'),
    ]) {
      final valor = Cumplimiento.calcular(completa: true, esperada: esperada,
        real: caso.$1, hoy: DateTime(2027));
      expect(valor.diasDesviacion, caso.$2);
      expect(valor.resultado, caso.$3);
      expect(valor.detalle, caso.$4);
    }
  });
  test('Pendientes y parciales usan hoy aunque haya entrega previa', () {
    for (final caso in [
      (DateTime(2026, 9, 25), 'Faltan 5 días', ResultadoCumplimiento.pendiente),
      (DateTime(2026, 9, 30), 'Vence hoy', ResultadoCumplimiento.pendiente),
      (DateTime(2026, 10, 5), 'Vencido 5 días', ResultadoCumplimiento.vencido),
    ]) {
      final valor = Cumplimiento.calcular(completa: false, esperada: esperada,
        real: DateTime(2026, 9, 28), hoy: caso.$1);
      expect(valor.detalle, caso.$2);
      expect(valor.resultado, caso.$3);
    }
  });
  test('Sin fechas no inventa cumplimiento ni días', () {
    for (final fechas in [(null, esperada), (esperada, null)]) {
      final valor = Cumplimiento.calcular(completa: true,
        esperada: fechas.$1, real: fechas.$2);
      expect(valor.resultado, ResultadoCumplimiento.sinDatos);
      expect(valor.diasDesviacion, isNull);
    }
  });
  test('Cada rol usa su cantidad y fecha; filtros coinciden con el detalle', () {
    final fila = ItemKardex(item: const ItemOrden(id: '1', op: '1', cliente: 'A',
      oc: 'OC', codigo: 'C', descripcion: 'Camisa', talla: 'M', cantidadPedida: 20),
      producido: 20, recibido: 20, despachado: 20, ubicaciones: const {},
      fechaEntrega: DateTime(2026, 9, 28), fechaDespacho: DateTime(2026, 10, 5),
      fechaEsperadaProduccion: esperada, fechaEsperadaLogistica: esperada);
    expect(fila.cumplimientoProduccion().resultado, ResultadoCumplimiento.aTiempo);
    expect(fila.cumplimientoLogistica().resultado, ResultadoCumplimiento.conRetraso);
    expect(columnasProduccion[ColKardex.diasFaltantes]!(fila), 'Entregado 2 días antes');
    expect(columnasDespacho[ColKardex.diasFaltantesBodega]!(fila), 'Entregado 5 días tarde');
  });
}
