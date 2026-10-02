import '../../../application/dashboard_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/dashboard_atencion.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'dashboard_recepcion_section.dart';

class DashboardAtencionSection extends ConsumerStatefulWidget {
  const DashboardAtencionSection({super.key, required this.corte});
  final DateTime corte;
  @override
  ConsumerState<DashboardAtencionSection> createState() =>
      _DashboardAtencionSectionState();
}

class _DashboardAtencionSectionState
    extends ConsumerState<DashboardAtencionSection> {
  int proximos = 3, antiguedad = 7, visibles = 20;
  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final auditoria = ref.watch(dashboardRecepcionProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prioridades del taller',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Estado actual de todas las OP vigentes. Independiente del período de las gráficas.',
          ),
          const SizedBox(height: 20),
          snapshot.when(
            loading:
                () => const WmsLoadingStrip(
                  label: 'Consultando OP y pendientes…',
                ),
            error:
                (_, __) => Column(
                  children: [
                    const Text('No se pudieron consultar las OP.'),
                    TextButton(
                      onPressed: () => ref.invalidate(dashboardSnapshotProvider),
                      child: const Text('Reintentar OP'),
                    ),
                  ],
                ),
            data: (s) {
              final etapas = contarEtapas(s.kardex);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TableroEtapas(conteos: etapas),
                  const SizedBox(height: 24),
                  Text(
                    'Atención requerida',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 235,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: proximos,
                          decoration: const InputDecoration(
                            labelText: 'Fechas próximas',
                          ),
                          items: [
                            for (final n in [1, 3, 7])
                              DropdownMenuItem(
                                value: n,
                                child: Text('Próximos $n días'),
                              ),
                          ],
                          onChanged:
                              (v) => setState(() {
                                proximos = v!;
                                visibles = 20;
                              }),
                        ),
                      ),
                      SizedBox(
                        width: 235,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: antiguedad,
                          decoration: const InputDecoration(
                            labelText: 'Antigüedad de pendientes',
                          ),
                          items: [
                            for (final n in [3, 7, 14, 30])
                              DropdownMenuItem(
                                value: n,
                                child: Text('Más de $n días'),
                              ),
                          ],
                          onChanged:
                              (v) => setState(() {
                                antiguedad = v!;
                                visibles = 20;
                              }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  auditoria.when(
                    skipLoadingOnRefresh: false,
                    loading:
                        () => const WmsLoadingStrip(
                          label: 'Revisando sobrantes y no conformes…',
                        ),
                    error:
                        (_, __) => Column(
                          children: [
                            const Text(
                              'No se pudo completar la lista de alertas.',
                            ),
                            TextButton(
                              onPressed:
                                  () => ref.invalidate(
                                    dashboardRecepcionProvider,
                                  ),
                              child: const Text('Reintentar alertas'),
                            ),
                          ],
                        ),
                    data: (filas) {
                      final alertas = calcularAtencion(
                        s.kardex,
                        filas,
                        corte: widget.corte,
                        proximos: proximos,
                        antiguedad: antiguedad,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${alertas.length} alertas · primero vencidas y pendientes antiguos; después fechas próximas',
                          ),
                          const SizedBox(height: 12),
                          if (alertas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Sin alertas detectadas con estos criterios y datos disponibles.',
                              ),
                            ),
                          for (final a in alertas.take(visibles))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      a.urgente
                                          ? Icons.error_outline
                                          : Icons.schedule,
                                      color:
                                          a.urgente
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                              : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.titulo,
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(a.detalle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (alertas.length > visibles)
                            TextButton(
                              onPressed: () => setState(() => visibles += 20),
                              child: Text(
                                'Mostrar más (${alertas.length - visibles} restantes)',
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'No conforme: días desde el último reporte o liberación de la línea, con saldo pendiente actual; no representa la edad exacta de cada unidad. Sin fecha o sin historial enlazable no se puede evaluar antigüedad. Los umbrales solo cambian esta visualización.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class TableroEtapas extends StatelessWidget {
  const TableroEtapas({super.key, required this.conteos});
  final List<int> conteos;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colores =
        dark
            ? [
              Colors.lightBlueAccent,
              Colors.amberAccent,
              Colors.tealAccent,
              Colors.greenAccent,
            ]
            : [
              Colors.blue.shade800,
              Colors.orange.shade900,
              Colors.teal.shade700,
              Colors.green.shade700,
            ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mapa de OP por etapa',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          '${conteos.take(3).fold(0, (a, b) => a + b)} OP activas · ${conteos[3]} completas',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas =
                constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 480
                    ? 2
                    : 1;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columnas - 1) * 12) / columnas,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          top: BorderSide(color: colores[i], width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(
                            label: etapasDashboard[i],
                            color: colores[i],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${conteos[i]}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const Text('órdenes de producción'),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Cada OP cuenta una vez en su primera etapa pendiente. No conformes pendientes se incluyen en Producción. Completo exige que todas sus líneas estén cubiertas y sin no conformes pendientes. Se excluyen líneas eliminadas.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

