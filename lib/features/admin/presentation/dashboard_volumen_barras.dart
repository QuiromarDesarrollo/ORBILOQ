import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../application/dashboard_tendencias.dart';

/// Agrega los mismos días filtrados; cambiar la escala no cambia los totales.
class DashboardVolumenBarras extends StatelessWidget {
  const DashboardVolumenBarras({
    super.key,
    required this.datos,
    required this.porSemana,
  });
  final List<SemanaVolumen> datos;
  final bool porSemana;

  static List<Color> colores(BuildContext context) => [
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9ACDDD)
        : const Color(0xFF093E52),
    const Color(0xFF4EA4BF),
    const Color(0xFF91A500),
  ];
  @override
  Widget build(BuildContext context) {
    final grupos = <DateTime, List<int>>{};
    for (final d in datos) {
      final fecha =
          porSemana
              ? d.inicio.subtract(Duration(days: d.inicio.weekday - 1))
              : d.inicio;
      final valores = grupos.putIfAbsent(fecha, () => [0, 0, 0]);
      for (var i = 0; i < 3; i++) {
        valores[i] += d.unidades[i];
      }
    }
    if (grupos.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('Sin movimientos en este período.')),
      );
    }
    final maximo = grupos.values.expand((v) => v).fold<int>(1, math.max);
    final colores = DashboardVolumenBarras.colores(context);
    const nombres = ['Entregado', 'Recibido', 'Despachado'];
    return LayoutBuilder(
      builder:
          (context, c) => SizedBox(
            height: 160,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(c.maxWidth, grupos.length * 65.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final g in grupos.entries)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Flexible(
                                      child: Tooltip(
                                        message:
                                            '${nombres[i]} · ${DateFormat('dd/MM').format(g.key)}: ${g.value[i]}',
                                        child: Semantics(
                                          label: '${nombres[i]}: ${g.value[i]}',
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${g.value[i]}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                  ),
                                                ),
                                                Container(
                                                  width: 15,
                                                  height: math.max(
                                                    1,
                                                    g.value[i] / maximo * 110,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colores[i],
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            3,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(height: 8),
                            Text(
                              DateFormat('dd MMM').format(g.key),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
