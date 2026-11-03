import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_pendiente.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';

import 'masiva_ui_test.dart' show captureMasiva;
import 'masiva_validacion_test.dart' show openValidation, tapVisible;
import 'masiva_validacion_workspace_test.dart' show WorkspaceFixture;

// Keep the real movimientoPendiente getter and its native storage. An awaiting
// protected RPC sets this state before Flutter paints the next frame.
class _PendingScanFixture extends WorkspaceFixture {
  _PendingScanFixture(super.articleCount, {this.loseResponse = false});

  final bool loseResponse;
  final release = Completer<void>();
  final sent = <MasivaJson>[];
  int commits = 0;
  int recoveries = 0;
  String? recoveredRequest;

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    if (accion != 'validar') return super.ejecutar(accion, datos);
    sent.add(Map.of(datos));
    guardarPendienteMasiva(
      'local',
      jsonEncode({'accion': accion, 'datos': datos}),
    );
    await release.future;
    commits++;
    final result = await super.ejecutar(accion, datos);
    if (loseResponse) {
      // The server committed once; the client has not received confirmation.
      throw TimeoutException('Se perdió la confirmación de la lectura.');
    }
    guardarPendienteMasiva('local', null);
    return result;
  }

  @override
  Future<MasivaJson> recuperarConfirmacion() async {
    recoveries++;
    final original = movimientoPendiente;
    recoveredRequest = mapaMasiva(original?['datos'])['request_id']?.toString();
    guardarPendienteMasiva('local', null);
    return {'validado': validated};
  }
}

Finder get _items => find.byKey(const ValueKey('masiva-validation-items'));
Finder get _person => find.byKey(const ValueKey('masiva-persona'));
Finder get _sku => find.byKey(const ValueKey('masiva-sku'));
Finder get _pack => find.widgetWithText(FilledButton, 'Empacar');
Finder get _recover => find.widgetWithText(TextButton, 'Recuperar');

ScrollableState _itemScroll(WidgetTester tester) {
  final scrollable = find.descendant(
    of: _items,
    matching: find.byType(Scrollable),
  );
  final vertical = scrollable.evaluate().where(
    (element) =>
        (element.widget as Scrollable).axisDirection == AxisDirection.down,
  );
  expect(vertical, hasLength(1));
  return (vertical.single as StatefulElement).state as ScrollableState;
}

Map<String, Rect> _geometry(WidgetTester tester) => {
  'person': tester.getRect(_person),
  'sku': tester.getRect(_sku),
  'table': tester.getRect(_items),
  'header': tester.getRect(find.text('DESCRIPCIÓN / PRENDA')),
  'pack': tester.getRect(_pack),
};

Future<void> _startScan(WidgetTester tester, _PendingScanFixture repo) async {
  await tester.ensureVisible(_sku);
  await tester.enterText(_sku, '000123');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(repo.sent, hasLength(1));
  expect(repo.movimientoPendiente, isNotNull);
  expect(repo.commits, 0);
}

void _expectTableUnmoved(
  WidgetTester tester,
  Map<String, Rect> before,
  ScrollableState scroll,
  double offset,
) {
  expect(
    _items,
    findsOneWidget,
    reason: 'La tabla no debe convertirse en tarjetas durante la RPC',
  );
  expect(find.text('DESCRIPCIÓN / PRENDA'), findsOneWidget);
  expect(
    _geometry(tester),
    before,
    reason: 'Campos, tabla y acción permanecen en sus posiciones',
  );
  expect(
    _itemScroll(tester),
    same(scroll),
    reason: 'No debe reconstruirse el estado del scroll',
  );
  expect(scroll.position.pixels, closeTo(offset, .01));
}

