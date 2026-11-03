import 'dart:convert';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/features/produccion/presentation/entrega_produccion_dialog.dart';

class AvanceMemoria extends BorradorLocalStore {
  final datos = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> leer(String key) async => datos[key];
  @override
  Future<void> guardar(String key, Map<String, dynamic> data) async {
    datos[key] = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
  }
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final size in [
    const Size(320, 640),
    const Size(768, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('Entrega: cantidades y resumen fijo $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = InMemoryWmsRepository.seeded();
      addTearDown(repo.dispose);
      final item = (await repo.cargarSnapshot()).kardex.firstWhere(
        (k) => k.pendienteProduccion > 1,
      );
      final store = AvanceMemoria();
      Widget app() => ProviderScope(
        overrides: [
          wmsRepositoryProvider.overrideWithValue(repo),
          transporteBorradorUsuarioProvider.overrideWithValue(
            'dev:usuario-prueba',
          ),
          transporteBorradorStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.kardex(TemaModo.corporativo),
          home: const RepaintBoundary(
            key: ValueKey('capture-production'),
            child: Scaffold(body: EntregaProduccionDialog()),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('Despachar lote a logística').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.text(size.width < 600 ? 'Manual' : 'Entrega manual'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, item.item.op);
      await tester.tap(
        size.width < 600 ? find.byTooltip('Buscar OP') : find.text('BUSCAR'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AGREGAR SELECCIONADAS (1)'));
      await tester.tap(find.text('AGREGAR SELECCIONADAS (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 1 unidades'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 2 unidades'), findsOneWidget);
      final lotesAntes = (await repo.cargarSnapshot()).lotes.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(size.width < 600 ? 'Manual' : 'Entrega manual'),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 2 unidades'), findsOneWidget);
      expect((await repo.cargarSnapshot()).lotes.length, lotesAntes);
      expect(
        store.datos.values.any(
          (d) => (d['datos']['tarjetas'] as List).isNotEmpty,
        ),
        isTrue,
      );

      expect(
        find.text('Despachar lote a logística').hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(
        (size.width < 600 ? find.byTooltip('Recontar') : find.text('Recontar')),
      );
      await tester.tap(
        (size.width < 600 ? find.byTooltip('Recontar') : find.text('Recontar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 productos · 1 unidades'), findsOneWidget);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture-production')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.dart_tool/produccion-entrega-${size.width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      if (size.width == 1440) {
        await tester.tap(find.text('Despachar lote a logística'));
        await tester.pumpAndSettle();
        expect((await repo.cargarSnapshot()).lotes.length, lotesAntes + 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entrega manual'));
        await tester.pumpAndSettle();
        expect(find.text('0 productos · 0 unidades'), findsOneWidget);
        expect((await repo.cargarSnapshot()).lotes.length, lotesAntes + 1);
      }
    });
  }
}
