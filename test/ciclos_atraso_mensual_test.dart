import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/domain/ciclos.dart';
import 'package:orbiloq_wms/domain/ciclos_indicadores.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/ciclos_resumen_compacto.dart';
import 'package:orbiloq_wms/features/ciclos/presentation/grafica_intercambiable.dart';

void main() {
  final parametros = [
    for (final p in ProcesoCiclo.values)
      ParametroCiclo(p.name, p, DateTime.utc(2026, 1), 1, null, null),
  ];
  OrdenCiclo op(String id, int fin, {bool meta = true, String cliente = 'A'}) =>
      OrdenCiclo(
        id,
        cliente,
        10,
        DateTime.utc(2026, 9, 1),
        List.filled(7, DateTime.utc(2026, 9, fin)),
        meta ? {for (final p in ProcesoCiclo.values) p.name: p.name} : {},
      );
  final datos = DatosCiclos(
    [
      op('puntual', 15),
      op('tarde2', 17),
      op('tarde4', 21),
      op('sinmeta', 25, meta: false),
      op('otro', 25, cliente: 'B'),
      op('futura', 30),
    ],
    parametros,
    DateTime.utc(2026, 9, 28),
    '0',
  );
  test(
    'Promedio usa solo tardías evaluables, respeta filtros y comparte meta con cumplimiento',
    () {
      final i = IndicadoresCiclos(datos, cliente: 'A');
      expect(i.atrasosTerminadas, [2, 4]);
      expect(i.atrasoPromedioTerminadas, 3);
      expect(i.excesoPromedioPorcentaje, 30);
      expect(i.cumplimientoTotal, closeTo(100 / 3, .0001));
      final puntual = IndicadoresCiclos(
        datos,
        cliente: 'A',
        hasta: DateTime.utc(2026, 9, 15),
      );
      expect(puntual.atrasoPromedioTerminadas, isNull);
      expect(puntual.excesoPromedioPorcentaje, isNull);
      expect(puntual.cumplimientoTotal, 100);
      expect(
        IndicadoresCiclos(datos, cliente: 'C').atrasoPromedioTerminadas,
        isNull,
      );
    },
  );
  test(
    'Exceso usa la meta de cada OP y admite valores superiores al 100 %',
    () {
      final otrasMetas = [
        for (final p in ProcesoCiclo.values)
          ParametroCiclo(
            'otra-${p.name}',
            p,
            DateTime.utc(2026, 1),
            2,
            null,
            null,
          ),
      ];
      final normal = op('normal', 25);
      final otra = OrdenCiclo('otra', 'A', 100, normal.inicio, normal.fines, {
        for (final p in ProcesoCiclo.values) p.name: 'otra-${p.name}',
      });
      final mezcla = IndicadoresCiclos(
        DatosCiclos(
          [normal, otra],
          [...parametros, ...otrasMetas],
          DateTime.utc(2026, 10, 1),
          '0',
        ),
      );
      expect(
        mezcla.excesoPromedioPorcentaje,
        closeTo((80 + 100 / 17) / 2, .000001),
      );
      final muyTarde = OrdenCiclo(
        'larga',
        'A',
        1,
        DateTime.utc(2026, 8, 1),
        List.filled(7, DateTime.utc(2026, 9, 25)),
        normal.versiones,
      );
      expect(
        IndicadoresCiclos(
          DatosCiclos([muyTarde], parametros, DateTime.utc(2026, 10, 1), '0'),
        ).excesoPromedioPorcentaje,
        greaterThan(100),
      );
    },
  );
  testWidgets(
    'Gráficas mensuales muestran exceso porcentual y cumplimiento, con muestra visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CiclosResumenCompacto(
                indicadores: IndicadoresCiclos(datos, cliente: 'A'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final graficas = tester.widgetList<GraficaIntercambiable>(
        find.byType(GraficaIntercambiable),
      );
      final atraso = graficas.firstWhere(
        (g) => g.titulo == 'Exceso promedio del plazo (%)',
      );
      expect(atraso.datos.valores, [30.0]);
      expect(atraso.datos.etiquetas.single, contains('2 OP tardías'));
      expect(atraso.datos.porcentaje, isTrue);
      expect(
        graficas
            .firstWhere((g) => g.titulo == 'Cumplimiento por mes')
            .datos
            .porcentaje,
        isTrue,
      );
      expect(find.text('Ciclo total por mes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
