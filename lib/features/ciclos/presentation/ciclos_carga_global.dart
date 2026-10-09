import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/ciclos.dart';
import '../../../domain/ciclos_indicadores.dart';
import 'ciclos_colores.dart';

/// Distribución de carga por atender: nunca suma OP con unidades.
class CiclosCargaGlobal extends StatelessWidget {
  const CiclosCargaGlobal({
    super.key,
    required this.indicadores,
    required this.desde,
    required this.hasta,
    required this.fin,
    required this.semanal,
  });
  final IndicadoresCiclos indicadores;
  final DateTime desde, hasta, fin;
  final bool semanal;
  static const colores = [
    Color(0xff103d4c),
    Color(0xff287d91),
    Color(0xff65b7c8),
    Color(0xffeda633),
    Color(0xffaed6de),
  ];
  @override
  Widget build(BuildContext context) {
    final procesos = ProcesoCiclo.values.where((p) => !p.porOrdenes).toList();
    final cargas = {
      for (final p in ProcesoCiclo.values)
        p: CargaCiclo.calcular(indicadores.ordenes, p, desde, hasta).porAtender,
    };
    final capacidades = {
      for (final p in ProcesoCiclo.values)
        p: indicadores.capacidad(p, desde, fin, semanal: semanal),
    };
    final total = procesos.fold<int>(0, (n, p) => n + cargas[p]!);
    final comparables = procesos.every(
      (p) => capacidades[p] != null && capacidades[p]! > 0,
    );
    final capacidad = procesos.fold<int>(
      0,
      (n, p) => n + (capacidades[p] ?? 0),
    );
    final excedidos =
        ProcesoCiclo.values
            .where(
              (p) => capacidades[p] != null && cargas[p]! > capacidades[p]!,
            )
            .length;
    final exceso = procesos.fold<int>(
      0,
      (n, p) => n + math.max(0, cargas[p]! - (capacidades[p] ?? cargas[p]!)),
    );
    final mayor = procesos.reduce((a, b) => cargas[a]! >= cargas[b]! ? a : b);
    final fondo =
        CiclosColores.oscuro(context) ? CiclosColores.panel : Colors.white;
    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .25),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
    final dona = SizedBox(
      width: 170,
      height: 170,
      child: Semantics(
        label: 'Carga total: $total unidades por atender',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _Distribucion(
                  [for (final p in procesos) cargas[p]!.toDouble()],
                  colores,
                  Theme.of(context).dividerColor,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'unidades por atender',
                  style: TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 5),
                Text(
                  comparables && capacidad > 0
                      ? '${(total / capacidad).toStringAsFixed(1)}× la capacidad'
                      : 'Capacidad no comparable',
                  style: TextStyle(
                    fontSize: 10,
                    color: CiclosColores.error(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Carga total por proceso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Distribución de unidades por atender',
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 12),
        for (var n = 0; n < procesos.length; n++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.square, size: 9, color: colores[n]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    procesos[n].titulo,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${cargas[procesos[n]]} · ${total == 0 ? '0' : (100 * cargas[procesos[n]]! / total).toStringAsFixed(1)} %',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Compras: ${cargas[ProcesoCiclo.compras]} OP · Trazo: ${cargas[ProcesoCiclo.trazo]} OP. Se muestran aparte porque su unidad es diferente.',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
    final resumen = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$excedidos de 7 procesos sobre capacidad',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            comparables
                ? 'Exceso total: $exceso unidades'
                : 'Exceso conocido: $exceso unidades',
          ),
          const SizedBox(height: 8),
          Text(
            total == 0
                ? 'Sin carga en unidades'
                : 'Mayor carga: ${mayor.titulo} · ${(100 * cargas[mayor]! / total).toStringAsFixed(1)} %',
          ),
          const SizedBox(height: 12),
          const Text(
            'Verde: hasta 80 % · Ámbar: hasta 100 % · Rojo: capacidad excedida',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          const Text(
            'Carga = cola inicial + entradas. Puede incluir prendas que pasaron por varios procesos durante el período; no es inventario único.',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final distribucion = panel(
          LayoutBuilder(
            builder:
                (context, b) =>
                    b.maxWidth < 460
                        ? Column(
                          children: [dona, const SizedBox(height: 16), leyenda],
                        )
                        : Row(
                          children: [
                            dona,
                            const SizedBox(width: 20),
                            Expanded(child: leyenda),
                          ],
                        ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child:
              c.maxWidth >= 850
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: distribucion),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: resumen),
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      distribucion,
                      const SizedBox(height: 12),
                      resumen,
                    ],
                  ),
        );
      },
    );
  }
}

class _Distribucion extends CustomPainter {
  _Distribucion(this.valores, this.colores, this.vacio);
  final List<double> valores;
  final List<Color> colores;
  final Color vacio;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.shortestSide - 24,
      height: size.shortestSide - 24,
    );
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = vacio.withValues(alpha: .2),
    );
    final total = valores.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var inicio = -math.pi / 2;
    for (var n = 0; n < valores.length; n++) {
      final arco = valores[n] / total * math.pi * 2;
      canvas.drawArc(rect, inicio, arco, false, paint..color = colores[n]);
      inicio += arco;
    }
  }

  @override
  bool shouldRepaint(covariant _Distribucion old) => true;
}
