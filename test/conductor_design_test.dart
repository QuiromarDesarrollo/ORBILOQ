import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/presentation/conductor_page.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';

void main() {
  testWidgets('Portal legible en horizontal y texto ampliado', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
          home: const ConductorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Capturas de revisión del portal y formulario', (tester) async {
    final loader =
        FontLoader('ConductorSans')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
    await loader.load();
    final fallback = FontLoader('Ahem')
      ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
    await fallback.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 1440.0, 1536.0]) {
      tester.view.physicalSize = Size(width, width == 1536 ? 737 : 1100);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(key: boundary, child: const ConductorPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width >= 900) {
        final sidebar = tester.getRect(
          find.byKey(const ValueKey('conductor-sidebar')),
        );
        final appbar = tester.getRect(find.byType(AppBar));
        expect(sidebar.top, closeTo(appbar.bottom, 1));
        expect(sidebar.bottom, closeTo(tester.view.physicalSize.height, 1));
        if (width == 1536) {
          expect(
            tester.getBottomLeft(find.text('Licencia de conducción')).dy,
            lessThan(tester.view.physicalSize.height),
          );
        }
      }
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.dart_tool/conductor-redesign-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.physicalSize = const Size(390, 850);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: const RegistroConductorPage(
              vehiculo: VehiculoConductor(
                id: 'demo',
                placa: 'DEMO 01',
                descripcion: 'Vehículo',
                km: 48250,
              ),
              tipo: 'Inicio de jornada',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '.dart_tool/conductor-redesign-form.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
