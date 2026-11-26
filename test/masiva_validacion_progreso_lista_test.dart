import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';

import 'masiva_ui_test.dart' show captureMasiva;
import 'masiva_validacion_test.dart'
    show ValidacionFixture, openValidation, scanSku, searchPerson, tapVisible;
import 'masiva_validacion_workspace_test.dart' show chooseContainer;

class _ProgressFixture extends ValidacionFixture {
  List<String> otherStates = ['validado', 'armado'];
  String? currentState;
  bool legacyContract = false, fail = false, omitCurrent = false;
  bool longName = false;
  Completer<MasivaJson>? firstRequest;
  final requestedLists = <String>[];
  String currentDocument = 'DEMO-01';

  MasivaJson progress({String list = '88'}) {
    final state = currentState ?? (validated >= 2 ? 'validado' : 'parcial');
    final kitId = list == '88' ? 'kit1' : 'kit2';
    final states = list == '88' ? otherStates : ['validado'];
    final kits = <MasivaJson>[
      if (!omitCurrent) {'id': kitId, 'numero_persona': 7, 'estado': state},
      for (var i = 0; i < states.length; i++)
        {
          'id': 'otro-$list-$i',
          'numero_persona': i == 0 ? 2 : i + 12,
          'estado': states[i],
          'armado': '2026-11-26T10:00:00Z',
        },
    ];
    return {
      if (!legacyContract)
        'validados': kits.where((row) => row['estado'] == 'validado').length,
      'kits': kits,
    };
  }

  @override
  Future<MasivaJson> consultarEmpaque(String operacion, String lista) async {
    requestedLists.add(lista);
    if (requestedLists.length == 1 && firstRequest != null) {
      return firstRequest!.future;
    }
    if (fail) throw TimeoutException('No respondió el resumen de la lista');
    return progress(list: lista);
  }

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
    if (operacion == null ||
        !['kits', 'validacion_documento'].contains(vista)) {
      return result;
    }
    if (vista == 'validacion_documento' && buscar == 'DEMO-02') {
      currentDocument = buscar;
    } else if (vista == 'validacion_documento' && buscar == 'DEMO-01') {
      currentDocument = buscar;
    }
    return {
      ...result,
      'filas': [
        for (final row in filasMasiva(result['filas']))
          {
            ...row,
            'id': currentDocument == 'DEMO-01' ? 'kit1' : 'kit2',
            'lista': currentDocument == 'DEMO-01' ? '88' : '89',
            'cedula': currentDocument,
            if (longName)
              'nombre':
                  'Persona de prueba con nombre extenso para verificar el espacio de la tarjeta',
          },
      ],
    };
  }
}

Finder get _progress =>
    find.byKey(const ValueKey('masiva-validation-list-progress'));

String _label(int count, int total) =>
    'Avance de lista: $count de $total kits · '
    'Faltan: ${total - count} (incluye actual)';

