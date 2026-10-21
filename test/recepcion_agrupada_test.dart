import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/inventario_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/recepcion_agrupada.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/domain/wms_repository.dart';
import 'package:orbiloq_wms/core/result.dart';
import 'package:orbiloq_wms/features/recepcion/presentation/recepcion_dialog.dart';

LineaRecepcionPendiente entrega(
  String id, {
  String talla = 'M',
  String codigo = 'C',
  String oc = 'OC1',
  String cliente = 'Cliente',
  int recibida = 0,
  bool reproceso = false,
  EstadoLineaLote estado = EstadoLineaLote.enTransito,
}) {
  final linea = LoteLinea(
    id: id,
    item: ItemOrden(
      id: 'i',
      op: '90005',
      cliente: cliente,
      oc: oc,
      codigo: codigo,
      descripcion: 'Prenda',
      talla: talla,
      cantidadPedida: 20,
    ),
    cantidadEnviada: 5,
    cantidadRecibida: recibida,
    esReproceso: reproceso,
    estado: estado,
  );
  return LineaRecepcionPendiente(
    Lote(
      id: id,
      operario: 'Ana',
      fechaEnvio: DateTime(2026, 10, 7),
      lineas: [linea],
    ),
    linea,
  );
}

class ReceptorPrueba implements WmsRepository {
  bool fallarSegunda = false;
  @override
  Future<void> refrescar() async {}
  final llamadas = <({String id, int cantidad})>[];
  @override
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
    required int cantidad,
    required String ubicacion,
    required String recibidoPor,
    String nota = '',
  }) async {
    llamadas.add((id: loteLineaId, cantidad: cantidad));
    if (fallarSegunda && llamadas.length == 2) {
      return const Err('Recepción no confirmada');
    }
    return Ok(entrega(loteLineaId, recibida: cantidad).linea);
  }

  @override
  Future<List<Movimiento>> cargarRecepciones() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InventarioRecepcionPrueba implements InventarioRepository {
  final llamadas = <InventarioFila>[];
  bool fallar = false;
  @override
  Future<dynamic> ejecutar(String funcion, InventarioFila parametros) async {
    expect(funcion, 'inventario_recibir');
    llamadas.add(parametros);
    if (fallar) throw Exception('La OP no tiene ficha técnica');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class OrigenInventarioPrueba implements InventarioRepository {
  bool sinFicha = false;
  final consultas = <InventarioFila>[];
  final transferencias = <InventarioFila>[];
  @override
  Future<List<InventarioFila>> filas(String funcion, InventarioFila p) async {
    if (funcion == 'inventario_historial_transferencias') {
      return [
        {
          'id': 'hist1',
          'item_id': 'item1',
          'numero_op': '90005',
          'producto': 'Camisa',
          'cliente': 'Cliente A',
          'talla': 'L',
          'ficha': 'FICHA V0',
          'tipo': 'Transferencia a inventario',
          'cantidad': 4,
          'fecha': '2026-10-19T12:00:00Z',
          'responsable': 'Bodega',
          'motivo': 'Stock libre',
          'estante_origen': 'A',
          'estante_destino': 'DESTINO',
          'reversion': false,
        },
      ];
    }
    expect(funcion, 'inventario_origenes');
    consultas.add(p);
    return [
      {
        'item_id': 'item1',
        'ubicacion_id': 'rack1',
        'numero_op': '90005',
        'producto': 'Camisa',
        'cliente': 'Cliente A',
        'talla': 'L',
        'ficha': sinFicha ? null : 'FICHA V0',
        'ubicacion': 'A',
        'disponible': 8 - transferencias.length * 4,
      },
    ];
  }

  @override
  Future<dynamic> ejecutar(String funcion, InventarioFila p) async {
    expect(funcion, 'inventario_transferir_estante');
    transferencias.add(p);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('Suma pendientes manteniendo referencias a los lotes', () {
    final a = entrega('L1'), b = entrega('L2', recibida: 2);
    final g = agruparRecepcionPendiente([a, b]).single;
    expect(g.cantidadPendiente, 8);
    expect(g.cantidadRecibida, 2);
    expect(g.lineas, [a, b]);
    expect(g.distribuir(7), [
      (lineaId: 'L1', cantidad: 5),
      (lineaId: 'L2', cantidad: 2),
    ]);
    expect(() => g.distribuir(9), throwsFormatException);
    expect(
      agruparRecepcionPendiente([entrega('L1', recibida: 5), b]).single.lineas,
      [b],
    );
  });
  test('No mezcla tallas, prendas, OC, clientes ni reprocesos', () {
    expect(
      agruparRecepcionPendiente([
        entrega('1'),
        entrega('2', talla: 'L'),
        entrega('3', codigo: 'D'),
        entrega('4', oc: 'OC2'),
        entrega('5', cliente: 'Otro'),
        entrega('6', reproceso: true),
      ]).length,
      6,
    );
  });
  for (final falla in [false, true]) {
    testWidgets('Recepción agrupada con error parcial: $falla', (tester) async {
      tester.view.physicalSize =
          falla ? const Size(1200, 1000) : const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ReceptorPrueba()..fallarSegunda = falla;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo),
            ubicacionesProvider.overrideWith((ref) async => ['A']),
            wmsSnapshotProvider.overrideWith(
              (ref) => Stream.value(
                WmsSnapshot(
                  kardex: [],
                  lotes: [entrega('L1').lote, entrega('L2').lote],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RecepcionDialog())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Validar recepción'), findsOneWidget);
      expect(find.text('10 pendientes'), findsOneWidget);
      await tester.ensureVisible(find.text('Validar recepción'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Validar recepción'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde quedan las prendas?'), findsNothing);
      expect(find.text('Cantidad a recibir'), findsOneWidget);
      expect(find.text('Todo a inventario'), findsNothing);
      expect(find.text('Para inventario'), findsNothing);
      expect(find.text('Lote de origen a recibir'), findsNothing);
      expect(find.textContaining('L1'), findsNothing);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.textAlign == TextAlign.center,
        ),
        '7',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar recepción · 8 unidades'), findsOneWidget);
      await tester.tap(find.byTooltip('Reducir cantidad'));
      await tester.pumpAndSettle();
      final confirmar = find.text('Confirmar recepción · 7 unidades');
      expect(confirmar.hitTestable(), findsOneWidget);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(repo.llamadas, [(id: 'L1', cantidad: 5), (id: 'L2', cantidad: 2)]);
      expect(
        find.textContaining(
          falla ? 'Se confirmaron 5 Uds.' : 'quedan 3 Uds pendientes',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(1366, 768),
    const Size(1093, 614),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('Recepción compacta con confirmar visible en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(ReceptorPrueba()),
            ubicacionesProvider.overrideWith((ref) async => ['A']),
            wmsSnapshotProvider.overrideWith(
              (ref) => Stream.value(
                WmsSnapshot(
                  kardex: [],
                  lotes: [entrega('L1', recibida: 2).lote],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.kardex(TemaModo.corporativo),
            home: const Scaffold(body: RecepcionDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Validar recepción'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Validar recepción'));
      await tester.pumpAndSettle();
      final confirmar = find.text('Confirmar recepción · 0 unidades');
      expect(confirmar.hitTestable(), findsOneWidget);
      expect(
        find
            .byType(TextField)
            .evaluate()
            .any(
              (e) =>
                  (e.widget as TextField).decoration?.hintText ==
                  'OP o código de etiqueta',
            ),
        isFalse,
      );
      if (size.width >= 1000) {
        expect(find.text('Reportar sobrante'), findsNothing);
        expect(find.text('Cerrar con faltante').hitTestable(), findsOneWidget);
        expect(find.text('Recibir todo').hitTestable(), findsOneWidget);
        final mas = tester.getCenter(find.byTooltip('Aumentar cantidad'));
        final todo = tester.getCenter(find.text('Recibir todo'));
        expect((mas.dy - todo.dy).abs(), lessThan(3));
      } else {
        await tester.ensureVisible(find.text('Recibir todo'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Recibir todo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Confirmar recepción · 3 unidades').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final ancho in [390.0, 1200.0]) {
    testWidgets('A inventario transfiere stock recibido en $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inventario = OrigenInventarioPrueba();
      final bodega = ReceptorPrueba();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(bodega),
            inventarioRepositoryProvider.overrideWithValue(inventario),
            ubicacionesProvider.overrideWith((ref) async => ['DESTINO']),
            usuarioSesionProvider.overrideWith(
              (ref) async => const UsuarioSesion(
                numeroUsuario: '1',
                nombre: 'Bodega',
                rolCuenta: RolCuenta.logistica,
              ),
            ),
            wmsSnapshotProvider.overrideWith(
              (ref) => Stream.value(WmsSnapshot(kardex: [], lotes: [])),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RecepcionDialog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A inventario'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Talla L'), findsOneWidget);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Buscar OP, ficha, producto o cliente',
        ),
        '90005',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(inventario.consultas.last['p_buscar'], '90005');
      await tester.ensureVisible(find.text('Enviar a inventario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar a inventario'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Cantidad',
        ),
        '4',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Motivo obligatorio',
        ),
        'Stock libre',
      );
      await tester.tap(find.text('Confirmar envío'));
      await tester.pumpAndSettle();
      expect(inventario.transferencias.single['p_item'], 'item1');
      expect(inventario.transferencias.single['p_ubicacion'], 'rack1');
      expect(inventario.transferencias.single['p_estante_destino'], 'DESTINO');
      expect(inventario.transferencias.single['p_cantidad'], 4);
      expect(bodega.llamadas, isEmpty);
      expect(find.text('4 uds'), findsOneWidget);
      inventario.sinFicha = true;
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Buscar OP, ficha, producto o cliente',
        ),
        '9000',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Falta ficha técnica:'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar a inventario'),
      );
      expect(boton.onPressed, isNull);
      expect(inventario.transferencias.length, 1);
      await tester.tap(find.text('Historial').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('OP 90005'), findsWidgets);
      expect(find.text('Filtrar por fecha'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }
}
