import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/historial_agrupado.dart';

void main() {
  testWidgets('Contador común separa etapas y aplica fecha sin duplicarlas', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HistorialAgrupado(
      grupos: [GrupoHistorial(id: '1', op: '90001', titulo: 'OP 90001', detalle: '', eventos: [
        EventoHistorial(id: 'envio', titulo: 'Envío', detalle: '', fecha: DateTime(2026, 9, 1), cantidad: 10, categoriaCantidad: 'Prendas enviadas'),
        EventoHistorial(id: 'liberacion', titulo: 'Liberación', detalle: '', fecha: DateTime(2026, 9, 2), cantidad: 4, categoriaCantidad: 'Prendas liberadas'),
      ])],
    ))));
    expect(find.text('Prendas enviadas: 10'), findsOneWidget);
    expect(find.text('Prendas liberadas: 4'), findsOneWidget);
    expect(find.textContaining('14 Uds'), findsNothing);
    await tester.tap(find.text('Filtrar por fecha'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(start: DateTime(2026, 9, 2), end: DateTime(2026, 9, 2)));
    await tester.pumpAndSettle();
    expect(find.text('Prendas enviadas: 0'), findsOneWidget);
    expect(find.text('Prendas liberadas: 4'), findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Prendas enviadas: 10'), findsOneWidget);
  });

  testWidgets('Historial vacío conserva un contador en cero', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HistorialAgrupado(
      etiquetaTotal: 'Prendas despachadas', grupos: [],
    ))));
    expect(find.text('Prendas despachadas: 0'), findsOneWidget);
  });
  test('OP y fecha son independientes y se combinan incluyendo ambos días', () {
    final rango =
        DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 2));
    expect(coincideHistorial('90001', null, ' 900 ', null), isTrue);
    expect(coincideHistorial('90001', DateTime(2026, 9, 1), '', rango), isTrue);
    expect(
        coincideHistorial(
            '90001', DateTime(2026, 9, 2, 23, 59), '90001', rango),
        isTrue);
    expect(coincideHistorial('90002', DateTime(2026, 9, 2), '90001', rango),
        isFalse);
    expect(coincideHistorial('90001', DateTime(2026, 9, 3), '90001', rango),
        isFalse);
    expect(coincideHistorial('90001', null, '', rango), isFalse);
  });

  testWidgets(
      'Filtra eventos dentro de la tarjeta y permite limpiar cada filtro',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GrupoHistorial grupo(String op) => GrupoHistorial(
            id: op,
            op: op,
            titulo: 'OP $op',
            detalle: 'Contexto',
            eventos: [
              EventoHistorial(
                  id: 'a',
                  titulo: 'Anterior $op',
                  detalle: 'Ana',
                  fecha: DateTime(2026, 9, 1),
                  cantidad: 5),
              EventoHistorial(
                  id: 'b',
                  titulo: 'Reciente $op',
                  detalle: 'Carlos',
                  fecha: DateTime(2026, 9, 2),
                  cantidad: 10),
            ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                HistorialAgrupado(
                  grupos: [grupo('90001'), grupo('90002')],
                  gruposRecepciones: [grupo('90001'), grupo('90002')],
                ))));
    expect(find.text('Prendas recibidas: 30'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '90001');
    await tester.pumpAndSettle();
    expect(find.text('OP 90002'), findsNothing);
    expect(find.text('15 Uds en el filtro'), findsOneWidget);
    expect(find.text('Prendas recibidas: 15'), findsOneWidget);
    expect(find.text('Anterior 90001'), findsNothing);
    await tester.tap(find.text('OP 90001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrar por fecha'));
    await tester.pumpAndSettle();
    // El selector nativo devuelve el rango elegido al control común.
    final picker = tester.element(find.byType(DateRangePickerDialog));
    Navigator.of(picker).pop(
        DateTimeRange(start: DateTime(2026, 9, 2), end: DateTime(2026, 9, 2)));
    await tester.pumpAndSettle();
    expect(find.text('Anterior 90001'), findsNothing);
    expect(find.text('Reciente 90001'), findsOneWidget);
    expect(find.text('10 Uds en el filtro'), findsOneWidget);
    expect(find.text('Prendas recibidas: 10'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpiar OP'));
    await tester.pumpAndSettle();
    expect(find.text('OP 90002'), findsOneWidget);
    expect(find.text('Prendas recibidas: 20'), findsOneWidget);
    expect(find.text('Anterior 90001'), findsNothing);
    await tester.tap(find.byTooltip('Quitar filtro de fecha'));
    await tester.pumpAndSettle();
    expect(find.text('Prendas recibidas: 30'), findsOneWidget);
    expect(find.text('Anterior 90001'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'NO EXISTE');
    await tester.pumpAndSettle();
    expect(find.text('Prendas recibidas: 0'), findsOneWidget);
    expect(find.text('No hay movimientos que coincidan con los filtros.'),
        findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Anterior 90001'), findsOneWidget);
  });
}
