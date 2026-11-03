import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_maestro_tabla.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_page.dart';

const _listadoMaestroFixture = <MasivaJson>[
  {
    'estado': 'EMPAQUE PARCIAL',
    'lista': '88',
    'cliente': 'Cliente de ejemplo',
    'ciudad': 'Bogotá',
    'sede': 'Centro administrativo',
    'direccion': 'Carrera 80 número 20-01',
    'responsable': 'Responsable de ejemplo',
    'total_piezas': 7,
    'cajas': 5,
    'bolsas': 2,
    'peso_total': 80.5,
    'volumen': .35,
    'kits_totales': 40,
    'kits_validados': 18,
    'kits_empacados': 24,
    'ultima_validacion': '2026-10-27T15:45:00Z',
    'fecha_generado': '2026-10-28T15:45:00Z',
    'fecha_despacho': null,
    'fecha_recepcion': null,
    'transportadora': null,
    'placa_guia': null,
    'novedades': 'Pendiente completar prendas de dos kits',
  },
  {
    'estado': 'POR EMPACAR',
    'lista': '89',
    'cliente': 'Cliente de ejemplo',
    'ciudad': 'Cali',
    'sede': 'Sede sur',
    'direccion': 'Calle 10 número 15-02',
    'responsable': 'Otra responsable',
    'total_piezas': 0,
    'cajas': 0,
    'bolsas': 0,
    'peso_total': 0,
    'volumen': 0,
    'kits_totales': 20,
    'kits_validados': 0,
    'kits_empacados': 0,
    'ultima_validacion': null,
    'fecha_generado': null,
    'fecha_despacho': null,
    'fecha_recepcion': null,
    'transportadora': null,
    'placa_guia': null,
    'novedades': null,
  },
];

const _baseMaestraFixture = <MasivaJson>[
  {
    'id': 'art1',
    'kit_id': 'kit1',
    'fecha_carga': '2026-10-26T13:30:00Z',
    'cliente': 'Cliente de ejemplo',
    'logistica': 'Operación nacional',
    'entrega': 'Primera entrega',
    'lista': '88',
    'numero_persona': '0001',
    'ciudad': 'Bogotá',
    'regional': 'Centro',
    'departamento': 'Cundinamarca',
    'sede': 'Centro administrativo',
    'sector': 'Operaciones',
    'unidad': 'Unidad operativa',
    'unidad_directiva': 'Dirección operativa',
    'gerencia': 'Gerencia nacional',
    'cargo': 'Auxiliar de operaciones',
    'direccion': 'Carrera 80 número 20-01',
    'responsable': 'Responsable de ejemplo',
    'cedula': '0001234567',
    'nombre': 'Persona de ejemplo',
    'sku': '000123',
    'prenda': 'Camisa',
    'descripcion': 'Camisa manga larga talla M',
    'empaque': 'Caja mediana',
    'numero_contenedor': '001',
    'cantidad': 2,
    'items_kit': 3,
    'items_lista': 120,
    'items_direccion': 120,
    'validado': 1,
    'estado': 'PARCIAL',
    'validador': 'Validadora de ejemplo',
    'empacador': 'Empacador de ejemplo',
    'fecha_validacion': '2026-10-27T15:45:00Z',
    'transportadora': null,
    'placa_guia': null,
    'motivo_modificacion': 'Ajuste de talla autorizado',
  },
];

class MasivaFixture extends MasivaRepository {
  MasivaFixture({this.archived = false, this.listadoMaestro}) : super(null);
  final bool archived;
  List<MasivaJson>? listadoMaestro;
  @override
  bool get conectado => true;
  final calls = <String>[];
  final recepcionConsultas = <MasivaJson>[];
  final historialRecepcionConsultas = <MasivaJson>[];
  final maestroConsultas = <MasivaJson>[];
  final consultas = <MasivaJson>[];

  @override
  Future<MasivaJson> consultarHistorialRecepcion({
    required String operacion,
    String buscar = '',
    int pagina = 1,
  }) async {
    historialRecepcionConsultas.add({
      'operacion': operacion,
      'buscar': buscar,
      'pagina': pagina,
    });
    if (buscar.isNotEmpty && !'000123'.contains(buscar)) {
      return {'total': 0, 'filas': <MasivaJson>[]};
    }
    return {
      'total': 1,
      'filas': [
        {
          'id': 'mov1',
          'sku': '000123',
          'descripcion': 'Camisa manga larga talla M',
          'cantidad': 2,
          'proveedor': 'Proveedor de ejemplo',
          'pedido': '10001',
          'soporte': 'REM-88',
          'operario': 'Administrador',
          'creado': '2026-10-28T15:45:00Z',
        },
      ],
    };
  }

