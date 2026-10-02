import 'package:orbiloq_wms/application/dashboard_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_atencion.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_atencion_section.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_recepcion_section.dart';

ItemKardex lineaAtencion(
  String op, {
  String? id,
  int producido = 0,
  int recibido = 0,
  int despachado = 0,
  int nc = 0,
  bool eliminada = false,
  DateTime? fecha,
}) => ItemKardex(
  item: ItemOrden(
    id: id ?? op,
    op: op,
    cliente: 'Cliente A',
    oc: 'OC1',
    codigo: 'CAM-$op',
    descripcion: 'Camisa',
    talla: 'M',
    cantidadPedida: 10,
  ),
  producido: producido,
  recibido: recibido,
  despachado: despachado,
  pendienteReproceso: nc,
  eliminada: eliminada,
  ubicaciones: {},
  fechaEsperadaProduccion: fecha,
);

final demoAtencion = [
  lineaAtencion('90001', fecha: DateTime(2026, 9, 30)),
  lineaAtencion('90002', producido: 10),
  lineaAtencion('90003', producido: 10, recibido: 10),
  lineaAtencion('90004', producido: 10, recibido: 10, despachado: 10),
  lineaAtencion('90005', fecha: DateTime(2026, 10, 4)),
];

void main() {
  final corte = DateTime.utc(2026, 10, 2, 17);
  test(
    'Cada OP cuenta una vez en primera etapa; NC impide completo y borradas no cuentan',
    () {
      expect(
        contarEtapas([
          ...demoAtencion,
          lineaAtencion(
            '90001',
            id: 'otra',
            producido: 10,
            recibido: 10,
            despachado: 10,
          ),
          lineaAtencion(
            'NC',
            producido: 10,
            recibido: 10,
            despachado: 10,
            nc: 2,
          ),
          lineaAtencion('BORRADA', eliminada: true),
        ]),
        [3, 1, 1, 1],
      );
    },
  );
  test(
    'Alertas respetan días, pendientes, deduplicación, corte y liberaciones recientes',
    () {
      final sobrante = {
        'registro': 's1',
        'origen': 'Sobrantes',
        'op': 'S1',
        'fecha': '2026-09-20T12:00:00Z',
        'datos_crudos': {'estado': 'pendiente', 'cantidad': 4},
      };
      final filas = [
        sobrante,
        sobrante,
        {
          'registro': 'r1',
          'origen': 'Sobrantes',
          'fecha': '2026-09-01T12:00:00Z',
          'datos_crudos': {'estado': 'resuelto', 'cantidad': 3},
        },
        {
          'registro': 'nc1',
          'origen': 'Logística',
          'fecha': '2026-09-01T12:00:00Z',
          'datos_crudos': {'item_orden_id': 'NC'},
        },
        {
          'registro': 'lib1',
          'origen': 'Liberaciones',
          'fecha': '2026-10-01T12:00:00Z',
          'datos_crudos': {'item_orden_id': 'NC'},
        },
      ];
      final alertas = calcularAtencion(
        [...demoAtencion, lineaAtencion('NC', producido: 10, nc: 4)],
        filas,
        corte: corte,
      );
      expect(alertas, hasLength(3));
      expect(alertas.first.titulo, contains('Sobrante'));
      expect(alertas.last.detalle, contains('vence en 2 días'));
      expect(alertas.where((a) => a.titulo.contains('No conforme')), isEmpty);
      final antiguas = calcularAtencion(
        [lineaAtencion('NC', nc: 4)],
        [filas[3]],
        corte: corte,
      );
      expect(antiguas.single.detalle, contains('31 días'));
      expect(
        calcularAtencion([], [sobrante], corte: corte, antiguedad: 14),
        isEmpty,
      );
    },
  );
  for (final modo in TemaModo.values) {
    for (final ancho in [320.0, 768.0, 1440.0]) {
      testWidgets(
        'Panel read-only responsive $modo $ancho y umbrales locales',
        (tester) async {
          tester.view.physicalSize = Size(ancho, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dashboardSnapshotProvider.overrideWith(
                  (ref) => Future.value(
                    WmsSnapshot(kardex: demoAtencion, lotes: []),
                  ),
                ),
                dashboardRecepcionProvider.overrideWith((ref) async => []),
              ],
              child: MaterialApp(
                theme: AppTheme.kardex(modo),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DashboardAtencionSection(corte: corte),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('4 OP activas · 1 completas'), findsOneWidget);
          await tester.ensureVisible(find.text('Próximos 3 días'));
          await tester.tap(find.text('Próximos 3 días'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Próximos 1 días').last);
          await tester.pumpAndSettle();
          expect(find.textContaining('vence en 2 días'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
