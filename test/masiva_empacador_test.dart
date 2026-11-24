import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_empacador_dialog.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_registrar_empaque_dialog.dart';

import 'masiva_empaque_avance_test.dart' show EmpaqueFixture, choose, submit;

Future<void> mount(
  WidgetTester tester,
  double width,
  EmpaqueFixture fixture,
  Future<MasivaJson> Function(String) add, {
  List<MasivaJson> people = const [],
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.kardex(TemaModo.corporativo),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => MasivaRegistrarEmpaqueDialog(
                            people: people,
                            agregarEmpacador: add,
                            initialLista: '88',
                            consultar: fixture.consult,
                            registrar: fixture.save,
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
}

Future<void> openAdd(WidgetTester tester) async {
  final button = find.widgetWithText(TextButton, 'Agregar empacador');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Finder get nameField => find.descendant(
  of: find.byType(MasivaEmpacadorDialog),
  matching: find.byType(TextField),
);

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('catálogo vacío agrega nombre y registra por UUID a $width', (
      tester,
    ) async {
      final fixture = EmpaqueFixture();
      final names = <String>[];
      const name = 'María Alejandra Apellidos Largos de Prueba';
      await mount(tester, width, fixture, (value) async {
        names.add(value);
        return {'id': 'a', 'nombre': value};
      });
      await openAdd(tester);
      expect(nameField, findsOneWidget);
      expect(find.text('Número de usuario ORBILOQ'), findsNothing);
      await tester.enterText(
        nameField,
        '  María   Alejandra Apellidos Largos de Prueba  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();
      expect(names, [name]);
      expect(find.byType(MasivaEmpacadorDialog), findsNothing);
      expect(find.text(name), findsOneWidget);
      await choose(tester, 'empaque-alcance', 'Solo pendientes');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(fixture.writes.single['empacador_id'], 'a');
      expect(fixture.writes.single['lista'], '88');
      expect(fixture.kits[3]['empacador_id'], 'b');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelar alta conserva empacador, rango y lista', (
    tester,
  ) async {
    final fixture = EmpaqueFixture();
    var calls = 0;
    await mount(
      tester,
      390,
      fixture,
      (_) async {
        calls++;
        return {'id': 'new', 'nombre': 'Nuevo'};
      },
      people: const [
        {'id': 'a', 'nombre': 'Operario A'},
      ],
    );
    await choose(tester, 'empaque-persona', 'Operario A');
    await choose(tester, 'empaque-alcance', 'Parcial · rango de personas');
    await tester.enterText(find.byKey(const ValueKey('empaque-desde')), '2');
    await tester.enterText(find.byKey(const ValueKey('empaque-hasta')), '3');
    await openAdd(tester);
    await tester.enterText(nameField, 'Borrador');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar').last);
    await tester.pumpAndSettle();
    expect(calls, 0);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(fixture.writes.single['empacador_id'], 'a');
    expect(fixture.writes.single['desde'], 2);
    expect(fixture.writes.single['hasta'], 3);
    expect(fixture.writes.single['lista'], '88');
    expect(tester.takeException(), isNull);
  });

  testWidgets('alta bloquea doble envío y conserva nombre al fallar', (
    tester,
  ) async {
    final fixture = EmpaqueFixture();
    final gate = Completer<void>();
    var calls = 0;
    await mount(tester, 768, fixture, (name) async {
      calls++;
      if (calls == 1) {
        await gate.future;
        throw const MasivaError('No fue posible guardar de prueba');
      }
      return {'id': 'a', 'nombre': name};
    });
    await openAdd(tester);
    await tester.enterText(nameField, 'Operario nuevo');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('No fue posible guardar de prueba'), findsOneWidget);
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      'Operario nuevo',
    );
    expect(fixture.writes, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Operario nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
