import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../../application/dashboard_acceso.dart';
import '../../../application/providers.dart';
import '../../../application/dashboard_recepcion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_loader.dart';

final dashboardRecepcionProvider =
    FutureProvider.autoDispose<List<FilaReporte>>((ref) async {
      if (ref.watch(dashboardAccesoProvider).$2 != RolCuenta.admin) {
        throw StateError('Acceso exclusivo del administrador.');
      }
      final repo = ref.watch(reportesAdminProvider);
      if (repo == null) throw StateError('Reportes no disponibles.');
      return repo.cargar('auditoria');
    });

String _decimal(double? v, String sufijo) =>
    v == null ? 'Sin datos' : '${NumberFormat('0.0', 'es').format(v)}$sufijo';

class DashboardRecepcionSection extends ConsumerWidget {
  const DashboardRecepcionSection({
    super.key,
    required this.movimientos,
    required this.corte,
    required this.semanas,
  });
  final List<FilaReporte> movimientos;
  final DateTime corte;
  final int semanas;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(dashboardRecepcionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Text(
          'Calidad de la recepción',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Conformidad, sobrantes y velocidad de resolución del período seleccionado.',
        ),
        const SizedBox(height: 20),
        datos.when(
          skipLoadingOnRefresh: false,
          loading:
              () => const WmsLoadingStrip(
                label: 'Consultando recepciones y sobrantes…',
              ),
          error:
              (_, __) => _Panel(
                child: Column(
                  children: [
                    const Text(
                      'No se pudieron cargar los indicadores de recepción.',
                    ),
                    TextButton.icon(
                      onPressed:
                          () => ref.invalidate(dashboardRecepcionProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar recepción'),
                    ),
                  ],
                ),
              ),
          data:
              (filas) => IndicadoresRecepcion(
                datos: calcularRecepcion(
                  filas,
                  movimientos,
                  corte: corte,
                  semanas: semanas,
                ),
              ),
        ),
      ],
    );
  }
}

