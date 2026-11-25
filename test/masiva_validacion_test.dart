import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'masiva_ui_test.dart'
    show MasivaFixture, captureMasiva, captureMasivaOverlay, mount;

class ValidacionFixture extends MasivaFixture {
  ValidacionFixture({
    this.multiple = false,
    this.validated = 1,
    this.secondArticle = false,
    this.missingPacker = false,
  });

  bool missingPacker;
  final bool multiple;
  final bool secondArticle;
  int validated;
  bool concurrentExcess = false;
  final writes = <({String action, MasivaJson data})>[];

  @override
  Future<MasivaJson> consultarEmpaque(String operacion, String lista) async => {
    'kits': [
      {'id': 'posterior', 'numero_persona': 12},
      {'id': 'kit1', 'numero_persona': 7},
      {'id': 'anterior', 'numero_persona': 2},
    ],
  };

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
      vista: vista == 'validacion_documento' ? 'kits' : vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
    if (operacion == null ||
        !['kits', 'validacion_documento'].contains(vista)) {
      return base;
    }
    final row = <String, dynamic>{
      ...filasMasiva(base['filas']).single,
      'armado': null,
      'empacador_id': missingPacker ? null : 'person1',
      'empacador': missingPacker ? null : 'Empacador de ejemplo',
      'sede': 'Sede de ejemplo',
      'ciudad': 'Bogotá D.C.',
      'sector': 'Centro',
      'estado': validated == 2 && !secondArticle ? 'validado' : 'parcial',
      'revision_abierta': validated < 2 || secondArticle,
      'articulos': [
        {
          'id': 'art1',
          'sku': '000123',
          'descripcion': 'Camisa manga larga talla M',
          'cantidad': 2,
          'validado': validated,
          'fecha_hora_validado': validated > 0 ? '2026-10-27T14:30:00Z' : null,
        },
        if (secondArticle)
          {
            'id': 'art2',
            'sku': '000456',
            'descripcion': 'Calzado de trabajo talla 40',
            'cantidad': 1,
            'validado': 0,
            'fecha_hora_validado': null,
          },
      ],
    };
    final rows = [
      row,
      if (multiple && buscar != 'kit1') {...row, 'id': 'kit2', 'lista': '89'},
    ];
    return jsonDecode(
          jsonEncode({...base, 'filas': rows, 'total': rows.length}),
        )
        as MasivaJson;
  }

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    calls.add(accion);
    writes.add((
      action: accion,
      data: jsonDecode(jsonEncode(datos)) as MasivaJson,
    ));
    if (accion == 'validar') {
      if (concurrentExcess) {
        concurrentExcess = false;
        validated = 2;
        throw PostgrestException(
          message: 'Retira la prenda adicional.',
          code: 'P0001',
          details: jsonEncode({
            'tipo': 'unidad_excedente',
            'sku': '000123',
            'descripcion': 'Camisa manga larga talla M',
            'cantidad': 2,
            'validado': 2,
          }),
        );
      }
      if (datos['empacador_id'] == 'person1') missingPacker = false;
      validated++;
      return {'validado': validated};
    }
    if (accion == 'reiniciar_validacion') validated = 0;
    return {};
  }
}

class PackedValidationFixture extends ValidacionFixture {
  PackedValidationFixture({bool partial = false})
    : reviewOpen = partial,
      super(validated: partial ? 1 : 2);

  bool reviewOpen;
  bool rejectPackaging = false;
  int containerNumber = 3;
  String packageId = 'box1';

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    final result = await super.consultar(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
    if (operacion != null && vista == 'empaques') {
      return {
        ...result,
        'filas': [
          ...filasMasiva(result['filas']),
          {
            'id': 'box2',
            'nombre': 'Bolsa grande',
            'peso_lleno': 5,
            'activo': true,
          },
        ],
      };
    }
    if (operacion != null && ['kits', 'validacion_documento'].contains(vista)) {
      return {
        ...result,
        'filas': [
          for (final row in filasMasiva(result['filas']))
            {
              ...row,
              'caja_id': 'packed-box',
              'caja': containerNumber,
              'empaque_id': packageId,
              'validacion_inicio': '2026-10-27T14:30:00Z',
              'revision_abierta': reviewOpen,
            },
        ],
      };
    }
    return result;
  }

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'reabrir') reviewOpen = true;
    if (accion == 'corregir') validated = datos['cantidad'] as int;
    if (accion == 'embalar') {
      if (rejectPackaging) {
        throw const PostgrestException(
          message:
              'El empaque contiene otros kits; selecciona otro contenedor.',
          code: 'P0001',
        );
      }
      containerNumber = datos['caja'] as int;
      packageId = datos['empaque_id'] as String;
    }
    return super.ejecutar(accion, datos);
  }
}

