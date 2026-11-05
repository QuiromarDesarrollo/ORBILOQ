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
import 'package:orbiloq_wms/shared/widgets/wms_camera_scanner.dart';
import 'package:orbiloq_wms/shared/widgets/wms_scan_field.dart';

const _cliente = 'BOGOTÁ MÓVIL';
const _oc1 = '731725 INGRESOS';
const _oc2 = 'OC-SEGUNDA';
const _qr1 =
    'https://etiqueta?25586;P34;PANTALON;BOGOTA MOVIL;731725 INGRESOS;1';
const _qr2 = 'https://etiqueta?26094;TS;TSHIRT;BOGOTA MOVIL;OC-SEGUNDA;2';
const _qrSinStock =
    'https://etiqueta?25586;P36;PANTALON;BOGOTA MOVIL;731725 INGRESOS;3';

class _Borradores implements DespachoBorradorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>?> cargar(String clave) async => {
    'version': 1,
    'datos': {
      'formato': 1,
      'paso': 1,
      'cliente': _cliente,
      'oc': null,
      'destinatario': 'destino',
      'oc_documento': '',
      'ops': <String>[],
      'pesos': <String, String>{},
      'asignaciones': <String, dynamic>{},
      'siguiente_empaque': 0,
      'masivo': false,
      'motivo': '',
      'grupos': <String, bool>{},
      'tarjetas': <String, bool>{},
    },
  };
}

class _Despachos implements DespachosOcRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<Map<String, dynamic>>> historial() async => [];
}

ItemKardex _fila(
  String op,
  String oc,
  String codigo,
  String talla,
  int pedidas,
  int producidas,
  int stock, {
  bool largo = false,
  String ubicacion = 'RACK C3',
}) => ItemKardex(
  item: ItemOrden(
    id: codigo,
    op: op,
    cliente: _cliente,
    oc: oc,
    codigo: codigo,
    descripcion:
        largo
            ? 'PRENDA INSTITUCIONAL DE TRABAJO CON REFUERZO ESPECIAL Y BOLSILLOS DE SEGURIDAD'
            : op == '25586'
            ? 'PANTALÓN CLÁSICO HOMBRE'
            : 'TSHIRT MANGA CORTA',
    talla: talla,
    cantidadPedida: pedidas,
  ),
  producido: producidas,
  recibido: stock,
  despachado: 0,
  ubicaciones: stock == 0 ? {} : {ubicacion: stock},
);

