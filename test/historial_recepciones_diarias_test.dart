import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/historial_recepciones.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/historial_recepcion_vista.dart';

void main() {
  const item = ItemOrden(
    id: 'i',
    op: '90006',
    cliente: 'Cliente',
    oc: 'OC',
    codigo: 'C',
    descripcion: 'Camisa',
    talla: 'L',
    cantidadPedida: 10,
  );
  final snapshot = WmsSnapshot(
    kardex: [],
    lotes: [
      Lote(
        id: '123',
        operario: 'Ana',
        fechaEnvio: DateTime(2026, 10, 19),
        lineas: [
          LoteLinea(
            id: 'linea',
            item: item,
            cantidadEnviada: 10,
            cantidadRecibida: 10,
          ),
        ],
      ),
    ],
  );
  Movimiento movimiento(int cantidad, int dia, {String itemId = 'i'}) =>
      Movimiento(
        tipo: TipoMovimiento.recepcion,
        itemId: itemId,
        cantidad: cantidad,
        fecha: DateTime(2026, 10, dia, 10),
        loteId: 'uuid',
        loteLineaId: itemId == 'i' ? 'linea' : null,
      );
  test('Conserva cada recepción parcial y la fecha de entrega original', () {
    final eventos =
        historialRecepcionesDiarias([
          movimiento(4, 20),
          movimiento(6, 21),
        ], snapshot).single.eventos;
    expect(eventos.map((e) => e.cantidad), [4, 6]);
    expect(eventos.map((e) => e.fecha!.day), [20, 21]);
    expect(eventos.first.detalle, contains('19/10/2026'));
    expect(eventos.first.detalle, contains('Lote: 123'));
  });
  test('Conserva ajustes y referencias antiguas sin metadatos', () {
    final grupos = historialRecepcionesDiarias([
      movimiento(4, 20),
      movimiento(-1, 20),
      movimiento(2, 20, itemId: 'antiguo'),
    ], snapshot);
    expect(
      grupos.expand((g) => g.eventos).fold<int>(0, (s, e) => s + e.cantidad!),
      5,
    );
    expect(
      grupos.last.eventos.single.detalle,
      contains('Sin registro vinculado'),
    );
  });
  testWidgets('El filtro diario suma movimientos y funciona en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistorialRecepcionVista(
            grupos: historialRecepcionesDiarias([
              movimiento(4, 20),
              movimiento(6, 21),
            ], snapshot),
            novedades: const {},
            parciales: const {},
            movimientosReales: true,
          ),
        ),
      ),
    );
    expect(find.text('Recibidas netas en el período'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.tap(find.text('Fecha: todas'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 20)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('4 prendas netas'), findsOneWidget);
    expect(find.text('21/10/2026'), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('4 prendas netas'), findsOneWidget);
  });
}
