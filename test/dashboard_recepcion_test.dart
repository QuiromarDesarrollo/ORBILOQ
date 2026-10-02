import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_recepcion.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_recepcion_section.dart';

final corte = DateTime.utc(2026, 10, 2, 20);
Map<String, dynamic> recepcion(String id, String estado) => {
  'registro': id,
  'origen': 'Recepción',
  'fecha': '2026-09-30T12:00:00Z',
  'datos_crudos': {'estado': estado},
};
Map<String, dynamic> sobrante(
  String id,
  String inicio,
  String? fin,
  int cantidad,
) => {
  'registro': id,
  'origen': 'Sobrantes',
  'fecha': inicio,
  'datos_crudos': {
    'fecha': inicio,
    'fecha_resolucion': fin,
    'estado': fin == null ? 'pendiente' : 'resuelto',
    'cantidad': cantidad,
  },
};

void main() {
  test(
    'Dona por líneas, tasa por unidades y resolución por registro, sin duplicar auditoría',
    () {
      final filas = [
        recepcion('r1', 'recibido_conforme'),
        recepcion('r2', 'recibido_con_novedad'),
        recepcion('r3', 'en_transito'), recepcion('r1', 'recibido_conforme'),
        sobrante('s1', '2026-09-30T12:00:00Z', '2026-10-01T12:00:00Z', 10),
        sobrante('s2', '2026-09-30T12:00:00Z', null, 20),
        // Creado fuera del rango, resuelto dentro: debe formar parte del promedio.
        sobrante('s3', '2026-08-30T12:00:00Z', '2026-09-29T12:00:00Z', 50),
        {
          'registro': 'res-s1',
          'origen': 'Resoluciones',
          'fecha': '2026-10-01T12:00:00Z',
        },
      ];
      final r = calcularRecepcion(
        filas,
        [
          {
            'tipo': 'recepcion',
            'fecha': '2026-09-30T12:00:00Z',
            'cantidad': 100,
          },
          {
            'tipo': 'recepcion',
            'fecha': '2026-09-30T12:00:00Z',
            'cantidad': 50,
            'datos_crudos': {'admin_correccion_id': 'correccion'},
          },
        ],
        corte: corte,
        semanas: 4,
      );
      expect(r.porcentajeConforme, 50);
      expect(r.enTransito, 1);
      expect(r.sobrantes, 30);
      expect(r.tasaSobrantes, 30);
      expect(r.resueltos, 2);
      expect(r.diasPromedio, 15.5);
      expect(r.tasasSemanales, [null, null, null, 30]);
      expect(r.diasSemanales, [null, null, null, 15.5]);
    },
  );
  test(
    'Sin base no se convierte en cero y las fechas inválidas no producen días negativos',
    () {
      final r = calcularRecepcion(
        [
          sobrante('s1', '2026-09-30T12:00:00Z', '2026-09-29T12:00:00Z', 3),
          sobrante('s2', '2026-09-30T12:00:00Z', '2026-10-10T12:00:00Z', 5),
        ],
        [],
        corte: corte,
        semanas: 4,
      );
      expect(r.tasaSobrantes, null);
      expect(r.diasPromedio, null);
      expect(r.porcentajeConforme, null);
      expect(r.invalidos, 1);
      expect(r.sobrantes, 8);
    },
  );
  for (final ancho in [320.0, 768.0, 1440.0]) {
    for (final modo in TemaModo.values) {
      testWidgets('Recepción $ancho $modo sin datos, sin desbordamientos', (
        tester,
      ) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.kardex(modo),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IndicadoresRecepcion(
                    datos: calcularRecepcion([], [], corte: corte, semanas: 4),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sin datos'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
