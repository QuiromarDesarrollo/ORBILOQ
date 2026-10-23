import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/historial_recepcion_vista.dart';
import 'package:orbiloq_wms/shared/widgets/historial_agrupado.dart';

void main() {
  testWidgets(
    'Bodega agrupa por día, conserva detalle y combina búsqueda, estado y fecha',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialRecepcionVista(
              grupos: [
                GrupoHistorial(
                  id: 'item',
                  op: '123',
                  titulo: 'OP 123 · Camisa · Talla M',
                  detalle: 'Código: CAM | Cliente: Quiromar | OC: 456',
                  eventos: [
                    EventoHistorial(
                      id: 'a',
                      titulo: 'Conforme',
                      detalle: 'Estante A · Ana',
                      fecha: DateTime(2026, 10, 21),
                      cantidad: 5,
                    ),
                    EventoHistorial(
                      id: 'b',
                      titulo: 'Recepción parcial',
                      detalle: 'Estante B · Luis · Daño',
                      fecha: DateTime(2026, 10, 22),
                      cantidad: 2,
                    ),
                  ],
                ),
              ],
              novedades: const {'b'},
              parciales: const {'b'},
              enviadas: const {'a': 5, 'b': 4},
            ),
          ),
        ),
      );
      expect(find.text('21/10/2026'), findsOneWidget);
      expect(find.text('22/10/2026'), findsOneWidget);
      expect(find.text('5 de 5'), findsOneWidget);
      expect(find.text('2 de 4'), findsOneWidget);
      await tester.tap(find.text('OP 123 · Camisa · Talla M').first);
      await tester.pumpAndSettle();
      expect(find.text('Estante B · Luis · Daño'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Quiromar');
      await tester.pumpAndSettle();
      expect(find.text('OP 123 · Camisa · Talla M'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('Conformes'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 de 4'), findsNothing);
      expect(find.text('5 de 5'), findsOneWidget);
      await tester.tap(find.text('Fecha: todas'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
        DateTimeRange(
          start: DateTime(2026, 10, 22),
          end: DateTime(2026, 10, 22),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No hay recepciones con estos filtros.'),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('Todas'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 de 4'), findsOneWidget);
      expect(find.text('5 de 5'), findsNothing);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2 de 4'), findsOneWidget);
    },
  );
}
