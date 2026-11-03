import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/flota_admin_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/kit_semanal_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';

import 'masiva_ui_test.dart' show MasivaFixture, mount, captureMasiva;
import 'masiva_validacion_test.dart' show openValidation, searchPerson, scanSku;
import 'masiva_validacion_workspace_test.dart'
    show WorkspaceFixture, chooseContainer;

const _sizes = [
  Size(320, 640),
  Size(390, 844),
  Size(768, 1024),
  Size(1440, 900),
];
const _vehicle = VehiculoConductor(
  id: 'responsive-audit',
  placa: 'PRUEBA01',
  descripcion: 'Vehículo de prueba aislado',
  km: 100,
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _transport(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('audit-capture'),
          child: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(ConductorPage).evaluate().isNotEmpty ||
      find.byType(FlotaAdminPage).evaluate().isNotEmpty) {
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/logo_orbiloq.png'),
        tester.element(find.byKey(const ValueKey('audit-capture'))),
      );
    });
    await tester.pumpAndSettle();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final image =
        await tester
            .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('audit-capture')),
            )
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in ['ConductorSans', 'Roboto', 'Ahem']) {
      await (FontLoader(name)
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(() async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    view.resetViewInsets();
  });

  for (final size in _sizes) {
    testWidgets(
      'Conductor navega sus ocho destinos a ${size.width.toInt()} px',
      (tester) async {
        await _transport(tester, const ConductorPage(), size);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'audit-conductor-${size.width.toInt()}');
        const sections = [
          'Inicio',
          'Checklist',
          'Seguimiento',
          'Mantenimiento',
          'Mi vehículo',
          'Alertas',
          'Historial',
          'Perfil',
        ];
        for (var i = 1; i < sections.length; i++) {
          Finder entry;
          if (size.width < 900) {
            if (i < 3) {
              entry = find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(sections[i]),
              );
            } else {
              await tester.tap(
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('Más'),
                ),
              );
              await tester.pumpAndSettle();
              entry = find.widgetWithText(ListTile, sections[i]).last;
            }
          } else {
            entry = find.descendant(
              of: find.byKey(const ValueKey('conductor-sidebar')),
              matching: find.text(sections[i]),
            );
          }
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('conductor-$i')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: sections[i]);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Flota abre expediente e inspecciones a ${size.width.toInt()} px',
      (tester) async {
        await _transport(tester, const FlotaAdminPage(), size);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.text('Ver vehículo').first);
        await tapVisible(tester, find.text('Inspecciones y salida'));
        expect(find.text('2 · Autorización de salida'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'audit-flota-${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Formularios transporte mantienen guardar accesible a ${size.width.toInt()} px',
      (tester) async {
        await _transport(
          tester,
          const RegistroConductorPage(
            vehiculo: _vehicle,
            tipo: 'Inicio de jornada',
          ),
          size,
        );
        expect(tester.takeException(), isNull);
        final save = find.textContaining('Guardar').last;
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        await _capture(tester, 'audit-checklist-${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox.shrink());
        await _transport(
          tester,
          const KitSemanalPage(vehiculo: _vehicle),
          size,
        );
        expect(tester.takeException(), isNull);
        final weeklySave = find.text('Guardar revisión semanal');
        await tester.ensureVisible(weeklySave);
        await tester.pumpAndSettle();
        expect(weeklySave.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [320.0, 768.0]) {
    testWidgets('Masiva navega sus secciones a ${width.toInt()} px', (
      tester,
    ) async {
      await mount(
        tester,
        Size(width, width == 320 ? 640 : 1024),
        MasivaFixture(),
      );
      expect(tester.takeException(), isNull);
      for (final title in [
        'Recepción',
        'Listado maestro',
        'Base de datos maestra',
        'Validación',
        'Listas y documentos',
        'Indicadores',
        'Auditoría',
        'Configuración',
      ]) {
        await tester.tap(find.byTooltip('Abrir menú'));
        await tester.pumpAndSettle();
        final menuEntry = find.descendant(
          of: find.byType(Drawer),
          matching: find.text(title),
        );
        await tester.scrollUntilVisible(
          menuEntry,
          160,
          scrollable:
              find
                  .descendant(
                    of: find.byType(Drawer),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        await tapVisible(tester, menuEntry);
        expect(
          tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: title);
      }
      await captureMasiva(tester, 'audit-masiva-${width.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Masiva 320 permite validar y empacar con teclado móvil', (
    tester,
  ) async {
    final repo = WorkspaceFixture(3);
    await openValidation(
      tester,
      repo,
      size: const Size(320, 640),
      search: false,
    );
    await searchPerson(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await scanSku(tester, '000123');
    expect(repo.writes.single.action, 'validar');
    expect(
      find.byKey(const ValueKey('masiva-sku')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await chooseContainer(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
    expect(repo.writes.last.action, 'embalar');
    expect(repo.writes.last.data['caja'], 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
