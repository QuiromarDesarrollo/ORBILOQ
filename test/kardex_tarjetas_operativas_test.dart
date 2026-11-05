import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/cumplimiento.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/kardex/presentation/kardex_table.dart';

// Cantidades y fechas distintas detectan cruces entre Producción, Bodega y
// Despacho al reutilizar la presentación de sus tarjetas.
ItemKardex _fila({bool largo = false, int factor = 1}) => ItemKardex(
  item: ItemOrden(
    id: 'operativa-prueba',
    op: '90005',
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
    cantidadPedida: 47 * factor,
    observacionOp: 'Empacar cada talla por separado.',
  ),
  producido: 31 * factor,
  recibido: 23 * factor,
  despachado: 7 * factor,
  stockInventario: 3 * factor,
  ubicaciones: {'A-01': 9 * factor, 'B-02': 4 * factor},
  pendienteReproceso: 2 * factor,
  fechaEntrega: DateTime(2026, 10, 27),
  fechaRecepcion: DateTime(2026, 10, 29),
  fechaDespacho: DateTime(2026, 10, 30),
  fechaEsperadaProduccion: DateTime(2026, 10, 28),
  fechaEsperadaLogistica: DateTime(2026, 10, 31),
);

Future<void> _montar(
  WidgetTester tester,
  Rol rol,
  double ancho, {
  double alto = 1100,
  bool largo = false,
  double escala = 1,
  bool operario = false,
  int factor = 1,
}) async {
  tester.view.physicalSize = Size(ancho, alto);
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
            (ref) async => UsuarioSesion(
              numeroUsuario: '100',
              nombre: 'Operario local',
              rolCuenta:
                  rol == Rol.logistica
                      ? RolCuenta.logistica
                      : RolCuenta.despacho,
            ),
          ),
        wmsRepositoryProvider.overrideWithValue(repo),
        kardexProvider.overrideWithValue([_fila(largo: largo, factor: factor)]),
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
        home: const Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: ValueKey('captura-tarjetas-operativas'),
              child: KardexTable(),
            ),
          ),
        ),
      ),
    ),
  );
  ProviderScope.containerOf(
    tester.element(find.byType(KardexTable)),
  ).read(rolProvider.notifier).cambiar(rol);
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('captura-tarjetas-operativas')),
  );
  await tester.runAsync(() async {
    final imagen = await boundary.toImage();
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/$nombre.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    imagen.dispose();
  });
}

void _campoDeTarjeta(String etiqueta, String valor) {
  final rotulo = find.descendant(
    of: find.byType(Card).first,
    matching: find.text(etiqueta),
  );
  expect(rotulo, findsOneWidget);
  final celda =
      find.ancestor(of: rotulo, matching: find.byType(Container)).first;
  final texto = find.descendant(of: celda, matching: find.text(valor));
  expect(texto, findsOneWidget);
  final parrafo = texto.evaluate().single.renderObject! as RenderParagraph;
  expect(
    parrafo.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: valor.length),
    ),
    hasLength(1),
    reason: '$etiqueta debe conservar $valor legible en una sola línea.',
  );
}

