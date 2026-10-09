import 'dart:math' as math;
import 'package:flutter/material.dart';

enum OrbiloqLoaderMode { orbit, bounce, progress, mini }

/// Adaptación nativa del SVG Orbiloq proporcionado: sin WebViews ni dependencias.
class WmsLoader extends StatefulWidget {
  const WmsLoader({
    super.key,
    this.color,
    this.strokeWidth = 2.5,
    this.mode = OrbiloqLoaderMode.mini,
    this.width = 56,
    this.value,
  });
  // Compatibilidad con llamadas anteriores; el logo conserva sus colores.
  final Color? color;
  final double strokeWidth;
  final OrbiloqLoaderMode mode;
  final double width;
  final double? value;
  @override
  State<WmsLoader> createState() => _WmsLoaderState();
}

class _WmsLoaderState extends State<WmsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  _DialogLoadingHostState? _host;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host =
        context.dependOnInheritedWidgetOfExactType<_DialogLoadingScope>()?.host;
    if (_host != host) {
      _host?.remove(this);
      _host = host;
      _host?.add(this);
    }
    if (_host != null ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _host?.remove(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_host != null) return const SizedBox.shrink();
    final progress = widget.value?.clamp(0.0, 1.0);
    final mini = widget.mode == OrbiloqLoaderMode.mini;
    final ratio = mini ? 376 / 236 : 400 / (progress == null ? 360 : 398);
    return Semantics(
      label: 'Cargando',
      value: progress == null ? null : '${(progress * 100).round()}%',
      child: SizedBox(
        width: widget.width,
        height: widget.width / ratio,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _OrbiloqPainter(
              _clock,
              widget.mode,
              progress,
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class WmsLoadingStrip extends StatelessWidget {
  const WmsLoadingStrip({super.key, this.label = 'Cargando…', this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WmsLoader(
          mode:
              value == null
                  ? OrbiloqLoaderMode.bounce
                  : OrbiloqLoaderMode.progress,
          width: value == null ? 88 : 156,
          value: value,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class WmsLoadingPanel extends StatelessWidget {
  const WmsLoadingPanel({super.key, this.label = 'Cargando…', this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WmsLoader(
            mode:
                value == null
                    ? OrbiloqLoaderMode.orbit
                    : OrbiloqLoaderMode.progress,
            width: math.min(260, MediaQuery.sizeOf(context).width * .6),
            value: value,
          ),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _OrbiloqPainter extends CustomPainter {
  _OrbiloqPainter(this.clock, this.mode, this.progress, this.dark)
    : super(repaint: clock);
  final Animation<double> clock;
  final OrbiloqLoaderMode mode;
  final double? progress;
  final bool dark;
  static const blue = Color(0xFF1F5C8B), green = Color(0xFF7ED957);
  Paint fill(Color c) => Paint()..color = c;
  void text(
    Canvas c,
    String text,
    double x,
    double y,
    double size, {
    double spacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: dark ? const Color(0xFFB5DBF3) : blue,
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: spacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height));
  }

  @override
  void paint(Canvas c, Size size) {
    final mini = mode == OrbiloqLoaderMode.mini;
    final vb =
        mini
            ? const Rect.fromLTWH(12, 88, 376, 236)
            : Rect.fromLTWH(0, 8, 400, progress == null ? 360 : 398);
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    c.save();
    c.translate(
      (size.width - vb.width * scale) / 2,
      (size.height - vb.height * scale) / 2,
    );
    c.scale(scale);
    c.translate(-vb.left, -vb.top);
    if (!mini) {
      const word = 'ORBILOQ';
      for (var i = 0; i < word.length; i++) {
        final a = -math.pi / 2 + (i - 3) * .22;
        c.save();
        c.translate(200 + 130 * math.cos(a), 200 + 130 * math.sin(a));
        c.rotate(a + math.pi / 2);
        text(c, word[i], 0, 0, 30);
        c.restore();
      }
    }
    final t =
        (mode == OrbiloqLoaderMode.orbit || mini)
            ? math.pi * .9 - clock.value * 2 * math.pi
            : math.pi * .32;
    final front = math.sin(t) >= 0;
    ring(c, false);
    if (!front) vehicle(c, t);
    c.drawCircle(const Offset(200, 200), 110, fill(green));
    c.save();
    c.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(200, 200), radius: 110)),
    );
    final stroke =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..moveTo(70, 178)
        ..quadraticBezierTo(180, 112, 330, 118),
      stroke..strokeWidth = 6,
    );
    c.drawPath(
      Path()
        ..moveTo(60, 300)
        ..quadraticBezierTo(190, 232, 335, 206),
      stroke..strokeWidth = 10,
    );
    c.drawPath(
      Path()
        ..moveTo(88, 342)
        ..quadraticBezierTo(200, 272, 335, 250),
      stroke,
    );
    c.drawPath(
      Path()
        ..moveTo(150, 362)
        ..quadraticBezierTo(240, 302, 335, 292),
      stroke,
    );
    c.restore();
    ring(c, true);
    if (front) vehicle(c, t);
    if (!mini) text(c, 'BY QUIROMAR', 200, 357, 24, spacing: 6);
    if (progress != null) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(60, 374, 230, 12),
          const Radius.circular(6),
        ),
        fill(blue.withValues(alpha: .18)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(60, 374, 230 * progress!, 12),
          const Radius.circular(6),
        ),
        fill(green),
      );
      text(c, '${(progress! * 100).round()}%', 340, 391, 18);
    }
    c.restore();
  }

  void ring(Canvas c, bool front) {
    c.save();
    c.translate(200, 218);
    c.rotate(-math.pi / 12);
    const outer = 52.0;
    final inner = front ? 36.0 : 46.0;
    final p = Path()..moveTo(-185, 0);
    for (var i = 0; i <= 60; i++) {
      final a = math.pi - i * math.pi / 60;
      p.lineTo(185 * math.cos(a), (front ? 1 : -1) * outer * math.sin(a));
    }
    for (var i = 0; i <= 60; i++) {
      final a = i * math.pi / 60;
      p.lineTo(185 * math.cos(a), (front ? 1 : -1) * inner * math.sin(a));
    }
    p.close();
    c.drawPath(p, fill(blue));
    c.restore();
  }

  void vehicle(Canvas c, double t) {
    final ry = math.sin(t) >= 0 ? 36.0 : 52.0;
    final vx = 185 * math.sin(t),
        vy = -ry * math.cos(t),
        sign = vx >= 0 ? 1.0 : -1.0;
    final k = math.min(1.0, vx.abs() / (185 * .35));
    final orbit =
        mode == OrbiloqLoaderMode.orbit || mode == OrbiloqLoaderMode.mini;
    c.save();
    c.translate(200, 218);
    c.rotate(-math.pi / 12);
    c.translate(185 * math.cos(t), ry * math.sin(t));
    c.rotate(math.atan2(vy * sign, vx.abs()) * k);
    final s = orbit ? 0.8 + 0.2 * math.sin(t) : 1.0;
    c.scale(orbit ? sign * math.max(.12, k) * s : 1, s);
    c.translate(
      0,
      -12 - (orbit ? 0 : math.sin(clock.value * 3.4 * 7).abs() * 3),
    );
    final line =
        Paint()
          ..color = blue.withValues(alpha: .6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      c.drawLine(
        Offset(-66.0 - i * 4, -30.0 + i * 9),
        Offset(-46, -30.0 + i * 9),
        line,
      );
    }
    final body =
        Path()
          ..moveTo(-34, -9)
          ..lineTo(-34, -33)
          ..quadraticBezierTo(-34, -38, -29, -38)
          ..lineTo(13, -38)
          ..quadraticBezierTo(17, -38, 19.5, -35)
          ..lineTo(29, -23)
          ..lineTo(34, -21)
          ..quadraticBezierTo(37, -20, 37, -16)
          ..lineTo(37, -10)
          ..quadraticBezierTo(37, -6, 33, -6)
          ..lineTo(-30, -6)
          ..close();
    c.drawPath(body, fill(blue));
    for (final x in [-28.0, -13.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, -33, 11, 9),
          const Radius.circular(2),
        ),
        fill(Colors.white),
      );
    }
    c.drawPath(
      Path()
        ..moveTo(3, -33)
        ..lineTo(12, -33)
        ..lineTo(20.5, -23)
        ..lineTo(3, -23)
        ..close(),
      fill(Colors.white),
    );
    for (final x in [-20.0, 20.0]) {
      c.save();
      c.translate(x, -5);
      c.drawCircle(Offset.zero, 10, fill(Colors.white));
      c.drawCircle(Offset.zero, 8.5, fill(blue));
      c.rotate(clock.value * 3.4 * 5 * math.pi);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, -5.5, 2, 11),
          const Radius.circular(1),
        ),
        fill(Colors.white),
      );
      c.drawCircle(Offset.zero, 2.4, fill(Colors.white));
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbiloqPainter old) =>
      old.mode != mode || old.progress != progress || old.dark != dark;
}

