import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/admin/presentation/empaque_editor.dart';
import 'package:orbiloq_wms/features/admin/presentation/catalogo_tabla.dart';
import 'package:orbiloq_wms/features/admin/presentation/destinatario_editor.dart';

void main() {
  final empaque = {
    'nombre': 'Empaque grande',
    'categoria': 'BOLSA',
    'largo_cm': 80,
    'ancho_cm': 30,
    'alto_cm': 20,
    'peso_neto_kg': .5,
    'peso_bruto_kg': 15,
    'activo': true,
  };
  for (final size in [
    const Size(1100, 850),
    const Size(390, 800),
    const Size(320, 640),
  ]) {
    testWidgets('Empaque: volumen y acciones visibles $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
      await font.load();
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: EmpaqueEditor(fila: empaque),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Volumen calculado: 0,048 m³'), findsOneWidget);
      expect(find.text('Guardar cambios').hitTestable(), findsOneWidget);
      if (size.width > 1000) {
        (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .markNeedsPaint();
        await tester.pump();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.dart_tool/catalogo_empaque.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets('Tablas de catálogos y destinatario $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final tipo in [
        'empaques',
        'ubicaciones',
        'causales_devolucion',
        'personal_logistica',
        'personal_produccion',
        'personal_aliados',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CatalogoTabla(
                tipo: tipo,
                filas: [empaque],
                ocupado: false,
                onEditar: (_) {},
                onDesactivar: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DestinatarioEditor(guardar: (_) async {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guardar destinatario').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
