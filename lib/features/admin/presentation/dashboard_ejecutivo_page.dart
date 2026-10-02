import 'dart:async';
import '../../../application/dashboard_snapshot.dart';
import 'dashboard_resumen.dart';
import 'dashboard_atencion_section.dart';
import 'dashboard_enfoque_section.dart';
import 'dart:math' as math;
import 'dashboard_recepcion_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../../../application/dashboard_acceso.dart';
import '../../../application/providers.dart';
import '../../../application/dashboard_tendencias.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../../../shared/widgets/wms_empty_state.dart';

class DatosDashboard {
  const DatosDashboard(this.movimientos, this.corte);
  final List<FilaReporte> movimientos;
  final DateTime corte;
}

final dashboardEjecutivoProvider = FutureProvider.autoDispose<DatosDashboard>((
  ref,
) async {
  if (ref.watch(dashboardAccesoProvider).$2 != RolCuenta.admin) {
    throw StateError('Acceso exclusivo del administrador.');
  }
  final repo = ref.watch(reportesAdminProvider);
  if (repo == null) {
    throw StateError(
      'Conecta la base de pruebas con los reportes de Administrador (SQL 062).',
    );
  }
  final resumen = await repo.resumen();
  final corte = DateTime.tryParse('${resumen['actualizado_en']}');
  if (corte == null) {
    throw StateError('El reporte no devolvió la fecha de corte.');
  }
  final filas = await repo.cargar('movimientos');
  return DatosDashboard(filas, corte);
});

