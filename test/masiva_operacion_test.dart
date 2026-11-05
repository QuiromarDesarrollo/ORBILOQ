import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:orbiloq_wms/shared/widgets/wms_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/masiva/masiva_repository.dart';
import 'masiva_ui_test.dart' show MasivaFixture, mount, captureMasiva;

class OperacionFixture extends MasivaFixture {
  int received = 1;
  final writes = <MasivaJson>[];
  Completer<void>? gate;
  bool fail = false;
  MasivaJson? pending;
  int recoveries = 0;
  @override
  MasivaJson? get movimientoPendiente => pending;
  @override
  Future<MasivaJson> recuperarConfirmacion() async {
    recoveries++;
    pending = null;
    return {'recibido': received};
  }

  @override
  Future<MasivaJson> consultarPuesto(String operacion) async => {
    'pedidos': [
      {
        'proveedor': 'Proveedor de ejemplo',
        'pedido': '10001',
        'esperado': 3,
        'recibido': received,
        'referencias': 1,
        'completas': received == 3 ? 1 : 0,
      },
    ],
  };
  @override
  Future<MasivaJson> consultarRecepcion({
    required String operacion,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    String? proveedor,
    String? pedido,
  }) async {
    if (proveedor == null) {
      return super.consultarRecepcion(
        operacion: operacion,
        buscar: buscar,
        filtros: filtros,
        pagina: pagina,
      );
    }
    final sku = filtros['sku']?.first;
    return {
      'filas': [
        if (sku == null || sku == '000123')
          {
            'id': 'inv1',
            'sku': '000123',
            'descripcion': 'Camisa manga larga talla M',
            'proveedor': 'Proveedor de ejemplo',
            'pedido': '10001',
            'esperado': 3,
            'recibido': received,
            'pendiente': 3 - received,
            'validado': 0,
          },
      ],
      'total': sku == null || sku == '000123' ? 1 : 0,
      'metricas': {},
      'pedido': {'proveedor': 'Proveedor de ejemplo', 'pedido': '10001'},
    };
  }

  @override
  Future<MasivaJson> ejecutar(String accion, MasivaJson datos) async {
    writes.add({...datos});
    if (gate != null) await gate!.future;
    if (fail) {
      pending = {'accion': accion, 'datos': datos};
      received += numeroMasiva(datos['cantidad']);
      throw const MasivaError(
        'Respuesta de red incierta: recuperar confirmación',
      );
    }
    received += numeroMasiva(datos['cantidad']);
    return {'recibido': received};
  }

  @override
  Future<MasivaJson> consultarConciliacion({
    required String operacion,
    String buscar = '',
    String estado = '',
    int pagina = 1,
  }) async => {
    'total': 1,
    'filas': [
      {
        'sku': '000456',
        'descripcion': 'Calzado de ejemplo',
        'proveedores': 'Sin pedido',
        'esperado': 0,
        'recibido': 0,
        'pendiente': 0,
        'requerido': 4,
        'validado': 0,
        'disponible': 0,
        'saldo': -4,
        'proyeccion': -4,
      },
    ],
    'metricas': {
      'base_personal_cargada': true,
      'esperado': 3,
      'recibido': received,
      'pendiente': 3 - received,
      'requerido': 4,
      'validado': 0,
      'disponible': received,
      'sobrante_previsto': 3,
      'faltante_previsto': 4,
      'referencias_faltantes': 1,
      'sin_pedido': 1,
    },
  };
}

Future<void> receipt(WidgetTester tester, OperacionFixture repo) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await mount(tester, const Size(1440, 1100), repo);
  await tester.tap(find.text('Recepción').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Ver prendas'));
  await tester.tap(find.text('Ver prendas'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('masiva-recepcion-sku')), findsNothing);
  final open = find.byKey(const ValueKey('open-receipt-station'));
  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('masiva-recepcion-sku')),
  );
}

