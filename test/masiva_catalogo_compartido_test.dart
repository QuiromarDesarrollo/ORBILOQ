import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/empaques_repository.dart';
import 'package:orbiloq_wms/features/admin/presentation/empaque_editor.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:orbiloq_wms/features/masiva/presentation/masiva_page.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'masiva_ui_test.dart' show captureMasiva;
import 'masiva_validacion_test.dart'
    show ValidacionFixture, openValidation, searchPerson, tapVisible;

const _package = <String, dynamic>{
  'id': 'box1',
  'version': 'version-original',
  'nombre': 'Caja mediana',
  'categoria': 'CAJA',
  'largo_cm': 50,
  'ancho_cm': 40,
  'alto_cm': 35,
  'peso_neto_kg': 0.5,
  'peso_promedio_masiva_kg': 15,
  'activo': true,
};

class _CatalogFixture extends EmpaquesRepository {
  _CatalogFixture({num? promedio = 15})
    : row = {..._package, 'peso_promedio_masiva_kg': promedio},
      super(
        SupabaseClient(
          'https://catalog-fixture.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  Map<String, dynamic> row;
  final writes =
      <({Map<String, dynamic> datos, Map<String, dynamic>? anterior})>[];

  @override
  Future<List<Map<String, dynamic>>> listar({bool todos = false}) async => [
    row,
  ];

  @override
  Future<void> guardar(
    Map<String, dynamic> datos,
    Map<String, dynamic>? anterior,
  ) async {
    writes.add((
      datos: Map.of(datos),
      anterior: anterior == null ? null : Map.of(anterior),
    ));
    row = {...row, ...datos, 'version': 'version-actualizada'};
  }
}

class _MasivaCatalogFixture extends ValidacionFixture {
  _MasivaCatalogFixture(
    this.catalog, {
    this.historical = false,
    this.historicalPackageId = 'old-box',
  }) : super(validated: 2);

  final _CatalogFixture catalog;
  bool historical;
  final String historicalPackageId;

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    final base = await super.consultar(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
    if (operacion == null) return base;
    if (vista == 'empaques') {
      return {
        ...base,
        'filas': [
          {
            ...catalog.row,
            'tipo': 'caja',
            'largo': catalog.row['largo_cm'],
            'ancho': catalog.row['ancho_cm'],
            'alto': catalog.row['alto_cm'],
            'peso_vacio': catalog.row['peso_neto_kg'],
            'peso_lleno': catalog.row['peso_promedio_masiva_kg'],
          },
          // It may be present in an administrator response, but must never
          // become available for a newly packed kit.
          {
            ..._package,
            'id': 'old-box',
            'nombre': 'Nombre actual inactivo',
            'activo': false,
          },
        ],
      };
    }
    if (['kits', 'validacion_documento'].contains(vista) && historical) {
      return {
        ...base,
        'filas': [
          for (final kit in filasMasiva(base['filas']))
            {
              ...kit,
              'caja': 7,
              'empaque_id': historicalPackageId,
              'empaque_snapshot': {
                'nombre': 'Caja histórica original',
                'tipo': 'caja',
                'largo': 60,
                'ancho': 40,
                'alto': 45,
                'peso_vacio': 1,
                'peso_lleno': 18,
              },
            },
        ],
      };
    }
    return base;
  }
}

Finder get _average =>
    find.byKey(const ValueKey('empaque-peso_promedio_masiva_kg'));
Finder get _save => find.widgetWithText(FilledButton, 'Guardar cambios');
Finder get _type => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> &&
      w.decoration.labelText == 'Tipo de empaque',
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
}

Future<void> _openEditor(
  WidgetTester tester,
  _CatalogFixture catalog, {
  bool masiva = false,
  Size size = const Size(1366, 900),
}) async {
  _viewport(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [empaquesRepositoryProvider.overrideWithValue(catalog)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kardex(TemaModo.corporativo),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showWmsDialog<bool>(
                        context,
                        (_) => EmpaqueEditor(
                          fila: catalog.row,
                          mostrarPesoMasiva: masiva,
                        ),
                      ),
                  child: const Text('Abrir editor'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir editor'));
  await tester.pumpAndSettle();
}

Future<void> _captureOverlay(WidgetTester tester, String name) async {
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
    for (final family in ['ConductorSans', 'Roboto']) {
      final font =
          FontLoader(family)
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'));
      await font.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'Despacho no muestra ni sobrescribe el promedio exclusivo de Masiva',
    (tester) async {
      final catalog = _CatalogFixture();
      await _openEditor(tester, catalog);
      expect(_average, findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('empaque-nombre')),
        'Caja mediana actualizada',
      );
      await _captureOverlay(tester, 'masiva-catalogo-editor-despacho');
      await tapVisible(tester, _save);
      expect(catalog.writes, hasLength(1));
      expect(
        catalog.writes.single.datos.containsKey('peso_promedio_masiva_kg'),
        isFalse,
      );
      expect(catalog.row['peso_promedio_masiva_kg'], 15);
      expect(catalog.writes.single.anterior?['version'], 'version-original');
      expect(find.byType(EmpaqueEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Masiva permite dejar el promedio pendiente sin inventar un peso cero',
    (tester) async {
      final catalog = _CatalogFixture();
      await _openEditor(tester, catalog, masiva: true);
      await tester.ensureVisible(_average);
      await tester.enterText(_average, '');
      await tapVisible(tester, _save);
      expect(catalog.writes, hasLength(1));
      expect(
        catalog.writes.single.datos.containsKey('peso_promedio_masiva_kg'),
        isTrue,
      );
      expect(catalog.row['peso_promedio_masiva_kg'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Promedio menor que tara se corrige sin perder el formulario y admite coma decimal',
    (tester) async {
      final catalog = _CatalogFixture();
      await _openEditor(tester, catalog, masiva: true);
      await tester.ensureVisible(_average);
      await tester.enterText(_average, '0,1');
      await tapVisible(tester, _save);
      expect(catalog.writes, isEmpty);
      expect(find.textContaining('igual o mayor que la tara'), findsWidgets);
      await _captureOverlay(tester, 'masiva-catalogo-editor-error-1366');
      await tester.ensureVisible(_average);
      await tester.enterText(_average, '18,75');
      await tapVisible(tester, _save);
      expect(catalog.writes.single.datos['peso_promedio_masiva_kg'], 18.75);
      expect(catalog.writes.single.datos['peso_neto_kg'], 0.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El kit encajado conserva su nombre original aunque el catálogo activo cambie',
    (tester) async {
      final catalog = _CatalogFixture();
      catalog.row = {...catalog.row, 'nombre': 'Caja mediana renombrada'};
      final repo = _MasivaCatalogFixture(
        catalog,
        historical: true,
        historicalPackageId: 'box1',
      );
      await openValidation(tester, repo, size: const Size(1366, 900));
      expect(find.text('Caja histórica original'), findsOneWidget);
      expect(find.text('Caja mediana renombrada'), findsNothing);
      expect(
        tester.widget<DropdownButtonFormField<String>>(_type).onChanged,
        isNull,
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
      expect(repo.writes.single.data['empaque_id'], 'box1');
      repo.historical = false;
      await searchPerson(tester);
      await tapVisible(tester, _type);
      expect(find.text('Caja histórica original'), findsNothing);
      expect(find.text('Caja mediana renombrada'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(1366, 900)]) {
    testWidgets(
      'Configuración ${size.width.toInt()}: editar catálogo compartido y refrescar promedio',
      (tester) async {
        final catalog = _CatalogFixture(promedio: null);
        final repo = _MasivaCatalogFixture(catalog);
        _viewport(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              masivaRepositoryProvider.overrideWithValue(repo),
              empaquesRepositoryProvider.overrideWithValue(catalog),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.kardex(TemaModo.corporativo),
              home: const RepaintBoundary(
                key: ValueKey('capture'),
                child: MasivaPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (size.width < 1080) {
          await tester.tap(find.byTooltip('Abrir menú'));
          await tester.pumpAndSettle();
        }
        await tapVisible(tester, find.text('Configuración').first);
        final edit = find.byTooltip('Editar Caja mediana');
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Promedio Masiva: pendiente de configurar'),
          findsWidgets,
        );
        await captureMasiva(
          tester,
          'masiva-catalogo-config-${size.width.toInt()}',
        );
        await tapVisible(tester, edit);
        expect(find.byType(EmpaqueEditor), findsOneWidget);
        await tester.ensureVisible(_average);
        await tester.enterText(_average, '16,5');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(_save.hitTestable(), findsOneWidget);
        await _captureOverlay(
          tester,
          'masiva-catalogo-editor-${size.width.toInt()}',
        );
        await tapVisible(tester, _save);
        expect(catalog.writes, hasLength(1));
        expect(catalog.writes.single.anterior?['id'], 'box1');
        expect(catalog.writes.single.anterior?['version'], 'version-original');
        expect(catalog.writes.single.datos['peso_promedio_masiva_kg'], 16.5);
        expect(find.textContaining('Promedio Masiva: 16.5 kg'), findsOneWidget);
        expect(
          repo.calls,
          isEmpty,
          reason:
              'El editor debe guardar en el catálogo compartido, no en guardar_empaque de Masiva',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Validación ${size.width.toInt()}: conserva empaque histórico inactivo y lo excluye del kit nuevo',
      (tester) async {
        final catalog = _CatalogFixture();
        final repo = _MasivaCatalogFixture(catalog, historical: true);
        await openValidation(tester, repo, size: size);
        await tester.ensureVisible(_type);
        await tester.pumpAndSettle();
        final historical = tester.widget<DropdownButtonFormField<String>>(
          _type,
        );
        expect(historical.onChanged, isNull);
        expect(find.text('Caja histórica original'), findsOneWidget);
        expect(find.text('Nombre actual inactivo'), findsNothing);
        final number = tester.widget<TextField>(
          find.byKey(const ValueKey('masiva-validation-container')),
        );
        expect(number.controller!.text, '7');
        expect(number.enabled, isFalse);
        await captureMasiva(
          tester,
          'masiva-catalogo-historico-${size.width.toInt()}',
        );
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
        expect(repo.writes.single.action, 'embalar');
        expect(repo.writes.single.data['empaque_id'], 'old-box');
        expect(repo.writes.single.data['caja'], 7);
        repo.historical = false;
        await searchPerson(tester);
        await tapVisible(tester, _type);
        expect(find.text('Caja histórica original'), findsNothing);
        expect(find.text('Nombre actual inactivo'), findsNothing);
        await tester.tap(find.text('Caja mediana').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('masiva-validation-container')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('masiva-validation-container')),
          '8',
        );
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
        expect(repo.writes, hasLength(2));
        expect(repo.writes.last.data['empaque_id'], 'box1');
        expect(repo.writes.last.data['caja'], 8);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
