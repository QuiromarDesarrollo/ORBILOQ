import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/ciclos.dart';
import '../../../domain/ciclos_indicadores.dart';
import '../../../domain/ciclos_prioridades.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'ciclos_colores.dart';

class CiclosPrioridadesCard extends StatelessWidget {
  const CiclosPrioridadesCard({super.key, required this.indicadores});
  final IndicadoresCiclos indicadores;

  void _detalle(BuildContext context, PrioridadProceso proceso) {
    showDialog<void>(
      context: context,
      builder:
          (context) => WmsExpandableAlertDialog(
            title: Text('OP atrasadas · ${proceso.proceso.titulo}'),
            content: SizedBox(
              width: 650,
              height: MediaQuery.sizeOf(context).height * .6,
              child: ListView.builder(
                itemCount: proceso.atrasadas.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Text(
                      'Ordenadas por mayor atraso. Cantidades completas de las OP, no saldo pendiente de prendas.',
                    );
                  }
                  final m = proceso.atrasadas[index - 1];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('OP ${m.orden.op} · ${m.orden.cliente}'),
                    subtitle: Text(
                      'Fecha objetivo: ${fechaCiclo(m.esperada!)}\n${proceso.atraso(m)} días hábiles de atraso · ${m.orden.cantidad} prendas en la OP',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = PrioridadesCiclos(indicadores);
    final atrasadas = resumen.procesos.fold<int>(
      0,
      (s, p) => s + p.atrasadas.length,
    );
    final abiertas = resumen.procesos.fold<int>(
      0,
      (s, p) => s + p.abiertas.length,
    );
    final sinMeta = resumen.procesos.fold<int>(0, (s, p) => s + p.sinMeta);
    final maximo = resumen.procesos.fold<int>(
      1,
      (s, p) => math.max(s, p.atrasadas.length),
    );
    final pendientes = _panel(context, [
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Atrasos actuales por proceso',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: CiclosColores.error(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$atrasadas OP atrasadas de $abiertas en proceso',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Último Excel · evaluación ${fechaCiclo(resumen.hoy)} · Todas las fechas',
      ),
      const SizedBox(height: 10),
      _tabla(context, resumen, maximo, historial: false),
      const SizedBox(height: 8),
      Text(
        'Prioridad por cantidad de OP · $sinMeta sin meta · ${resumen.sinInicio} sin inicio válido. No se clasifican como a tiempo.',
      ),
      const Text(
        'Fecha de última carga no disponible · No es seguimiento en tiempo real. Prendas = cantidad completa de las OP.',
      ),
    ]);
    final historico = _panel(context, [
      Text(
        indicadores.desde == null && indicadores.hasta == null
            ? 'Cumplimiento · últimos 28 días'
            : 'Cumplimiento · período seleccionado',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      Text(
        '${fechaCiclo(resumen.desde)} – ${fechaCiclo(resumen.hasta)} vs. ${fechaCiclo(resumen.anteriorDesde)} – ${fechaCiclo(resumen.anteriorHasta)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      _tabla(context, resumen, maximo, historial: true),
      const SizedBox(height: 8),
      Text(
        '${resumen.procesos.fold<int>(0, (s, p) => s + p.terminadas.length - p.evaluadas.length)} registros de proceso sin meta excluidos del porcentaje.',
      ),
      const Text(
        'Meta histórica por OP · Cada proceso evalúa sus propias OP; no sumar porcentajes.',
      ),
    ]);
    return LayoutBuilder(
      builder: (context, box) {
        final ancho =
            box.maxWidth >= 1050 &&
            MediaQuery.textScalerOf(context).scale(12) <= 15;
        return ancho
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pendientes),
                const SizedBox(width: 12),
                Expanded(child: historico),
              ],
            )
            : Column(
              children: [pendientes, const SizedBox(height: 12), historico],
            );
      },
    );
  }

  Widget _tabla(
    BuildContext context,
    PrioridadesCiclos r,
    int maximo, {
    required bool historial,
  }) => LayoutBuilder(
    builder: (context, box) {
      final tabla =
          box.maxWidth >= 480 &&
          MediaQuery.textScalerOf(context).scale(12) <= 15;
      final anchos =
          historial
              ? <double>[74, -1, 38, 78, 64]
              : <double>[74, -1, 58, 72, 44];
      Widget texto(String t, {Color? color}) =>
          Text(t, style: TextStyle(fontSize: 11, color: color));
      Widget fila(List<Widget> widgets) => Row(
        children: [
          for (var n = 0; n < widgets.length; n++)
            anchos[n] < 0
                ? Expanded(child: widgets[n])
                : SizedBox(
                  width: anchos[n],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: widgets[n],
                  ),
                ),
        ],
      );
      Widget barra(double valor, Color color, {bool meta = false}) =>
          LayoutBuilder(
            builder:
                (context, c) => SizedBox(
                  height: 12,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: valor,
                          minHeight: 5,
                          color: color,
                          backgroundColor: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: .12),
                        ),
                      ),
                      if (meta)
                        Positioned(
                          left: math.max(0, c.maxWidth - 1) * .85,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .6),
                          ),
                        ),
                    ],
                  ),
                ),
          );
      return Column(
        children: [
          if (tabla)
            fila([
              texto('Proceso'),
              texto(historial ? 'A tiempo' : 'Atrasadas / en proceso'),
              texto(historial ? 'OP' : 'Prendas'),
              texto(historial ? 'Variación' : 'Mayor atraso'),
              texto(historial ? 'Atraso prom.' : ''),
            ]),
          if (tabla) const Divider(height: 10),
          for (final p in historial ? r.procesos : r.ordenados)
            Builder(
              builder: (context) {
                final valor =
                    historial
                        ? (p.cumplimiento ?? 0) / 100
                        : p.atrasadas.length / maximo;
                final color =
                    historial
                        ? (p.cumplimiento ?? 0) >= 85
                            ? CiclosColores.bien(context)
                            : CiclosColores.alerta(context)
                        : CiclosColores.error(context);
                final cifra =
                    historial
                        ? p.cumplimiento == null
                            ? '—'
                            : '${p.cumplimiento!.toStringAsFixed(1)} %'
                        : '${p.atrasadas.length} / ${p.abiertas.length}';
                final variacion =
                    p.cambio == null
                        ? 'Sin base'
                        : p.cambio == 0
                        ? 'Sin cambio'
                        : '${p.cambio! > 0 ? '▲ +' : '▼ '}${p.cambio!.toStringAsFixed(1)} pp';
                final variacionColor =
                    p.cambio == null || p.cambio == 0
                        ? null
                        : p.cambio! > 0
                        ? CiclosColores.bien(context)
                        : CiclosColores.error(context);
                final atraso =
                    p.excesoMedio == null
                        ? '—'
                        : '${p.excesoMedio!.toStringAsFixed(1)} d';
                return Tooltip(
                  message:
                      historial
                          ? 'Atraso promedio de OP terminadas tarde, en días hábiles. ${p.terminadas.length - p.evaluadas.length} sin meta excluidas.'
                          : 'Cantidades completas de las OP afectadas. Atraso en días hábiles.',
                  child: InkWell(
                    key:
                        historial
                            ? null
                            : ValueKey('prioridad-${p.proceso.name}'),
                    onTap:
                        historial || p.atrasadas.isEmpty
                            ? null
                            : () => _detalle(context, p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child:
                          tabla
                              ? fila([
                                texto(p.proceso.titulo),
                                Row(
                                  children: [
                                    Expanded(
                                      child: barra(
                                        valor,
                                        color,
                                        meta: historial,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    texto(cifra),
                                  ],
                                ),
                                texto(
                                  historial
                                      ? '${p.aTiempo}/${p.evaluadas.length}'
                                      : p.atrasadas.isEmpty
                                      ? '—'
                                      : '${p.prendas}',
                                ),
                                texto(
                                  historial
                                      ? variacion
                                      : p.atrasadas.isEmpty
                                      ? '—'
                                      : '${p.mayorAtraso} d',
                                  color: historial ? variacionColor : color,
                                ),
                                texto(
                                  historial
                                      ? atraso
                                      : p.atrasadas.isEmpty
                                      ? '—'
                                      : 'Ver OP',
                                ),
                              ])
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        p.proceso.titulo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      texto(cifra),
                                    ],
                                  ),
                                  barra(valor, color, meta: historial),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      texto(
                                        historial
                                            ? '${p.aTiempo}/${p.evaluadas.length} OP · $variacion'
                                            : '${p.prendas} prendas · ${p.mayorAtraso} días hábiles',
                                      ),
                                      texto(
                                        historial
                                            ? 'Atraso promedio: $atraso'
                                            : p.atrasadas.isEmpty
                                            ? 'Sin atrasos identificados'
                                            : 'Ver OP',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                    ),
                  ),
                );
              },
            ),
          if (historial)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Línea vertical: referencia 85 % · Variación en puntos porcentuales.',
              ),
            ),
        ],
      );
    },
  );

  Widget _panel(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:
          CiclosColores.oscuro(context)
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .18),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 11, height: 1.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}
