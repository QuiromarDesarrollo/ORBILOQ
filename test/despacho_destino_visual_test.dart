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
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/despacho/presentation/despacho_dialog.dart';

const _cliente = 'CLIENTE DE PRUEBAS';
const _nombreDestino = 'AXION LOG S.A.S.';
const _direccionDestino =
    'Autopista Medellín, kilómetro 6, costado sur, Parque Empresarial Siberia';

class _Borradores implements DespachoBorradorRepository {
  Map<String, dynamic>? registro;
  int guardados = 0;
  final claves = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>?> cargar(String clave) async {
    claves.add(clave);
    return registro;
  }

  @override
  Future<Map<String, dynamic>> guardar(
    String clave,
    Map<String, dynamic> datos, {
    int version = 0,
  }) async {
    expect(clave, 'nuevo');
    expect(version, registro?['version'] ?? 0);
    guardados++;
    return registro = {
      'version': version + 1,
      'datos': jsonDecode(jsonEncode(datos)),
    };
  }
}

class _Despachos implements DespachosOcRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<Map<String, dynamic>>> historial() async => [];
}

class _Entorno {
  final borradores = _Borradores();
  int consultasDestinos = 0;
  int consultasEmpaques = 0;
}

final _destinos = <Map<String, dynamic>>[
  {
    'id': 'axion-tenjo',
    'version': '1',
    'datos': {
      'nombre': _nombreDestino,
      'sede': 'ALMACÉN PRINCIPAL',
      'ciudad': 'TENJO',
      'direccion': _direccionDestino,
    },
  },
  {
    'id': 'colsubsidio-62',
    'version': '1',
    'datos': {
      'nombre': 'COLSUBSIDIO',
      'sede': 'CALLE 62',
      'ciudad': 'BOGOTÁ',
      'direccion': 'Calle 62 # 24-45',
    },
  },
  {
    'id': 'axion-centro',
    'version': '1',
    'datos': {
      'nombre': _nombreDestino,
      'sede': 'CENTRO',
      'ciudad': 'MEDELLÍN',
      'direccion': 'Carrera 23 # 40-17',
    },
  },
];

const _prenda = ItemKardex(
  item: ItemOrden(
    id: 'prenda-destino-prueba',
    op: '90005',
    cliente: _cliente,
    oc: 'OC-PRUEBA-A',
    codigo: 'TEST-90005',
    descripcion: 'PRENDA PRUEBA 90005',
    talla: 'M',
    cantidadPedida: 20,
  ),
  producido: 15,
  recibido: 10,
  despachado: 0,
  ubicaciones: {'RACK C3': 10},
);

