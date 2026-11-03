import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';

void main() {
  testWidgets('Arrastre acotado, fullscreen y cambio a móvil conservan datos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.kardex(TemaModo.corporativo),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showWmsDialog(
                        context,
                        (_) => WmsDialogShell(
                          title: 'Recepción de prendas',
                          icon: Icons.inventory_2,
                          iconColor: Colors.blue,
                          draggable: true,
                          expand: true,
                          child: TextField(controller: controller),
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
    await tester.enterText(find.byType(TextField), 'Borrador');
    final surface = find.byKey(const ValueKey('wms-dialog-surface'));
    final handle = find.byKey(const ValueKey('wms-dialog-drag-handle'));
    final original = tester.getRect(surface);
    await tester.drag(handle, const Offset(80, 50));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).left, greaterThan(original.left));
    expect(tester.getRect(surface).top, greaterThan(original.top));
    expect(find.text('Borrador'), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: surface, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '.dart_tool/dialog-drag-desktop.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.drag(handle, const Offset(2000, 2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).right, lessThanOrEqualTo(1424));
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(984));
    await tester.drag(handle, const Offset(-4000, -4000));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).left, greaterThanOrEqualTo(16));
    expect(tester.getRect(surface).top, greaterThanOrEqualTo(16));
    await tester.tap(find.byTooltip('Ampliar pantalla'));
    await tester.pumpAndSettle();
    final full = tester.getRect(surface);
    await tester.drag(handle, const Offset(80, 50));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), full);
    await tester.tap(find.byTooltip('Restaurar tamaño'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final mobile = tester.getRect(surface);
    expect(mobile.left, greaterThanOrEqualTo(8));
    expect(mobile.right, lessThanOrEqualTo(382));
    await tester.drag(handle, const Offset(80, 50));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), mobile);
    expect(find.text('Borrador'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });
}