Future<void> scan(WidgetTester tester, String code) async {
  final field = find.byKey(const ValueKey('masiva-recepcion-sku'));
  await tester.ensureVisible(field);
  await tester.enterText(field, code);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> openReceiptCard(WidgetTester tester, {String id = 'inv1'}) async {
  final quantity = find.byKey(ValueKey('receipt-quantity-$id'));
  if (quantity.evaluate().isNotEmpty) return;
  final toggle = find.byKey(ValueKey('toggle-receipt-$id'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

class MultipleReceiptsFixture extends OperacionFixture {
  @override
  Future<MasivaJson> consultarRecepcion({
    required String operacion,
    String buscar = '',
    Map<String, Set<String>> filtros = const {},
    int pagina = 1,
    String? proveedor,
    String? pedido,
  }) async {
    final result = await super.consultarRecepcion(
      operacion: operacion,
      buscar: buscar,
      filtros: filtros,
      pagina: pagina,
      proveedor: proveedor,
      pedido: pedido,
    );
    if (proveedor != null &&
        (filtros['sku'] == null || filtros['sku']!.contains('000456'))) {
      final rows = filasMasiva(result['filas']);
      rows.add({
        'id': 'inv2',
        'sku': '000456',
        'descripcion': 'Pantalón talla L',
        'proveedor': 'Proveedor de ejemplo',
        'pedido': '10001',
        'esperado': 10,
        'recibido': 0,
        'pendiente': 10,
        'validado': 0,
      });
      return {...result, 'filas': rows, 'total': rows.length};
    }
    return result;
  }
}

Future<void> captureReceipt(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final finder =
        find
            .ancestor(
              of: find.byType(WmsDialogShell),
              matching: find.byType(RepaintBoundary),
            )
            .first;
    final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = FontLoader('ConductorSans')
      ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'El último SKU queda primero sin duplicar ni perder su cantidad',
    (tester) async {
      final repo = MultipleReceiptsFixture();
      await receipt(tester, repo);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Remisión o soporte',
        ),
        'REM-ORDEN',
      );
      final first = find.byKey(const ValueKey('receipt-card-inv1'));
      final second = find.byKey(const ValueKey('receipt-card-inv2'));
      await scan(tester, '000123');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-quantity-inv1')), findsNothing);
      await openReceiptCard(tester);
      await scan(tester, '000456');
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
      );
      await scan(tester, '000123');
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      // La expansión y el controlador pertenecen al SKU, no a su posición.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('receipt-quantity-inv1')),
            )
            .controller!
            .text,
        '2',
      );
      expect(find.byKey(const ValueKey('receipt-quantity-inv2')), findsNothing);
      expect(repo.writes, isEmpty);
      await scan(tester, '000456');
      await tester.pumpAndSettle();
      await scan(tester, '000123'); // Excede el máximo: no debe reordenar.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar aviso').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
      );
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('open-receipt-station'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(second).dy,
        lessThan(tester.getTopLeft(first).dy),
      );
      expect(find.text('+2 por confirmar'), findsNWidgets(2));
      await tester.ensureVisible(second);
      await captureReceipt(tester, 'masiva-recepcion-compacta-integrada-1440');
      await openReceiptCard(tester, id: 'inv2');
      final quantity2 = find.byKey(const ValueKey('receipt-quantity-inv2'));
      await tester.ensureVisible(quantity2);
      await tester.enterText(quantity2, '3');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(quantity2).controller!.text, '3');
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Tarjeta acumula lecturas y confirma una sola recepción', (
    tester,
  ) async {
    final repo = OperacionFixture();
    await receipt(tester, repo);
    final consultasAntesDeEscanear = repo.consultas.length;
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Remisión o soporte',
      ),
      'REM-001',
    );
    await scan(tester, '000123');
    await tester.pumpAndSettle();
    expect(repo.consultas.length, consultasAntesDeEscanear);
    await scan(tester, '000123');
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(find.byKey(const ValueKey('receipt-card-inv1')), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-quantity-inv1')), findsNothing);
    expect(find.text('+2 por confirmar'), findsOneWidget);
    await openReceiptCard(tester);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('receipt-quantity-inv1')),
          )
          .controller!
          .text,
      '2',
    );
    await scan(tester, '000123');
    await tester.pumpAndSettle();
    expect(find.text('Revisar recepción'), findsOneWidget);
    await tester.tap(find.text('Cerrar aviso').last);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('confirm-receipt-inv1'));
    await tester.ensureVisible(confirm);
    final consultasAntesDeConfirmar = repo.consultas.length;
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.consultas.length, consultasAntesDeConfirmar);
    expect(repo.writes, hasLength(1));
    expect(repo.writes.single['cantidad'], 2);
    expect(repo.writes.single['soporte'], 'REM-001');
    expect(repo.received, 3);
    expect(find.byKey(const ValueKey('receipt-card-inv1')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Cantidad manual, Todo y Recontar respetan límite y móvil', (
    tester,
  ) async {
    final repo = OperacionFixture();
    await receipt(tester, repo);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Remisión o soporte',
      ),
      'REM-002',
    );
    await scan(tester, '000123');
    await tester.pumpAndSettle();
    await openReceiptCard(tester);
    final quantity = find.byKey(const ValueKey('receipt-quantity-inv1'));
    await tester.ensureVisible(quantity);
    await tester.enterText(quantity, '99');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-receipt-inv1')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Todo (2)'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(quantity).controller!.text, '2');
    await tester.tap(find.text('Recontar'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(quantity).controller!.text, '1');
    tester.view.physicalSize = const Size(390, 1000);
    await tester.pumpAndSettle();
    await tester.ensureVisible(quantity);
    await captureReceipt(tester, 'masiva-modal-recepcion-390');
    tester.view.physicalSize = const Size(768, 1000);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-receipt-inv1')),
    );
    await captureReceipt(tester, 'masiva-modal-recepcion-768-teclado');
    expect(
      find.byKey(const ValueKey('confirm-receipt-inv1')).hitTestable(),
      findsOneWidget,
    );
    tester.view.resetViewInsets();
    expect(tester.takeException(), isNull);
    expect(repo.writes, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Actualiza el límite si otro usuario recibió antes de confirmar',
    (tester) async {
      final repo = OperacionFixture();
      await receipt(tester, repo);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Remisión o soporte',
        ),
        'REM-003',
      );
      await scan(tester, '000123');
      await tester.pumpAndSettle();
      await openReceiptCard(tester);
      await tester.ensureVisible(find.text('Todo (2)'));
      await tester.tap(find.text('Todo (2)'));
      await tester.pumpAndSettle();
      repo.received = 2;
      final confirm = find.byKey(const ValueKey('confirm-receipt-inv1'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.writes, isEmpty);
      expect(find.textContaining('Cambió la cantidad pendiente'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Cerrar conserva borrador y el modal bloquea cierre al confirmar',
    (tester) async {
      final repo = OperacionFixture();
      await receipt(tester, repo);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Remisión o soporte',
        ),
        'REM-GUARDAR',
      );
      await scan(tester, '000123');
      await tester.pumpAndSettle();
      await openReceiptCard(tester);
      final quantity = find.byKey(const ValueKey('receipt-quantity-inv1'));
      await tester.ensureVisible(quantity);
      await tester.enterText(quantity, '2');
      await tester.pumpAndSettle();
      await captureReceipt(tester, 'masiva-modal-recepcion-1440');
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-card-inv1')), findsNothing);
      expect(repo.writes, isEmpty);
      final open = find.byKey(const ValueKey('open-receipt-station'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      await openReceiptCard(tester);
      expect(tester.widget<TextField>(quantity).controller!.text, '2');
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.labelText == 'Remisión o soporte',
              ),
            )
            .controller!
            .text,
        'REM-GUARDAR',
      );
      repo.gate = Completer<void>();
      final confirm = find.byKey(const ValueKey('confirm-receipt-inv1'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<WmsDialogShell>(find.byType(WmsDialogShell)).canClose,
        false,
      );
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.received, 3);
      expect(repo.writes, hasLength(1));
      expect(
        tester.widget<WmsDialogShell>(find.byType(WmsDialogShell)).canClose,
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Recupera recepción incierta dentro del modal sin duplicar', (
    tester,
  ) async {
    final repo = OperacionFixture()..fail = true;
    await receipt(tester, repo);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Remisión o soporte',
      ),
      'REM-RED',
    );
    await scan(tester, '000123');
    await tester.pumpAndSettle();
    await openReceiptCard(tester);
    final confirm = find.byKey(const ValueKey('confirm-receipt-inv1'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Cerrar aviso').last);
    await tester.pumpAndSettle();
    final recover = find.descendant(
      of: find.byType(WmsDialogShell),
      matching: find.text('Recuperar'),
    );
    await tester.ensureVisible(recover);
    await tester.tap(recover);
    await tester.pumpAndSettle();
    expect(repo.recoveries, 1);
    expect(repo.writes, hasLength(1));
    expect(repo.received, 2);
    expect(find.byKey(const ValueKey('receipt-card-inv1')), findsNothing);
    expect(find.text('Recepción de prendas'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [390.0, 1440.0, 1920.0]) {
    testWidgets('Conciliación muestra faltante sin pedido a $width', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, Size(width, 1100), OperacionFixture());
      if (width < 1080) {
        await tester.tap(find.byTooltip('Abrir menú'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Conciliación').first);
      await tester.pumpAndSettle();
      expect(find.text('Faltan 4'), findsOneWidget);
      expect(find.textContaining('4 unidades faltantes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureMasiva(tester, 'masiva-conciliacion-$width');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
