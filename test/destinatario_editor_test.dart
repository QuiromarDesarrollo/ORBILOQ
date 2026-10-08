import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/admin/presentation/destinatario_editor.dart';

void main() {
  testWidgets('valida nombre y guarda datos opcionales sin Excel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, String>? guardado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => showDialog<bool>(
                        context: context,
                        builder:
                            (_) => DestinatarioEditor(
                              guardar: (datos) async {
                                guardado = datos;
                              },
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
    await tester.ensureVisible(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el nombre del destinatario.'), findsOneWidget);
    expect(guardado, isNull);
    await tester.enterText(find.byKey(const ValueKey('nombre')), ' Empresa A ');
    await tester.enterText(find.byKey(const ValueKey('nit')), '00123-4');
    await tester.enterText(find.byKey(const ValueKey('sede')), ' Norte ');
    await tester.enterText(
      find.byKey(const ValueKey('direccion')),
      ' Calle 10 ',
    );
    await tester.ensureVisible(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    expect(guardado!['nombre'], 'Empresa A');
    expect(guardado!['nit'], '00123-4');
    expect(guardado!['sede'], 'Norte');
    expect(guardado!['direccion'], 'Calle 10');
    expect(guardado!['telefono'], '');
    expect(guardado!.length, 8);
    expect(find.text('Nuevo destinatario'), findsNothing);
  });
  testWidgets('conserva el formulario cuando falla el guardado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinatarioEditor(
            guardar: (_) async => throw Exception('red'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('nombre')), 'Empresa B');
    await tester.ensureVisible(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar destinatario'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo guardar'), findsOneWidget);
    expect(find.text('Empresa B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