Future<void> _montar(
  WidgetTester tester,
  Size size, {
  double escala = 1,
  bool largo = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final repo = InMemoryWmsRepository.seeded();
  addTearDown(repo.dispose);
  final snapshot = WmsSnapshot(
    kardex: [
      _fila('25586', _oc1, 'P34', '34', 38, 38, 6, largo: largo),
      _fila('25586', _oc1, 'P36', '36', 12, 4, 0, largo: largo),
      _fila('25590', _oc1, 'PM', 'M', 20, 10, 4, largo: largo),
      _fila('26094', _oc2, 'TS', 'S', 10, 8, 7, largo: largo),
      _fila(
        '26094',
        _oc2,
        'TXS',
        'XS',
        10,
        10,
        2,
        largo: largo,
        ubicacion: 'RACK D2',
      ),
      _fila('26094', _oc2, 'TXL', 'XL/14', 20, 2, 0, largo: largo),
      _fila('26100', _oc2, 'TL', 'L', 5, 0, 0, largo: largo),
    ],
    lotes: [],
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
        despachoBorradorRepositoryProvider.overrideWithValue(_Borradores()),
        wmsRepositoryProvider.overrideWithValue(repo),
        despachosOcProvider.overrideWithValue(_Despachos()),
        entregasProvider.overrideWith((ref) async => []),
        destinatariosEmpaqueProvider.overrideWith(
          (ref) async => [
            {
              'id': 'destino',
              'version': 'v1',
              'datos': {
                'nombre': 'AXION LOG S.A.S.',
                'sede': 'ALMACÉN',
                'ciudad': 'TENJO',
                'direccion': 'Autopista Medellín km 6',
              },
            },
          ],
        ),
        empaquesProvider.overrideWith(
          (ref) async => [
            {
              'id': 'caja1',
              'nombre': 'Caja prueba',
              'categoria': 'CAJA',
              'version': 'v1',
              'alto_cm': 10,
              'ancho_cm': 20,
              'largo_cm': 30,
            },
          ],
        ),
        wmsSnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kardex(TemaModo.corporativo),
        builder:
            (context, child) => RepaintBoundary(
              key: const ValueKey('captura-despacho-prendas'),
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
  await tester.tap(find.text('Abrir despacho de prueba'));
  await tester.pumpAndSettle();
  expect(find.text('¿Qué OP van en este despacho?'), findsOneWidget);
}

Finder _op(String oc, String op) => find.byKey(ValueKey('despacho-op-$oc-$op'));
bool _seleccionada(WidgetTester tester, String oc, String op) =>
    tester.widget<CheckboxListTile>(_op(oc, op)).value == true;

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _cantidad(WidgetTester tester, int esperado) {
  final valor = tester.widget<Text>(
    find.byKey(const ValueKey('despacho-prendas-resumen-cantidad')),
  );
  expect(valor.data, '$esperado');
  expect(find.text('$esperado OP elegidas'), findsOneWidget);
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Armar empaques'),
        )
        .onPressed,
    esperado == 0 ? isNull : isNotNull,
  );
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('captura-despacho-prendas')),
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

Future<Finder> _abrirEntrada(
  WidgetTester tester, {
  required bool manual,
}) async {
  await _tocar(
    tester,
    find.byKey(ValueKey('despacho-prendas-${manual ? 'codigo' : 'lector'}')),
  );
  expect(find.text('Seleccionar prendas'), findsOneWidget);
  if (manual) {
    await _tocar(tester, find.text('Ingresar código manualmente'));
  } else {
    await _tocar(tester, find.text('Activar lector'));
  }
  final campo = find.descendant(
    of: find.byType(WmsScanField),
    matching: find.byType(TextField),
  );
  expect(campo, findsOneWidget);
  return campo;
}

Future<void> _enviar(WidgetTester tester, Finder campo, String codigo) async {
  await tester.enterText(campo, codigo);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
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
    testWidgets(
      'Prendas ${size.width}: tallas, progreso, selección y una OC por despacho',
      (tester) async {
        await _montar(tester, size);
        if (size.width == 1280) {
          await _tocar(tester, find.byTooltip('Ampliar pantalla'));
        }
        _cantidad(tester, 0);
        expect(find.byType(CheckboxListTile), findsNWidgets(3));
        expect(_op(_oc2, '26100'), findsNothing);
        expect(find.text('T. 34 · 6 en bodega'), findsOneWidget);
        expect(find.text('T. S · 7 en bodega'), findsOneWidget);
        expect(find.text('T. XS · 2 en bodega'), findsOneWidget);
        for (final (talla, ubicacion, otraUbicacion) in [
          ('S', 'RACK C3', 'RACK D2'),
          ('XS', 'RACK D2', 'RACK C3'),
        ]) {
          final etiqueta = find.textContaining('T. $talla ·');
          final fila =
              find.ancestor(of: etiqueta, matching: find.byType(Wrap)).first;
          expect(
            find.descendant(of: fila, matching: find.text(ubicacion)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: fila, matching: find.text(otraUbicacion)),
            findsNothing,
          );
        }
        expect(find.textContaining('T. 36'), findsNothing);
        expect(find.textContaining('T. XL/14'), findsNothing);
        // Incluye tallas y OP sin existencias en los denominadores de producción.
        expect(
          find.text('Producción OC: 52 de 70 prendas · 74.3 %'),
          findsOneWidget,
        );
        expect(
          find.text('Producción OP 25586: 42 de 50 prendas · 84.0 %'),
          findsOneWidget,
        );
        expect(
          find.text('Producción OC: 20 de 45 prendas · 44.4 %'),
          findsOneWidget,
        );
        expect(
          find.text('Producción OP 26094: 20 de 40 prendas · 50.0 %'),
          findsOneWidget,
        );
        await _capturar(tester, 'despacho-prendas-${size.width.toInt()}');
        await _tocar(tester, _op(_oc1, '25586'));
        _cantidad(tester, 1);
        await _tocar(tester, _op(_oc1, '25590'));
        _cantidad(tester, 2);
        await _tocar(tester, _op(_oc1, '25586'));
        _cantidad(tester, 1);
        await _tocar(tester, find.byKey(const ValueKey('elegir-oc-$_oc1')));
        _cantidad(tester, 2);
        expect(_seleccionada(tester, _oc1, '25586'), isTrue);
        expect(_seleccionada(tester, _oc1, '25590'), isTrue);
        await tester.ensureVisible(find.text('Sincronizar datos'));
        final scroll = tester.state<ScrollableState>(
          find
              .ancestor(
                of: find.text('Sincronizar datos'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        await _capturar(
          tester,
          'despacho-prendas-${size.width.toInt()}-seleccionadas',
        );
        await _tocar(tester, find.byKey(const ValueKey('elegir-oc-$_oc2')));
        _cantidad(tester, 1);
        expect(_seleccionada(tester, _oc1, '25586'), isFalse);
        expect(_seleccionada(tester, _oc1, '25590'), isFalse);
        expect(_seleccionada(tester, _oc2, '26094'), isTrue);
        await tester.ensureVisible(_op(_oc2, '26094'));
        await tester.pumpAndSettle();
        await _capturar(
          tester,
          'despacho-prendas-${size.width.toInt()}-tallas',
        );
        await _tocar(
          tester,
          find.widgetWithText(FilledButton, 'Armar empaques'),
        );
        expect(find.byKey(const ValueKey('grupo-op-26094')), findsOneWidget);
        expect(find.byKey(const ValueKey('grupo-op-25586')), findsNothing);
        await _tocar(tester, find.text('Atrás'));
        _cantidad(tester, 1);
        expect(_seleccionada(tester, _oc2, '26094'), isTrue);
        await _tocar(tester, _op(_oc2, '26094'));
        _cantidad(tester, 0);
        await _tocar(tester, _op(_oc1, '25586'));
        _cantidad(tester, 1);
        expect(_seleccionada(tester, _oc2, '26094'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final ancho in [320.0, 390.0]) {
    testWidgets(
      'Prendas $ancho: lector, ingreso manual y teclado conservan selección',
      (tester) async {
        await _montar(tester, Size(ancho, 720), escala: 1.3, largo: true);
        await tester.ensureVisible(_op(_oc2, '26094'));
        await tester.pumpAndSettle();
        await _capturar(
          tester,
          'despacho-prendas-${ancho.toInt()}-texto-ampliado',
        );
        var campo = await _abrirEntrada(tester, manual: false);
        expect(
          tester.widget<TextField>(campo).keyboardType,
          TextInputType.none,
        );
        await _enviar(tester, campo, _qr1);
        _cantidad(tester, 1);
        expect(_seleccionada(tester, _oc1, '25586'), isTrue);
        campo = await _abrirEntrada(tester, manual: true);
        await tester.enterText(campo, 'PM');
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
          expect(editable.widget.controller.text, 'PM');
          expect(
            tester.testTextInput.log.map((e) => e.method),
            isNot(
              anyOf(
                contains('TextInput.hide'),
                contains('TextInput.clearClient'),
              ),
            ),
          );
          expect(campo.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await _capturar(tester, 'despacho-prendas-${ancho.toInt()}-teclado');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        _cantidad(tester, 2);
        expect(_seleccionada(tester, _oc1, '25590'), isTrue);
        campo = await _abrirEntrada(tester, manual: true);
        await _enviar(tester, campo, ancho == 320 ? 'NO-EXISTE' : _qr2);
        expect(
          find.textContaining(
            ancho == 320
                ? 'QR no encontrado.'
                : 'La etiqueta pertenece a otra OC.',
          ),
          findsOneWidget,
        );
        await _tocar(tester, find.text('Cerrar aviso'));
        _cantidad(tester, 2);
        expect(_seleccionada(tester, _oc2, '26094'), isFalse);
        campo = await _abrirEntrada(tester, manual: true);
        await _enviar(tester, campo, _qrSinStock);
        expect(
          find.text('La prenda no tiene unidades disponibles en bodega.'),
          findsOneWidget,
        );
        await _tocar(tester, find.text('Cerrar aviso'));
        _cantidad(tester, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Prendas cámara: acceso y callback mantienen OC sin registrar movimientos',
    (tester) async {
      await _montar(tester, const Size(390, 844));
      final boton = find.byKey(const ValueKey('despacho-prendas-camara'));
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      expect(boton.hitTestable(), findsOneWidget);
      await tester.tap(boton);
      await tester.pump(const Duration(milliseconds: 500));
      final scanner = tester.widget<WmsCameraScanner>(
        find.byType(WmsCameraScanner),
      );
      expect((await scanner.onRead(_qr1)).isError, isFalse);
      expect((await scanner.onRead(_qr2)).isError, isTrue);
      expect((await scanner.onRead(_qrSinStock)).isError, isTrue);
      expect((await scanner.onRead('INVALIDO')).isError, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Volver a las tarjetas'));
      await tester.pumpAndSettle();
      _cantidad(tester, 1);
      expect(_seleccionada(tester, _oc1, '25586'), isTrue);
      expect(_seleccionada(tester, _oc2, '26094'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