Future<void> _search(WidgetTester tester, String document) async {
  final field = find.byKey(const ValueKey('masiva-persona'));
  await tester.ensureVisible(field);
  await tester.enterText(field, document);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
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

  testWidgets('Avance incluye el actual parcial y solo otros kits validados', (
    tester,
  ) async {
    final repo =
        _ProgressFixture()..otherStates = ['validado', 'parcial', 'armado'];
    await openValidation(tester, repo);
    expect(find.text('Kit 2 de 4'), findsOneWidget);
    expect(find.text(_label(2, 4)), findsOneWidget);
    expect(repo.requestedLists, ['88']);
    expect(repo.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Actual validado no se suma dos veces y usa el estado del resumen',
    (tester) async {
      final repo = _ProgressFixture()..currentState = 'validado';
      await openValidation(tester, repo);
      expect(find.text(_label(2, 3)), findsOneWidget);
      expect(find.text(_label(3, 3)), findsNothing);
      expect(repo.writes, isEmpty);
    },
  );

  for (final scenario in ['error', 'contrato anterior', 'kit ausente']) {
    testWidgets('Avance no inventa cero ante $scenario', (tester) async {
      final repo =
          _ProgressFixture()
            ..fail = scenario == 'error'
            ..legacyContract = scenario == 'contrato anterior'
            ..omitCurrent = scenario == 'kit ausente';
      await openValidation(tester, repo);
      expect(find.text('Avance de lista no disponible'), findsOneWidget);
      expect(find.textContaining('Avance de lista:'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
            .enabled,
        isTrue,
      );
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Carga demorada no bloquea el lector y se descarta al cambiar lista',
    (tester) async {
      final repo = _ProgressFixture()..firstRequest = Completer<MasivaJson>();
      final old = repo.progress();
      await openValidation(tester, repo);
      expect(find.text('Consultando avance de lista…'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
            .enabled,
        isTrue,
      );
      await _search(tester, 'DEMO-02');
      expect(find.text(_label(2, 2)), findsOneWidget);
      repo.firstRequest!.complete(old);
      await tester.pumpAndSettle();
      expect(find.text(_label(2, 2)), findsOneWidget);
      expect(repo.requestedLists, ['88', '89']);
      expect(repo.writes, isEmpty);
    },
  );

  testWidgets(
    'Respuesta anterior del mismo kit no reemplaza un refresco reciente',
    (tester) async {
      final repo =
          _ProgressFixture()
            ..otherStates = ['parcial', 'armado']
            ..firstRequest = Completer<MasivaJson>();
      final old = repo.progress();
      await openValidation(tester, repo);
      repo.otherStates = ['validado', 'armado'];
      await tapVisible(tester, find.byTooltip('Actualizar datos'));
      expect(find.text(_label(2, 3)), findsOneWidget);
      repo.firstRequest!.complete(old);
      await tester.pumpAndSettle();
      expect(find.text(_label(2, 3)), findsOneWidget);
      expect(find.text(_label(1, 3)), findsNothing);
      expect(repo.writes, isEmpty);
    },
  );

  testWidgets('Escanear refresca el avance recibido de otra estación', (
    tester,
  ) async {
    final repo = _ProgressFixture();
    await openValidation(tester, repo);
    expect(find.text(_label(2, 3)), findsOneWidget);
    repo.otherStates = ['validado', 'validado'];
    await scanSku(tester, '000123');
    expect(find.text(_label(3, 3)), findsOneWidget);
    expect(repo.requestedLists.length, greaterThanOrEqualTo(2));
    expect(repo.writes, hasLength(1));
    expect(repo.writes.single.action, 'validar');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('masiva-sku')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1156, 768),
  ]) {
    testWidgets(
      'Resolver el avance a ${size.width.toInt()} px conserva el código en curso y el foco',
      (tester) async {
        final repo =
            _ProgressFixture()
              ..longName = true
              ..firstRequest = Completer<MasivaJson>();
        await openValidation(tester, repo, size: size);
        final sku = find.byKey(const ValueKey('masiva-sku'));
        await tester.ensureVisible(sku);
        await tester.enterText(sku, '000');
        await tester.pumpAndSettle();
        await captureMasiva(
          tester,
          'masiva-progreso-cargando-${size.width.toInt()}',
        );
        repo.firstRequest!.complete(repo.progress());
        await tester.pumpAndSettle();
        expect(find.text(_label(2, 3)), findsOneWidget);
        final field = tester.widget<TextField>(sku);
        expect(field.controller!.text, '000');
        expect(field.focusNode!.hasFocus, isTrue);
        expect(field.enabled, isTrue);
        expect(sku.hitTestable(), findsOneWidget);
        await captureMasiva(
          tester,
          'masiva-progreso-resuelto-${size.width.toInt()}',
        );
        expect(repo.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Cerrar y reabrir el mismo documento consulta el avance nuevo', (
    tester,
  ) async {
    final repo = _ProgressFixture();
    await openValidation(tester, repo);
    await tapVisible(tester, find.byTooltip('Cerrar kit'));
    expect(_progress, findsNothing);
    repo.otherStates = ['validado', 'validado'];
    await searchPerson(tester);
    expect(find.text(_label(3, 3)), findsOneWidget);
    expect(repo.writes, isEmpty);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1366, 768),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Avance conserva lectura y empaque a ${size.width.toInt()} px',
      (tester) async {
        final repo = _ProgressFixture()..longName = true;
        await openValidation(tester, repo, size: size);
        await tester.ensureVisible(_progress);
        await tester.pumpAndSettle();
        expect(find.text(_label(2, 3)), findsOneWidget);
        final bounds = tester.getRect(_progress);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
        await captureMasiva(
          tester,
          'masiva-progreso-lista-${size.width.toInt()}',
        );
        if (size.width <= 390) {
          addTearDown(tester.view.resetViewInsets);
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          await tester.pumpAndSettle();
        }
        await scanSku(tester, '000123');
        expect(repo.writes.single.action, 'validar');
        expect(find.text(_label(2, 3)), findsOneWidget);
        if (size.width <= 390) {
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        await chooseContainer(tester);
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Empacar'));
        expect(repo.writes.last.action, 'embalar');
        expect(_progress, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
