import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/reproceso/presentation/historial_liberaciones.dart';

void main() {
  testWidgets(
      'Agrupa entregas sin mezclar tallas y conserva su orden y responsables',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ItemOrden item(String talla) => ItemOrden(
        id: talla,
        op: '90001',
        cliente: 'Cliente',
        oc: 'OC1',
        codigo: 'DEMO-002',
        descripcion: 'CAMISETA',
        talla: talla,
        cantidadPedida: 20);
    Liberacion evento(
            String id, String talla, int cantidad, int hora, String recibido) =>
        Liberacion(
            id: id,
            item: item(talla),
            cantidad: cantidad,
            operario: 'Operario $id',
            fecha: DateTime(2026, 9, 30, hora),
            recibidoPorLogistica: recibido,
            nota: 'Nota $id');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HistorialLiberaciones(
      liberaciones: [
        evento('b', 'M', 5, 11, 'Carlos'),
        evento('c', 'S', 2, 9, ''),
        evento('a', 'M', 10, 8, 'Ana')
      ],
    ))));
    final grupo = find.byKey(const ValueKey('historial-M'));
    expect(grupo, findsOneWidget);
    expect(find.text('Liberación · 10 Uds'), findsNothing);
    await tester.tap(find.text('OP: 90001 - CAMISETA (M)'));
    await tester.pumpAndSettle();
    expect(find.text('15 Uds en total'), findsOneWidget);
    expect(find.text('2 movimiento(s)'), findsOneWidget);
    expect(find.textContaining('Recibido por Logística: Ana'), findsOneWidget);
    expect(
        find.textContaining('Recibido por Logística: Carlos'), findsOneWidget);
    expect(find.textContaining('Nota: Nota a'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Liberación · 10 Uds')).dy,
        lessThan(tester.getTopLeft(find.text('Liberación · 5 Uds')).dy));
    expect(find.byKey(const ValueKey('historial-S')), findsOneWidget);
    expect(find.textContaining('Recibido por Logística: Sin registrar'),
        findsNothing);
    await tester.tap(find.text('OP: 90001 - CAMISETA (M)'));
    await tester.pumpAndSettle();
    expect(find.text('Liberación · 10 Uds'), findsNothing);
    expect(find.text('15 Uds en total'), findsOneWidget);
    await tester.tap(find.text('OP: 90001 - CAMISETA (S)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recibido por Logística: Sin registrar'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
