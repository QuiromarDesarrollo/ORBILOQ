import 'dart:typed_data';
import 'package:orbiloq_wms/application/providers.dart' show temaProvider;
import 'package:orbiloq_wms/features/ciclos/presentation/grafica_intercambiable.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/ciclos_providers.dart';
import 'package:orbiloq_wms/application/dashboard_acceso.dart';
import 'package:orbiloq_wms/data/excel_ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_page.dart';

DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');
OrdenCiclo orden({
  String op = 'OS421',
  int cantidad = 20,
  String? inicio = '2026-09-01',
  List<String?>? fines,
  Map<String, dynamic> versiones = const {},
}) => OrdenCiclo(op, 'Cliente', cantidad, inicio == null ? null : d(inicio), [
  for (final f in fines ?? List.filled(7, null)) f == null ? null : d(f),
], versiones);
Uint8List excel(List<List<CellValue?>> filas, {bool combinar = false}) {
  final e = Excel.createExcel(), h = e['Sheet1'];
  h.appendRow([for (final s in ExcelCiclos.columnas) TextCellValue(s)]);
  for (final fila in filas) {
    h.appendRow(fila);
  }
  if (combinar) {
    h.merge(CellIndex.indexByString('C2'), CellIndex.indexByString('C3'));
  }
  return Uint8List.fromList(e.encode()!);
}

