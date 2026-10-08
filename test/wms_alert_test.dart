import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';

void main() {
  testWidgets(
    'Aviso centrado se puede repetir y cerrar sin cerrar formulario',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Formulario'),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => mostrarAviso(
                                          ctx,
                                          'Revisa las cantidades.',
                                          error: true,
                                        ),
                                    child: const Text('Validar'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Abrir'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Validar'));
        await tester.pumpAndSettle();
        expect(find.text('Revisa las cantidades.'), findsOneWidget);
        final centro = tester.getCenter(find.byType(AlertDialog).last);
        expect(centro.dx, closeTo(400, 1));
        expect(centro.dy, closeTo(300, 1));
        await tester.tap(find.text('Cerrar aviso'));
        await tester.pumpAndSettle();
        expect(find.text('Formulario'), findsOneWidget);
        expect(find.text('Revisa las cantidades.'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