class DashboardEjecutivoPage extends ConsumerStatefulWidget {
  const DashboardEjecutivoPage({super.key});
  @override
  ConsumerState<DashboardEjecutivoPage> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<DashboardEjecutivoPage> {
  int _semanas = 12;
  bool _detalle = false;
  bool _tiempoReal = false;
  Timer? _temporizador;

  void _actualizar() {
    if (!mounted || ref.read(dashboardAccesoProvider).$2 != RolCuenta.admin) {
      return;
    }
    if (ref.read(dashboardEjecutivoProvider).isLoading ||
        ref.read(dashboardRecepcionProvider).isLoading ||
        ref.read(dashboardEnfoqueProvider).isLoading ||
        ref.read(dashboardSnapshotProvider).isLoading) {
      return;
    }
    ref.invalidate(dashboardEjecutivoProvider);
    ref.invalidate(dashboardRecepcionProvider);
    ref.invalidate(dashboardEnfoqueProvider);
    ref.invalidate(dashboardSnapshotProvider);
  }

  void _cambiarTiempoReal(bool activo) {
    _temporizador?.cancel();
    _temporizador = null;
    setState(() => _tiempoReal = activo);
    if (activo) {
      _temporizador = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _actualizar(),
      );
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final esAdmin = ref.watch(dashboardAccesoProvider).$2 == RolCuenta.admin;
    if (!esAdmin) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Acceso exclusivo del administrador.')),
        ),
      );
    }
    final datos = ref.watch(dashboardEjecutivoProvider);
    final recepcion = ref.watch(dashboardRecepcionProvider);
    final enfoque = ref.watch(dashboardEnfoqueProvider);
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final actualizando =
        datos.isLoading ||
        recepcion.isLoading ||
        enfoque.isLoading ||
        snapshot.isLoading;
    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        title: const Text('Dashboard ejecutivo'),
        actions: [
          IconButton(
            tooltip: _detalle ? 'Vista compacta' : 'Vista detallada',
            onPressed: () => setState(() => _detalle = !_detalle),
            icon: Icon(
              _detalle ? Icons.dashboard_outlined : Icons.view_agenda_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: () => ref.read(temaProvider.notifier).alternar(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            MediaQuery.sizeOf(context).width < 480 ? 94 : 50,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 16,
                runSpacing: 2,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tiempo real'),
                          Text(
                            'Cada 5 minutos',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Tiempo real',
                        child: Switch(
                          value: _tiempoReal,
                          onChanged: _cambiarTiempoReal,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: actualizando ? null : _actualizar,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(
                      actualizando ? 'Actualizando…' : 'Actualizar datos',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: datos.when(
        skipLoadingOnRefresh: true,
        loading:
            () => const Center(
              child: WmsLoadingStrip(label: 'Consultando movimientos…'),
            ),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WmsEmptyState(
                      title: 'No pudimos cargar las tendencias',
                      message:
                          'Verifica tu conexión y que los reportes de Administrador estén disponibles en esta base.',
                    ),
                    FilledButton.icon(
                      onPressed:
                          () => ref.invalidate(dashboardEjecutivoProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
        data: (datos) {
          if (!_detalle) {
            return DashboardResumen(
              datos: datos,
              semanas: _semanas,
              cambiarSemanas: (v) => setState(() => _semanas = v),
            );
          }
          final tendencia = calcularTendencias(
            datos.movimientos,
            corte: datos.corte,
            semanas: _semanas,
          );
          final colores = coloresSeries(context);
          final totales = tendencia.totales;
          final corteLocal = fechaReporte(datos.corte.toIso8601String())!;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VISIÓN GENERAL',
                                style: TextStyle(
                                  color: pal.accent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tendencias generales',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                          StatusChip(label: 'Solo lectura', color: pal.accent),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'El ritmo semanal de Producción y Logística, en una sola vista.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          Text(
                            '${fechaCorta(tendencia.semanas.first.inicio)} ${tendencia.semanas.first.inicio.year} – ${fechaCorta(corteLocal)} ${corteLocal.year}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(
                            width: 215,
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _semanas,
                              decoration: const InputDecoration(
                                labelText: 'Período',
                              ),
                              items: [
                                for (final n in [4, 8, 12, 26])
                                  DropdownMenuItem(
                                    value: n,
                                    child: Text('Últimas $n semanas'),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _semanas = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder:
                            (_, c) => Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  SizedBox(
                                    width:
                                        c.maxWidth < 650
                                            ? c.maxWidth
                                            : (c.maxWidth - 32) / 3,
                                    child: MetricCard(
                                      title:
                                          '${nombresSeries[i].toUpperCase()} · UDS',
                                      value: numero(totales[i]),
                                      color: colores[i],
                                      icon:
                                          [
                                            Icons
                                                .precision_manufacturing_outlined,
                                            Icons.move_to_inbox_outlined,
                                            Icons.local_shipping_outlined,
                                          ][i],
                                    ),
                                  ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: pal.card,
                          border: Border.all(color: pal.cardBorder),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .035),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Volumen semanal',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unidades por semana · lunes a domingo · Bogotá (UTC−5)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 20,
                              runSpacing: 10,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        [
                                          Icons.circle,
                                          Icons.square,
                                          Icons.change_history,
                                        ][i],
                                        color: colores[i],
                                        size: 12,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(nombresSeries[i]),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            if (totales.every((n) => n == 0))
                              const WmsEmptyState(
                                title: 'Sin movimientos en este período',
                                message:
                                    'Prueba un período más amplio. No se registran entregas, recepciones ni despachos operativos en estas semanas.',
                              )
                            else
                              GraficaVolumenSemanal(
                                key: ValueKey(_semanas),
                                semanas: tendencia.semanas,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Semana actual en curso: los valores aún pueden aumentar.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Ver datos por semana'),
                        subtitle: const Text('Detalle de las tres series'),
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Semana del')),
                                for (final n in nombresSeries)
                                  DataColumn(label: Text(n), numeric: true),
                              ],
                              rows: [
                                for (final s in tendencia.semanas)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${fechaCorta(s.inicio)} ${s.inicio.year}',
                                        ),
                                      ),
                                      for (final v in s.unidades)
                                        DataCell(Text(numero(v))),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Corte: ${DateFormat('dd/MM/yyyy HH:mm').format(corteLocal)} · Fuente: movimientos registrados.\nVolumen operativo bruto; excluye ajustes administrativos, importaciones de saldos y movimientos inversos. No representa inventario disponible.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      DashboardRecepcionSection(
                        movimientos: datos.movimientos,
                        corte: datos.corte,
                        semanas: _semanas,
                      ),
                      DashboardEnfoqueSection(
                        movimientos: datos.movimientos,
                        corte: datos.corte,
                        semanas: _semanas,
                      ),
                      DashboardAtencionSection(corte: datos.corte),
                      if (tendencia.registrosInvalidos > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${tendencia.registrosInvalidos} registros no se pudieron graficar por fecha o cantidad inválida.',
                            style: TextStyle(color: pal.chipRed),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const nombresSeries = ['Entregado', 'Recibido', 'Despachado'];
String numero(int n) => NumberFormat.decimalPattern('es').format(n);
String fechaCorta(DateTime fecha) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${fecha.day.toString().padLeft(2, '0')} ${meses[fecha.month - 1]}';
}

List<Color> coloresSeries(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? [
          const Color(0xFF2DD4BF),
          const Color(0xFF60A5FA),
          const Color(0xFFC4B5FD),
        ]
        : [
          const Color(0xFF0F766E),
          const Color(0xFF2563EB),
          const Color(0xFF7C3AED),
        ];

class GraficaVolumenSemanal extends StatefulWidget {
  const GraficaVolumenSemanal({
    super.key,
    required this.semanas,
    this.altura = 310,
    this.compacta = false,
  });
  final double altura;
  final bool compacta;
  final List<SemanaVolumen> semanas;
  @override
  State<GraficaVolumenSemanal> createState() => _GraficaState();
}

class _GraficaState extends State<GraficaVolumenSemanal> {
  int? _seleccion;
  @override
  Widget build(BuildContext context) {
    final colores = coloresSeries(context);
    final pal = palOf(context);
    final seleccion = (_seleccion ?? widget.semanas.length - 1).clamp(
      0,
      widget.semanas.length - 1,
    );
    final semana = widget.semanas[seleccion];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.altura,
          child: LayoutBuilder(
            builder: (_, c) {
              void seleccionar(double x) {
                final index = (((x - 55) / (c.maxWidth - 70)) *
                        (widget.semanas.length - 1))
                    .round()
                    .clamp(0, widget.semanas.length - 1);
                if (_seleccion != index) setState(() => _seleccion = index);
              }

              return Semantics(
                label:
                    'Gráfica de líneas de entregado, recibido y despachado. El detalle está disponible en Ver datos por semana.',
                child: MouseRegion(
                  onHover: (e) => seleccionar(e.localPosition.dx),
                  child: GestureDetector(
                    onTapDown: (e) => seleccionar(e.localPosition.dx),
                    onHorizontalDragUpdate:
                        (e) => seleccionar(e.localPosition.dx),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _LineasPainter(
                        widget.semanas,
                        colores,
                        pal.textSecondary,
                        pal.cardBorder,
                        seleccion,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(widget.compacta ? 4 : 12),
          decoration: BoxDecoration(
            color: pal.input,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Semana del ${fechaCorta(semana.inicio)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (var i = 0; i < 3; i++)
                Text(
                  '${nombresSeries[i]}: ${numero(semana.unidades[i])}',
                  style: TextStyle(
                    color: colores[i],
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.compacta
              ? ''
              : 'Toca o pasa el cursor sobre la gráfica para consultar una semana.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LineasPainter extends CustomPainter {
  _LineasPainter(
    this.semanas,
    this.colores,
    this.texto,
    this.borde,
    this.seleccion,
  );
  final List<SemanaVolumen> semanas;
  final List<Color> colores;
  final Color texto, borde;
  final int seleccion;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(55, 16, size.width - 15, size.height - 34);
    final maximo = semanas.expand((s) => s.unidades).fold<int>(1, math.max);
    final base =
        math.pow(10, (math.log(maximo / 4) / math.ln10).floor()).toDouble();
    final paso = math.max(1.0, ((maximo / 4) / base).ceil() * base);
    final techo = paso * 4;
    void etiqueta(String label, Offset offset, {bool derecha = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: texto, fontSize: 10, fontFamily: 'Roboto'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        derecha ? offset.translate(-tp.width, -tp.height / 2) : offset,
      );
    }

    for (var i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = borde
          ..strokeWidth = 1,
      );
      etiqueta(
        NumberFormat.compact(locale: 'es').format(paso * i),
        Offset(rect.left - 9, y),
        derecha: true,
      );
    }
    double x(int i) => rect.left + rect.width * i / (semanas.length - 1);
    final salto = math.max(
      1,
      (semanas.length / (size.width < 500 ? 3 : 6)).ceil(),
    );
    for (var i = 0; i < semanas.length; i += salto) {
      etiqueta(
        DateFormat('dd/MM').format(semanas[i].inicio),
        Offset(x(i) - 15, rect.bottom + 12),
      );
    }
    canvas.drawLine(
      Offset(x(seleccion), rect.top),
      Offset(x(seleccion), rect.bottom),
      Paint()
        ..color = texto.withValues(alpha: .3)
        ..strokeWidth = 1,
    );
    for (var serie = 0; serie < 3; serie++) {
      final path = Path();
      for (var i = 0; i < semanas.length; i++) {
        final p = Offset(
          x(i),
          rect.bottom - semanas[i].unidades[serie] / techo * rect.height,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colores[serie]
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < semanas.length; i++) {
        final p = Offset(
          x(i),
          rect.bottom - semanas[i].unidades[serie] / techo * rect.height,
        );
        final radio = i == seleccion ? 4.5 : 2.5;
        final paint = Paint()..color = colores[serie];
        if (serie == 0) {
          canvas.drawCircle(p, radio, paint);
        } else if (serie == 1) {
          canvas.drawRect(
            Rect.fromCenter(center: p, width: radio * 2, height: radio * 2),
            paint,
          );
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - radio - 1)
              ..lineTo(p.dx + radio + 1, p.dy + radio)
              ..lineTo(p.dx - radio - 1, p.dy + radio)
              ..close(),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineasPainter old) => true;
}