Future<_Entorno> _montar(
  WidgetTester tester,
  Size size, {
  double escala = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  final entorno = _Entorno();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Usa la misma rama funcional que producción sin consultar servicios.
        usarSupabaseProvider.overrideWithValue(true),
        usuarioSesionProvider.overrideWith(
          (ref) async => const UsuarioSesion(
            numeroUsuario: '1',
            nombre: 'Administrador',
            rolCuenta: RolCuenta.admin,
          ),
        ),
        wmsRepositoryProvider.overrideWithValue(repo),
        despachoBorradorRepositoryProvider.overrideWithValue(
          entorno.borradores,
        ),
        despachosOcProvider.overrideWithValue(_Despachos()),
        entregasProvider.overrideWith((ref) async => []),
        destinatariosEmpaqueProvider.overrideWith((ref) async {
          entorno.consultasDestinos++;
          return _destinos;
        }),
        empaquesProvider.overrideWith((ref) async {
          entorno.consultasEmpaques++;
          return [
            {
              'id': 'caja1',
              'nombre': 'Caja prueba',
              'categoria': 'CAJA',
              'version': 'v1',
              'alto_cm': 10,
              'ancho_cm': 20,
              'largo_cm': 30,
            },
          ];
        }),
        wmsSnapshotProvider.overrideWith(
          (ref) => Stream.value(WmsSnapshot(kardex: [_prenda], lotes: [])),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kardex(TemaModo.corporativo),
        builder:
            (context, child) => RepaintBoundary(
              key: const ValueKey('captura-despacho-destino'),
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
                    onPressed: () => showDespachoDialog(context),
                    child: const Text('Abrir despacho de prueba'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await _abrir(tester);
  return entorno;
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('Abrir despacho de prueba'));
  await tester.pumpAndSettle();
}

Finder get _busqueda => find.byKey(const ValueKey('despacho-destino-busqueda'));
Finder get _popup => find.byKey(const ValueKey('despacho-destino-options'));
Finder get _siguiente => find.widgetWithText(FilledButton, 'Elegir prendas');

Future<void> _abrirDestinos(WidgetTester tester) async {
  await tester.ensureVisible(_busqueda);
  await tester.tap(_busqueda);
  await tester.pumpAndSettle();
  expect(_popup, findsOneWidget);
}

Future<void> _seleccionarDestino(WidgetTester tester) async {
  await _abrirDestinos(tester);
  await tester.enterText(_busqueda, 'TENJO');
  await tester.pumpAndSettle();
  final opcion = find.byKey(const ValueKey('destino-opcion-axion-tenjo'));
  await tester.ensureVisible(opcion);
  await tester.tap(opcion);
  await tester.pumpAndSettle();
  expect(_popup, findsNothing);
}

Future<void> _seleccionarCliente(WidgetTester tester) async {
  final selector = find.widgetWithText(
    DropdownButtonFormField<String>,
    'Cliente',
  );
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_cliente).last);
  await tester.pumpAndSettle();
}

void _resumen(String clave, String texto) {
  final widget = find.byKey(ValueKey('despacho-resumen-$clave'));
  expect(widget, findsOneWidget);
  expect(testerText(widget), contains(texto));
}

String testerText(Finder finder) {
  final widget = finder.evaluate().single.widget;
  return widget is Text ? widget.data ?? widget.textSpan!.toPlainText() : '';
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('captura-despacho-destino')),
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

  for (final size in [
    const Size(320, 720),
    const Size(390, 844),
    const Size(768, 900),
    const Size(1280, 720),
    const Size(1440, 900),
  ]) {
    testWidgets('Destino ${size.width}: resumen, selección y avance', (
      tester,
    ) async {
      await _montar(tester, size);
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(_siguiente).onPressed, isNull);
      _resumen('estado', 'Faltan 2 datos');
      await _capturar(tester, 'despacho-destino-${size.width.toInt()}');
      if (size.width == 1280) {
        await tester.tap(find.byTooltip('Ampliar pantalla'));
        await tester.pumpAndSettle();
        await _capturar(tester, 'despacho-destino-1280-pantalla-completa');
        await tester.tap(find.byTooltip('Restaurar tamaño'));
        await tester.pumpAndSettle();
      }
      await _abrirDestinos(tester);
      final ancla = tester.getRect(_busqueda);
      final popup = tester.getRect(_popup);
      expect((popup.left - ancla.left).abs(), lessThan(2));
      expect((popup.width - ancla.width).abs(), lessThan(2));
      await _capturar(tester, 'despacho-destino-${size.width.toInt()}-abierto');
      await tester.enterText(_busqueda, 'TENJO');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('destino-opcion-axion-tenjo')),
      );
      await tester.pumpAndSettle();
      _resumen('destino', _nombreDestino);
      _resumen('estado', 'Falta 1 dato');
      expect(tester.widget<FilledButton>(_siguiente).onPressed, isNull);
      await _seleccionarCliente(tester);
      _resumen('cliente', _cliente);
      _resumen('estado', 'Listo para elegir prendas');
      expect(tester.widget<FilledButton>(_siguiente).onPressed, isNotNull);
      await tester.ensureVisible(_siguiente);
      await tester.tap(_siguiente);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Armar empaques'),
        findsOneWidget,
      );
      expect(find.textContaining('90005'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets('Destino $ancho: búsqueda, teclado y foco con texto ampliado', (
      tester,
    ) async {
      await _montar(tester, Size(ancho, 720), escala: 1.3);
      await _abrirDestinos(tester);
      await tester.enterText(_busqueda, 'NO EXISTE ESTA SEDE');
      await tester.pumpAndSettle();
      expect(find.text('No hay destinatarios que coincidan.'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('destino-opcion-axion-tenjo')),
        findsOneWidget,
      );
      await tester.enterText(_busqueda, 'Siberia');
      final editableFinder = find.descendant(
        of: _busqueda,
        matching: find.byType(EditableText),
      );
      final editable = tester.state<EditableTextState>(editableFinder);
      editable.widget.controller.selection = const TextSelection.collapsed(
        offset: 3,
      );
      for (final inset in [180.0, 280.0, 0.0, 280.0]) {
        tester.testTextInput.log.clear();
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        expect(tester.state(editableFinder), same(editable));
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(editable.widget.controller.text, 'Siberia');
        expect(editable.widget.controller.selection.baseOffset, 3);
        expect(
          tester.testTextInput.log.map((e) => e.method),
          isNot(
            anyOf(
              contains('TextInput.hide'),
              contains('TextInput.clearClient'),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(_popup);
        if (inset == 280) {
          await _capturar(tester, 'despacho-destino-${ancho.toInt()}-teclado');
        }
        expect(panel.height, greaterThanOrEqualTo(44));
        expect(panel.top, greaterThanOrEqualTo(0));
        expect(panel.bottom, lessThanOrEqualTo(720 - inset + 1));
      }
      expect(_popup, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capturar(tester, 'despacho-destino-${ancho.toInt()}-teclado');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      if (ancho == 320) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      _resumen('destino', _nombreDestino);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await _abrirDestinos(tester);
      await tester.enterText(_busqueda, 'COLSUBSIDIO');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      _resumen('destino', _nombreDestino);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Destino: sincronizar conserva selección y guardar permite reabrir',
    (tester) async {
      final entorno = await _montar(tester, const Size(1280, 720));
      await _seleccionarDestino(tester);
      await _seleccionarCliente(tester);
      final consultas = entorno.consultasDestinos;
      await tester.tap(
        find.byKey(const ValueKey('despacho-sincronizar-datos')),
      );
      await tester.pumpAndSettle();
      expect(entorno.consultasDestinos, consultas + 1);
      expect(find.text('Datos actualizados'), findsOneWidget);
      _resumen('destino', _nombreDestino);
      _resumen('cliente', _cliente);
      _resumen('estado', 'Listo para elegir prendas');
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Deseas guardar los cambios?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      _resumen('destino', _nombreDestino);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(DespachoDialog), findsNothing);
      expect(entorno.borradores.guardados, 1);
      expect(
        entorno.borradores.registro!['datos']['destinatario'],
        'axion-tenjo',
      );
      expect(entorno.borradores.registro!['datos']['cliente'], _cliente);
      await _abrir(tester);
      _resumen('destino', _nombreDestino);
      _resumen('cliente', _cliente);
      _resumen('estado', 'Listo para elegir prendas');
      expect(tester.widget<FilledButton>(_siguiente).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Ampliar pantalla'));
      await tester.pumpAndSettle();
      await _capturar(tester, 'despacho-destino-1280-borrador-recuperado');
      await _abrirDestinos(tester);
      await _capturar(tester, 'despacho-destino-1280-seleccionado-abierto');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
