import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/flota_admin_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/revision_salida_page.dart';

void main() {
  testWidgets('Expediente e inspecciones adaptados a móvil y escritorio', (
    tester,
  ) async {
    await (FontLoader('ConductorSans')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('Ahem')..addFont(
      rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
    )).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1100);
      final boundary = GlobalKey();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/flota-$name-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(key: boundary, child: const FlotaAdminPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('panel-general');
      await tester.ensureVisible(find.text('Ver vehículo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver vehículo').first);
      await tester.pumpAndSettle();
      await capture('resumen');
      await tester.tap(find.text('Inspecciones y salida'));
      await tester.pumpAndSettle();
      expect(find.text('2 · Autorización de salida'), findsOneWidget);
      await capture('inspecciones');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(
              key: boundary,
              child: const RevisionSalidaPage(
                vehiculo: 'demo',
                administrador: true,
                contextoVehiculo: {
                  'placa': 'DEMO01',
                  'descripcion': 'Vehículo de prueba',
                  'conductor_nombre': 'Conductor demo',
                  'km': 48250,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Autorizar salida'), findsNothing);
      expect(find.text('No hay inspecciones que coincidan con los filtros'), findsOneWidget);
      await capture('revision');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
