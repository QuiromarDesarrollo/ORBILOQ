import 'dart:async';
import 'dart:convert';
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
import 'package:orbiloq_wms/data/despacho_borrador_repository.dart';
import 'package:orbiloq_wms/data/despachos_oc_repository.dart';
import 'package:orbiloq_wms/data/destinatarios_empaque.dart';
import 'package:orbiloq_wms/data/empaques_repository.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/data/seguimiento_entregas.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/rotulo_empaque.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';

const _cliente = 'CLIENTE PRUEBA A';
const _oc = 'OC-PRUEBA-A';

class _Borradores implements DespachoBorradorRepository {
  _Borradores(Map<String, dynamic> datos)
    : registro = {'version': 1, 'datos': datos};
  Map<String, dynamic>? registro;
  int eliminados = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>?> cargar(String clave) async => registro;
  @override
  Future<Map<String, dynamic>> guardar(
    String clave,
    Map<String, dynamic> datos, {
    int version = 0,
  }) async {
    expect(version, registro?['version'] ?? 0);
    return registro = {
      'version': version + 1,
      'datos': jsonDecode(jsonEncode(datos)),
    };
  }

  @override
  Future<void> eliminar(String clave, {required int version}) async {
    expect(version, registro!['version']);
    eliminados++;
    registro = null;
  }
}

class _Despachos implements DespachosOcRepository {
  final solicitudes = <String>[];
  final planes = <List<Map<String, dynamic>>>[];
  final empaques = <List<Map<String, dynamic>>>[];
  Completer<void>? respuesta;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<Map<String, dynamic>>> historial() async => [];
  @override
  Future<void> confirmar(
    String solicitud,
    String cliente,
    String oc,
    List<Map<String, dynamic>> lineas, {
    List<Map<String, dynamic>> empaques = const [],
    String? destinatarioId,
    String? destinatarioVersion,
    String? ocDocumento,
  }) async {
    expect(cliente, _cliente);
    expect(oc, _oc);
    expect(destinatarioId, 'destino');
    expect(destinatarioVersion, 'v1');
    solicitudes.add(solicitud);
    planes.add(lineas);
    this.empaques.add(empaques);
    if (respuesta != null) await respuesta!.future;
  }
}

