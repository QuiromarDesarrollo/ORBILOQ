import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/despacho/presentation/historial_despachos_vista.dart';

void main() {
  testWidgets('Distingue entregas sin cargar de cero y de una entrega real', (
    tester,
  ) async {
    Future<void> mostrar(List<Map<String, dynamic>>? entregas) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialDespachosVista(
              filas: const [
                {'despacho_oc_id': 'd1', 'cantidad': 5, 'le_numero': 2982},
              ],
              entregas: entregas,
              pendientes: false,
              onCorregir: null,
              onDocumento: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mostrar(null);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('0 de 1'), findsNothing);
    await mostrar([]);
    expect(find.text('0 de 1'), findsOneWidget);
    await mostrar([
      {'id': 'd1', 'estado': 'entregado'},
    ]);
    expect(find.text('1 de 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final ancho in [320.0, 1000.0]) {
    testWidgets('LE agrupa estantes y conserva acciones a $ancho px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final acciones = <String>[];
      final empaque = {
        'numero': 1,
        'op': '90003',
        'talla': 'M',
        'nombre': 'Bolsa grande',
        'cantidad': 5,
        'largo_cm': 80,
        'ancho_cm': 30,
        'alto_cm': 20,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialDespachosVista(
              pendientes: true,
              entregas: const [],
              filas: [
                for (final estante in ['A', 'B'])
                  {
                    'registro': estante,
                    'despacho_oc_id': 'd1',
                    'le_numero': 2984,
                    'cliente': 'Cliente B',
                    'oc': 'OC-1',
                    'op': '90003',
                    'producto': 'Camisa',
                    'talla': 'M',
                    'persona': 'Ana',
                    'ubicacion': estante,
                    'cantidad': estante == 'A' ? 2 : 3,
                    'fecha': '2026-10-09T12:00:00Z',
                    'empaques': [empaque],
                  },
              ],
              onCorregir: (id) => acciones.add('corregir:$id'),
              onDocumento: (id) => acciones.add('salida:$id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 prendas reservadas · 1 LE'), findsOneWidget);
      await tester.tap(find.text('LE N° 2984'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Empaque 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Corregir despacho'));
      await tester.tap(find.text('Corregir despacho'));
      await tester.ensureVisible(find.text('Confirmar salida'));
      await tester.tap(find.text('Confirmar salida'));
      expect(acciones, ['corregir:d1', 'salida:d1']);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('LE N° 2984'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
