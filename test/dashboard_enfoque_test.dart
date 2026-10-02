import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/dashboard_enfoque.dart';
import 'package:orbiloq_wms/core/theme/app_theme.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_enfoque_section.dart';

void main() {
  final corte = DateTime.utc(2026, 10, 2, 17);
  test(
    'Fechas por etapa, OP distintas y líneas eliminadas al corte Bogotá',
    () {
      ItemKardex linea(
        String id, {
        bool eliminada = false,
        int producido = 0,
      }) => ItemKardex(
        eliminada: eliminada,
        item: ItemOrden(
          id: id,
          op: 'OP1',
          cliente: 'A',
          oc: 'OC1',
          codigo: id,
          descripcion: 'Prenda',
          talla: 'M',
          cantidadPedida: 10,
        ),
        producido: producido,
        recibido: 0,
        despachado: 0,
        ubicaciones: {},
        fechaEsperadaProduccion: DateTime(2026, 10, 1),
        fechaEsperadaLogistica: DateTime(2026, 10, 5),
      );
      final c =
          saludClientes(
            [linea('1'), linea('2')],
            [],
            [],
            corte: corte,
            semanas: 4,
          ).single;
      expect(c.activas, {'OP1'});
      expect(c.vencidas, {'OP1'});
      expect(c.proximas, {'OP1'});
      expect(c.nivel, 2);
      final completada =
          saludClientes(
            [linea('1', producido: 10)],
            [],
            [],
            corte: corte,
            semanas: 4,
          ).single;
      expect(completada.vencidas, isEmpty);
      expect(
        saludClientes(
          [linea('1', eliminada: true)],
          [],
          [],
          corte: corte,
          semanas: 4,
        ),
        isEmpty,
      );
      // 02:00 UTC del día 2 sigue siendo el día 1 en Bogotá.
      final local =
          saludClientes(
            [linea('1')],
            [],
            [],
            corte: DateTime.utc(2026, 10, 2, 2),
            semanas: 4,
          ).single;
      expect(local.vencidas, isEmpty);
    },
  );
  test('Volumen respeta período, correcciones y cantidad operativa', () {
    final datos = volumenClientes(
      [
        {
          'cliente': 'A',
          'tipo': 'despacho',
          'fecha': '2026-09-30T12:00:00Z',
          'cantidad': 8,
        },
        {
          'cliente': 'B',
          'tipo': 'despacho',
          'fecha': '2026-09-30T12:00:00Z',
          'cantidad': 20,
        },
        {
          'cliente': 'A',
          'tipo': 'despacho',
          'fecha': '2026-09-30T12:00:00Z',
          'cantidad': 99,
          'datos_crudos': {'admin_correccion_id': 'a'},
        },
        {
          'cliente': 'A',
          'tipo': 'despacho',
          'fecha': '2026-01-01T12:00:00Z',
          'cantidad': 99,
        },
        {
          'cliente': 'A',
          'tipo': 'despacho',
          'fecha': '2026-10-03T12:00:00Z',
          'cantidad': 99,
        },
      ],
      corte: corte,
      semanas: 4,
    );
    expect(datos.keys.toList(), ['B', 'A']);
    expect(datos['A'], 8);
  });
  test(
    'Causales deduplica y compara últimas cuatro semanas con todo el histórico',
    () {
      final fila = {
        'registro': 'a',
        'causal': 'Tela',
        'fecha': '2026-09-30T12:00:00Z',
        'cantidad': 5,
      };
      final datos = compararCausales([
        fila,
        fila,
        {
          'registro': 'b',
          'causal': 'Tela',
          'fecha': '2025-09-30T12:00:00Z',
          'cantidad': 10,
        },
      ], corte);
      expect(datos.single.recientes, 5);
      expect(datos.single.historico, 15);
    },
  );
  test('Salud incluye todos los clientes y distingue ausencia de base', () {
    final datos = saludClientes(
      [],
      [
        for (var i = 0; i < 15; i++)
          {
            'cliente': 'Cliente $i',
            'tipo': 'despacho',
            'fecha': '2026-09-30T12:00:00Z',
            'cantidad': 5,
          },
      ],
      [],
      corte: corte,
      semanas: 4,
    );
    expect(datos, hasLength(15));
    expect(datos.every((c) => c.nivel == 1 && c.tasa == null), isTrue);
    final c = SaludCliente('A')..entregado = 100;
    expect(c.nivel, 0);
    c.noConforme = 3;
    expect(c.nivel, 1);
    c.noConforme = 6;
    expect(c.nivel, 2);
    c.noConforme = 0;
    c.vencidas.add('OP1');
    expect(c.nivel, 2);
  });
  for (final modo in TemaModo.values) {
    for (final ancho in [320.0, 768.0, 1440.0]) {
      testWidgets(
        'Todos los clientes buscables y gráficos sin overflow $modo $ancho',
        (tester) async {
          tester.view.physicalSize = Size(ancho, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final datos = [
            for (var i = 1; i <= 15; i++)
              SaludCliente('Cliente $i')..entregado = 100,
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.kardex(modo),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      BarrasCausales(
                        datos: [
                          CausalComparada('Costura')
                            ..historico = 100
                            ..recientes = 10,
                          CausalComparada('Talla')
                            ..historico = 40
                            ..recientes = 20,
                        ],
                      ),
                      TablaSaludClientes(datos: datos),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(find.byType(TextField), 'Cliente 15');
          await tester.pumpAndSettle();
          expect(find.text('Cliente 15'), findsWidgets);
          expect(find.text('Cliente 1'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