/// Agrupa las cargas descendientes en una sola capa centrada en el diálogo.
/// La capa no desmonta el formulario ni duplica sus consultas.
class WmsDialogLoadingHost extends StatefulWidget {
  const WmsDialogLoadingHost({super.key, required this.child});
  final Widget child;
  @override
  State<WmsDialogLoadingHost> createState() => _DialogLoadingHostState();
}

class _DialogLoadingHostState extends State<WmsDialogLoadingHost> {
  final Set<Object> _loaders = {};
  bool _scheduled = false;
  void add(Object loader) {
    if (_loaders.add(loader)) _refresh();
  }

  void remove(Object loader) {
    if (_loaders.remove(loader)) _refresh();
  }

  void _refresh() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _loaders.isEmpty,
    child: Stack(
      children: [
        _DialogLoadingScope(host: this, child: widget.child),
        if (_loaders.isNotEmpty)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ModalBarrier(
                    dismissible: false,
                    color: Color(0xF2FFFFFF),
                  ),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.min(
                          240.0,
                          math.min(
                            constraints.maxWidth * .65,
                            constraints.maxHeight * .65,
                          ),
                        );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WmsLoader(
                              key: const ValueKey('dialog-loader-central'),
                              mode: OrbiloqLoaderMode.orbit,
                              width: width,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Procesando…',
                              style: TextStyle(
                                color: Color(0xFF1F5C8B),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _DialogLoadingScope extends InheritedWidget {
  const _DialogLoadingScope({required this.host, required super.child});
  final _DialogLoadingHostState host;
  @override
  bool updateShouldNotify(_DialogLoadingScope oldWidget) =>
      oldWidget.host != host;
}
