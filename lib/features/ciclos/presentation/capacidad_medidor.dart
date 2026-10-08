import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ciclos_colores.dart';

class CapacidadMedidor extends StatelessWidget {
  const CapacidadMedidor({
    super.key,
    required this.porcentaje,
    this.compacto = false,
  });
  final double? porcentaje;
  final bool compacto;
  @override
  Widget build(BuildContext context) {
    final valor = porcentaje;
    final color =
        valor == null
            ? CiclosColores.neutro(context)
            : valor <= 80
            ? CiclosColores.bien(context)
            : valor <= 100
            ? CiclosColores.alerta(context)
            : CiclosColores.error(context);
    return Semantics(
      label:
          valor == null
              ? 'Capacidad sin dato comparable'
              : 'Carga sobre capacidad: ${valor.toStringAsFixed(1)} por ciento',
      child: Column(
        children: [
          SizedBox(
            height: compacto ? 80 : 124,
            width: compacto ? 144 : 224,
            child: FittedBox(
              child: SizedBox(
                width: 224,
                height: 124,
                child: CustomPaint(
                  painter: _Reloj(valor, [
                    CiclosColores.bien(context),
                    CiclosColores.alerta(context),
                    CiclosColores.error(context),
                  ], Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ),
          ),
          Text(
            valor == null
                ? (compacto ? '—' : 'Sin comparación')
                : '${valor.toStringAsFixed(1)} %',
            style: TextStyle(
              fontSize: compacto ? 21 : 26,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor == null
                ? (compacto
                    ? 'Sin referencia'
                    : 'Falta capacidad o día no hábil')
                : valor <= 80
                ? 'Dentro de capacidad'
                : valor <= 100
                ? 'Próximo al límite'
                : 'Capacidad excedida',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _Reloj extends CustomPainter {
  _Reloj(this.valor, this.colores, this.texto);
  final double? valor;
  final List<Color> colores;
  final Color texto;
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, 106),
        radio = math.min(size.width / 2 - 25, 82.0);
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final pincel =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.butt;
    final disco =
        Paint()
          ..shader = RadialGradient(
            colors: [
              texto.withValues(alpha: .07),
              texto.withValues(alpha: .015),
            ],
          ).createShader(rect);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio - 13),
      math.pi,
      math.pi,
      true,
      disco,
    );
    final exterior =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = texto.withValues(alpha: .12);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio + 7),
      math.pi,
      math.pi,
      false,
      exterior,
    );
    for (var n = 0; n <= 100; n += 5) {
      final a = math.pi + math.pi * n / 100,
          v = Offset(math.cos(a), math.sin(a));
      exterior
        ..color = texto.withValues(alpha: n % 25 == 0 ? .5 : .2)
        ..strokeWidth = n % 25 == 0 ? 1.5 : 1;
      canvas.drawLine(
        centro + v * (radio - 11),
        centro + v * (radio - (n % 25 == 0 ? 20 : 15)),
        exterior,
      );
    }
    if (valor == null) {
      pincel.color = texto.withValues(alpha: .15);
      canvas.drawArc(rect, math.pi, math.pi, false, pincel);
    } else {
      for (final tramo in [(0.0, .8, colores[0]), (.8, 1.0, colores[1])]) {
        pincel.color = tramo.$3.withValues(alpha: .9);
        canvas.drawArc(
          rect,
          math.pi + math.pi * tramo.$1,
          math.pi * (tramo.$2 - tramo.$1),
          false,
          pincel,
        );
      }
      if (valor! > 100) {
        pincel.color = colores[2];
        canvas.drawArc(rect, math.pi * 1.96, math.pi * .04, false, pincel);
      }
    }
    for (final n in [0, 50, 80, 100]) {
      final angulo = math.pi + math.pi * n / 100,
          vector = Offset(math.cos(angulo), math.sin(angulo));
      pincel
        ..color = texto.withValues(alpha: .5)
        ..strokeWidth = 1;
      canvas.drawLine(
        centro + vector * (radio - 9),
        centro + vector * (radio - 15),
        pincel,
      );
      final t = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(fontSize: 10, color: texto),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = centro + vector * (radio + 16);
      t.paint(canvas, pos - Offset(t.width / 2, t.height / 2));
    }
    if (valor != null) {
      final angulo = math.pi + math.pi * (valor! / 100).clamp(0, 1),
          vector = Offset(math.cos(angulo), math.sin(angulo));
      pincel
        ..color = valor! > 100 ? colores[2] : texto
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        centro - vector * 7,
        centro + vector * (radio - 20),
        pincel,
      );
      pincel.style = PaintingStyle.fill;
      pincel.color = texto.withValues(alpha: .12);
      canvas.drawCircle(centro, 9, pincel);
      pincel.color = valor! > 100 ? colores[2] : texto;
      canvas.drawCircle(centro, 5, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _Reloj old) =>
      old.valor != valor || old.texto != texto;
}
