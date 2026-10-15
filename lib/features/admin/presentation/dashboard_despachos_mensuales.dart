import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Cada grupo cuenta despachos únicos por mes de salida, no prendas.
class DashboardDespachosMensuales extends StatelessWidget {
  const DashboardDespachosMensuales({
    super.key,
    required this.datos,
    this.claves = const ['total', 'sin_contratiempo', 'con_contratiempo'],
    this.nombres = const [
      'Total de despachos',
      'Sin contratiempo',
      'Con contratiempo',
    ],
  }) : assert(claves.length == 3 && nombres.length == 3);
  final List<Map<String, dynamic>> datos;
  final List<String> claves;
  final List<String> nombres;

  static List<Color> colores(BuildContext context) => [
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9ACDDD)
        : const Color(0xFF093E52),
    const Color(0xFF158568),
    const Color(0xFFBF6516),
  ];
  @override
  Widget build(BuildContext context) {
    final grupos = <DateTime, List<int>>{};
    for (final d in datos) {
      final mes = DateTime.parse(d['mes'] as String);
      grupos[mes] = [for (final k in claves) (d[k] as num).toInt()];
    }
    if (grupos.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('Sin despachos en este período.')),
      );
    }
    final maximo = grupos.values.expand((v) => v).fold<int>(1, math.max);
    final colores = DashboardDespachosMensuales.colores(context);
    return LayoutBuilder(
      builder:
          (context, c) => SizedBox(
            height: 145,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(c.maxWidth, grupos.length * 100.0),
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
                                            '${nombres[i]} · ${DateFormat('MM/yyyy').format(g.key)}: ${g.value[i]}',
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
                                                    g.value[i] / maximo * 95,
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
                              DateFormat('MM/yyyy').format(g.key),
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