Future<void> _finishFailure(
  WidgetTester tester,
  _PendingScanFixture repo,
) async {
  repo.release.complete();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('aviso-global')), findsOneWidget);
  await tester.tap(find.text('Cerrar aviso'));
  await tester.pumpAndSettle();
  expect(repo.movimientoPendiente, isNotNull);
  expect(repo.commits, 1);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['ConductorSans', 'Roboto']) {
      await (FontLoader(family)
            ..addFont(
              rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
            )
            ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => guardarPendienteMasiva('local', null));
  tearDown(() => guardarPendienteMasiva('local', null));

  for (final size in [const Size(1366, 768), const Size(1920, 930)]) {
    testWidgets(
      'Tabla ${size.width.toInt()} conserva estructura, posición y scroll durante lectura y confirmación',
      (tester) async {
        final repo = _PendingScanFixture(20);
        await openValidation(tester, repo, size: size);
        final scroll = _itemScroll(tester);
        scroll.position.jumpTo(120);
        await tester.pumpAndSettle();
        final before = _geometry(tester);
        final offset = scroll.position.pixels;
        expect(
          find.textContaining('Validadas: 20 · Pendientes: 1'),
          findsOneWidget,
        );
        await captureMasiva(
          tester,
          'masiva-estable-antes-${size.width.toInt()}',
        );
        await _startScan(tester, repo);
        _expectTableUnmoved(tester, before, scroll, offset);
        expect(
          find.textContaining('Validadas: 20 · Pendientes: 1'),
          findsOneWidget,
          reason: 'No se adelantan cantidades antes de recibir confirmación',
        );
        expect(tester.widget<TextField>(_sku).focusNode!.hasFocus, isTrue);
        expect(tester.widget<TextField>(_sku).enabled, isTrue);
        expect(tester.widget<FilledButton>(_pack).onPressed, isNull);
        expect(
          _recover,
          findsNothing,
          reason:
              'Una lectura normal pendiente no debe invitar a duplicar la recuperación',
        );
        await captureMasiva(
          tester,
          'masiva-estable-esperando-${size.width.toInt()}',
        );
        repo.release.complete();
        await tester.pumpAndSettle();
        _expectTableUnmoved(tester, before, scroll, offset);
        expect(repo.movimientoPendiente, isNull);
        expect(repo.commits, 1);
        expect(
          find.textContaining('Validadas: 21 · Pendientes: 0'),
          findsOneWidget,
        );
        expect(find.text('000123 · 1 unidad validada'), findsOneWidget);
        expect(tester.widget<TextField>(_sku).focusNode!.hasFocus, isTrue);
        await captureMasiva(
          tester,
          'masiva-estable-confirmado-${size.width.toInt()}',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tabla ${size.width.toInt()} mantiene kit y permite recuperar la confirmación perdida',
      (tester) async {
        final repo = _PendingScanFixture(3, loseResponse: true);
        await openValidation(tester, repo, size: size);
        final scroll = _itemScroll(tester);
        final before = _geometry(tester);
        await _startScan(tester, repo);
        _expectTableUnmoved(tester, before, scroll, 0);
        await _finishFailure(tester, repo);
        _expectTableUnmoved(tester, before, scroll, 0);
        expect(find.text('Persona de ejemplo'), findsOneWidget);
        expect(
          find.textContaining('Validadas: 3 · Pendientes: 1'),
          findsOneWidget,
        );
        expect(_recover.hitTestable(), findsOneWidget);
        expect(tester.widget<TextField>(_sku).enabled, isFalse);
        await captureMasiva(
          tester,
          'masiva-estable-error-${size.width.toInt()}',
        );
        await tapVisible(tester, _recover);
        _expectTableUnmoved(tester, before, scroll, 0);
        expect(repo.movimientoPendiente, isNull);
        expect(repo.recoveries, 1);
        expect(repo.recoveredRequest, repo.sent.single['request_id']);
        expect(
          repo.commits,
          1,
          reason: 'Recuperar consulta la escritura original sin volver a sumar',
        );
        expect(find.text('Persona de ejemplo'), findsOneWidget);
        expect(
          find.textContaining('Validadas: 4 · Pendientes: 0'),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(_sku).enabled, isTrue);
        await captureMasiva(
          tester,
          'masiva-estable-recuperado-${size.width.toInt()}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Móvil 390 conserva tarjetas y recupera una lectura sin perder el kit',
    (tester) async {
      final repo = _PendingScanFixture(3, loseResponse: true);
      await openValidation(tester, repo, size: const Size(390, 844));
      expect(_items, findsNothing);
      await _startScan(tester, repo);
      expect(_items, findsNothing);
      expect(find.text('Persona de ejemplo'), findsOneWidget);
      await _finishFailure(tester, repo);
      await tester.ensureVisible(_recover);
      await tester.pumpAndSettle();
      expect(_recover.hitTestable(), findsOneWidget);
      await captureMasiva(tester, 'masiva-estable-error-390');
      await tapVisible(tester, _recover);
      expect(repo.movimientoPendiente, isNull);
      expect(repo.recoveries, 1);
      expect(repo.commits, 1);
      expect(find.text('Persona de ejemplo'), findsOneWidget);
      expect(
        find.textContaining('Validadas: 4 · Pendientes: 0'),
        findsOneWidget,
      );
      await tester.ensureVisible(_pack);
      await tester.pumpAndSettle();
      expect(_pack.hitTestable(), findsOneWidget);
      await captureMasiva(tester, 'masiva-estable-recuperado-390');
      expect(tester.takeException(), isNull);
    },
  );
}
