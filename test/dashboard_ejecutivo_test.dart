import 'package:orbiloq_wms/application/dashboard_snapshot.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/dashboard_tendencias.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/data/reportes_admin_repository.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_ejecutivo_page.dart';

class ReportesDashboardPrueba implements ReportesAdminRepository {
  int llamadas = 0;
  @override
  Future<FilaReporte> resumen() async {
    llamadas++;
    return {'actualizado_en': '2026-10-02T17:00:00Z'};
  }

  @override
  Future<List<FilaReporte>> cargar(String tipo) async {
    llamadas++;
    if (tipo == 'nc') {
      return [
        for (var i = 0; i < 12; i++)
          {
            'registro': 'nc:$i',
            'cliente': 'Cliente ${i + 1}',
            'causal': ['Costura', 'Tela', 'Talla'][i % 3],
            'cantidad': 10 + i * 3,
            'fecha': i < 6 ? '2026-09-30T12:00:00Z' : '2026-07-30T12:00:00Z',
          },
      ];
    }
    if (tipo == 'auditoria') {
      return [
        for (var i = 0; i < 12; i++) ...[
          for (var r = 0; r < 5; r++)
            {
              'registro': 'Recepción:$i-$r',
              'origen': 'Recepción',
              'fecha':
                  DateTime.utc(
                    2026,
                    7,
                    15,
                  ).add(Duration(days: i * 7)).toIso8601String(),
              'datos_crudos': {
                'estado': r == 4 ? 'recibido_con_novedad' : 'recibido_conforme',
              },
            },
          {
            'registro': 'Sobrantes:$i',
            'origen': 'Sobrantes',
            'fecha':
                DateTime.utc(
                  2026,
                  7,
                  15,
                ).add(Duration(days: i * 7)).toIso8601String(),
            'datos_crudos': {
              'cantidad': 15 + i * 3 + (i % 3) * 10,
              'estado': 'resuelto',
              'fecha':
                  DateTime.utc(
                    2026,
                    7,
                    15,
                  ).add(Duration(days: i * 7)).toIso8601String(),
              'fecha_resolucion':
                  DateTime.utc(
                    2026,
                    7,
                    16,
                  ).add(Duration(days: i * 7 + i % 3)).toIso8601String(),
            },
          },
        ],
      ];
    }
    if (tipo != 'movimientos') throw StateError('Reporte inesperado');
    return [
      for (var semana = 0; semana < 12; semana++)
        for (var serie = 0; serie < 3; serie++)
          {
            'fecha':
                DateTime.utc(
                  2026,
                  7,
                  15,
                ).add(Duration(days: 7 * semana)).toIso8601String(),
            'tipo': tiposVolumen[serie],
            'cliente': 'Cliente ${semana + 1}',
            'cantidad': 800 + semana * 70 - serie * 130 + (semana % 3) * 190,
            'datos_crudos': {'admin_correccion_id': null},
          },
    ];
  }
}

void main() {
  test(
    'Agrupa con límites de lunes en Bogotá y excluye correcciones, negativos y fechas posteriores al corte',
    () {
      final datos = calcularTendencias(
        [
          {'fecha': '2026-09-28T04:59:00Z', 'tipo': 'recepcion', 'cantidad': 5},
          {'fecha': '2026-09-28T05:00:00Z', 'tipo': 'recepcion', 'cantidad': 7},
          {
            'fecha': '2026-09-29T12:00:00Z',
            'tipo': 'entrega_produccion',
            'cantidad': 10,
          },
          {
            'fecha': '2026-09-30T12:00:00Z',
            'tipo': 'entrega_produccion',
            'cantidad': 100,
            'datos_crudos': {'admin_correccion_id': 'ajuste'},
          },
          {'fecha': '2026-09-30T12:00:00Z', 'tipo': 'despacho', 'cantidad': -3},
          {'fecha': '2026-09-30T12:00:00Z', 'tipo': 'despacho', 'cantidad': 4},
          {
            'fecha': '2026-10-03T12:00:00Z',
            'tipo': 'despacho',
            'cantidad': 500,
          },
          {
            'fecha': '2026-09-30T12:00:00Z',
            'tipo': 'devolucion_produccion',
            'cantidad': 100,
          },
          {'fecha': 'invalida', 'tipo': 'recepcion', 'cantidad': 20},
        ],
        corte: DateTime.utc(2026, 10, 2),
        semanas: 4,
      );
      expect(datos.semanas, hasLength(4));
      expect(datos.semanas.last.inicio, DateTime.utc(2026, 9, 28));
      expect(datos.semanas[2].unidades, [0, 5, 0]);
      expect(datos.semanas.last.unidades, [10, 7, 4]);
      expect(datos.semanas.first.unidades, [0, 0, 0]);
      expect(datos.totales, [10, 12, 4]);
      expect(datos.registrosInvalidos, 1);
    },
  );

  for (final modo in TemaModo.values) {
    for (final ancho in [390.0, 1440.0]) {
      testWidgets(
        'Dashboard $modo en $ancho: período, datos y gráfico sin desbordamientos',
        (tester) async {
          tester.view.physicalSize = Size(ancho, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = ReportesDashboardPrueba();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                usarSupabaseProvider.overrideWithValue(false),
                reportesAdminProvider.overrideWithValue(repo),
                dashboardSnapshotProvider.overrideWith(
                  (ref) => Future.value(WmsSnapshot(kardex: [], lotes: [])),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.kardex(modo),
                home: const DashboardEjecutivoPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(GraficaVolumenSemanal), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Últimas 12 semanas'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Últimas 4 semanas').last);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<GraficaVolumenSemanal>(
                  find.byType(GraficaVolumenSemanal),
                )
                .semanas,
            hasLength(4),
          );
          expect(repo.llamadas, 4);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Un usuario operativo no puede consultar el dashboard', (
    tester,
  ) async {
    final repo = ReportesDashboardPrueba();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usarSupabaseProvider.overrideWithValue(true),
          usuarioSesionProvider.overrideWith(
            (ref) async => const UsuarioSesion(
              numeroUsuario: '1',
              nombre: 'Operario',
              rolCuenta: RolCuenta.logistica,
            ),
          ),
          reportesAdminProvider.overrideWithValue(repo),
          dashboardSnapshotProvider.overrideWith(
            (ref) => Future.value(WmsSnapshot(kardex: [], lotes: [])),
          ),
        ],
        child: const MaterialApp(home: DashboardEjecutivoPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.llamadas, 0);
    expect(find.text('Acceso exclusivo del administrador.'), findsOneWidget);
  });
}
