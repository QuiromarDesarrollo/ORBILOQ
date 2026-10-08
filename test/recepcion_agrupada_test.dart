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
    if (fallarSegunda && llamadas.length == 2)
      return const Err('Recepción no confirmada');
    return Ok(entrega(loteLineaId, recibida: cantidad).linea);
  }

  @override
  Future<List<Movimiento>> cargarRecepciones() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  for (final falla in [false, true])
    testWidgets('Recepción agrupada con error parcial: $falla', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
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
      expect(find.text('VALIDAR'), findsOneWidget);
      expect(find.textContaining('10 Uds pendientes'), findsOneWidget);
      await tester.tap(find.text('VALIDAR'));
      await tester.pumpAndSettle();
      expect(find.text('Cant. a recibir ahora (máx 10)'), findsOneWidget);
      expect(find.text('Lote de origen a recibir'), findsNothing);
      expect(find.textContaining('L1'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Cant. a recibir ahora (máx 10)'),
        '7',
      );
      final confirmar = find.text('INGRESAR A ESTANTE & CONFIRMAR');
      await tester.ensureVisible(confirmar);
      await tester.pumpAndSettle();
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
