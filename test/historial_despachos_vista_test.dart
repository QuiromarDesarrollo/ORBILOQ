import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/despacho/presentation/historial_despachos_vista.dart';

void main() {
  testWidgets(
    'Historial incluye reservas y cancelaciones con sus movimientos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialDespachosVista(
              filas: const [
                {
                  'despacho_oc_id': 'cancelada',
                  'le_numero': 113,
                  'fase': 'cancelado',
                  'cantidad': 4,
                  'cliente': 'Cliente',
                  'oc': 'OC 1',
                  'fecha': '2026-10-20T10:00:00Z',
                  'eventos': [
                    {
                      'accion': 'Reserva cancelada',
                      'actor': 'Administrador',
                      'fecha': '2026-10-20T12:00:00Z',
                      'detalle': 'Cambio de destino',
                    },
                    {
                      'accion': 'Empaque confirmado',
                      'actor': 'Empacador',
                      'fecha': '2026-10-20T10:00:00Z',
                      'detalle': '',
                    },
                  ],
                },
                {
                  'despacho_oc_id': 'pendiente',
                  'le_numero': 114,
                  'fase': 'empacado',
                  'cantidad': 2,
                  'cliente': 'Cliente',
                  'oc': 'OC 2',
                  'fecha': '2026-10-20T11:00:00Z',
                },
              ],
              entregas: const [],
              pendientes: false,
              onCorregir: (_) {},
              onDocumento: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Por liberar'), findsOneWidget);
      expect(find.text('2 · 2 movimientos registrados'), findsOneWidget);
      await tester.tap(find.text('LE N° 113'));
      await tester.pumpAndSettle();
      expect(find.text('Reserva cancelada'), findsOneWidget);
      expect(find.text('Cambio de destino'), findsOneWidget);
      expect(find.text('Corregir despacho'), findsNothing);
      expect(find.text('Lista de empaque PDF'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Cambio de destino');
      await tester.pumpAndSettle();
      expect(find.text('LE N° 113'), findsOneWidget);
      expect(find.text('LE N° 114'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