Future<({_Borradores borradores, _Despachos despachos})> _montar(
  WidgetTester tester,
  Size size, {
  double escala = 1,
  bool largo = false,
  bool correccion = false,
  bool unico = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  final destino = <String, dynamic>{
    'nombre':
        largo
            ? 'CENTRO DE INVESTIGACIÓN Y OPERACIÓN LOGÍSTICA INSTITUCIONAL COLOMBIA S.A.S.'
            : '4LIFE RESEARCH COLOMBIA LLC',
    'sede': 'ALMACÉN PRINCIPAL',
    'ciudad': 'BOGOTÁ D.C.',
    'direccion': 'Calle 100 # 25-30',
  };
  final rotulo = RotuloEmpaque(
    numero: 1,
    destinatario: destino,
    oc: _oc,
    empacadoPor: 'Administrador',
    productos: const [ProductoRotulo('CAMISA OPERATIVA', 'M', 2, op: '90005')],
    tipoEmpaque: 'Caja',
    pesoBrutoKg: 10,
  );
  final borradores = _Borradores({
    'formato': 1,
    'paso': 2,
    'cliente': _cliente,
    'oc': _oc,
    'destinatario': 'destino',
    'oc_documento': '',
    'ops': ['90005', if (!unico) '90006'],
    'pesos': {'1': '10', if (!unico) '2': '8'},
    'asignaciones': {
      'camisa': {
        '1': {'empaque': 'caja', 'prendas': '2'},
        if (!unico) '2': {'empaque': 'paquete', 'prendas': '3'},
      },
      if (!unico)
        'pantalon': {
          '2': {'empaque': 'paquete', 'prendas': '4'},
        },
    },
    'siguiente_empaque': 2,
    'masivo': false,
    'motivo': '',
    'grupos': <String, bool>{},
    'tarjetas': <String, bool>{},
    'rotulos': {if (!unico) '1': 'caja:${rotulo.firma}'},
  });
  final despachos = _Despachos();
  ItemKardex fila(
    String id,
    String op,
    String descripcion,
    String talla,
    Map<String, int> ubicaciones,
  ) => ItemKardex(
    item: ItemOrden(
      id: id,
      op: op,
      cliente: _cliente,
      oc: _oc,
      codigo: id,
      descripcion: descripcion,
      talla: talla,
      cantidadPedida: 20,
    ),
    producido: 20,
    recibido: ubicaciones.values.fold(0, (a, b) => a + b),
    despachado: 0,
    ubicaciones: ubicaciones,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usarSupabaseProvider.overrideWithValue(true),
        usuarioSesionProvider.overrideWith(
          (ref) async => const UsuarioSesion(
            numeroUsuario: '1',
            nombre: 'Administrador',
            rolCuenta: RolCuenta.admin,
          ),
        ),
        despachoBorradorRepositoryProvider.overrideWithValue(borradores),
        wmsRepositoryProvider.overrideWithValue(repo),
        despachosOcProvider.overrideWithValue(despachos),
        entregasProvider.overrideWith((ref) async => []),
        destinatariosEmpaqueProvider.overrideWith(
          (ref) async => [
            {'id': 'destino', 'version': 'v1', 'datos': destino},
          ],
        ),
        empaquesProvider.overrideWith(
          (ref) async => [
            {
              'id': 'caja',
              'nombre': 'CAJA ESTANDAR',
              'categoria': 'CAJA',
              'version': 'v1',
              'largo_cm': 57,
              'ancho_cm': 37,
              'alto_cm': 37,
              'peso_neto_kg': 1,
            },
            {
              'id': 'paquete',
              'nombre':
                  largo
                      ? 'PAQUETE CON PROTECCIÓN ADICIONAL PARA TRASLADO DE PRENDAS INSTITUCIONALES'
                      : 'PAQUETE GRANDE',
              'categoria': 'PAQUETE',
              'version': 'v1',
              'largo_cm': 30,
              'ancho_cm': 20,
              'alto_cm': 10,
              'peso_neto_kg': 0.5,
            },
          ],
        ),
        wmsSnapshotProvider.overrideWith(
          (ref) => Stream.value(
            WmsSnapshot(
              kardex: [
                fila('camisa', '90005', 'CAMISA OPERATIVA', 'M', {
                  'RACK C3': 3,
                  'RACK D2': 4,
                }),
                fila('pantalon', '90006', 'PANTALÓN OPERATIVO', 'L', {
                  'RACK E1': 6,
                }),
              ],
              lotes: [],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kardex(TemaModo.corporativo),
        builder:
            (context, child) => RepaintBoundary(
              key: const ValueKey('captura-confirmar'),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(escala)),
                child: child!,
              ),
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed:
                        () => showWmsDialog<void>(
                          context,
                          (_) => DespachoDialog(
                            correccion:
                                correccion
                                    ? {
                                      'id': 'despacho-existente',
                                      'version': 'v1',
                                      'le_numero': 2997,
                                      'cliente': _cliente,
                                      'oc': _oc,
                                      'detalle': <Map<String, dynamic>>[],
                                      'empaques': <Map<String, dynamic>>[],
                                    }
                                    : null,
                          ),
                        ),
                    child: const Text('Abrir despacho de prueba'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir despacho de prueba'));
  await tester.pumpAndSettle();
  if (size.width == 1280) {
    await _tocar(tester, find.byTooltip('Ampliar pantalla'));
  }
  await _tocar(tester, find.widgetWithText(FilledButton, 'Revisar empaque'));
  expect(find.text('Revisa antes de confirmar'), findsOneWidget);
  return (borradores: borradores, despachos: despachos);
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _arriba(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(
    find
        .ancestor(
          of: find.text('Revisa antes de confirmar'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scroll.position.jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('captura-confirmar')),
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

void _comprobarRevision() {
  expect(find.text('9 prendas · 2 empaques'), findsOneWidget);
  expect(find.text('Rótulo generado'), findsOneWidget);
  expect(find.text('Rótulo sin generar'), findsOneWidget);
  expect(find.text('OP 90005 · Talla M · 2 prendas'), findsOneWidget);
  expect(find.text('OP 90005 · Talla M · 3 prendas'), findsOneWidget);
  expect(find.text('OP 90006 · Talla L · 4 prendas'), findsOneWidget);
  expect(find.text('OP 90005 · Talla M · 3 desde RACK C3'), findsOneWidget);
  expect(find.text('OP 90005 · Talla M · 2 desde RACK D2'), findsOneWidget);
  expect(find.text('OP 90006 · Talla L · 4 desde RACK E1'), findsOneWidget);
  final primero = find.byKey(const ValueKey('despacho-confirmar-empaque-1'));
  final segundo = find.byKey(const ValueKey('despacho-confirmar-empaque-2'));
  for (final (panel, valores) in [
    (
      primero,
      [
        'Bruto: 10.0 kg',
        'Tara: 1 kg',
        'Neto: 9.000 kg',
        'OP 90005 · Talla M · 2 prendas',
        'Rótulo generado',
      ],
    ),
    (
      segundo,
      [
        'Bruto: 8.0 kg',
        'Tara: 0.5 kg',
        'Neto: 7.500 kg',
        'OP 90005 · Talla M · 3 prendas',
        'OP 90006 · Talla L · 4 prendas',
        'Rótulo sin generar',
      ],
    ),
  ]) {
    for (final valor in valores) {
      expect(
        find.descendant(of: panel, matching: find.text(valor)),
        findsOneWidget,
      );
    }
  }
  final resumen = find.byKey(const ValueKey('despacho-confirmar-resumen'));
  expect(
    find.descendant(of: resumen, matching: find.text('9')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: resumen, matching: find.text('2')),
    findsOneWidget,
  );
}

void main() {
  setUp(() {
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final size in [
    const Size(320, 720),
    const Size(390, 844),
    const Size(768, 900),
    const Size(1280, 720),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Confirmar ${size.width}: origen, empaques y retorno conservan cantidades',
      (tester) async {
        final f = await _montar(tester, size);
        _comprobarRevision();
        final sincronizar = find.byKey(
          const ValueKey('despacho-sincronizar-datos'),
        );
        expect(sincronizar, findsOneWidget);
        if (size.width == 1280) {
          expect(sincronizar.hitTestable(), findsOneWidget);
          await _tocar(tester, find.widgetWithText(Tab, 'Historial'));
          expect(sincronizar, findsNothing);
          await _tocar(tester, find.widgetWithText(Tab, 'Despacho'));
          expect(sincronizar, findsOneWidget);
          await _tocar(tester, sincronizar);
          _comprobarRevision();
        }
        await _arriba(tester);
        await _capturar(tester, 'despacho-confirmar-${size.width.toInt()}');
        await tester.ensureVisible(
          find.byKey(const ValueKey('despacho-confirmar-empaque-2')),
        );
        await tester.pumpAndSettle();
        await _capturar(
          tester,
          'despacho-confirmar-${size.width.toInt()}-empaques',
        );
        if (size.width <= 390) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('despacho-confirmar-origenes')),
          );
          await tester.pumpAndSettle();
          await _capturar(
            tester,
            'despacho-confirmar-${size.width.toInt()}-origenes',
          );
        }
        await _tocar(tester, find.text('Editar empaques'));
        expect(find.widgetWithText(TextFormField, 'Prendas'), findsNWidgets(3));
        final cantidades =
            tester
                .widgetList<TextFormField>(
                  find.widgetWithText(TextFormField, 'Prendas'),
                )
                .map((e) => e.initialValue)
                .toList();
        expect(cantidades, ['2', '3', '4']);
        await _tocar(
          tester,
          find.widgetWithText(FilledButton, 'Revisar empaque'),
        );
        _comprobarRevision();
        await _tocar(tester, find.text('Atrás'));
        await _tocar(
          tester,
          find.widgetWithText(FilledButton, 'Revisar empaque'),
        );
        _comprobarRevision();
        expect(f.despachos.solicitudes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets(
      'Confirmar $ancho: texto ampliado y motivo mantienen foco con teclado',
      (tester) async {
        await _montar(
          tester,
          Size(ancho, 720),
          escala: 1.3,
          largo: true,
          correccion: true,
        );
        expect(find.text('Se actualiza la LE existente.'), findsOneWidget);
        expect(find.text('Se crea la LE.'), findsNothing);
        expect(
          find.text('Campo obligatorio para guardar los cambios.'),
          findsOneWidget,
        );
        _comprobarRevision();
        await tester.ensureVisible(
          find.byKey(const ValueKey('despacho-confirmar-empaque-2')),
        );
        await tester.pumpAndSettle();
        await _capturar(tester, 'despacho-confirmar-${ancho.toInt()}-ampliado');
        final campo = find.widgetWithText(
          TextField,
          'Motivo de la corrección (obligatorio)',
        );
        await tester.ensureVisible(campo);
        await tester.pumpAndSettle();
        expect(campo.hitTestable(), findsOneWidget);
        await tester.enterText(
          campo,
          'Se verificaron pesos y estantes de origen.',
        );
        final editableFinder = find.descendant(
          of: campo,
          matching: find.byType(EditableText),
        );
        final editable = tester.state<EditableTextState>(editableFinder);
        for (final inset in [180.0, 280.0, 0.0, 280.0]) {
          tester.testTextInput.log.clear();
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();
          expect(tester.state(editableFinder), same(editable));
          expect(editable.widget.focusNode.hasFocus, isTrue);
          expect(
            editable.widget.controller.text,
            'Se verificaron pesos y estantes de origen.',
          );
          expect(
            tester.testTextInput.log.map((e) => e.method),
            isNot(
              anyOf(
                contains('TextInput.hide'),
                contains('TextInput.clearClient'),
              ),
            ),
          );
          await tester.ensureVisible(campo);
          await tester.pumpAndSettle();
          expect(campo.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await _capturar(tester, 'despacho-confirmar-${ancho.toInt()}-teclado');
      },
    );
  }

  testWidgets('Confirmar1280: resumen singular sin rótulo puede confirmarse', (
    tester,
  ) async {
    final f = await _montar(tester, const Size(1280, 720), unico: true);
    expect(find.text('1 empaque'), findsOneWidget);
    expect(find.text('Rótulo sin generar'), findsOneWidget);
    expect(find.text('Rótulo generado'), findsNothing);
    expect(find.text('OP 90005 · Talla M · 2 desde RACK C3'), findsOneWidget);
    await _arriba(tester);
    await _capturar(tester, 'despacho-confirmar-1280-un-empaque');
    final boton = find.widgetWithText(FilledButton, 'Confirmar empaque');
    expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
    expect(f.despachos.solicitudes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Confirmar: rótulo modificado bloquea; reserva válida evita doble envío',
    (tester) async {
      final f = await _montar(tester, const Size(390, 844));
      await _tocar(tester, find.text('Editar empaques'));
      final peso = find.byKey(const ValueKey('peso-bruto-1'));
      await tester.ensureVisible(peso);
      await tester.pumpAndSettle();
      await tester.enterText(peso, '11');
      await _tocar(
        tester,
        find.widgetWithText(FilledButton, 'Revisar empaque'),
      );
      expect(
        find.text('Rótulo modificado: vuelve a generarlo'),
        findsOneWidget,
      );
      await _tocar(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar empaque'),
      );
      expect(
        find.text(
          'Vuelve a generar los rótulos modificados antes de confirmar.',
        ),
        findsOneWidget,
      );
      expect(f.despachos.solicitudes, isEmpty);
      await _tocar(tester, find.text('Cerrar aviso'));
      await _tocar(tester, find.text('Editar empaques'));
      await tester.ensureVisible(peso);
      await tester.pumpAndSettle();
      await tester.enterText(peso, '10');
      await _tocar(
        tester,
        find.widgetWithText(FilledButton, 'Revisar empaque'),
      );
      _comprobarRevision();
      f.despachos.respuesta = Completer<void>();
      final confirmar = find.widgetWithText(FilledButton, 'Confirmar empaque');
      expect(confirmar.hitTestable(), findsOneWidget);
      await tester.tap(confirmar);
      // Segundo toque antes del siguiente frame: la guarda interna ya debe actuar.
      await tester.tap(confirmar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.despachos.solicitudes, hasLength(1));
      final guardando = find.widgetWithText(FilledButton, 'Guardando…');
      expect(tester.widget<FilledButton>(guardando).onPressed, isNull);
      expect(guardando.hitTestable(), findsNothing);
      expect(f.despachos.solicitudes, hasLength(1));
      f.despachos.respuesta!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Empaque confirmado'), findsOneWidget);
      expect(
        find.textContaining('Las 9 prendas quedaron reservadas en 2 empaques.'),
        findsOneWidget,
      );
      expect(f.borradores.eliminados, 1);
      expect(f.despachos.empaques.single.map((e) => e['cantidad']), [2, 3, 4]);
      expect(f.despachos.empaques.single.map((e) => e['numero']), [1, 2, 2]);
      expect(f.despachos.empaques.single.map((e) => e['peso_bruto_kg']), [
        10,
        8,
        8,
      ]);
      expect(f.despachos.planes.single.map((e) => e['cantidad']), [3, 2, 4]);
      expect(f.despachos.planes.single.map((e) => e['ubicacion']), [
        'RACK C3',
        'RACK D2',
        'RACK E1',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