  @override
  Future<MasivaJson> consultarMaestro({
    required String operacion,
    required String vista,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    int tamano = 30,
    String fechaTipo = 'fecha_carga',
    String? desde,
    String? hasta,
    bool incluirOpciones = true,
  }) async {
    maestroConsultas.add({
      'operacion': operacion,
      'vista': vista,
      'buscar': buscar,
      'filtros': {
        for (final entry in filtros.entries) entry.key: {...entry.value},
      },
      'pagina': pagina,
      'tamano': tamano,
      'fecha_tipo': fechaTipo,
      'desde': desde,
      'hasta': hasta,
      'incluir_opciones': incluirOpciones,
    });
    final source =
        vista == 'base'
            ? _baseMaestraFixture
            : listadoMaestro ?? _listadoMaestroFixture;
    final columns =
        vista == 'base' ? masivaBaseColumnas : masivaListadoColumnas;
    final selected =
        source.where((row) {
          if (buscar.isNotEmpty &&
              !row.values.any(
                (value) =>
                    '$value'.toLowerCase().contains(buscar.toLowerCase()),
              )) {
            return false;
          }
          return filtros.entries.every(
            (filter) =>
                filter.value.isEmpty ||
                filter.value.contains('${row[filter.key] ?? ''}'),
          );
        }).toList();
    return {
      'filas': selected.skip((pagina - 1) * tamano).take(tamano).toList(),
      'total': selected.length,
      'pagina': pagina,
      'tamano': tamano,
      'opciones':
          incluirOpciones
              ? {
                for (final column in columns)
                  column.key:
                      {
                        for (final row in source) '${row[column.key] ?? ''}',
                      }.toList(),
              }
              : {},
    };
  }

