import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_table.dart';

ItemKardex _fila({bool largo = false}) => ItemKardex(
  item: ItemOrden(
    id: 'tarjeta-prueba',
    op: '100022',
    cliente:
        largo
            ? 'CLIENTE DE PRUEBAS CON NOMBRE EXTENSO PARA VERIFICAR ADAPTACIÓN'
            : 'COLSUBSIDIO',
    oc: 'OC-2026-4567',
    codigo: '57002',
    descripcion:
        largo
            ? 'CAMISA MANGA LARGA DOTACIÓN INSTITUCIONAL CON REFUERZO ESPECIAL Y BOLSILLOS'
            : 'CAMISA MANGA LARGA',
    talla: 'XXL',
    cantidadPedida: 40,
    observacionOp: 'Empacar cada talla por separado.',
  ),
  producido: 25,
  recibido: 20,
  despachado: 7,
  ubicaciones: const {'A': 13},
  pendienteReproceso: 2,
  fechaEntrega: DateTime(2026, 10, 28),
  fechaEsperadaProduccion: DateTime(2026, 11, 10),
);

Future<void> _montar(
  WidgetTester tester,
  double width, {
  bool largo = false,
  double escala = 1,
  Rol rol = Rol.produccion,
  bool operario = false,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usarSupabaseProvider.overrideWithValue(operario),
        if (operario)
          usuarioSesionProvider.overrideWith(
            (ref) async => const UsuarioSesion(
              numeroUsuario: '100',
              nombre: 'Operario local',
              rolCuenta: RolCuenta.produccion,
            ),
          ),
        wmsRepositoryProvider.overrideWithValue(repo),
        kardexProvider.overrideWithValue([_fila(largo: largo)]),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kardex(TemaModo.corporativo),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
        home: const Scaffold(body: SingleChildScrollView(child: KardexTable())),
      ),
    ),
  );
  ProviderScope.containerOf(
    tester.element(find.byType(KardexTable)),
  ).read(rolProvider.notifier).cambiar(rol);
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final scene = tester.binding.renderViews.single.debugLayer!.buildScene(
      ui.SceneBuilder(),
    );
    final size = tester.view.physicalSize;
    final image = await scene.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    scene.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 768.0]) {
    for (final largo in [false, true]) {
      testWidgets('Tarjeta Producción $width texto largo=$largo', (
        tester,
      ) async {
        await _montar(tester, width, largo: largo, escala: largo ? 1.3 : 1);
        expect(tester.takeException(), isNull);
        final card = find.byType(Card).first;
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(find.textContaining('100022'), findsWidgets);
        expect(find.textContaining('OC-2026-4567'), findsWidgets);
        expect(find.textContaining('57002'), findsWidgets);
        await _capturar(
          tester,
          'kardex-produccion-${width.toInt()}${largo ? '-texto-ampliado' : ''}',
        );
        final observaciones = find.text('Observaciones');
        await tester.ensureVisible(observaciones);
        await tester.tap(observaciones);
        await tester.pumpAndSettle();
        expect(find.text('Empacar cada talla por separado.'), findsOneWidget);
        await tester.tap(find.text('ENTENDIDO'));
        await tester.pumpAndSettle();
        final menu = find.byTooltip('Acciones de la fila');
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Bodega conserva saldos y acciones de su tarjeta', (
    tester,
  ) async {
    await _montar(tester, 390, rol: Rol.logistica);
    expect(find.text('BODEGA'), findsWidgets);
    expect(find.text('INVENTARIO'), findsWidgets);
    expect(find.text('ENTREGADO POR PRODUCCIÓN'), findsWidgets);
    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.byTooltip('Acciones de la fila'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Operario de Producción consulta observaciones sin menú administrativo',
    (tester) async {
      await _montar(tester, 390, operario: true);
      expect(find.byTooltip('Acciones de la fila'), findsNothing);
      await tester.ensureVisible(find.text('Observaciones'));
      await tester.tap(find.text('Observaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Empacar cada talla por separado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
