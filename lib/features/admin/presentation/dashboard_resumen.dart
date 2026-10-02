import '../../../application/dashboard_snapshot.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/dashboard_tendencias.dart';
import '../../../application/dashboard_recepcion.dart';
import '../../../application/dashboard_enfoque.dart';
import '../../../application/dashboard_atencion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/reportes_admin_repository.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'dashboard_ejecutivo_page.dart';
import 'dashboard_recepcion_section.dart';
import 'dashboard_enfoque_section.dart';

class DashboardResumen extends ConsumerStatefulWidget {
  const DashboardResumen({
    super.key,
    required this.datos,
    required this.semanas,
    required this.cambiarSemanas,
  });
  final DatosDashboard datos;
  final int semanas;
  final ValueChanged<int> cambiarSemanas;
  @override
  ConsumerState<DashboardResumen> createState() => _DashboardResumenState();
}

class _DashboardResumenState extends ConsumerState<DashboardResumen> {
  String? cliente;
  int proximos = 3, antiguedad = 7;
  @override
  Widget build(BuildContext context) {
    final aud = ref.watch(dashboardRecepcionProvider);
    final nc = ref.watch(dashboardEnfoqueProvider);
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final clientes =
        <String>{
            for (final f in widget.datos.movimientos)
              clienteDashboard(f['cliente']),
            for (final f in aud.value ?? <FilaReporte>[])
              if ('${f['cliente'] ?? ''}'.trim().isNotEmpty)
                clienteDashboard(f['cliente']),
            for (final f in nc.value ?? <FilaReporte>[])
              clienteDashboard(f['cliente']),
            for (final k in snapshot.value?.kardex ?? [])
              if (!k.eliminada) clienteDashboard(k.item.cliente),
            if (cliente != null) cliente!,
          }.toList()
          ..sort();
    List<FilaReporte> filtrar(List<FilaReporte> filas) =>
        filas
            .where(
              (f) =>
                  cliente == null || clienteDashboard(f['cliente']) == cliente,
            )
            .toList();
    final movimientos = filtrar(widget.datos.movimientos);
    final tendencia = calcularTendencias(
      movimientos,
      corte: widget.datos.corte,
      semanas: widget.semanas,
    );
    final volumen = volumenClientes(
      movimientos,
      corte: widget.datos.corte,
      semanas: widget.semanas,
    );
    final kardex =
        snapshot.value?.kardex
            .where(
              (k) =>
                  cliente == null ||
                  clienteDashboard(k.item.cliente) == cliente,
            )
            .toList();
    final pal = palOf(context);
    Widget datosAud(Widget Function(List<FilaReporte>) build) => aud.when(
      skipLoadingOnRefresh: false,
      loading: () => const WmsLoadingStrip(label: 'Consultando…'),
      error:
          (_, __) => TextButton(
            onPressed: () => ref.invalidate(dashboardRecepcionProvider),
            child: const Text('Error de consulta · Reintentar'),
          ),
      data: (f) => build(filtrar(f)),
    );
    Widget datosNc(Widget Function(List<FilaReporte>) build) => nc.when(
      skipLoadingOnRefresh: false,
      loading: () => const WmsLoadingStrip(label: 'Consultando…'),
      error:
          (_, __) => TextButton(
            onPressed: () => ref.invalidate(dashboardEnfoqueProvider),
            child: const Text('Error de consulta · Reintentar'),
          ),
      data: (f) => build(filtrar(f)),
    );
    Widget estado(Widget Function() build) => snapshot.when(
      loading: () => const WmsLoadingStrip(label: 'Consultando OP…'),
      error:
          (_, __) => TextButton(
            onPressed: () => ref.invalidate(dashboardSnapshotProvider),
            child: const Text('Error de OP · Reintentar'),
          ),
      data: (_) => build(),
    );
    ResumenRecepcion recepcion(List<FilaReporte> f) => calcularRecepcion(
      f,
      movimientos,
      corte: widget.datos.corte,
      semanas: widget.semanas,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= 1100;
        final rowHeight =
            desktop ? math.max(180.0, (c.maxHeight - 132) / 3) : 270.0;
        Widget tile(
          String titulo,
          String ayuda,
          Widget child, {
          Widget? detalle,
        }) => PanelResumen(
          titulo: titulo,
          ayuda: ayuda,
          detalle: detalle,
          child: child,
        );
        final cards = <Widget>[
          tile(
            'Volumen semanal',
            'Unidades positivas entregadas por Producción, recibidas y despachadas por semana en Bogotá. Excluye ajustes administrativos y movimientos inversos. La semana actual es parcial. El cliente y el período seleccionados se aplican a las tres líneas.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 14,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Text(
                        '${nombresSeries[i]}  ${numero(tendencia.totales[i])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: coloresSeries(context)[i],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                GraficaVolumenSemanal(
                  semanas: tendencia.semanas,
                  altura: math.max(100, rowHeight - 125),
                  compacta: true,
                ),
                if (tendencia.registrosInvalidos > 0)
                  Text(
                    '${tendencia.registrosInvalidos} registros inválidos omitidos',
                  ),
              ],
            ),
          ),
          tile(
            'Conformidad de recepción',
            'Cuenta líneas de lote recibidas conformes o con novedad, según su estado actual y última fecha de recepción dentro del período. Excluye líneas aún en tránsito. No cuenta unidades ni reconstruye estados pasados.',
            datosAud((f) {
              final d = recepcion(f);
              return Column(
                children: [
                  SizedBox(
                    height: math.min(120, rowHeight - 95),
                    width: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DonaRecepcionPainter(
                              d.conformes,
                              d.novedades,
                              pal.accent,
                              pal.chipRed,
                              pal.cardBorder,
                            ),
                          ),
                        ),
                        Text(
                          d.porcentajeConforme == null
                              ? 'Sin datos'
                              : '${d.porcentajeConforme!.toStringAsFixed(1)} %',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d.conformes} conformes · ${d.novedades} con novedad',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    '${d.enTransito} en tránsito excluidas',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }),
          ),
          tile(
            'Sobrantes y resolución',
            'Tasa = unidades sobrantes registradas / unidades recibidas del período × 100; puede superar 100 %. Resolución = promedio de días entre creación y resolución de los registros resueltos dentro del período. Las mini líneas son semanales; los huecos indican falta de base.',
            datosAud((f) {
              final d = recepcion(f);
              Widget metrica(
                String label,
                double? valor,
                String sufijo,
                List<double?> serie,
              ) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 11)),
                          Text(
                            valor == null
                                ? 'Sin datos'
                                : '${valor.toStringAsFixed(1)} $sufijo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      height: 38,
                      child: CustomPaint(
                        painter: TendenciaRecepcionPainter(serie, pal.accent),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Cómo se calcula: $label',
                      icon: const Icon(Icons.help_outline, size: 16),
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text(label),
                                  content: Text(
                                    sufijo == '%'
                                        ? 'Unidades sobrantes registradas divididas entre unidades recibidas en el período, por 100. Puede superar el 100 %. La mini línea muestra la tasa por semana; sin recepción base no se calcula.'
                                        : 'Promedio por registro de los días entre creación y resolución. Incluye registros resueltos en el período aunque se hayan creado antes. Excluye pendientes. La mini línea agrupa por semana de resolución.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Entendido'),
                                    ),
                                  ],
                                ),
                          ),
                    ),
                  ],
                ),
              );
              return Column(
                children: [
                  metrica(
                    'Tasa de sobrantes',
                    d.tasaSobrantes,
                    '%',
                    d.tasasSemanales,
                  ),
                  metrica(
                    'Resolución promedio',
                    d.diasPromedio,
                    'días',
                    d.diasSemanales,
                  ),
                  if (d.invalidos > 0)
                    Text(
                      '${d.invalidos} registros inválidos omitidos',
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              );
            }),
          ),
          tile(
            'Top 10 · despachos',
            'Suma unidades despachadas operativas del cliente y período seleccionados. Ordena de mayor a menor y muestra los diez primeros; excluye ajustes administrativos. La tabla de salud conserva todos los clientes.',
            volumen.isEmpty
                ? const Text('Sin despachos en este período.')
                : Column(
                  children: [
                    for (final e in volumen.entries.take(10))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 105,
                              child: Tooltip(
                                message: e.key,
                                child: Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: e.value / volumen.values.first,
                                minHeight: 8,
                                color: pal.accent,
                                backgroundColor: pal.accent.withValues(
                                  alpha: .1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              numero(e.value),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
          tile(
            'Causales de no conformidad',
            'Unidades reportadas en Logística y Aliados, agrupadas por causal. Compara últimas 4 semanas calendario con todo el histórico hasta el corte. El histórico incluye esas 4 semanas. El filtro de cliente sí aplica; este comparativo conserva sus ventanas fijas. Una prenda puede tener varios reportes.',
            datosNc(
              (f) => _CausalesCompactas(
                datos: compararCausales(f, widget.datos.corte),
                alto: rowHeight - 90,
              ),
            ),
          ),
          tile(
            'Salud de clientes',
            'Todos los clientes del alcance seleccionado. Rojo: OP vencida o tasa NC > 5 %. Amarillo: fecha próxima a 3 días, tasa NC > 2 % o datos incompletos. Verde: sin estas alertas. NC = unidades reportadas / entregadas por Producción en el período. Las fechas y pendientes son actuales.',
            estado(
              () => datosNc((f) {
                final salud = saludClientes(
                  kardex!,
                  movimientos,
                  f,
                  corte: widget.datos.corte,
                  semanas: widget.semanas,
                );
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${salud.length} clientes · estado actual',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    for (final s in salud)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: '${s.nombre}: ${s.motivo}',
                                child: Text(
                                  s.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            StatusChip(
                              label:
                                  ['En rango', 'Seguimiento', 'Prioridad'][s
                                      .nivel],
                              color:
                                  [
                                    pal.accent,
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.amberAccent
                                        : Colors.orange.shade900,
                                    pal.chipRed,
                                  ][s.nivel],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),
            detalle: estado(
              () => datosNc(
                (f) => TablaSaludClientes(
                  datos: saludClientes(
                    kardex!,
                    movimientos,
                    f,
                    corte: widget.datos.corte,
                    semanas: widget.semanas,
                  ),
                ),
              ),
            ),
          ),
          tile(
            'Mapa de OP · estado actual',
            'Cada OP cuenta una vez en la primera etapa pendiente entre sus líneas vigentes. Producción incluye no conformes pendientes. Después: recepción, despacho y completo. Se excluyen líneas eliminadas. El cliente filtra las OP; el período no cambia su estado actual.',
            estado(() {
              final etapas = contarEtapas(kardex!);
              return Column(
                children: [
                  Text(
                    '${etapas.take(3).fold(0, (a, b) => a + b)} activas · ${etapas[3]} completas',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder:
                        (_, box) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                width: (box.maxWidth - 24) / 4,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.accent.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${etapas[i]}',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                    ),
                                    Text(
                                      etapasDashboard[i],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                  ),
                ],
              );
            }),
          ),
          tile(
            'Atención requerida',
            'Ordena vencimientos y pendientes antiguos antes de fechas próximas. Sobrantes: días desde creación, aún pendientes. NC: saldo pendiente actual y días desde último reporte o liberación de la línea; no es la edad de cada unidad. Sin fecha o enlace no se infiere antigüedad. Aplica cliente; no el período de las gráficas.',
            estado(
              () => datosAud((f) {
                final alertas = calcularAtencion(
                  kardex!,
                  f,
                  corte: widget.datos.corte,
                  proximos: proximos,
                  antiguedad: antiguedad,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      children: [
                        DropdownButton<int>(
                          value: proximos,
                          isDense: true,
                          items: [
                            for (final n in [1, 3, 7])
                              DropdownMenuItem(
                                value: n,
                                child: Text(
                                  'Próximos $n días',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => proximos = v!),
                        ),
                        DropdownButton<int>(
                          value: antiguedad,
                          isDense: true,
                          items: [
                            for (final n in [3, 7, 14, 30])
                              DropdownMenuItem(
                                value: n,
                                child: Text(
                                  'Pendientes > $n días',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => antiguedad = v!),
                        ),
                      ],
                    ),
                    Text(
                      '${alertas.length} alertas',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (alertas.isEmpty)
                      const Text(
                        'Sin alertas detectadas con estos criterios.',
                        style: TextStyle(fontSize: 11),
                      ),
                    for (final a in alertas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              a.urgente ? Icons.error_outline : Icons.schedule,
                              size: 16,
                              color: a.urgente ? pal.chipRed : pal.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${a.titulo}\n${a.detalle}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ];
        Widget fila(List<int> indices, List<int> pesos) => SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < indices.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(flex: pesos[i], child: cards[indices[i]]),
              ],
            ],
          ),
        );
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Resumen ejecutivo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(
                      width: 185,
                      child: DropdownButtonFormField<int>(
                        initialValue: widget.semanas,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Período'),
                        items: [
                          for (final n in [4, 8, 12, 26])
                            DropdownMenuItem(
                              value: n,
                              child: Text(
                                'Últimas $n semanas',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        onChanged: (v) => widget.cambiarSemanas(v!),
                      ),
                    ),
                    SizedBox(
                      width: 225,
                      child: DropdownButtonFormField<String>(
                        initialValue: cliente,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos los clientes'),
                          ),
                          for (final n in clientes)
                            DropdownMenuItem(
                              value: n,
                              child: Text(n, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => cliente = v),
                      ),
                    ),
                    Text(
                      'Corte ${fechaCorta(fechaReporte(widget.datos.corte.toIso8601String())!)} · Solo lectura',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (desktop) ...[
                  fila([0, 1, 2], [2, 1, 1]),
                  const SizedBox(height: 12),
                  fila([3, 4, 5], [1, 1, 1]),
                  const SizedBox(height: 12),
                  fila([6, 7], [1, 1]),
                ] else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in cards)
                        SizedBox(
                          width:
                              c.maxWidth >= 700
                                  ? (c.maxWidth - 44) / 2
                                  : c.maxWidth - 32,
                          height: rowHeight,
                          child: card,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PanelResumen extends StatelessWidget {
  const PanelResumen({
    super.key,
    required this.titulo,
    required this.ayuda,
    required this.child,
    this.detalle,
  });
  final String titulo, ayuda;
  final Widget child;
  final Widget? detalle;
  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.card,
        border: Border.all(color: pal.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (detalle != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ampliar $titulo',
                  icon: const Icon(Icons.open_in_full, size: 16),
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (context) => Dialog(
                              child: SizedBox(
                                width: 1100,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        tooltip: 'Cerrar detalle',
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        child: detalle!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Cómo se calcula: $titulo',
                icon: const Icon(Icons.help_outline, size: 18),
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(titulo),
                            content: Text(ayuda),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _CausalesCompactas extends StatelessWidget {
  const _CausalesCompactas({required this.datos, required this.alto});
  final List<CausalComparada> datos;
  final double alto;
  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return const Text('Sin no conformidades registradas.');
    final pal = palOf(context);
    final maximo = datos.map((c) => c.historico).reduce(math.max);
    final altura = math.max(40.0, alto - 58);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            Text(
              '● 4 semanas',
              style: TextStyle(fontSize: 10, color: pal.accent),
            ),
            Text(
              '● Histórico',
              style: TextStyle(fontSize: 10, color: coloresSeries(context)[1]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in datos)
                SizedBox(
                  width: 95,
                  child: Column(
                    children: [
                      SizedBox(
                        height: altura + 18,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 2; i++)
                              SizedBox(
                                width: 42,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${i == 0 ? c.recientes : c.historico}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Container(
                                      width: 19,
                                      height:
                                          (i == 0 ? c.recientes : c.historico) /
                                          maximo *
                                          altura,
                                      color:
                                          i == 0
                                              ? pal.accent
                                              : coloresSeries(context)[1],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          c.nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