  @override
  Future<MasivaJson> consultarRecepcion({
    required String operacion,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    String? proveedor,
    String? pedido,
  }) async {
    recepcionConsultas.add({
      'operacion': operacion,
      'buscar': buscar,
      'filtros': {
        for (final entry in filtros.entries) entry.key: {...entry.value},
      },
      'pagina': pagina,
      'proveedor': proveedor,
      'pedido': pedido,
    });
    final base = await consultar(operacion: operacion, vista: 'inventario');
    final rows =
        proveedor == null
            ? <MasivaJson>[
              {
                'pedido': '10001',
                'proveedor': 'Proveedor de ejemplo',
                'pendiente': 150,
                'esperado': 400,
                'recibido': 250,
                'horario': '8:00 AM A 12:00 PM',
                'novedad': 'RECIBIDO PARCIAL',
                'requerido': 300,
                'saldo': -50,
              },
            ]
            : <MasivaJson>[
              {
                ...filasMasiva(base['filas']).first,
                'pendiente': 150,
                'unidad': 'UN',
                'saldo_oc_sku': -50,
                'horario': '8:00 AM A 12:00 PM',
                'novedad': 'RECIBIDO PARCIAL',
              },
            ];
    return {
      ...base,
      'filas': rows,
      'total': rows.length,
      'pagina': pagina,
      'metricas': {
        ...mapaMasiva(base['metricas']),
        'base_personal_cargada': true,
        'recibido': 250,
        'requerido': 300,
        'saldo': -50,
        'saldo_sin_pedido': 0,
      },
      'opciones': {
        'pedido': ['10001'],
        'pendiente': ['150'],
        'esperado': ['400'],
        'recibido': ['250'],
        'horario': ['8:00 AM A 12:00 PM'],
        'novedad': ['RECIBIDO PARCIAL'],
        'saldo': ['-50'],
      },
    };
  }

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    consultas.add({
      'operacion': operacion,
      'vista': vista,
      'buscar': buscar,
      'lista': lista,
      'pagina': pagina,
    });
    final op = {
      'id': 'demo',
      'nombre': 'Dotación · Octubre 2026',
      'cliente': 'Cliente de ejemplo',
      'estado': archived ? 'cerrada' : 'activa',
    };
    if (operacion == null) {
      return {
        'operaciones': [op],
      };
    }
    final rows = switch (vista) {
      'personal' => [
        {'id': 'person1', 'nombre': 'Empacador de ejemplo'},
      ],
      'empaques' => [
        {
          'id': 'box1',
          'nombre': 'Caja mediana',
          'peso_lleno': 15,
          'largo': 50,
          'ancho': 40,
          'alto': 35,
        },
      ],
      'inventario' => [
        {
          'id': 'inv1',
          'sku': '000123',
          'descripcion': 'Camisa manga larga talla M',
          'proveedor': 'Proveedor de ejemplo',
          'pedido': '10001',
          'esperado': 400,
          'recibido': 250,
          'requerido': 300,
          'disponible': 180,
        },
      ],
      'listas' => [
        {
          'lista': '88',
          'kits': 40,
          'armados': 24,
          'validados': 18,
          'responsable': 'Responsable de ejemplo',
        },
      ],
      'kits' || 'validacion_documento' => [
        {
          'id': 'kit1',
          'lista': '88',
          'numero_persona': 1,
          'cedula': 'DEMO-01',
          'nombre': 'Persona de ejemplo',
          'empacador_id': 'person1',
          'empacador': 'Empacador de ejemplo',
          'estado': 'parcial',
          'armado': '2026-10-27T08:00:00Z',
          'revision_abierta': true,
          'validacion_inicio': '2026-10-27T09:00:00Z',
          'articulos': [
            {
              'id': 'art1',
              'sku': '000123',
              'descripcion': 'Camisa manga larga talla M',
              'cantidad': 2,
              'validado': 1,
            },
          ],
        },
      ],
      'documentos' => [
        {
          'id': 'doc1',
          'lista': '88',
          'tipo': 'lista',
          'version': 1,
          'created_at': '2026-10-27T09:00:00Z',
        },
      ],
      'indicadores' => [
        {
          'nombre': 'Empacador de ejemplo',
          'kits': 24,
          'errores': 1,
          'puntos': 22,
          'promedio_segundos': 130,
        },
      ],
      'auditoria' => [
        {
          'accion': 'recibir',
          'actor_nombre': 'Usuario de ejemplo',
          'creado': '2026-10-27T09:00:00Z',
          'datos': {
            'entrada': {'cantidad': 20, 'soporte': 'REM-001'},
          },
        },
      ],
      _ => <MasivaJson>[],
    };
    return {
      'operacion': op,
      'filas': rows,
      'total': rows.length,
      'metricas': {
        'kits': 40,
        'armados': 24,
        'validados': 18,
        'recibido': 250,
        'disponible': 180,
        'unidades': 300,
        'segundos_empaque': 3120,
        'promedio_segundos_kit': 130,
      },
    };
  }

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    calls.add(accion);
    return {};
  }
}

class _ExcelPickerFixture extends FilePicker {
  Uint8List? archivo;
  String? nombre;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    nombre = fileName;
    archivo = bytes;
    return null;
  }
}