List<CellValue?> fila(
  String op, {
  CellValue? cantidad = const IntCellValue(20),
  CellValue? fecha,
}) => [
  TextCellValue(op),
  TextCellValue('Cliente'),
  cantidad,
  fecha ?? TextCellValue('01/09/2026'),
  TextCellValue('03/09/2026'),
  null,
  null,
  null,
  null,
  null,
  TextCellValue('-'),
];
void main() {
  test(
    'Calendario colombiano: Emiliani, Semana Santa, fin de año y mismo día',
    () {
      final c = CalendarioColombia();
      expect(c.sumar(d('2026-10-09'), 1), d('2026-10-13'));
      expect(c.transcurridos(d('2026-04-01'), d('2026-04-06')), 1);
      expect(c.sumar(d('2026-12-31'), 1), d('2027-01-04'));
      expect(c.transcurridos(d('2026-09-01'), d('2026-09-01')), 0);
      expect(c.habil(d('2026-03-23')), false);
      expect(c.habil(d('2026-08-07')), false);
    },
  );
  test(
    'Sin inicio no inventa fechas; conserva parámetro asociado histórico',
    () {
      final viejo = ParametroCiclo(
        'v1',
        ProcesoCiclo.compras,
        d('2026-01-01'),
        6,
        10,
        null,
      );
      final nuevo = ParametroCiclo(
        'v2',
        ProcesoCiclo.compras,
        d('2026-08-01'),
        2,
        20,
        null,
      );
      final o = orden(versiones: {'compras': 'v1'}),
          datos = DatosCiclos([], [viejo, nuevo], d('2026-09-15'), '1');
      expect(datos.medir(o, ProcesoCiclo.compras).esperada, d('2026-09-09'));
      expect(datos.medir(o, ProcesoCiclo.compras).estado, 'Vencido');
      expect(datos.medir(o, ProcesoCiclo.trazo).esperada, isNull);
      expect(datos.objetivoTotal(o), isNull);
      expect(datos.medir(orden(), ProcesoCiclo.compras).esperada, isNull);
    },
  );
  test(
    'Carga semanal no suma las colas diarias ni libera sin fecha anterior',
    () {
      final o = orden(
        inicio: '2026-08-28',
        fines: ['2026-09-03', null, null, null, null, null, null],
      );
      final a = CargaCiclo.calcular(
        [o],
        ProcesoCiclo.compras,
        d('2026-08-31'),
        d('2026-09-04'),
      );
      expect(
        [a.inicial, a.entradas, a.salidas, a.finalPendiente],
        [1, 0, 1, 0],
      );
      final b = CargaCiclo.calcular(
        [o],
        ProcesoCiclo.trazo,
        d('2026-08-31'),
        d('2026-09-04'),
      );
      expect(
        [b.inicial, b.entradas, b.salidas, b.finalPendiente],
        [0, 1, 0, 1],
      );
      expect(
        CargaCiclo.calcular(
          [o],
          ProcesoCiclo.corte,
          d('2026-08-31'),
          d('2026-09-04'),
        ).porAtender,
        0,
      );
    },
  );
  test('Percentiles y capacidad semanal independiente y sin prorrata', () {
    expect(percentil([1, 2, 3, 10], .5), 2.5);
    expect(percentil([1, 2, 3, 10], .8), closeTo(5.8, .0001));
    expect(percentil([], .8), isNull);
    final p = ParametroCiclo(
      '1',
      ProcesoCiclo.corte,
      d('2026-01-01'),
      3,
      100,
      7000,
    );
    final i = IndicadoresCiclos(DatosCiclos([], [p], d('2026-09-04'), '0'));
    expect(
      i.capacidad(
        ProcesoCiclo.corte,
        d('2026-08-31'),
        d('2026-09-06'),
        semanal: true,
      ),
      7000,
    );
    expect(
      i.capacidad(
        ProcesoCiclo.corte,
        d('2026-09-05'),
        d('2026-09-05'),
        semanal: false,
      ),
      isNull,
    );
    expect(i.cumplimientoTotal, isNull);
  });
  test('Cumplimiento histórico no se convierte en comparación actual', () {
    final parametros = [
      for (final p in ProcesoCiclo.values)
        ParametroCiclo(p.name, p, d('2026-01-01'), 2, null, null),
      ParametroCiclo(
        'nuevo',
        ProcesoCiclo.compras,
        d('2026-08-01'),
        0,
        null,
        null,
      ),
    ];
    final o = orden(
      fines: [
        '2026-09-03',
        '2026-09-04',
        '2026-09-07',
        '2026-09-08',
        '2026-09-09',
        '2026-09-10',
        '2026-09-11',
      ],
      versiones: {for (final p in ProcesoCiclo.values) p.name: p.name},
    );
    final i = IndicadoresCiclos(
      DatosCiclos([o], parametros, d('2026-10-01'), '0'),
    );
    expect(i.cumplimientoProceso(ProcesoCiclo.compras), 100);
    expect(
      i.cumplimientoProceso(ProcesoCiclo.compras, compararActual: true),
      0,
    );
    expect(i.completas.length, 1);
    expect(i.cumplimientoTotal, 100);
  });
  test(
    'Excel respeta OP alfanumérica, guiones, fechas y celdas combinadas reales',
    () {
      final r = ExcelCiclos.leer(
        excel([fila('OS421'), fila('OS428', cantidad: null)], combinar: true),
      );
      expect(r[0]['op'], 'OS421');
      expect(r[1]['cantidad'], 20);
      expect((r[0]['fines'] as Map)['logistica'], isNull);
      expect(r[0]['inicio'], '2026-09-01');
      expect(
        () => ExcelCiclos.leer(excel([fila('1'), fila('2', cantidad: null)])),
        throwsFormatException,
      );
    },
  );
  test(
    'Excel rechaza duplicados, fechas imposibles, texto, fórmulas y orden incoherente',
    () {
      expect(
        () => ExcelCiclos.leer(excel([fila('1'), fila('1')])),
        throwsFormatException,
      );
      for (final f in [
        TextCellValue('31/02/2026'),
        TextCellValue('INVENTARIO'),
        FormulaCellValue('TODAY()'),
        TextCellValue('09/09/2026'),
      ]) {
        expect(
          () => ExcelCiclos.leer(excel([fila('1', fecha: f)])),
          throwsFormatException,
        );
      }
    },
  );
  testWidgets('Cada selector conserva datos, metas y admite cinco tipos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GraficaIntercambiable(
            titulo: 'Prueba',
            datos: const DatosGrafica(
              ['Compras', 'Trazo', 'Corte'],
              [120, null, 0],
              metas: [100, 100, 100],
              unidad: '%',
              porcentaje: true,
            ),
            original: const Text('Original'),
          ),
        ),
      ),
    );
    for (final tipo in [
      'Barras horizontales',
      'Columnas',
      'Líneas',
      'Área',
      'Donas',
    ]) {
      await tester.tap(find.byTooltip('Tipo de gráfica: Prueba'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tipo).last);
      await tester.pumpAndSettle();
      expect(find.text('1. Compras: 120.0'), findsOneWidget);
      expect(find.text('2. Trazo: —'), findsOneWidget);
      expect(find.text('3. Corte: 0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Alterna tema del dashboard y conserva la pestaña seleccionada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardAccesoProvider.overrideWithValue(('5', RolCuenta.gerencia)),
          ciclosProvider.overrideWith(
            (ref) async => DatosCiclos([], [], d('2026-10-07'), '0'),
          ),
        ],
        child: Consumer(
          builder:
              (context, ref, _) => MaterialApp(
                theme: AppTheme.kardex(ref.watch(temaProvider)),
                home: const CiclosPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(CiclosPage))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('Detalle por OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cambiar a vista clara'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(CiclosPage))).brightness,
      Brightness.light,
    );
    expect(find.text('Trazabilidad por OP'), findsOneWidget);
    await tester.tap(find.byTooltip('Cambiar a vista oscura'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(CiclosPage))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
  for (final ancho in [390.0, 1366.0]) {
    testWidgets('Gerencia solo lectura y dashboard adaptable a $ancho', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final datos = DatosCiclos(
        [
          orden(),
          orden(
            op: 'COMPLETA',
            fines: [
              '2026-09-03',
              '2026-09-04',
              '2026-09-07',
              '2026-09-08',
              '2026-09-09',
              '2026-09-10',
              '2026-09-11',
            ],
          ),
        ],
        [],
        d('2026-10-06'),
        '0',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardAccesoProvider.overrideWithValue((
              '5',
              RolCuenta.gerencia,
            )),
            ciclosProvider.overrideWith((ref) async => datos),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const CiclosPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Importar históricos Excel'), findsNothing);
      expect(find.text('Parámetros'), findsNothing);
      expect(find.text('Tiempos de ciclo por proceso'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (ancho >= 1100) {
        expect(
          tester.getBottomRight(find.text('Ver desglose en Capacidad')).dy,
          lessThanOrEqualTo(768),
        );
      }
      await tester.scrollUntilVisible(find.text('P50'), 200);
      await tester.ensureVisible(find.text('P50').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('P50').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capacidad').first);
      await tester.pumpAndSettle();
      expect(find.text('Carga disponible y capacidad'), findsOneWidget);
      if (ancho >= 1100) {
        expect(
          tester.getBottomRight(find.text('Ver tendencia de capacidad')).dy,
          lessThanOrEqualTo(768),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Detalle por OP').first);
      await tester.pumpAndSettle();
      expect(find.text('Trazabilidad por OP'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scroll = find.byType(Scrollable).first;
      for (var n = 0; n < 15; n++) {
        await tester.drag(scroll, const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
