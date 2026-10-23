import 'package:orbiloq_wms/shared/widgets/bienvenida_usuario.dart';
import 'dashboard_facturacion_semanal.dart';
import '../../../application/dashboard_despachos_mensuales.dart';
import 'dashboard_despachos_mensuales.dart';
import '../../../application/dashboard_flujo_acumulado.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import '../../../shared/widgets/wms_dialog.dart';
import 'dashboard_volumen_barras.dart';
import 'dashboard_calendario.dart';
import '../../../application/dashboard_periodo.dart';
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
import '../../../shared/widgets/wms_loader.dart';
import 'dashboard_ejecutivo_page.dart';
import 'dashboard_recepcion_section.dart';
import 'dashboard_enfoque_section.dart';

class DashboardResumen extends ConsumerStatefulWidget {
  const DashboardResumen({
    super.key,
    required this.datos,
    required this.semanas,
    this.periodo,
    required this.cambiarSemanas,
    this.cambiarPeriodo,
  });
  final DatosDashboard datos;
  final int semanas;
  final PeriodoDashboard? periodo;
  final ValueChanged<int> cambiarSemanas;
  final ValueChanged<PeriodoDashboard>? cambiarPeriodo;
  @override
  ConsumerState<DashboardResumen> createState() => _DashboardResumenState();
}