void _verificarDatos(Rol rol) {
  expect(find.text('OP 90005'), findsOneWidget);
  expect(find.text('57002'), findsOneWidget);
  expect(find.text('Talla XXL'), findsOneWidget);
  expect(find.text('OC OC-2026-4567'), findsOneWidget);
  expect(find.text(_fila().estadoLogistica.etiqueta), findsOneWidget);
  _campoDeTarjeta('PEDIDAS', '47');
  _campoDeTarjeta('BODEGA', '13');
  _campoDeTarjeta('INVENTARIO', '3');
  if (rol == Rol.logistica) {
    _campoDeTarjeta('ENTREGADO POR PRODUCCIÓN', '31');
    _campoDeTarjeta('PENDIENTE POR PRODUCCIÓN', '16');
    _campoDeTarjeta('PRODUCTO NO CONFORME', '2');
    _campoDeTarjeta('ÚLTIMA RECEPCIÓN', '29/10/2026');
    expect(find.text('23 de 47 · 49 %'), findsOneWidget);
    expect(find.text('27/10/2026'), findsNothing);
    expect(find.text('30/10/2026'), findsNothing);
  } else {
    _campoDeTarjeta('DESPACHADAS', '7');
    final rotuloDespachadas = find.descendant(
      of: find.byType(Card).first,
      matching: find.text('DESPACHADAS'),
    );
    final parrafo =
        rotuloDespachadas.evaluate().single.renderObject! as RenderParagraph;
    expect(
      parrafo.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 11),
      ),
      hasLength(1),
      reason:
          'El rótulo DESPACHADAS no debe dividir una palabra en dos líneas.',
    );
    _campoDeTarjeta('FECHA PACTADA', '31/10/2026');
    _campoDeTarjeta('FECHA DE DESPACHO', '30/10/2026');
    expect(find.text('7 de 47 · 15 %'), findsOneWidget);
    expect(
      find.textContaining(
        _fila().cumplimientoLogistica().detalle,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('29/10/2026'), findsNothing);
    expect(find.text('28/10/2026'), findsNothing);
    expect(find.text('ENTREGADO POR PRODUCCIÓN'), findsNothing);
  }
}

Future<void> _consultarObservacion(WidgetTester tester) async {
  final boton = find.text('Observaciones');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
  expect(find.text('Empacar cada talla por separado.'), findsOneWidget);
  expect(find.text('OBSERVACIÓN OP: 90005'), findsOneWidget);
  await tester.ensureVisible(find.text('ENTENDIDO'));
  await tester.tap(find.text('ENTENDIDO'));
  await tester.pumpAndSettle();
  expect(find.text('OBSERVACIÓN OP: 90005'), findsNothing);
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

  for (final rol in [Rol.logistica, Rol.despacho]) {
    final area = rol == Rol.logistica ? 'bodega' : 'despacho';
    for (final ancho in [320.0, 390.0, 768.0]) {
      for (final largo in [false, true]) {
        testWidgets(
          '$area $ancho: datos, observaciones y acciones; largo=$largo',
          (tester) async {
            await _montar(
              tester,
              rol,
              ancho,
              largo: largo,
              escala: largo ? 1.3 : 1,
            );
            expect(tester.takeException(), isNull);
            _verificarDatos(rol);
            await _capturar(
              tester,
              'kardex-$area-${ancho.toInt()}${largo ? '-texto-ampliado' : ''}',
            );
            await _consultarObservacion(tester);
            final menu = find.byTooltip('Acciones de la fila');
            await tester.ensureVisible(menu);
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(find.text('Editar'), findsOneWidget);
            expect(find.text('Eliminar'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      '$area: operario puede consultar, sin acciones administrativas',
      (tester) async {
        await _montar(tester, rol, 390, operario: true);
        _verificarDatos(rol);
        expect(find.byTooltip('Acciones de la fila'), findsNothing);
        await _consultarObservacion(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$area: scroll y regreso tras modal en altura reducida y giro',
      (tester) async {
        await _montar(tester, rol, 320, alto: 480, largo: true, escala: 1.3);
        await _consultarObservacion(tester);
        tester.view.physicalSize = const Size(768, 480);
        await tester.pumpAndSettle();
        _verificarDatos(rol);
        await _consultarObservacion(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$area: escritorio conserva tabla y acceso a observaciones', (
      tester,
    ) async {
      await _montar(tester, rol, 1920);
      expect(find.text('FILTRAR POR COLUMNA'), findsNothing);
      expect(find.text('#90005'), findsOneWidget);
      expect(find.text('BODEGA'), findsOneWidget);
      expect(find.text('INVENTARIO'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      expect(find.text('OBSERVACIÓN OP: 90005'), findsOneWidget);
      await tester.tap(find.text('ENTENDIDO'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$area: seis cifras y texto al 200 % en pantalla estrecha', (
      tester,
    ) async {
      await _montar(tester, rol, 320, escala: 2, largo: true, factor: 10000);
      _campoDeTarjeta('PEDIDAS', '470000');
      _campoDeTarjeta('BODEGA', '130000');
      expect(tester.takeException(), isNull);
      await _capturar(tester, 'kardex-$area-320-texto-200');
      await _consultarObservacion(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
