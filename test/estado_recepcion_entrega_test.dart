import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/estado_recepcion_entrega.dart';
import 'package:orbiloq_wms/shared/widgets/historial_agrupado.dart';

void main() {
  test('Completado exige recibir toda la entrega', () {
    expect(EstadoRecepcionEntrega.calcular(10, 0), EstadoRecepcionEntrega.pendiente);
    expect(EstadoRecepcionEntrega.calcular(10, 4), EstadoRecepcionEntrega.parcial);
    expect(EstadoRecepcionEntrega.calcular(10, 10), EstadoRecepcionEntrega.completado);
    expect(EstadoRecepcionEntrega.calcular(0, 0), EstadoRecepcionEntrega.pendiente);
  });

  testWidgets('Estado visible al cerrar card, por entrega y según filtro de envío', (tester) async {
    Widget vista(int recibidas) => MaterialApp(home: Scaffold(body: HistorialAgrupado(
      grupos: [GrupoHistorial(id: 'op', op: '1', titulo: 'OP 1', detalle: '', eventos: [
        EventoHistorial(id: 'a', titulo: 'Entrega A', detalle: '', fecha: DateTime(2026, 10, 1), cantidad: 10, cantidadRecibida: 10),
        EventoHistorial(id: 'b', titulo: 'Entrega B', detalle: '', fecha: DateTime(2026, 10, 2), cantidad: 10, cantidadRecibida: recibidas),
      ])],
    )));
    await tester.pumpWidget(vista(0));
    expect(find.text('Recibido parcial'), findsOneWidget);
    expect(find.text('Entrega A'), findsNothing);
    expect(find.text('Recepción actual de las entregas: 10 de 20 prendas'), findsOneWidget);
    await tester.tap(find.text('OP 1'));
    await tester.pumpAndSettle();
    expect(find.text('Completado'), findsOneWidget);
    expect(find.text('Pendiente por recibir'), findsOneWidget);
    await tester.pumpWidget(vista(10));
    await tester.pumpAndSettle();
    expect(find.text('Completado'), findsNWidgets(3));
    expect(find.text('Recibido parcial'), findsNothing);
    await tester.tap(find.text('Filtrar por fecha'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 2)));
    await tester.pumpAndSettle();
    expect(find.text('Recepción actual de las entregas filtradas: 10 de 10 prendas'), findsOneWidget);
    expect(find.text('Entrega A'), findsNothing);
  });
}