class IndicadoresRecepcion extends StatelessWidget {
  const IndicadoresRecepcion({super.key, required this.datos});
  final ResumenRecepcion datos;
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final novedad =
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFBBF24)
            : const Color(0xFFB45309);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, c) {
            final ancho =
                c.maxWidth < 1000 ? c.maxWidth : (c.maxWidth - 32) / 3;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: ancho,
                  child: _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Recepciones conformes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: SizedBox(
                            width: 168,
                            height: 168,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DonaRecepcionPainter(
                                      datos.conformes,
                                      datos.novedades,
                                      pal.accent,
                                      novedad,
                                      pal.cardBorder,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _decimal(datos.porcentajeConforme, '%'),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                    ),
                                    const Text('conformes'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: '${datos.conformes} conformes',
                              color: pal.accent,
                            ),
                            StatusChip(
                              label: '${datos.novedades} con novedad',
                              color: novedad,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          datos.recepciones == 0
                              ? 'Sin líneas recibidas clasificables en este período.'
                              : '${datos.recepciones} líneas recibidas · ${_decimal(100 - datos.porcentajeConforme!, '%')} con novedad.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${datos.enTransito} líneas con recepción parcial aún en tránsito, excluidas.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: _MetricaTendencia(
                    titulo: 'Tasa de sobrantes',
                    valor: _decimal(datos.tasaSobrantes, '%'),
                    color: novedad,
                    detalle:
                        '${datos.sobrantes} Uds sobrantes / ${datos.recibidas} Uds recibidas',
                    nota:
                        'Unidades registradas de más frente al volumen recibido. Puede superar el 100 %.',
                    valores: datos.tasasSemanales,
                  ),
                ),
                SizedBox(
                  width: ancho,
                  child: _MetricaTendencia(
                    titulo: 'Resolución de sobrantes',
                    valor: _decimal(datos.diasPromedio, ' días'),
                    color: pal.accent,
                    detalle:
                        '${datos.resueltos} registros resueltos · tiempo promedio',
                    nota:
                        'Desde el registro hasta su resolución. Excluye pendientes; agrupa por semana de resolución.',
                    valores: datos.diasSemanales,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Conformidad: estado actual de cada línea de lote, agrupada por su última fecha de recepción. Las tendencias usan semanas de lunes a domingo; la actual está en curso.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (datos.invalidos > 0)
          Text(
            '${datos.invalidos} registros omitidos por estado, fecha o cantidad inválidos.',
            style: TextStyle(color: pal.chipRed),
          ),
        ExpansionTile(
          title: const Text('Ver detalle de recepción por semana'),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Semana del')),
                  DataColumn(label: Text('Tasa de sobrantes')),
                  DataColumn(label: Text('Días de resolución')),
                ],
                rows: [
                  for (var i = 0; i < datos.semanas.length; i++)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${datos.semanas[i].day.toString().padLeft(2, '0')}/${datos.semanas[i].month.toString().padLeft(2, '0')}/${datos.semanas[i].year}',
                          ),
                        ),
                        DataCell(Text(_decimal(datos.tasasSemanales[i], '%'))),
                        DataCell(
                          Text(_decimal(datos.diasSemanales[i], ' días')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: pal.card,
        border: Border.all(color: pal.cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricaTendencia extends StatelessWidget {
  const _MetricaTendencia({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.nota,
    required this.valores,
    required this.color,
  });
  final String titulo, valor, detalle, nota;
  final List<double?> valores;
  final Color color;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 22),
        Text(
          valor,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: color),
        ),
        const SizedBox(height: 8),
        Text(detalle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
        SizedBox(
          height: 86,
          child:
              valores.every((v) => v == null)
                  ? const Center(
                    child: Text('Sin base para calcular la tendencia'),
                  )
                  : Semantics(
                    label:
                        'Tendencia semanal. Consulta las cifras en el detalle por semana.',
                    child: CustomPaint(
                      painter: TendenciaRecepcionPainter(valores, color),
                    ),
                  ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tendencia semanal · huecos = sin base de cálculo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Text(nota, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class DonaRecepcionPainter extends CustomPainter {
  DonaRecepcionPainter(
    this.conformes,
    this.novedades,
    this.color,
    this.alerta,
    this.fondo,
  );
  final int conformes, novedades;
  final Color color, alerta, fondo;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(12);
    final p =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = fondo);
    final total = conformes + novedades;
    if (total == 0) return;
    final angulo = math.pi * 2 * conformes / total;
    canvas.drawArc(rect, -math.pi / 2, angulo, false, p..color = color);
    canvas.drawArc(
      rect,
      -math.pi / 2 + angulo,
      math.pi * 2 - angulo,
      false,
      p..color = alerta,
    );
  }

  @override
  bool shouldRepaint(covariant DonaRecepcionPainter old) =>
      old.conformes != conformes ||
      old.novedades != novedades ||
      old.color != color ||
      old.alerta != alerta ||
      old.fondo != fondo;
}

class TendenciaRecepcionPainter extends CustomPainter {
  TendenciaRecepcionPainter(this.valores, this.color);
  final List<double?> valores;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final maximo = valores.whereType<double>().fold<double>(1, math.max);
    final path = Path();
    var continuar = false;
    for (var i = 0; i < valores.length; i++) {
      final v = valores[i];
      if (v == null) {
        continuar = false;
        continue;
      }
      final punto = Offset(
        5 + (size.width - 10) * i / math.max(1, valores.length - 1),
        size.height - 5 - v / maximo * (size.height - 10),
      );
      if (continuar) {
        path.lineTo(punto.dx, punto.dy);
      } else {
        path.moveTo(punto.dx, punto.dy);
      }
      continuar = true;
      canvas.drawCircle(punto, 3, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant TendenciaRecepcionPainter old) =>
      old.valores != valores || old.color != color;
}
