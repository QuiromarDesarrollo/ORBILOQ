import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'ciclos_colores.dart';

enum TipoGrafica { barras, columnas, lineas, area, dona }

class DatosGrafica {
  const DatosGrafica(
    this.etiquetas,
    this.valores, {
    this.metas = const [],
    this.unidad = '',
    this.porcentaje = false,
  });
  final List<String> etiquetas;
  final List<double?> valores, metas;
  final String unidad;
  final bool porcentaje;
}

/// Las donas son indicadores individuales: no suman porcentajes ni percentiles.
class GraficaIntercambiable extends StatefulWidget {
  const GraficaIntercambiable({
    super.key,
    required this.datos,
    required this.original,
    required this.titulo,
    this.ayuda,
    this.inicial,
    this.altura = 150,
    this.controles,
  });
  final DatosGrafica datos;
  final Widget original;
  final String titulo;
  final String? ayuda;
  final TipoGrafica? inicial;
  final double altura;
  final Widget? controles;
  @override
  State<GraficaIntercambiable> createState() => _GraficaState();
}

class _GraficaState extends State<GraficaIntercambiable> {
  TipoGrafica? tipo;
  @override
  void initState() {
    super.initState();
    tipo = widget.inicial;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    final maximo = [
      ...d.valores,
      ...d.metas,
      if (d.porcentaje) 100.0,
    ].whereType<double>().fold<double>(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.ayuda != null)
              Tooltip(
                message: widget.ayuda!,
                child: const Icon(Icons.help_outline, size: 16),
              ),
            SizedBox(
              width: 30,
              height: 28,
              child: PopupMenuButton<String>(
                tooltip: 'Tipo de gráfica: ${widget.titulo}',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.bar_chart, size: 20),
                onSelected:
                    (v) => setState(
                      () =>
                          tipo =
                              v == 'original'
                                  ? null
                                  : TipoGrafica.values.byName(v),
                    ),
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'original',
                        child: Text('Vista inicial'),
                      ),
                      for (final t in TipoGrafica.values)
                        PopupMenuItem(
                          value: t.name,
                          child: Text(nombres[t.index]),
                        ),
                    ],
              ),
            ),
          ],
        ),
        if (tipo != null && widget.controles != null) widget.controles!,
        if (tipo == null)
          widget.original
        else if (d.valores.whereType<double>().isEmpty)
          SizedBox(
            height: widget.altura,
            child: Center(child: Text('Sin datos para el filtro')),
          )
        else ...[
          Text(
            tipo == TipoGrafica.dona
                ? 'Indicadores individuales · ${d.unidad}'
                : '${d.unidad} · escala desde 0',
            style: const TextStyle(fontSize: 10),
          ),
          SizedBox(
            height: widget.altura,
            child: CustomPaint(
              painter: _Pintor(
                d,
                tipo!,
                maximo,
                Theme.of(context).colorScheme.onSurface,
                List.filled(7, CiclosColores.bien(context)),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              for (var n = 0; n < d.etiquetas.length; n++)
                Tooltip(
                  message:
                      '${d.etiquetas[n]}: ${d.valores[n]?.toStringAsFixed(1) ?? "Sin datos"} ${d.unidad}${n < d.metas.length ? " · Meta: ${d.metas[n]?.toStringAsFixed(1) ?? "Sin configurar"}" : ""}',
                  child: Text(
                    '${n + 1}. ${d.etiquetas[n]}: ${d.valores[n]?.toStringAsFixed(1) ?? "—"}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (d.metas.isNotEmpty)
            const Text(
              'Marca blanca/oscura = meta · — = sin datos',
              style: TextStyle(fontSize: 10),
            ),
        ],
      ],
    );
  }

  static const nombres = [
    'Barras horizontales',
    'Columnas',
    'Líneas',
    'Área',
    'Donas',
  ];
}

class _Pintor extends CustomPainter {
  _Pintor(this.d, this.tipo, this.maximo, this.texto, this.paleta);
  final List<Color> paleta;
  final DatosGrafica d;
  final TipoGrafica tipo;
  final double maximo;
  final Color texto;
  void label(Canvas c, String s, Offset p, {double size = 10}) {
    final t = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: texto, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, p);
  }

  @override
  void paint(Canvas c, Size s) {
    final n = d.valores.length;
    if (n == 0) {
      return;
    }
    final paint = Paint();
    final w = s.width - 30, h = s.height - (s.height > 220 ? 70 : 26);
    if (tipo == TipoGrafica.dona) {
      final cell = s.width / n;
      final radius = math.min(cell / 2 - 4, 28.0);
      for (var j = 0; j < n; j++) {
        final center = Offset(cell * (j + .5), 65), v = d.valores[j];
        final rect = Rect.fromCircle(center: center, radius: radius);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = texto.withValues(alpha: .12);
        c.drawOval(rect, paint);
        if (v != null) {
          paint.color = paleta[j % 7];
          c.drawArc(
            rect,
            -math.pi / 2,
            2 * math.pi * (v / maximo).clamp(0, 1),
            false,
            paint,
          );
        }
        if (j < d.metas.length && d.metas[j] != null) {
          final angle = -math.pi / 2 + 2 * math.pi * d.metas[j]! / maximo;
          final direction = Offset(math.cos(angle), math.sin(angle));
          paint
            ..color = texto
            ..strokeWidth = 2;
          c.drawLine(
            center + direction * (radius - 5),
            center + direction * (radius + 5),
            paint,
          );
        }
        label(c, '${j + 1}', center - const Offset(3, 6));
        label(
          c,
          v == null ? '—' : v.toStringAsFixed(1),
          Offset(cell * j + 4, 105),
        );
      }
      label(
        c,
        'Anillo completo = ${maximo.toStringAsFixed(1)} ${d.unidad}',
        const Offset(0, 132),
      );
      return;
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = texto.withValues(alpha: .12);
    for (var k = 0; k <= 2; k++) {
      final y = 8 + h * k / 2;
      c.drawLine(Offset(28, y), Offset(s.width, y), paint);
    }
    if (tipo == TipoGrafica.barras) {
      final step = h / n;
      for (var j = 0; j < n; j++) {
        final y = 8 + j * step, v = d.valores[j];
        label(c, '${j + 1}', Offset(0, y));
        if (v != null) {
          paint
            ..style = PaintingStyle.fill
            ..color = paleta[j % 7];
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(28, y, w * v / maximo, math.max(3, step - 5)),
              const Radius.circular(3),
            ),
            paint,
          );
        }
        if (j < d.metas.length && d.metas[j] != null) {
          final x = 28 + w * d.metas[j]! / maximo;
          paint
            ..color = texto
            ..strokeWidth = 2;
          c.drawLine(Offset(x, y), Offset(x, y + step - 4), paint);
        }
      }
      return;
    }
    label(c, maximo.toStringAsFixed(0), Offset.zero);
    label(c, '0', Offset(0, h));
    final step = w / n;
    Offset point(int j, double v) =>
        Offset(28 + step * (j + .5), 8 + h * (1 - v / maximo));
    Offset? previous;
    for (var j = 0; j < n; j++) {
      final v = d.valores[j];
      if (s.height > 220) {
        c.save();
        c.translate(28 + step * (j + .5) - 12, h + 38);
        c.rotate(-math.pi / 5);
        label(c, d.etiquetas[j], Offset.zero);
        c.restore();
      } else {
        label(c, '${j + 1}', Offset(28 + step * (j + .5) - 3, h + 12));
      }
      if (v == null) {
        previous = null;
        continue;
      }
      final p = point(j, v);
      paint
        ..style = PaintingStyle.fill
        ..color = paleta[j % 7];
      if (tipo == TipoGrafica.columnas) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(p.dx - step * .3, p.dy, step * .6, 8 + h - p.dy),
            const Radius.circular(3),
          ),
          paint,
        );
      } else {
        if (previous != null) {
          if (tipo == TipoGrafica.area) {
            final path =
                Path()
                  ..moveTo(previous.dx, 8 + h)
                  ..lineTo(previous.dx, previous.dy)
                  ..lineTo(p.dx, p.dy)
                  ..lineTo(p.dx, 8 + h)
                  ..close();
            paint.color = paleta[0].withValues(alpha: .25);
            c.drawPath(path, paint);
          }
          paint
            ..color = paleta[0]
            ..strokeWidth = 2;
          c.drawLine(previous, p, paint);
        }
        paint.color = paleta[j % 7];
        c.drawCircle(p, 4, paint);
        previous = p;
      }
      if (j < d.metas.length && d.metas[j] != null) {
        final target = point(j, d.metas[j]!);
        paint
          ..color = texto
          ..strokeWidth = 2;
        c.drawLine(
          target - const Offset(5, 0),
          target + const Offset(5, 0),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Pintor old) => true;
}
