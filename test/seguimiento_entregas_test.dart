import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/data/seguimiento_entregas.dart';
import 'package:orbiloq_wms/features/despacho/presentation/seguimiento_entregas_tabla.dart';

void main() {
  test('Filtro recibido incluye extremos y excluye fechas vacías', () {
    final rango = DateTimeRange(
      start: DateTime(2026, 10, 8),
      end: DateTime(2026, 10, 10),
    );
    expect(recibidoEnRango(null, rango), false);
    expect(recibidoEnRango(null, null), true);
    expect(recibidoEnRango(DateTime(2026, 10, 8), rango), true);
    expect(recibidoEnRango(DateTime(2026, 10, 10, 23), rango), true);
    expect(recibidoEnRango(DateTime(2026, 10, 7), rango), false);
    expect(recibidoEnRango(DateTime(2026, 10, 11), rango), false);
  });
  testWidgets('Cards de LE abren formulario compacto y conservan edición', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entregasProvider.overrideWith(
            (ref) async => [
              {
                'id': 'd1',
                'revision': 0,
                'le': 2971,
                'cliente': 'CLIENTE A',
                'numero_guia': '001234',
                'placa': 'ABC123',
                'placa_guia': 'ANTERIOR',
                'fecha': '2026-10-08T15:00:00Z',
                'cajas': 2,
                'empaques': 3,
                'version': 0,
                'evidencia_le': {
                  'path': 'd1/0/evidencia_le/prueba.pdf',
                  'nombre': 'prueba.pdf',
                },
              },
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SeguimientoPanel(pendientes: Text('Pendientes de liberar')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liberados'));
    await tester.pumpAndSettle();
    expect(find.text('5 piezas · 2 cajas · 3 empaques'), findsOneWidget);
    expect(find.text('LE 2971'), findsOneWidget);
    await tester.tap(find.text('LE 2971'));
    await tester.pumpAndSettle();
    expect(find.text('Seguimiento · LE 2971'), findsOneWidget);
    expect(find.text('N° de guía'), findsOneWidget);
    expect(find.text('Placa'), findsOneWidget);
    expect(find.text('001234'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(
      find.textContaining('Dato histórico (placa o guía): ANTERIOR'),
      findsOneWidget,
    );
    tester.view.physicalSize = const Size(430, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(1), 'QUIROMAR');
    await tester.tap(find.text('En tránsito').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devuelto por el cliente').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Este estado no reingresa'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('quitar-evidencia_le')),
    );
    await tester.tap(find.byKey(const ValueKey('quitar-evidencia_le')));
    await tester.pumpAndSettle();
    expect(find.text('prueba.pdf'), findsNothing);
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por liberar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liberados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LE 2971'));
    await tester.pumpAndSettle();
    expect(find.text('QUIROMAR'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Hay cambios sin guardar'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Entregado · 0'));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay despachos que coincidan con los filtros.'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(ChoiceChip, 'Devuelto por el cliente · 1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('LE 2971'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '9999');
    await tester.pumpAndSettle();
    expect(
      find.text('No hay despachos que coincidan con los filtros.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
