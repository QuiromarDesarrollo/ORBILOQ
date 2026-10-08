import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ciclos_colores.dart';

const coloresCiclos = [Color(0xff38bdf8), Color(0xffa78bfa), Color(0xfffbbf24)];

class BarrasCiclos extends StatelessWidget {
  const BarrasCiclos({
    super.key,
    required this.etiquetas,
    required this.series,
    required this.nombres,
    this.porcentaje = false,
  });
  final List<String> etiquetas, nombres;
  final List<List<double?>> series;
  final bool porcentaje;
  @override
  Widget build(BuildContext context) {
    final colores =
        CiclosColores.oscuro(context)
            ? coloresCiclos
            : const [Color(0xff24476a), Color(0xff497d80), Color(0xffa37832)];
    final maximo =
        porcentaje
            ? 100.0
            : math.max(
              1.0,
              series
                  .expand((s) => s)
                  .whereType<double>()
                  .fold<double>(0, math.max),
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          children: [
            for (var i = 0; i < nombres.length; i++)
              Text('● ${nombres[i]}', style: TextStyle(color: colores[i])),
          ],
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < etiquetas.length; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiquetas[r]),
                for (var s = 0; s < series.length; s++)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder:
                                (context, c) => Stack(
                                  children: [
                                    Container(
                                      height: 10,
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: .12),
                                    ),
                                    Container(
                                      height: 10,
                                      width:
                                          c.maxWidth *
                                          ((series[s][r] ?? 0) / maximo).clamp(
                                            0,
                                            1,
                                          ),
                                      color: colores[s],
                                    ),
                                    if (porcentaje)
                                      Positioned(
                                        left: c.maxWidth * .85,
                                        child: Container(
                                          width: 2,
                                          height: 10,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            series[s][r] == null
                                ? ' —'
                                : ' ${series[s][r]!.toStringAsFixed(1)}${porcentaje ? '%' : ''}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (porcentaje)
          const Text('Línea de referencia: 85 %. — = sin datos evaluables.'),
      ],
    );
  }
}

class LineasCiclos extends StatelessWidget {
  const LineasCiclos({
    super.key,
    required this.etiquetas,
    required this.series,
    required this.nombres,
  });
  final List<String> etiquetas, nombres;
  final List<List<double?>> series;
  @override
  Widget build(BuildContext context) {
    final colores =
        CiclosColores.oscuro(context)
            ? coloresCiclos
            : const [Color(0xff24476a), Color(0xff497d80), Color(0xffa37832)];
    final maximo = math.max(
      1.0,
      series.expand((s) => s).whereType<double>().fold<double>(0, math.max),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          children: [
            for (var i = 0; i < nombres.length; i++)
              Text('● ${nombres[i]}', style: TextStyle(color: colores[i])),
          ],
        ),
        const SizedBox(height: 12),
        Text('Escala: 0–${maximo.ceil()}'),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _Lineas(
              series,
              maximo,
              Theme.of(context).dividerColor,
              colores,
            ),
          ),
        ),
        // Valores accesibles: también explican los huecos sin muestra.
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            for (var r = 0; r < etiquetas.length; r++)
              Text(
                '${etiquetas[r]}: ${[for (final s in series) s[r]?.toStringAsFixed(1) ?? '—'].join(' / ')}',
              ),
          ],
        ),
      ],
    );
  }
}

class _Lineas extends CustomPainter {
  _Lineas(this.series, this.maximo, this.eje, this.colores);
  final List<Color> colores;
  final List<List<double?>> series;
  final double maximo;
  final Color eje;
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = eje
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(4, size.height - 10),
      Offset(size.width - 4, size.height - 10),
      paint,
    );
    for (var i = 0; i < series.length; i++) {
      final lista = series[i];
      Offset? anterior;
      paint
        ..color = colores[i]
        ..strokeWidth = 2;
      for (var j = 0; j < lista.length; j++) {
        if (lista[j] == null) {
          anterior = null;
          continue;
        }
        final punto = Offset(
          6 + (size.width - 12) * j / math.max(1, lista.length - 1),
          size.height - 10 - (size.height - 20) * lista[j]! / maximo,
        );
        if (anterior != null) canvas.drawLine(anterior, punto, paint);
        canvas.drawCircle(punto, 3, paint);
        anterior = punto;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Lineas oldDelegate) => true;
}
