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
        cantidadPedida: 20,
      );
      Liberacion evento(
        String id,
        String talla,
        int cantidad,
        int hora,
        String recibido,
      ) => Liberacion(
        id: id,
        item: item(talla),
        cantidad: cantidad,
        operario: 'Operario $id',
        fecha: DateTime(2026, 9, 30, hora),
        recibidoPorLogistica: recibido,
        nota: 'Nota $id',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialLiberaciones(
              liberaciones: [
                evento('b', 'M', 5, 11, 'Carlos'),
                evento('c', 'S', 2, 9, ''),
                evento('a', 'M', 10, 8, 'Ana'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OP 90001 · Talla M'), findsOneWidget);
      expect(find.text('OP 90001 · Talla S'), findsOneWidget);
      expect(find.text('15 uds'), findsOneWidget);
      expect(find.text('2 uds'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('Sin registrar'), findsOneWidget);
      expect(find.text('Nota: Nota a'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('Liberación de 5 unidades')).dy,
        lessThan(
          tester
              .getTopLeft(find.textContaining('Liberación de 10 unidades'))
              .dy,
        ),
      );
      await tester.tap(find.text('OP 90001 · Talla M'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsNothing);
      expect(find.text('15 uds'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no coincide');
      await tester.pumpAndSettle();
      expect(
        find.text('No hay liberaciones con estos filtros.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
