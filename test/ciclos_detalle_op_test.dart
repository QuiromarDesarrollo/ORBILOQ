import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_detalle_op.dart';

void main() {
  final inicio = DateTime.utc(2026, 6, 1);
  final parametros = [
    for (final p in ProcesoCiclo.values)
      ParametroCiclo(p.name, p, inicio, p.diasIniciales, null, null),
  ];
  final ordenes = [
    for (var n = 1; n <= 23; n++)
      OrdenCiclo(
        'OP-$n',
        'Cliente $n',
        150,
        inicio,
        List.generate(
          7,
          (i) => n == 1 ? inicio.add(Duration(days: (i + 1) * 2)) : null,
        ),
        {for (final p in ProcesoCiclo.values) p.name: p.name},
      ),
  ];
  final datos = DatosCiclos(
    ordenes,
    parametros,
    DateTime.utc(2026, 7, 1),
    'test',
  );
  for (final ancho in [360.0, 1280.0]) {
    testWidgets('Detalle responsive $ancho y búsqueda por cliente', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CiclosDetalleOp(datos: datos, ordenes: ordenes),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Cliente 1');
      await tester.pumpAndSettle();
      expect(find.text('OP-2'), findsNothing);
      await tester.tap(find.text('OP-1'));
      await tester.pumpAndSettle();
      expect(find.text('Compras'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(
        find.text('No hay OP que coincidan con los filtros.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Paginación y filtros de estado', (tester) async {
    tester.view.physicalSize = const Size(1280, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CiclosDetalleOp(datos: datos, ordenes: ordenes),
          ),
        ),
      ),
    );
    expect(find.text('Mostrando 1–20 de 23 OP'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrando 21–23 de 23 OP'), findsOneWidget);
    await tester.ensureVisible(find.text('En proceso'));
    await tester.tap(find.text('En proceso'));
    await tester.pumpAndSettle();
    expect(find.text('OP-1'), findsNothing);
    expect(find.text('Mostrando 1–20 de 22 OP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
