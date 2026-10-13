import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/admin/presentation/destinatario_editor.dart';
import 'package:orbiloq_wms/domain/destinatario_internacional.dart';

void main() {
  for (final ancho in [320.0, 390.0, 1200.0]) {
    testWidgets('Internacional condicional y guardado responsive $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, String>? guardado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DestinatarioEditor(
              guardar: (d) async {
                guardado = d;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('via')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('nombre')),
        'Cliente exterior',
      );
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Internacional').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('via')), findsOneWidget);
      await tester.tap(find.text('Guardar destinatario').hitTestable());
      await tester.pumpAndSettle();
      expect(guardado, isNull);
      for (final k in camposDestinatarioInternacional.keys) {
        final finder = find.byKey(ValueKey(k));
        await tester.ensureVisible(finder);
        await tester.enterText(
          finder,
          k == 'email' ? 'test@example.com' : 'VALOR $k',
        );
      }
      await tester.tap(find.text('Guardar destinatario').hitTestable());
      await tester.pumpAndSettle();
      expect(guardado?['tipo_destinatario'], 'internacional');
      expect(guardado?['puerto_destino'], 'VALOR puerto_destino');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Volver a nacional no envía campos internacionales ocultos', (
    tester,
  ) async {
    Map<String, String>? guardado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinatarioEditor(
            guardar: (d) async {
              guardado = d;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nombre')),
      'Cliente nacional',
    );
    final selector = find.byType(DropdownButtonFormField<bool>);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internacional').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('via')));
    await tester.enterText(find.byKey(const ValueKey('via')), 'MARÍTIMA');
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nacional').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar destinatario').hitTestable());
    await tester.pumpAndSettle();
    expect(guardado?['nombre'], 'Cliente nacional');
    expect(guardado!.containsKey('via'), isFalse);
    expect(guardado!.containsKey('tipo_destinatario'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