Future<void> mount(
  WidgetTester tester,
  Size size,
  MasivaRepository repo,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [masivaRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.kardex(TemaModo.corporativo),
        home: const RepaintBoundary(
          key: ValueKey('capture'),
          child: MasivaPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> captureMasiva(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> captureMasivaOverlay(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final scene = tester.binding.renderViews.single.debugLayer!.buildScene(
      ui.SceneBuilder(),
    );
    try {
      final image = await scene.toImage(
        tester.view.physicalSize.width.toInt(),
        tester.view.physicalSize.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '.dart_tool/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    } finally {
      scene.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font =
        FontLoader('ConductorSans')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('Masiva adapta todas las secciones a $width px', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, Size(width, 1000), MasivaFixture());
      expect(tester.takeException(), isNull);
      if (width == 1440 || width == 390) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/masiva-preview-$width.png');
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
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
        if (width < 1080) {
          await tester.tap(find.byTooltip('Abrir menú'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(title).first);
        await tester.tap(find.text(title).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
        if (title == 'Recepción' && (width == 1440 || width == 390)) {
          await captureMasiva(tester, 'masiva-recepcion-$width');
        }
        if ((title == 'Listado maestro' || title == 'Base de datos maestra') &&
            (width == 1440 || width == 390)) {
          final tableTitle = find.descendant(
            of: find.byType(MasivaMaestroTabla),
            matching: find.text(title),
          );
          await tester.ensureVisible(tableTitle);
          await tester.pumpAndSettle();
          await captureMasiva(
            tester,
            'masiva-${title == 'Listado maestro' ? 'listado-maestro' : 'base-maestra'}-$width',
          );
        }
        if (title == 'Validación') {
          final document = find.byKey(const ValueKey('masiva-persona'));
          await tester.ensureVisible(document);
          await tester.enterText(document, 'DEMO-01');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          expect(find.text('Validar 1 unidad'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (width == 1440 || width == 390) {
            await tester.ensureVisible(
              find.byKey(const ValueKey('masiva-sku')),
            );
            await tester.pumpAndSettle();
            await captureMasiva(tester, 'masiva-validacion-detalle-$width');
            await tester.ensureVisible(
              find.byKey(const ValueKey('masiva-validation-summary')),
            );
            await tester.pumpAndSettle();
            await captureMasiva(tester, 'masiva-validacion-$width');
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test('Los fixtures cubren las 22 y 36 columnas del maestro', () {
    expect(
      masivaListadoColumnas
          .singleWhere((column) => column.key == 'fecha_generado')
          .title,
      'Fecha de PDF',
    );
    expect(masivaListadoColumnas.length, 22);
    expect(masivaBaseColumnas.length, 36);
    for (final row in _listadoMaestroFixture) {
      expect(row.keys.toSet(), masivaListadoColumnas.map((c) => c.key).toSet());
    }
    for (final column in masivaBaseColumnas) {
      expect(
        _baseMaestraFixture.single.containsKey(column.key),
        isTrue,
        reason: column.key,
      );
    }
  });

  testWidgets('Generar lista individual o listas masivas según selección', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MasivaFixture();
    await mount(tester, const Size(1440, 1000), repo);
    await tester.tap(find.text('Listado maestro').first);
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('masiva-master-generate-lists'));
    expect(tester.widget<OutlinedButton>(action).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('maestro-select-88')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
    expect(find.text('Generar lista (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('maestro-select-89')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
    expect(find.text('Generar listas (2)'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Listado maestro consulta filtros y búsqueda en servidor', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MasivaFixture();
    await mount(tester, const Size(1440, 1000), repo);
    await tester.tap(find.text('Listado maestro').first);
    await tester.pumpAndSettle();
    expect(repo.maestroConsultas.last['vista'], 'listado');
    expect(repo.maestroConsultas.last['fecha_tipo'], 'ultima_validacion');
    expect(repo.maestroConsultas.last['tamano'], 30);

    await tester.ensureVisible(
      find.byKey(const ValueKey('maestro-filter-lista')),
    );
    await tester.tap(find.byKey(const ValueKey('maestro-filter-lista')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '89'));
    await tester.tap(find.text('APLICAR FILTRO'));
    await tester.pumpAndSettle();
    expect(repo.maestroConsultas.last['filtros'], {
      'lista': {'89'},
    });
    final filtered = tester.widget<MasivaMaestroTabla>(
      find.byType(MasivaMaestroTabla),
    );
    expect(filtered.filas.map((row) => row['lista']), ['89']);
    // La faceta recibida conserva las opciones globales aunque solo haya una fila.
    expect(filtered.opciones['lista'], ['88', '89']);

    final search = find.byKey(const ValueKey('masiva-master-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Cali');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.maestroConsultas.last['buscar'], 'Cali');
    expect(repo.maestroConsultas.last['filtros'], {
      'lista': {'89'},
    });
    expect(repo.maestroConsultas.last['pagina'], 1);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Detalle navega de listado a base filtrada y al kit de validación',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MasivaFixture();
      await mount(tester, const Size(1440, 1000), repo);
      await tester.tap(find.text('Listado maestro').first);
      await tester.pumpAndSettle();
      final openList = find.byKey(const ValueKey('maestro-open-88'));
      await tester.ensureVisible(openList);
      await tester.tap(openList);
      await tester.pumpAndSettle();
      expect(repo.maestroConsultas.last['vista'], 'base');
      expect(repo.maestroConsultas.last['filtros'], {
        'lista': {'88'},
      });
      final base = tester.widget<MasivaMaestroTabla>(
        find.byType(MasivaMaestroTabla),
      );
      expect(base.base, isTrue);
      expect(base.filas.single['kit_id'], 'kit1');
      expect(base.filas.single['cedula'], '0001234567');
      expect(base.onSeleccionChanged, isNull);

      final openKit = find.byKey(const ValueKey('maestro-open-kit1'));
      await tester.ensureVisible(openKit);
      final openKitText = find.descendant(
        of: openKit,
        matching: find.text('Abrir kit'),
      );
      expect(
        DefaultTextStyle.of(tester.element(openKitText)).style.fontFamily,
        'ConductorSans',
        reason: 'La acción conserva la tipografía corporativa.',
      );
      await tester.tap(openKit);
      await tester.pumpAndSettle();
      final kitQuery = repo.consultas.lastWhere((q) => q['vista'] == 'kits');
      expect(kitQuery['buscar'], 'kit1');
      expect(find.text('Validar 1 unidad'), findsOneWidget);
      expect(find.byKey(const ValueKey('masiva-sku')), findsOneWidget);
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Al reducirse el total se recarga una página válida del maestro', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rows = List<MasivaJson>.generate(
      31,
      (i) => {..._listadoMaestroFixture.first, 'lista': '${100 + i}'},
    );
    final repo = MasivaFixture(listadoMaestro: rows);
    await mount(tester, const Size(1440, 1000), repo);
    await tester.tap(find.text('Listado maestro').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MasivaMaestroTabla>(find.byType(MasivaMaestroTabla))
          .filas
          .length,
      30,
    );
    expect(find.text('Página 1 de 2'), findsOneWidget);
    final next = find.byTooltip('Página siguiente');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(repo.maestroConsultas.last['pagina'], 2);
    expect(
      tester
          .widget<MasivaMaestroTabla>(find.byType(MasivaMaestroTabla))
          .filas
          .single['lista'],
      '130',
    );
    expect(find.text('Página 2 de 2'), findsOneWidget);

    // Otro usuario reduce el conjunto mientras esta sesión está en la página 2.
    repo.listadoMaestro = [rows.first];
    final before = repo.maestroConsultas.length;
    await tester.tap(find.byTooltip('Actualizar datos'));
    await tester.pumpAndSettle();
    expect(repo.maestroConsultas.skip(before).map((q) => q['pagina']), [2, 1]);
    expect(
      tester
          .widget<MasivaMaestroTabla>(find.byType(MasivaMaestroTabla))
          .filas
          .single['lista'],
      '100',
    );
    expect(find.text('Página 1 de 1'), findsOneWidget);
    expect(find.text('1 listas · Mostrando 1–1'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'El Excel exporta la consulta aplicada aunque se edite texto sin consultar',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final picker = _ExcelPickerFixture();
      FilePicker.platform = picker;
      // El runner de widgets no registra el plugin nativo automáticamente.
      addTearDown(() => FilePicker.platform = _ExcelPickerFixture());
      final repo = MasivaFixture();
      await mount(tester, const Size(1440, 1000), repo);
      await tester.tap(find.text('Listado maestro').first);
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('masiva-master-search'));
      final list = find.byKey(const ValueKey('masiva-master-list'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Cali');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.enterText(list, '89');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.maestroConsultas.last['buscar'], 'Cali');
      expect(repo.maestroConsultas.last['filtros'], {
        'lista': {'89'},
      });

      final consulted = repo.maestroConsultas.length;
      await tester.enterText(search, 'Bogotá');
      await tester.enterText(list, '88');
      expect(
        repo.maestroConsultas.length,
        consulted,
        reason: 'Editar campos no debe aplicar la nueva consulta.',
      );
      final export = find.text('Descargar informe Excel');
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.pumpAndSettle();
      final query =
          repo.maestroConsultas
              .where((q) => q['incluir_opciones'] == false)
              .single;
      expect(query['buscar'], 'Cali');
      expect(query['filtros'], {
        'lista': {'89'},
      });
      expect(query['fecha_tipo'], 'ultima_validacion');
      expect(query['tamano'], 1000);
      expect(query['pagina'], 1);
      expect(picker.nombre, 'Listado_maestro.xlsx');
      expect(picker.archivo, isNotNull);
      final sheet = xlsx.Excel.decodeBytes(picker.archivo!).tables['Masiva']!;
      expect(sheet.rows.length, 2);
      final headers =
          sheet.rows.first.map((cell) => cell?.value.toString()).toList();
      expect(
        sheet.rows[1][headers.indexOf('Lista de empaque')]?.value,
        xlsx.TextCellValue('89'),
      );
      expect(
        sheet.rows[1][headers.indexOf('Ciudad')]?.value,
        xlsx.TextCellValue('Cali'),
      );
      expect(repo.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Recepción conserva filtros al consultar prendas y cancelar ingreso',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MasivaFixture();
      await mount(tester, const Size(1920, 1100), repo);
      await tester.tap(find.text('Recepción').first);
      await tester.pumpAndSettle();
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Ver prendas')),
        ).style.fontFamily,
        'ConductorSans',
      );
      await captureMasiva(tester, 'masiva-recepcion-1920');
      await tester.ensureVisible(
        find.byKey(const ValueKey('masiva-filter-pedido')),
      );
      await tester.tap(find.byKey(const ValueKey('masiva-filter-pedido')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, '10001'));
      await tester.tap(find.text('APLICAR FILTRO'));
      await tester.pumpAndSettle();
      expect(repo.recepcionConsultas.last['filtros'], {
        'pedido': {'10001'},
      });
      await tester.ensureVisible(find.text('Ver prendas'));
      await tester.tap(find.text('Ver prendas'));
      await tester.pumpAndSettle();
      expect(repo.recepcionConsultas.last['proveedor'], 'Proveedor de ejemplo');
      expect(repo.recepcionConsultas.last['pedido'], '10001');
      expect(find.textContaining('Camisa manga larga talla M'), findsWidgets);
      await tester.ensureVisible(find.text('Recibir'));
      await captureMasiva(tester, 'masiva-recepcion-prendas-ancho');
      await tester.tap(find.text('Recibir'));
      await tester.pumpAndSettle();
      expect(find.text('Recepción de prendas'), findsOneWidget);
      expect(find.text('Remisión o soporte'), findsOneWidget);
      expect(find.text('Novedad de recepción (opcional)'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('masiva-recepcion-sku')),
            )
            .controller!
            .text,
        '000123',
      );
      await tester.tap(find.byKey(const ValueKey('receipt-tab-1')));
      await tester.pumpAndSettle();
      expect(repo.historialRecepcionConsultas, hasLength(1));
      expect(find.text('SKU 000123'), findsOneWidget);
      expect(find.text('Remisión: REM-88'), findsOneWidget);
      await captureMasivaOverlay(tester, 'masiva-recepcion-historial-1920');
      await tester.tap(find.byKey(const ValueKey('receipt-tab-0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('masiva-recepcion-sku')),
            )
            .controller!
            .text,
        '000123',
      );
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('Volver a órdenes'));
      await tester.pumpAndSettle();
      expect(repo.recepcionConsultas.last['proveedor'], isNull);
      expect(repo.recepcionConsultas.last['filtros'], {
        'pedido': {'10001'},
      });
      expect(find.text('1 filtro activo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets(
      'Historial de recepción a $width px y búsqueda sin resultados',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MasivaFixture();
        await mount(tester, Size(width, 844), repo);
        await tester.tap(find.byTooltip('Abrir menú'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recepción').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('open-receipt-station')),
        );
        await tester.tap(find.byKey(const ValueKey('open-receipt-station')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('receipt-tab-1')));
        await tester.pumpAndSettle();
        expect(find.text('SKU 000123'), findsOneWidget);
        if (width == 390) {
          await captureMasivaOverlay(tester, 'masiva-recepcion-historial-390');
        }
        await tester.enterText(
          find.byKey(const ValueKey('receipt-history-search')),
          'sin-coincidencias',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          repo.historialRecepcionConsultas.last['buscar'],
          'sin-coincidencias',
        );
        expect(find.text('Sin resultados para la búsqueda'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('No hay datos de ejemplo guardados en la vista local', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, const Size(1440, 900), MasivaRepository(null));
    expect(find.text('Tu próxima masiva comienza aquí'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear primera masiva'),
    );
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
