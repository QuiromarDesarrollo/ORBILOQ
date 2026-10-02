import '../../../application/dashboard_snapshot.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../../application/dashboard_acceso.dart';
import '../../../application/providers.dart';
import '../../../application/dashboard_enfoque.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_loader.dart';

final dashboardEnfoqueProvider = FutureProvider.autoDispose<List<FilaReporte>>((
  ref,
) async {
  if (ref.watch(dashboardAccesoProvider).$2 != RolCuenta.admin) {
    throw StateError('Acceso exclusivo del administrador.');
  }
  final repo = ref.watch(reportesAdminProvider);
  if (repo == null) throw StateError('Reportes no disponibles.');
  return repo.cargar('nc');
});

String _numero(num n) => NumberFormat.decimalPattern('es').format(n);
Color _teal(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark
        ? const Color(0xFF5EEAD4)
        : const Color(0xFF087F79);
Color _azul(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark
        ? const Color(0xFF93B4F4)
        : const Color(0xFF315689);

class DashboardEnfoqueSection extends ConsumerWidget {
  const DashboardEnfoqueSection({
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
    final nc = ref.watch(dashboardEnfoqueProvider);
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final volumen = volumenClientes(
      movimientos,
      corte: corte,
      semanas: semanas,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Text(
          'Clientes y causas de no conformidad',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Volumen, cumplimiento y calidad para orientar el seguimiento.',
        ),
        const SizedBox(height: 20),
        _Panel(
          titulo: 'Top 10 clientes por volumen',
          detalle:
              'Unidades despachadas · período seleccionado · ${volumen.length} clientes con despachos',
          child: Column(
            children: [
              if (volumen.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Sin despachos registrados en este período.'),
                ),
              for (final e in volumen.entries.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: LayoutBuilder(
                    builder:
                        (context, constraints) => Row(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth < 500 ? 100 : 220,
                              child: Text(
                                e.key,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                label:
                                    '${e.key}: ${e.value} unidades despachadas',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: e.value / volumen.values.first,
                                    minHeight: 14,
                                    color: _teal(context),
                                    backgroundColor: _teal(
                                      context,
                                    ).withValues(alpha: .08),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 65,
                              child: Text(
                                _numero(e.value),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        nc.when(
          skipLoadingOnRefresh: false,
          loading:
              () => const WmsLoadingStrip(
                label: 'Consultando clientes y causales…',
              ),
          error:
              (_, __) => Column(
                children: [
                  const Text(
                    'No se pudieron cargar los datos de no conformidad.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(dashboardEnfoqueProvider),
                    child: const Text('Reintentar clientes y causales'),
                  ),
                ],
              ),
          data:
              (filas) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Panel(
                    titulo: 'Causales de no conformidad',
                    detalle:
                        'Unidades reportadas · Logística + Aliados · últimas 4 semanas frente al histórico (que incluye esas 4 semanas).',
                    child: BarrasCausales(
                      datos: compararCausales(filas, corte),
                    ),
                  ),
                  const SizedBox(height: 20),
                  snapshot.when(
                    loading:
                        () => const WmsLoadingStrip(
                          label: 'Consultando fechas y pendientes por cliente…',
                        ),
                    error:
                        (_, __) => Column(
                          children: [
                            const Text(
                              'No se pudo consultar el estado actual de las OP.',
                            ),
                            TextButton(
                              onPressed:
                                  () =>
                                      ref.invalidate(dashboardSnapshotProvider),
                              child: const Text(
                                'Reintentar estado de clientes',
                              ),
                            ),
                          ],
                        ),
                    data:
                        (s) => TablaSaludClientes(
                          datos: saludClientes(
                            s.kardex,
                            movimientos,
                            filas,
                            corte: corte,
                            semanas: semanas,
                          ),
                        ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.titulo,
    required this.detalle,
    required this.child,
  });
  final String titulo, detalle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(detalle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class BarrasCausales extends StatelessWidget {
  const BarrasCausales({super.key, required this.datos});
  final List<CausalComparada> datos;
  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sin no conformidades registradas hasta el corte.'),
      );
    }
    final maximo = datos.map((e) => e.historico).reduce(math.max);
    Widget barra(int n, Color color, String label) => Semantics(
      label: '$label: $n unidades',
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(_numero(n), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            Container(
              height: n * 170 / maximo,
              width: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            StatusChip(label: 'Últimas 4 semanas', color: _teal(context)),
            StatusChip(label: 'Histórico', color: _azul(context)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Escala común · máximo ${_numero(maximo)} unidades',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in datos)
                SizedBox(
                  width: 150,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 208,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            barra(
                              c.recientes,
                              _teal(context),
                              '${c.nombre}, últimas 4 semanas',
                            ),
                            barra(
                              c.historico,
                              _azul(context),
                              '${c.nombre}, histórico',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(c.nombre, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada reporte suma sus unidades; una prenda puede aparecer en más de un reporte. Desliza horizontalmente para ver todas las causales.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class TablaSaludClientes extends StatefulWidget {
  const TablaSaludClientes({super.key, required this.datos});
  final List<SaludCliente> datos;
  @override
  State<TablaSaludClientes> createState() => _TablaSaludClientesState();
}

class _TablaSaludClientesState extends State<TablaSaludClientes> {
  String busqueda = '';
  int pagina = 0;
  @override
  Widget build(BuildContext context) {
    final filas =
        widget.datos
            .where(
              (c) => c.nombre.toLowerCase().contains(busqueda.toLowerCase()),
            )
            .toList();
    final ultima = math.max(0, (filas.length - 1) ~/ 10);
    final actual = math.min(pagina, ultima);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colores =
        dark
            ? [
              const Color(0xFF6EE7B7),
              const Color(0xFFFCD34D),
              const Color(0xFFFDA4AF),
            ]
            : [
              const Color(0xFF157347),
              const Color(0xFF916000),
              const Color(0xFFB42335),
            ];
    return _Panel(
      titulo: 'Salud de todos los clientes',
      detalle:
          '${widget.datos.length} clientes · fechas y pendientes actuales; tasa NC del período seleccionado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar cliente',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged:
                (v) => setState(() {
                  busqueda = v.trim();
                  pagina = 0;
                }),
          ),
          const SizedBox(height: 16),
          if (filas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No hay clientes que coincidan con la búsqueda.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 86,
                columns: const [
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Salud')),
                  DataColumn(label: Text('OP activas'), numeric: true),
                  DataColumn(label: Text('OP vencidas'), numeric: true),
                  DataColumn(label: Text('Tasa NC'), numeric: true),
                  DataColumn(label: Text('Motivo de seguimiento')),
                ],
                rows: [
                  for (final c in filas.skip(actual * 10).take(10))
                    DataRow(
                      cells: [
                        DataCell(SizedBox(width: 170, child: Text(c.nombre))),
                        DataCell(
                          StatusChip(
                            label:
                                ['En rango', 'Seguimiento', 'Prioridad'][c
                                    .nivel],
                            color: colores[c.nivel],
                          ),
                        ),
                        DataCell(Text('${c.activas.length}')),
                        DataCell(Text('${c.vencidas.length}')),
                        DataCell(
                          Text(
                            c.tasa == null
                                ? 'Sin base'
                                : '${NumberFormat('0.0', 'es').format(c.tasa)} %',
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              c.motivo,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '${filas.length} clientes · página ${actual + 1} de ${ultima + 1}',
              ),
              IconButton(
                tooltip: 'Clientes anteriores',
                onPressed:
                    actual == 0
                        ? null
                        : () => setState(() => pagina = actual - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Más clientes',
                onPressed:
                    actual == ultima
                        ? null
                        : () => setState(() => pagina = actual + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Rojo: OP vencida o tasa NC > 5 %. Amarillo: vencimiento en los próximos 3 días, tasa NC > 2 % o información incompleta. Verde: sin estas alertas. NC = unidades reportadas / entregadas por Producción; puede superar el 100 %. Las fechas evalúan etapas con pendientes.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