class _DashboardResumenState extends ConsumerState<DashboardResumen> {
  String? cliente;
  bool _porSemana = true;
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
      periodo: widget.periodo,
    );
    final volumen = volumenClientes(
      movimientos,
      corte: widget.datos.corte,
      semanas: widget.semanas,
      periodo: widget.periodo,
    );
    final kardex =
        snapshot.value?.kardex
            .where(
              (k) =>
                  cliente == null ||
                  clienteDashboard(k.item.cliente) == cliente,
            )
            .toList();
    final diaCorte = fechaReporte(widget.datos.corte.toIso8601String())!;
    final desdeDespachos =
        widget.periodo?.inicio ??
        diaCorte.subtract(
          Duration(days: 7 * (widget.semanas - 1) + diaCorte.weekday - 1),
        );
    final hastaDespachos = widget.periodo?.fin ?? diaCorte;
    final filtroDespachos = (
      desde: desdeDespachos.toIso8601String().substring(0, 10),
      hasta: hastaDespachos.toIso8601String().substring(0, 10),
      cliente: cliente,
      corte: widget.datos.corte.toUtc().toIso8601String(),
    );
    final despachosMes = ref.watch(despachosMensualesProvider(filtroDespachos));
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
      periodo: widget.periodo,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
        final desktop = c.maxWidth >= 1050 && escala <= 1.3;
        final rowHeight = desktop ? 250.0 : 290.0;
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
            _porSemana ? 'Volumen por semana' : 'Volumen por día',
            'Unidades positivas entregadas por Producción, recibidas y despachadas en Bogotá, agrupadas por día o semana. Excluye ajustes administrativos y movimientos inversos. El día actual puede estar incompleto. El cliente y el período seleccionados se aplican a las tres series.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Text(
                            '${nombresSeries[i]}  ${numero(tendencia.totales[i])}',
                            style: TextStyle(
                              fontSize: 11,
                              color: DashboardVolumenBarras.colores(context)[i],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Día')),
                        ButtonSegment(value: true, label: Text('Semana')),
                      ],
                      selected: {_porSemana},
                      onSelectionChanged:
                          (v) => setState(() => _porSemana = v.single),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                DashboardVolumenBarras(
                  datos: tendencia.semanas,
                  porSemana: _porSemana,
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
            'Tasa = unidades sobrantes registradas / unidades recibidas del período × 100; puede superar 100 %. Resolución = promedio de días entre creación y resolución de los registros resueltos dentro del período. Las mini líneas son diarias; los huecos indican falta de base.',
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
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
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
                                (context) => WmsExpandableAlertDialog(
                                  title: Text(label),
                                  content: Text(
                                    sufijo == '%'
                                        ? 'Unidades sobrantes registradas divididas entre unidades recibidas en el período, por 100. Puede superar el 100 %. La mini línea muestra la tasa por día; sin recepción base no se calcula.'
                                        : 'Promedio por registro de los días entre creación y resolución. Incluye registros resueltos en el período aunque se hayan creado antes. Excluye pendientes. La mini línea agrupa por día de resolución.',
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
            'Despachos por cliente',
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
                                minHeight: 5,
                                color:
                                    DashboardVolumenBarras.colores(
                                      context,
                                    ).first,
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
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${(100 * e.value / volumen.values.fold<int>(0, (a, b) => a + b)).toStringAsFixed(0)} %',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: pal.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          ),
          tile(
            'Causales de no conformidad',
            'Unidades reportadas en Logística y Aliados, agrupadas por causal. Compara el período seleccionado (lunes a viernes) con todo el histórico hasta el corte. El histórico incluye el período seleccionado. El filtro de cliente también aplica. Una prenda puede tener varios reportes.',
            datosNc(
              (f) => _CausalesCompactas(
                datos: compararCausales(
                  f,
                  widget.datos.corte,
                  periodo: widget.periodo,
                ),
                alto: rowHeight - 90,
              ),
            ),
          ),
          tile(
            'Puntualidad de despachos por mes',
            'Cuenta cada LE liberada una vez, por mes de salida de bodega (Bogotá, lunes a viernes), con el cliente y período seleccionados. A tiempo: salida en o antes de todas las fechas esperadas de Logística de sus OP. Con retraso: supera al menos una. Si falta alguna fecha o vínculo, solo cuenta en total y sin fecha esperada. Usa los plazos actuales; no mide entrega al cliente ni reconstruye cambios históricos de las metas.',
            ref
                .watch(puntualidadMensualProvider(filtroDespachos))
                .when(
                  loading:
                      () => const WmsLoadingStrip(
                        label: 'Consultando puntualidad…',
                      ),
                  error:
                      (_, __) => Column(
                        children: [
                          const Text(
                            'No se pudo consultar puntualidad. Verifica la migración SQL 100.',
                          ),
                          TextButton(
                            onPressed:
                                () => ref.invalidate(
                                  puntualidadMensualProvider(filtroDespachos),
                                ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                  data:
                      (datos) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              for (final e
                                  in [
                                    'Total',
                                    'A tiempo',
                                    'Con retraso',
                                  ].asMap().entries)
                                Text(
                                  '● ${e.value}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        DashboardDespachosMensuales.colores(
                                          context,
                                        )[e.key],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DashboardDespachosMensuales(
                            key: const ValueKey('puntualidad-mensual'),
                            datos: datos,
                            claves: const ['total', 'a_tiempo', 'con_retraso'],
                            nombres: const [
                              'Total de despachos',
                              'Completados a tiempo',
                              'Completados con retraso',
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fecha de salida vs. fecha esperada de Logística',
                            style: TextStyle(fontSize: 10),
                          ),
                          for (final d in datos.where(
                            (d) => (d['sin_fecha'] as num) > 0,
                          ))
                            Text(
                              '${d['mes'].toString().substring(0, 7)}: ${d['sin_fecha']} sin fecha esperada completa',
                              style: const TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                ),
          ),
          tile(
            'Despachos por mes',
            'Cuenta cada despacho confirmado una vez, por mes de salida en Bogotá. Total incluye todos los estados; sin contratiempo corresponde a Entregado y con contratiempo a Entregado con novedad. En tránsito y devoluciones solo cuentan en el total. Usa el estado actual de la revisión vigente, cliente y fechas seleccionados (lunes a viernes). No cuenta prendas ni mide puntualidad.',
            despachosMes.when(
              loading:
                  () => const WmsLoadingStrip(label: 'Consultando despachos…'),
              error:
                  (_, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo consultar el reporte de despachos. Verifica la migración SQL 096.',
                      ),
                      TextButton(
                        onPressed:
                            () => ref.invalidate(
                              despachosMensualesProvider(filtroDespachos),
                            ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
              data:
                  (datos) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          for (final entry
                              in [
                                'Total',
                                'Sin contratiempo',
                                'Con contratiempo',
                              ].asMap().entries)
                            Text(
                              '● ${entry.value}',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    DashboardDespachosMensuales.colores(
                                      context,
                                    )[entry.key],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DashboardDespachosMensuales(datos: datos),
                    ],
                  ),
            ),
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
                    _AlertasResumen(alertas: alertas),
                  ],
                );
              }),
            ),
          ),
        ];
        cards.add(
          tile(
            'Facturación de despachos semanales',
            'Cuenta despachos únicos por semana de salida (lunes a viernes, Bogotá), dentro del período y cliente seleccionados. Completada usa el estado actual de Facturación: entrega registrada, LE, OC, remisión e ID OC completos en la revisión vigente. Pendientes incluye despachos todavía no entregados. No cuenta prendas ni facturas fiscales emitidas.',
            DashboardFacturacionSemanal(filtro: filtroDespachos),
          ),
        );
        Widget valor(String numero, String pie, {Color? color}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              numero,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color ?? pal.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pie,
              style: TextStyle(fontSize: 10, color: color ?? pal.textMuted),
            ),
          ],
        );
        final flujo = FlujoAcumulado(kardex ?? []);
        final kpis = <(String, Widget)>[
          (
            'Unidades pedidas',
            estado(() => valor(numero(flujo.pedidas), 'Total solicitado')),
          ),
          (
            'Entregado a Logística',
            estado(
              () => valor(
                numero(flujo.entregado),
                '${porcentajeFlujo(flujo.entregado, flujo.pedidas)} de lo pedido',
              ),
            ),
          ),
          (
            'Pendiente por entregar a Logística',
            estado(
              () => valor(
                numero(flujo.pendienteEntrega),
                '${porcentajeFlujo(flujo.pendienteEntrega, flujo.pedidas)} de lo pedido',
                color: const Color(0xff9a7800),
              ),
            ),
          ),
          (
            'Recibido en Bodega',
            estado(
              () => valor(
                numero(flujo.recibido),
                '${porcentajeFlujo(flujo.recibido, flujo.entregado)} de lo entregado',
                color: const Color(0xff158568),
              ),
            ),
          ),
          (
            'Despachadas',
            estado(
              () => valor(
                numero(flujo.despachado),
                '${porcentajeFlujo(flujo.despachado, flujo.recibido)} de lo recibido',
              ),
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
                const BienvenidaUsuario(),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Resumen ejecutivo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Corte ${fechaCorta(fechaReporte(widget.datos.corte.toIso8601String())!)} · Solo lectura',
                          style: TextStyle(fontSize: 10, color: pal.textMuted),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.periodo != null)
                          DashboardCalendario(
                            periodo: widget.periodo!,
                            onChanged: widget.cambiarPeriodo ?? (_) {},
                          ),
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            initialValue: cliente,
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cliente',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todos los clientes'),
                              ),
                              for (final n in clientes)
                                DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                    n,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => cliente = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Acumulado · ${cliente ?? 'Todos los clientes'} · OP vigentes · Sin recorte por fechas',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, box) {
                    final columnas =
                        box.maxWidth >= 1000 && escala <= 1.3
                            ? 5
                            : box.maxWidth >= 600
                            ? 3
                            : 2;
                    final ancho = (box.maxWidth - 2) / columnas;
                    return Container(
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pal.cardBorder),
                      ),
                      child: Wrap(
                        spacing: 0,
                        runSpacing: 0,
                        children: [
                          for (final k in kpis)
                            SizedBox(
                              width: ancho,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 86,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.card,
                                  border: Border(
                                    right: BorderSide(
                                      color: pal.cardBorder.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      k.$1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    k.$2,
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (desktop) ...[
                  fila([0, 6], [2, 1]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[3]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[8]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[5]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 200, child: cards[7]),
                ] else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final i in [0, 6, 3, 8, 5, 7])
                        SizedBox(
                          width:
                              c.maxWidth >= 700 && escala <= 1.3
                                  ? (c.maxWidth - 44) / 2
                                  : c.maxWidth - 32,
                          height: i == 0 ? 320 : 290,
                          child: cards[i],
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
                            (context) => WmsDialogShell(
                              title: titulo,
                              closeTooltip: 'Cerrar detalle',
                              icon: Icons.analytics_outlined,
                              iconColor: const Color(0xff123e4f),
                              maxWidth: 1100,
                              child: detalle!,
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
                          (context) => WmsExpandableAlertDialog(
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
    if (datos.isEmpty) {
      return const Text(
        'Sin no conformidades registradas.',
        style: TextStyle(fontSize: 11),
      );
    }
    final pal = palOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Causales de novedad',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: pal.cardBorder.withValues(alpha: .5),
            ),
          ),
          children: [
            const TableRow(
              children: [
                Text('Causal', style: TextStyle(fontSize: 10)),
                Text(
                  'Período',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10),
                ),
                Text(
                  'Histórico',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            for (final c in datos)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(c.nombre, style: const TextStyle(fontSize: 11)),
                  ),
                  Text(
                    '${c.recientes}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    '${c.historico}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _AlertasResumen extends StatelessWidget {
  const _AlertasResumen({required this.alertas});
  final List<AlertaDashboard> alertas;

  Widget tabla(BuildContext context, List<AlertaDashboard> filas) {
    final pal = palOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 650 ||
            MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
            children: [
              for (final a in filas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    a.titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    a.detalle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          );
        }
        return Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(4),
            2: FixedColumnWidth(100),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: pal.cardBorder.withValues(alpha: .5),
            ),
          ),
          children: [
            const TableRow(
              children: [
                Text('OP / Área / Cliente', style: TextStyle(fontSize: 10)),
                Text('Pendiente', style: TextStyle(fontSize: 10)),
                Text(
                  'Antigüedad / plazo',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            for (final a in filas)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(a.titulo, style: const TextStyle(fontSize: 11)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      a.detalle,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Text(
                    a.dias > 0
                        ? '${a.dias} días'
                        : a.dias == 0
                        ? 'Hoy'
                        : 'En ${-a.dias} días',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: a.urgente ? pal.chipRed : pal.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (alertas.isNotEmpty) tabla(context, alertas.take(2).toList()),
      if (alertas.length > 2)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                () => showWmsDialog<void>(
                  context,
                  (context) => WmsDialogShell(
                    title: 'Atención requerida · ${alertas.length} alertas',
                    closeTooltip: 'Cerrar alertas',
                    icon: Icons.warning_amber_rounded,
                    iconColor: palOf(context).chipRed,
                    maxWidth: 1100,
                    child: SingleChildScrollView(
                      child: tabla(context, alertas),
                    ),
                  ),
                ),
            child: Text(
              'Ver las ${alertas.length} alertas',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
    ],
  );
}