class DelayedValidationFixture extends ValidacionFixture {
  DelayedValidationFixture() : super(validated: 0);

  final release = Completer<void>();
  final started = <MasivaJson>[];
  MasivaJson? pending;

  @override
  MasivaJson? get movimientoPendiente => pending;

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'validar') {
      started.add(datos);
      if (started.length == 1) {
        pending = {'accion': accion, 'datos': datos};
        try {
          await release.future;
        } finally {
          pending = null;
        }
      }
    }
    return super.ejecutar(accion, datos);
  }
}

class InventoryRejectedFixture extends ValidacionFixture {
  InventoryRejectedFixture() : super(secondArticle: true);

  final rejected = <MasivaJson>[];

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'validar' && datos['sku'] == '000456') {
      rejected.add(Map<String, dynamic>.from(datos));
      throw const PostgrestException(
        message: 'No hay inventario recibido suficiente para este SKU',
        code: 'P0001',
      );
    }
    return super.ejecutar(accion, datos);
  }
}

class NetworkRejectedFixture extends ValidacionFixture {
  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'validar') {
      throw TimeoutException('No se recibió confirmación del servidor');
    }
    return super.ejecutar(accion, datos);
  }
}

class ExcessRefreshFailedFixture extends ValidacionFixture {
  ExcessRefreshFailedFixture() : super(secondArticle: true) {
    concurrentExcess = true;
  }

  bool failRefresh = true;

  @override
  Future<MasivaJson> consultar({
    String? operacion,
    String vista = 'resumen',
    String buscar = '',
    String lista = '',
    int pagina = 1,
  }) async {
    if (vista == 'kits' && buscar == 'kit1' && failRefresh) {
      failRefresh = false;
      throw TimeoutException('Falló la actualización posterior al rechazo');
    }
    return super.consultar(
      operacion: operacion,
      vista: vista,
      buscar: buscar,
      lista: lista,
      pagina: pagina,
    );
  }
}

class DelayedInventoryRejectedFixture extends InventoryRejectedFixture {
  final release = Completer<void>();

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion == 'validar' && datos['sku'] == '000456') {
      await release.future;
    }
    return super.ejecutar(accion, datos);
  }
}

