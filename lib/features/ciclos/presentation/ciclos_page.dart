import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../../shared/widgets/boton_plantilla_excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/ciclos_providers.dart';
import '../../../application/dashboard_acceso.dart';
import '../../../domain/ciclos.dart';
import '../../../domain/ciclos_indicadores.dart';
import '../../../domain/sesion.dart';
import 'ciclos_charts.dart';
import 'ciclos_colores.dart';
import 'capacidad_medidor.dart';
import '../../../application/providers.dart' show temaProvider;
import '../../../core/theme/app_theme.dart' show TemaModo;
import 'grafica_intercambiable.dart';
import 'ciclos_editores.dart';
import 'ciclos_resumen_compacto.dart';

class CiclosPage extends ConsumerStatefulWidget {
  const CiclosPage({super.key});
  @override
  ConsumerState<CiclosPage> createState() => _CiclosState();
}

class _CiclosState extends ConsumerState<CiclosPage> {
  DateTimeRange? _periodo;
  DateTime? _diaCarga;
  String? _cliente;
  String _busqueda = '';
  bool _semanal = false, _ocupado = false;
  ProcesoCiclo _tendencia = ProcesoCiclo.compras;
  int _pagina = 0, _vista = 0;
  Future<void> _accion(Future<void> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) {
        mostrarAvisoSnack(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(dashboardAccesoProvider).$2;
    if (!(rol?.puedeVerDashboards ?? false)) {
      return const Scaffold(
        body: Center(child: Text('Sin acceso a dashboards.')),
      );
    }
    final estado = ref.watch(ciclosProvider), datos = estado.value;
    final repo = ref.watch(ciclosRepositoryProvider);
    return Scaffold(
      backgroundColor:
          CiclosColores.oscuro(context) ? CiclosColores.fondo : null,
      appBar: AppBar(
        backgroundColor:
            CiclosColores.oscuro(context) ? const Color(0xff101e32) : null,
        surfaceTintColor: Colors.transparent,
        shape:
            CiclosColores.oscuro(context)
                ? const Border(bottom: BorderSide(color: CiclosColores.borde))
                : null,
        title: const Text('Tiempos de ciclo por proceso'),
        actions: [
          IconButton(
            tooltip:
                ref.watch(temaProvider) == TemaModo.oscuro
                    ? 'Cambiar a vista clara'
                    : 'Cambiar a vista oscura',
            onPressed: () => ref.read(temaProvider.notifier).alternar(),
            icon: Icon(
              ref.watch(temaProvider) == TemaModo.oscuro
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _ocupado ? null : () => ref.invalidate(ciclosProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar los ciclos.\n$e'),
              ),
            ),
        data:
            (d) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (rol == RolCuenta.admin)
                      BotonPlantillaExcel(tipo: PlantillaExcel.ciclos, habilitado: !_ocupado),
                    if (rol == RolCuenta.admin)
                      FilledButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importar históricos Excel'),
                        onPressed:
                            _ocupado || repo == null
                                ? null
                                : () => _accion(() async {
                                  if (await importarCiclos(context, repo, d)) {
                                    ref.invalidate(ciclosProvider);
                                  }
                                }),
                      ),
                    if (rol == RolCuenta.admin)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune),
                        label: const Text('Parámetros'),
                        onPressed:
                            _ocupado || repo == null
                                ? null
                                : () => _accion(() async {
                                  await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder:
                                        (_) => ParametrosCiclosDialog(
                                          repo: repo,
                                          datos: d,
                                        ),
                                  );
                                  ref.invalidate(ciclosProvider);
                                }),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _periodo == null
                            ? 'Histórico: todas las fechas'
                            : '${fechaCiclo(_periodo!.start)} — ${fechaCiclo(_periodo!.end)}',
                      ),
                      onPressed: () async {
                        final p = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(
                            d.hoy.year,
                            d.hoy.month,
                            d.hoy.day,
                          ),
                          initialDateRange: _periodo,
                        );
                        if (p != null && mounted) {
                          setState(() {
                            _periodo = DateTimeRange(
                              start: diaCiclo(p.start),
                              end: diaCiclo(p.end),
                            );
                            _pagina = 0;
                          });
                        }
                      },
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_cliente),
                        initialValue: _cliente,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos los clientes'),
                          ),
                          for (final c
                              in (d.ordenes
                                  .map((o) => o.cliente)
                                  .toSet()
                                  .toList()
                                ..sort()))
                            DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged:
                            (v) => setState(() {
                              _cliente = v;
                              _pagina = 0;
                            }),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => setState(() {
                            _cliente = null;
                            _periodo = null;
                            _pagina = 0;
                          }),
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ),
                if (_ocupado) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var n = 0; n < 3; n++)
                      ChoiceChip(
                        label: Text(
                          ['Resumen', 'Capacidad', 'Detalle por OP'][n],
                        ),
                        selected: _vista == n,
                        onSelected: (_) => setState(() => _vista = n),
                      ),
                    const Tooltip(
                      message:
                          'Históricos independientes del kardex. Días hábiles de Colombia. El período filtra la finalización de cada proceso; el ciclo total usa Logística. Solo las finalizaciones completas liberan la OP al siguiente proceso.',
                      child: Icon(Icons.info_outline, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._contenido(datos ?? d),
              ],
            ),
      ),
    );
  }

  Widget _panel(String titulo, String ayuda, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: CiclosColores.oscuro(context) ? CiclosColores.panel : null,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color:
            CiclosColores.oscuro(context)
                ? CiclosColores.borde
                : const Color(0xffd8e2ec),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: ayuda,
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
                icon: const Icon(Icons.help_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
  List<Widget> _contenido(DatosCiclos d) {
    final i = IndicadoresCiclos(
      d,
      desde: _periodo?.start,
      hasta: _periodo?.end,
      cliente: _cliente,
    );
    final completas = i.completas, duraciones = completas.map(i.duracionTotal);
    final detalles =
        i.ordenes
            .where(
              (o) =>
                  (_busqueda.isEmpty ||
                      o.op.toLowerCase().contains(_busqueda.toLowerCase())) &&
                  (_periodo == null || [o.inicio, ...o.fines].any(i.enPeriodo)),
            )
            .toList()
          ..sort((a, b) => a.op.compareTo(b.op));
    final pagina = _pagina.clamp(
      0,
      detalles.isEmpty ? 0 : (detalles.length - 1) ~/ 20,
    );
    return [
      if (_vista == 0)
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metrica('OP completas', '${completas.length}'),
            _metrica('P50 total', _numero(percentil(duraciones, .5), ' días')),
            _metrica('P80 total', _numero(percentil(duraciones, .8), ' días')),
            _metrica(
              'Cumplimiento histórico',
              _numero(i.cumplimientoTotal, '%'),
            ),
            _metrica(
              'Promesa actual',
              i.objetivoActual == null
                  ? 'Sin configurar'
                  : '${i.objetivoActual} días',
            ),
          ],
        ),
      const SizedBox(height: 8),
      if (d.ordenes.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Aún no hay históricos. Administración puede configurar las vigencias e importar el Excel.',
          ),
        ),
      if (_vista == 0)
        CiclosResumenCompacto(
          key: ValueKey('$_cliente/$_periodo'),
          indicadores: i,
        ),
      if (_vista == 1) _carga(d, i),
      if (_vista == 2)
        _panel(
          'Trazabilidad por OP',
          'Las fechas vacías siguen vacías. Solo se calcula un vencimiento cuando existe el inicio real y una versión de parámetros. Las OP sin trazabilidad completa no participan del ciclo total. El filtro de fechas conserva OP con algún hito dentro del período.',
          Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Buscar OP'),
                onChanged:
                    (v) => setState(() {
                      _busqueda = v;
                      _pagina = 0;
                    }),
              ),
              for (final o in detalles.skip(pagina * 20).take(20))
                ExpansionTile(
                  title: Text('OP ${o.op} · ${o.cliente}'),
                  subtitle: Text(
                    '${o.cantidad} unidades · ${o.completa ? 'Trazabilidad completa' : 'Trazabilidad incompleta'}',
                  ),
                  children: [
                    for (final p in ProcesoCiclo.values)
                      _detalle(d.medir(o, p)),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed:
                        pagina == 0
                            ? null
                            : () => setState(() => _pagina = pagina - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${detalles.length} OP · Página ${pagina + 1}'),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed:
                        (pagina + 1) * 20 >= detalles.length
                            ? null
                            : () => setState(() => _pagina = pagina + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _metrica(String titulo, String valor) => SizedBox(
    width:
        MediaQuery.sizeOf(context).width >= 1100
            ? (MediaQuery.sizeOf(context).width - 72) / 5
            : 205,
    child: Card(
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      elevation: CiclosColores.oscuro(context) ? 4 : 1,
      shadowColor: Colors.black.withValues(alpha: .2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: CiclosColores.bien(context).withValues(alpha: .25),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                CiclosColores.oscuro(context)
                    ? CiclosColores.superficie(context)
                    : const [Colors.white, Color(0xffedf3f8)],
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String _numero(double? v, String unidad) =>
      v == null ? 'Sin datos' : '${v.toStringAsFixed(1)}$unidad';
  DateTime _minFecha(DateTime a, DateTime? b) =>
      b != null && b.isBefore(a) ? b : a;
  Widget _detalle(MedicionCiclo m) {
    String f(DateTime? d) => d == null ? '—' : fechaCiclo(d);
    final pendiente = m.inicio != null && m.fin == null && m.esperada != null;
    final dias =
        pendiente
            ? m.calendario.transcurridos(
              m.hoy.isAfter(m.esperada!) ? m.esperada! : m.hoy,
              m.hoy.isAfter(m.esperada!) ? m.hoy : m.esperada!,
            )
            : null;
    return ListTile(
      title: Text('${m.proceso.titulo} · ${m.estado}'),
      subtitle: Text(
        'Inicio: ${f(m.inicio)} · Fin: ${f(m.fin)} · Esperada: ${f(m.esperada)}\n${m.duracion == null ? 'Duración real: —' : 'Duración real: ${m.duracion} días hábiles'}${dias == null ? '' : ' · ${m.hoy.isAfter(m.esperada!) ? 'Retraso' : 'Restantes'}: $dias días'} · Objetivo: ${m.parametro?.dias ?? '—'}',
      ),
    );
  }

  Widget _carga(DatosCiclos d, IndicadoresCiclos i) {
    final dia = _diaCarga ?? d.hoy;
    final desde =
        _semanal ? dia.subtract(Duration(days: dia.weekday - 1)) : dia;
    final fin = _semanal ? desde.add(const Duration(days: 6)) : dia;
    final hasta = fin.isAfter(d.hoy) ? d.hoy : fin;
    return _panel(
      'Carga disponible y capacidad',
      'Cola inicial + entradas liberadas = carga por atender. Menos las salidas completas = cola final. La carga semanal se calcula una sola vez, no suma las colas diarias. Capacidad semanal es un límite independiente, sin prorrata por festivos. Si cambia la versión en la semana, consulta por día. Estos datos reflejan el último Excel, no una programación futura.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(fechaCiclo(dia)),
                onPressed: () async {
                  final v = await showDatePicker(
                    context: context,
                    initialDate: dia,
                    firstDate: DateTime(1900),
                    lastDate: d.hoy,
                  );
                  if (v != null && mounted) {
                    setState(() => _diaCarga = diaCiclo(v));
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Diaria'),
                selected: !_semanal,
                onSelected: (_) => setState(() => _semanal = false),
              ),
              ChoiceChip(
                label: const Text('Semanal'),
                selected: _semanal,
                onSelected: (_) => setState(() => _semanal = true),
              ),
            ],
          ),
          Text(
            '${fechaCiclo(desde)} — ${fechaCiclo(hasta)} · Filtro de cliente aplicado. El período histórico de arriba no limita las colas.',
          ),
          if (!_semanal && !d.calendario.habil(dia))
            const Text('Día no hábil: no se compara capacidad diaria.'),
          if (_semanal && fin.isAfter(d.hoy))
            const Text(
              'Semana en curso: carga registrada hasta hoy frente al límite semanal completo.',
            ),
          const SizedBox(height: 12),
          const Text(
            'Carga / capacidad · Verde: hasta 80 % · Ámbar: hasta 100 % · Rojo: excedida',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
              final columnas =
                  escala > 1.3
                      ? 1
                      : box.maxWidth >= 1080
                      ? 7
                      : box.maxWidth >= 800
                      ? 3
                      : box.maxWidth >= 520
                      ? 2
                      : 1;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in ProcesoCiclo.values)
                    SizedBox(
                      width: (box.maxWidth - 12 * (columnas - 1)) / columnas,
                      child: _tarjetaCarga(d, i, p, desde, hasta, fin),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text(
              'Ver tendencia de capacidad',
              style: TextStyle(fontSize: 13),
            ),
            children: [
              DropdownButton<ProcesoCiclo>(
                isExpanded: true,
                value: _tendencia,
                items: [
                  for (final p in ProcesoCiclo.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text('Tendencia · ${p.titulo}'),
                    ),
                ],
                onChanged: (p) => setState(() => _tendencia = p!),
              ),
              const Text(
                'Carga por atender en las últimas seis semanas (incluye la cola al inicio de cada semana).',
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final lunes = dia.subtract(Duration(days: dia.weekday - 1));
                  final semanas = [
                    for (var n = 5; n >= 0; n--)
                      lunes.subtract(Duration(days: n * 7)),
                  ];
                  final original = LineasCiclos(
                    etiquetas: [for (final s in semanas) fechaCiclo(s)],
                    nombres: [
                      'Carga (${_tendencia.unidad})',
                      'Capacidad semanal',
                    ],
                    series: [
                      [
                        for (final s in semanas)
                          CargaCiclo.calcular(
                            i.ordenes,
                            _tendencia,
                            s,
                            _minFecha(s.add(const Duration(days: 6)), d.hoy),
                          ).porAtender.toDouble(),
                      ],
                      [
                        for (final s in semanas)
                          i
                              .capacidad(
                                _tendencia,
                                s,
                                s.add(const Duration(days: 6)),
                                semanal: true,
                              )
                              ?.toDouble(),
                      ],
                    ],
                  );
                  return GraficaIntercambiable(
                    titulo: 'Tendencia de capacidad',
                    datos: DatosGrafica(
                      original.etiquetas,
                      original.series.first,
                      metas: original.series.last,
                      unidad: _tendencia.unidad,
                    ),
                    original: original,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCarga(
    DatosCiclos d,
    IndicadoresCiclos i,
    ProcesoCiclo p,
    DateTime desde,
    DateTime hasta,
    DateTime fin,
  ) {
    final c = CargaCiclo.calcular(i.ordenes, p, desde, hasta),
        cap = i.capacidad(p, desde, fin, semanal: _semanal);
    final uso = cap == null ? null : 100 * c.porAtender / cap;
    final color =
        uso == null
            ? CiclosColores.neutro(context)
            : uso <= 80
            ? CiclosColores.bien(context)
            : uso <= 100
            ? CiclosColores.alerta(context)
            : CiclosColores.error(context);
    return Card(
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      elevation: CiclosColores.oscuro(context) ? 4 : 1,
      shadowColor: Colors.black.withValues(alpha: .2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              CiclosColores.oscuro(context)
                  ? color.withValues(alpha: .3)
                  : const Color(0xffd8e2ec),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                CiclosColores.oscuro(context)
                    ? CiclosColores.superficie(context)
                    : const [Color(0xfff6f8fb), Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xff65b8ed).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.index + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      color:
                          CiclosColores.oscuro(context)
                              ? const Color(0xff8bc9f2)
                              : const Color(0xff24476a),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  uso == null
                      ? Icons.remove_circle_outline
                      : uso > 100
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: color,
                  size: 18,
                ),
              ],
            ),
            CapacidadMedidor(porcentaje: uso, compacto: true),
            const SizedBox(height: 10),
            Text(
              '${c.porAtender} ${p.unidad} por atender',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              cap == null ? 'Capacidad: —' : 'Capacidad: $cap ${p.unidad}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            if (uso != null && uso > 100)
              Text(
                'Exceso: ${c.porAtender - cap!} ${p.unidad}',
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Ver desglose', style: TextStyle(fontSize: 12)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cola inicial: ${c.inicial}\nLiberadas: ${c.entradas}\nFinalizadas: ${c.salidas}\nCola final: ${c.finalPendiente}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (p == ProcesoCiclo.corte || p == ProcesoCiclo.separado)
                  Text('${c.ordenesTerminadas} OP finalizadas'),
                if (!_semanal &&
                    p == ProcesoCiclo.trazo &&
                    parametroVigente(d.parametros, p, hasta)?.umbralCola !=
                        null)
                  Text(
                    'Cola final: ${c.finalPendiente} / ${parametroVigente(d.parametros, p, hasta)!.umbralCola} OP de umbral',
                    style: TextStyle(
                      color:
                          c.finalPendiente >
                                  parametroVigente(
                                    d.parametros,
                                    p,
                                    hasta,
                                  )!.umbralCola!
                              ? CiclosColores.error(context)
                              : CiclosColores.bien(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