Future<void> openValidation(
  WidgetTester tester,
  ValidacionFixture repo, {
  Size size = const Size(1440, 1100),
  bool search = true,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  await mount(tester, size, repo);
  if (size.width < 1080) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Validación').first);
  await tester.pumpAndSettle();
  if (search) await searchPerson(tester);
}

Future<void> searchPerson(WidgetTester tester) async {
  final person = find.byKey(const ValueKey('masiva-persona'));
  await tester.ensureVisible(person);
  await tester.enterText(person, 'DEMO-01');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Future<void> scanSku(WidgetTester tester, String sku) async {
  final input = find.byKey(const ValueKey('masiva-sku'));
  await tester.ensureVisible(input);
  await tester.enterText(input, sku);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // The scan remains pending until the operator acknowledges the blocking
  // alert, so its loading animation intentionally keeps scheduling frames.
  if (find.text('Prenda retirada · continuar').evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> captureValidationAlert(WidgetTester tester) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.single;
    final scene = view.debugLayer!.buildScene(ui.SceneBuilder());
    try {
      final image = await scene.toImage(
        tester.view.physicalSize.width.toInt(),
        tester.view.physicalSize.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '.dart_tool/masiva-validacion-excedente.png',
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
    // Global dialogs inherit Roboto outside the Masiva page's custom theme.
    final materialFonts = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.uri.resolve('material_fonts/');
    final roboto = FontLoader('Roboto');
    for (final weight in ['regular', 'bold']) {
      final file = File.fromUri(materialFonts.resolve('roboto-$weight.ttf'));
      roboto.addFont(
        file.existsSync()
            ? file.readAsBytes().then((bytes) => bytes.buffer.asByteData())
            : rootBundle.load(
              'assets/fonts/LiberationSans-${weight == 'bold' ? 'Bold' : 'Regular'}.ttf',
            ),
      );
    }
    await roboto.load();
  });

  testWidgets('Documento único abre automáticamente la estación sin escribir', (
    tester,
  ) async {
    final repo = ValidacionFixture();
    await openValidation(tester, repo, search: false);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
          .enabled,
      isFalse,
    );
    await captureMasiva(tester, 'masiva-validacion-inicial');
    await searchPerson(tester);
    expect(find.text('KIT EN VALIDACIÓN'), findsOneWidget);
    expect(find.text('Kit 2 de 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('masiva-sku')), findsOneWidget);
    expect(find.text('Validar 1 unidad'), findsOneWidget);
    expect(find.text('Sede: Sede de ejemplo'), findsOneWidget);
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Documento duplicado detiene validación sin elegir una persona', (
    tester,
  ) async {
    final repo = ValidacionFixture(multiple: true);
    await openValidation(tester, repo);
    expect(find.textContaining('El documento está duplicado'), findsOneWidget);
    expect(find.text('Abrir kit'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
          .enabled,
      isFalse,
    );
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SKU correcto suma uno; incorrecto y excedente exigen retirar', (
    tester,
  ) async {
    final repo = ValidacionFixture();
    await openValidation(tester, repo);
    await scanSku(tester, 'CODIGO-ERRADO');
    expect(find.text('Código incorrecto'), findsOneWidget);
    expect(find.text('SKU: CODIGO-ERRADO'), findsOneWidget);
    expect(repo.writes, isEmpty);
    expect(repo.validated, 1);
    await tester.tapAt(const Offset(4, 90));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Código incorrecto'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Código incorrecto'), findsOneWidget);
    expect(repo.writes, isEmpty);
    await tester.tap(find.text('Prenda retirada · continuar'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await scanSku(tester, '000123');
    expect(repo.writes.where((w) => w.action == 'validar'), hasLength(1));
    expect(repo.validated, 2);
    expect(find.text('000123 · 1 unidad validada'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
          .enabled,
      isTrue,
    );
    await scanSku(tester, '000123');
    expect(find.text('Unidad excedente'), findsOneWidget);
    expect(find.text('SKU: 000123'), findsOneWidget);
    expect(find.text('Requeridas: 2 · Ya validadas: 2'), findsOneWidget);
    await captureValidationAlert(tester);
    expect(repo.writes.where((w) => w.action == 'validar'), hasLength(1));
    expect(repo.validated, 2);
    await tester.tap(find.text('Prenda retirada · continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Exceso confirmado por servidor muestra alerta y refresca conteo',
    (tester) async {
      final repo = ValidacionFixture()..concurrentExcess = true;
      await openValidation(tester, repo);
      await scanSku(tester, '000123');
      expect(find.text('Unidad excedente'), findsOneWidget);
      expect(repo.writes.where((w) => w.action == 'validar'), hasLength(1));
      await tester.tap(find.text('Prenda retirada · continuar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Este kit está validado.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('000123 · 1 unidad validada'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets(
      'Excedente con refresco fallido permite seguir validando $width',
      (tester) async {
        final repo = ExcessRefreshFailedFixture();
        await openValidation(tester, repo, size: Size(width, 1100));
        await scanSku(tester, '000123');
        expect(find.text('Unidad excedente'), findsOneWidget);
        await tester.tap(find.text('Prenda retirada · continuar'));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('masiva-sku')),
        );
        expect(field.enabled, isTrue);
        expect(field.focusNode!.hasPrimaryFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(repo.validated, 2);
        await captureMasiva(
          tester,
          'masiva-excedente-recuperado-${width.toInt()}',
        );
        // Input through the existing scanner connection, without refocusing it.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(text: '000456'),
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(repo.writes.where((w) => w.action == 'validar'), hasLength(2));
        expect(repo.writes.last.data['sku'], '000456');
        expect(find.text('000456 · 1 unidad validada'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Empaque parcial exige confirmación y cancelar no escribe', (
    tester,
  ) async {
    final repo = ValidacionFixture();
    await openValidation(tester, repo);
    final pack = find.widgetWithText(FilledButton, 'Empacar');
    await tapVisible(tester, pack);
    expect(find.text('Kit incompleto'), findsOneWidget);
    expect(
      find.textContaining('000123 · Camisa manga larga talla M: faltan 1'),
      findsOneWidget,
    );
    expect(find.text('Empacar parcial'), findsOneWidget);
    await tester.tap(find.text('Seguir validando'));
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    await tapVisible(tester, pack);
    await tester.tap(find.text('Empacar parcial'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Selecciona el tipo de empaque'),
      findsOneWidget,
    );
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reinicio envía motivo y snapshot de todas las cantidades', (
    tester,
  ) async {
    final repo = ValidacionFixture(secondArticle: true);
    await openValidation(tester, repo);
    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Reiniciar validación'),
    );
    final motive = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Motivo del reinicio *',
    );
    await tester.enterText(motive, 'Reconteo por revisión física');
    await tester.tap(find.widgetWithText(FilledButton, 'Reiniciar validación'));
    await tester.pumpAndSettle();
    final write = repo.writes.single;
    expect(write.action, 'reiniciar_validacion');
    expect(write.data['operacion_id'], 'demo');
    expect(write.data['kit_id'], 'kit1');
    expect(write.data['motivo'], 'Reconteo por revisión física');
    expect(write.data['cantidades'], [
      {'articulo_id': 'art1', 'validado': 1},
      {'articulo_id': 'art2', 'validado': 0},
    ]);
    expect(write.data['request_id'], matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(repo.validated, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dos lecturas rápidas se encolan con la primera RPC pendiente', (
    tester,
  ) async {
    final repo = DelayedValidationFixture();
    await openValidation(tester, repo);
    final field = find.byKey(const ValueKey('masiva-sku'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '000123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repo.started, hasLength(1));
    expect(repo.movimientoPendiente, isNotNull);
    expect(repo.validated, 0);
    expect(tester.widget<TextField>(field).enabled, isTrue);
    expect(
      tester.widget<TextField>(field).focusNode!.hasFocus,
      isTrue,
      reason:
          'El lector conserva el foco mientras se confirma la primera lectura',
    );
    await tester.enterText(field, '000123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      repo.started,
      hasLength(1),
      reason: 'La segunda lectura espera a la primera',
    );
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(repo.started, hasLength(2));
    expect(repo.writes.where((w) => w.action == 'validar'), hasLength(2));
    expect(repo.validated, 2);
    expect(repo.started.map((r) => r['request_id']).toSet(), hasLength(2));
    expect(repo.movimientoPendiente, isNull);
    expect(find.text('Completo'), findsWidgets);
    expect(find.text('000123 · 1 unidad validada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Asignación tardía viaja con la primera validación sin armado previo',
    (tester) async {
      final repo = ValidacionFixture(missingPacker: true, validated: 0);
      await openValidation(tester, repo);
      final sku = find.byKey(const ValueKey('masiva-sku'));
      expect(tester.widget<TextField>(sku).enabled, isFalse);
      await captureMasiva(tester, 'masiva-validacion-sin-empaque');
      final picker = find.byKey(const ValueKey('masiva-validation-packer'));
      await tapVisible(tester, picker);
      await tester.tap(find.text('Empacador de ejemplo').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('MAL EMPAQUE'), findsWidgets);
      await scanSku(tester, '000123');
      expect(repo.writes.single.data['empacador_id'], 'person1');
      expect(repo.writes.single.data.containsKey('validador_id'), isFalse);
      await scanSku(tester, '000123');
      expect(repo.writes.last.data.containsKey('empacador_id'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Empacar conserva tipo y contenedor para el siguiente documento',
    (tester) async {
      final repo = ValidacionFixture(validated: 2);
      await openValidation(tester, repo);
      final type = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Tipo de empaque',
      );
      await tapVisible(tester, type);
      await tester.tap(find.text('Caja mediana').last);
      await tester.pumpAndSettle();
      final number = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'N.º de contenedor',
      );
      await tester.ensureVisible(number);
      await tester.enterText(number, '3');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
      expect(repo.writes.single.action, 'embalar');
      expect(repo.writes.single.data['caja'], 3);
      expect(repo.writes.single.data['empaque_id'], 'box1');
      expect(find.text('KIT EN VALIDACIÓN'), findsNothing);
      await searchPerson(tester);
      expect(tester.widget<TextField>(number).controller!.text, '3');
      expect(find.text('Caja mediana'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('Kit empacado permite ver y editar empaque a $width px', (
      tester,
    ) async {
      final repo = PackedValidationFixture();
      await openValidation(tester, repo, size: Size(width, 1200));
      expect(find.text('El kit ya está empacado'), findsOneWidget);
      expect(find.text('Ver'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(repo.writes, isEmpty);
      await captureMasivaOverlay(
        tester,
        'masiva-kit-empacado-aviso-${width.toInt()}',
      );
      await tapVisible(tester, find.text('Ver'));
      final sku = find.byKey(const ValueKey('masiva-sku'));
      final container = find.byKey(
        const ValueKey('masiva-validation-container'),
      );
      final type = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Tipo de empaque',
      );
      expect(tester.widget<TextField>(sku).enabled, isFalse);
      expect(tester.widget<TextField>(container).enabled, isFalse);
      expect(
        tester.widget<DropdownButtonFormField<String>>(type).onChanged,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton &&
                    w.tooltip == 'Corregir cantidad con motivo',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(repo.writes, isEmpty);
      expect(repo.validated, 2);
      await searchPerson(tester);
      await tapVisible(tester, find.text('Editar'));
      final motive = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Motivo de la reapertura *',
      );
      await tester.enterText(motive, 'Cambiar bolsa y revisar cantidad');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Reabrir kit'),
      );
      expect(repo.writes.single.action, 'reabrir');
      expect(
        repo.writes.single.data['motivo'],
        'Cambiar bolsa y revisar cantidad',
      );
      expect(tester.widget<TextField>(sku).enabled, isTrue);
      expect(tester.widget<TextField>(container).enabled, isTrue);
      expect(
        tester.widget<DropdownButtonFormField<String>>(type).onChanged,
        isNotNull,
      );
      await tapVisible(tester, type);
      await tapVisible(tester, find.text('Paquete grande').last);
      await tester.ensureVisible(container);
      await tester.enterText(container, '7');
      await tester.pumpAndSettle();
      await captureMasiva(
        tester,
        'masiva-kit-empacado-editar-${width.toInt()}',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(repo.writes.last.action, 'embalar');
      expect(repo.writes.last.data['caja'], 7);
      expect(repo.writes.last.data['empaque_id'], 'box2');
      expect(repo.validated, 2);
      expect(find.text('KIT EN VALIDACIÓN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Cancelar edición de kit empacado conserva consulta sin escrituras',
    (tester) async {
      final repo = PackedValidationFixture();
      await openValidation(tester, repo);
      await tapVisible(tester, find.text('Editar'));
      await tapVisible(tester, find.widgetWithText(TextButton, 'Cancelar'));
      expect(repo.writes, isEmpty);
      expect(repo.reviewOpen, isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
            .enabled,
        isFalse,
      );
      expect(find.text('KIT EN VALIDACIÓN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reabrir kit parcial habilita correcciones y tipo de empaque', (
    tester,
  ) async {
    final repo = PackedValidationFixture(partial: true);
    await openValidation(tester, repo);
    await tapVisible(tester, find.text('Ver'));
    await tapVisible(tester, find.text('Reabrir revisión'));
    final motive = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Motivo de la reapertura *',
    );
    await tester.enterText(motive, 'Completar y corregir kit parcial');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Reabrir kit'));
    expect(repo.writes.single.action, 'reabrir');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('masiva-validation-container')),
          )
          .enabled,
      isTrue,
    );
    await tapVisible(tester, find.byTooltip('Corregir cantidad con motivo'));
    final quantity = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Cantidad final validada *',
    );
    final correctionMotive = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Motivo de la corrección *',
    );
    await tester.enterText(quantity, '2');
    await tester.enterText(correctionMotive, 'Conteo físico de dos unidades');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Guardar corrección'),
    );
    expect(repo.writes.last.action, 'corregir');
    expect(repo.writes.last.data['cantidad'], 2);
    expect(repo.validated, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rechazo al guardar conserva edición y permite reintentar', (
    tester,
  ) async {
    final repo = PackedValidationFixture()..rejectPackaging = true;
    await openValidation(tester, repo);
    await tapVisible(tester, find.text('Editar'));
    final motive = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Motivo de la reapertura *',
    );
    await tester.enterText(motive, 'Cambiar contenedor');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Reabrir kit'));
    final container = find.byKey(const ValueKey('masiva-validation-container'));
    await tester.enterText(container, '7');
    final save = find.widgetWithText(FilledButton, 'Guardar cambios');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining('El empaque contiene otros kits'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(repo.writes.map((w) => w.action), ['reabrir']);
    expect(repo.containerNumber, 3);
    expect(repo.validated, 2);
    expect(tester.widget<TextField>(container).enabled, isTrue);
    expect(tester.widget<TextField>(container).controller!.text, '7');
    expect(find.text('KIT EN VALIDACIÓN'), findsOneWidget);
    repo.rejectPackaging = false;
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Guardar cambios'),
    );
    expect(repo.writes.last.action, 'embalar');
    expect(repo.containerNumber, 7);
    expect(find.text('KIT EN VALIDACIÓN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rechazo de inventario detiene cola y avisa repetir pendientes', (
    tester,
  ) async {
    final repo = DelayedInventoryRejectedFixture();
    await openValidation(tester, repo);
    final input = find.byKey(const ValueKey('masiva-sku'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '000456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(input, '000123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(repo.rejected, hasLength(1));
    expect(repo.writes, isEmpty);
    expect(repo.validated, 1);
    expect(
      find.textContaining('Repite las 1 lecturas posteriores'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(input).enabled, isTrue);
    await scanSku(tester, '000123');
    expect(repo.writes, hasLength(1));
    expect(repo.validated, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Error de red no se confunde con rechazo de inventario', (
    tester,
  ) async {
    final repo = NetworkRejectedFixture();
    await openValidation(tester, repo);
    final input = find.byKey(const ValueKey('masiva-sku'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '000123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cerrar aviso'), findsOneWidget);
    expect(
      find.textContaining('Sin inventario recibido disponible'),
      findsNothing,
    );
    expect(repo.writes, isEmpty);
    expect(repo.validated, 1);
    await tester.tap(find.text('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('Inventario insuficiente permite continuar a $width px', (
      tester,
    ) async {
      final repo = InventoryRejectedFixture();
      await openValidation(tester, repo, size: Size(width, 1200));
      final existingBarriers = find.byType(ModalBarrier).evaluate().length;
      final input = find.byKey(const ValueKey('masiva-sku'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '000456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.rejected, hasLength(1));
      expect(repo.writes, isEmpty);
      expect(repo.validated, 1);
      expect(find.byType(ModalBarrier), findsNWidgets(existingBarriers));
      await tester.pumpAndSettle();
      expect(find.textContaining('inventario'), findsWidgets);
      expect(find.text('KIT EN VALIDACIÓN'), findsOneWidget);
      expect(find.text('Kit 2 de 3'), findsOneWidget);
      expect(tester.widget<TextField>(input).enabled, isTrue);
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await captureMasiva(tester, 'masiva-inventario-aviso-${width.toInt()}');
      await scanSku(tester, '000123');
      expect(repo.validated, 2);
      expect(repo.writes, hasLength(1));
      expect(repo.writes.single.data['sku'], '000123');
      expect(find.text('000123 · 1 unidad validada'), findsOneWidget);
      if (width < 1080) {
        await tester.tap(find.byTooltip('Abrir menú'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Recepción').first);
      await tester.pumpAndSettle();
      expect(find.text('KIT EN VALIDACIÓN'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Validación responsive sin desbordamientos a $width px', (
      tester,
    ) async {
      await openValidation(
        tester,
        ValidacionFixture(),
        size: Size(width, 1200),
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('KIT EN VALIDACIÓN')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kit 2 de 3'), findsOneWidget);
      await captureMasiva(tester, 'masiva-validacion-${width.toInt()}');
      expect(tester.takeException(), isNull);
      await scanSku(tester, '000123');
      expect(find.text('000123 · 1 unidad validada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
