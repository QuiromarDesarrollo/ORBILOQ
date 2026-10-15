import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/ciclos.dart';
import '../../../domain/ciclos_indicadores.dart';
import 'ciclos_colores.dart';
import 'grafica_intercambiable.dart';
import 'ciclos_prioridades_card.dart';

/// Vista de lectura: comparte los cálculos y filtros del dashboard detallado.
class CiclosResumenCompacto extends StatefulWidget {
  const CiclosResumenCompacto({super.key, required this.indicadores});
  final IndicadoresCiclos indicadores;
  @override
  State<CiclosResumenCompacto> createState() => _ResumenState();
}

class _ResumenState extends State<CiclosResumenCompacto> {
  bool _p80 = true, _actual = false;
  TipoGrafica? _tipoRuta;
  int _mesPagina = 0;
  Map<String, DatosGrafica> _graficas = {};
  Widget? _navegacionMeses;
  final _mensuales = <DateTime, IndicadoresCiclos>{};
  @override
  void didUpdateWidget(CiclosResumenCompacto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.indicadores, widget.indicadores)) {
      _mensuales.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.indicadores, d = i.datos;
    final completas = i.completas;
    final evaluables =
        completas.where((o) => d.objetivoTotal(o) != null).toList();
    final aTiempo =
        evaluables
            .where((o) => i.duracionTotal(o) <= d.objetivoTotal(o)!)
            .length;
    final mesesConDatos =
        {
            for (final o in completas)
              DateTime.utc(o.fines.last!.year, o.fines.last!.month),
          }.toList()
          ..sort();
    final meses = <DateTime>[
      if (mesesConDatos.isNotEmpty)
        for (
          var m = mesesConDatos.first;
          !m.isAfter(mesesConDatos.last);
          m = DateTime.utc(m.year, m.month + 1)
        )
          m,
    ];
    final offset =
        _mesPagina.clamp(0, math.max(0, (meses.length - 1) ~/ 6)).toInt() * 6;
    final visibles =
        meses.reversed.skip(offset).take(6).toList().reversed.toList();
    final labels = [
      for (final m in visibles)
        '${m.month.toString().padLeft(2, '0')}/${m.year}',
    ];
    final mensual = [
      for (final m in visibles)
        _mensuales.putIfAbsent(
          m,
          () => IndicadoresCiclos(
            d,
            cliente: i.cliente,
            desde: i.desde != null && i.desde!.isAfter(m) ? i.desde : m,
            hasta:
                i.hasta != null &&
                        i.hasta!.isBefore(DateTime.utc(m.year, m.month + 1, 0))
                    ? i.hasta
                    : DateTime.utc(m.year, m.month + 1, 0),
          ),
        ),
    ];
    final duraciones = [
      for (final p in ProcesoCiclo.values)
        i.percentilProceso(p, _p80 ? .8 : .5),
    ];
    final objetivos = [
      for (final p in ProcesoCiclo.values)
        parametroVigente(d.parametros, p, d.hoy)?.dias.toDouble(),
    ];
    final maxDias = [
      ...duraciones,
      ...objetivos,
    ].whereType<double>().fold<double>(1, math.max);
    _graficas = {
      'Duración por proceso': DatosGrafica(
        [for (final p in ProcesoCiclo.values) p.titulo],
        duraciones,
        metas: objetivos,
        unidad: 'días hábiles',
      ),
      'Cumplimiento total': DatosGrafica(
        ['A tiempo', 'Con retraso'],
        evaluables.isEmpty
            ? [null, null]
            : [aTiempo.toDouble(), (evaluables.length - aTiempo).toDouble()],
        unidad: 'OP',
      ),
      'Cumplimiento por proceso': DatosGrafica(
        [for (final p in ProcesoCiclo.values) p.titulo],
        [
          for (final p in ProcesoCiclo.values)
            i.cumplimientoProceso(p, compararActual: _actual),
        ],
        metas: List.filled(7, 85),
        unidad: '%',
        porcentaje: true,
      ),
      'Exceso promedio del plazo (%)': DatosGrafica(
        [
          for (var n = 0; n < labels.length; n++)
            '${labels[n]} · ${mensual[n].atrasosTerminadas.length} OP tardías${mensual[n].cumplimientoTotal == null
                ? ' · sin OP evaluables'
                : mensual[n].atrasosTerminadas.isEmpty
                ? ' · sin atrasos'
                : ''}',
        ],
        [for (final m in mensual) m.excesoPromedioPorcentaje],
        unidad: '% de exceso sobre el plazo',
        porcentaje: true,
      ),
      'Cumplimiento por mes': DatosGrafica(
        labels,
        [for (final m in mensual) m.cumplimientoTotal],
        metas: List.filled(labels.length, 85),
        unidad: '%',
        porcentaje: true,
      ),
      'Capacidad diaria · ${fechaCiclo(d.hoy)}': DatosGrafica(
        [for (final p in ProcesoCiclo.values) p.titulo],
        [
          for (final p in ProcesoCiclo.values)
            i.capacidad(p, d.hoy, d.hoy, semanal: false) == null
                ? null
                : 100 *
                    CargaCiclo.calcular(i.ordenes, p, d.hoy, d.hoy).porAtender /
                    i.capacidad(p, d.hoy, d.hoy, semanal: false)!,
        ],
        metas: List.filled(7, 100),
        unidad: '% de capacidad',
        porcentaje: true,
      ),
    };
    _navegacionMeses = _controlMeses(meses.length, offset);
    final tarjetas = <Widget>[
      _card(
        'Duración por proceso',
        'Días hábiles de procesos finalizados. n = OP evaluadas. Selecciona P50 (mediana) o P80. El marcador indica el objetivo vigente hoy.',
        Column(
          children: [
            Row(
              children: [
                _selector('P50', !_p80, () => setState(() => _p80 = false)),
                _selector('P80', _p80, () => setState(() => _p80 = true)),
                const Spacer(),
                const Text(
                  '│ Meta actual',
                  style: TextStyle(fontSize: 11, height: 1.2),
                ),
              ],
            ),
            for (var n = 0; n < 7; n++)
              _barra(
                '${ProcesoCiclo.values[n].titulo} (${i.terminadas(ProcesoCiclo.values[n]).length})',
                duraciones[n],
                maxDias,
                CiclosColores.paleta(context)[_p80 ? 1 : 0],
                objetivo: objetivos[n],
                suffix: ' d',
              ),
          ],
        ),
      ),
      _card(
        'Cumplimiento total',
        'OP completas evaluables dentro de la suma de sus objetivos históricos + 3 días. Las OP sin parámetros se excluyen del porcentaje; se muestran aparte.',
        Row(
          children: [
            SizedBox(
              width: 135,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: CustomPaint(
                      painter: _Dona(
                        aTiempo,
                        evaluables.length - aTiempo,
                        Theme.of(context).dividerColor,
                        CiclosColores.bien(context),
                        CiclosColores.alerta(context),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        evaluables.isEmpty
                            ? '—'
                            : '${(100 * aTiempo / evaluables.length).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'A tiempo',
                        style: TextStyle(fontSize: 11, height: 1.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leyenda(CiclosColores.bien(context), '$aTiempo a tiempo'),
                  _leyenda(
                    CiclosColores.alerta(context),
                    '${evaluables.length - aTiempo} con retraso',
                  ),
                  Text(
                    '${completas.length - evaluables.length} sin parámetros',
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Meta: 85 %',
                    style: TextStyle(fontSize: 12, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _card(
        'Cumplimiento por proceso',
        'Histórico compara cada OP con su versión asociada. Actual compara las duraciones con el objetivo vigente hoy. Marcador de referencia: 85 %.',
        Column(
          children: [
            Row(
              children: [
                _selector(
                  'Histórico',
                  !_actual,
                  () => setState(() => _actual = false),
                ),
                _selector(
                  'Actual',
                  _actual,
                  () => setState(() => _actual = true),
                ),
                const Spacer(),
                const Text(
                  '│ 85 %',
                  style: TextStyle(fontSize: 11, height: 1.2),
                ),
              ],
            ),
            for (final p in ProcesoCiclo.values)
              _barra(
                p.titulo,
                i.cumplimientoProceso(p, compararActual: _actual),
                100,
                CiclosColores.bien(context),
                objetivo: 85,
                suffix: '%',
              ),
          ],
        ),
      ),
      _card(
        'Exceso promedio del plazo (%)',
        'Promedio de ((duración real − meta histórica) / meta histórica) × 100, solo de OP completas terminadas tarde, con igual peso por OP. Ejemplo: meta 30 días hábiles y duración 36 = 20 % de exceso. La meta es la suma de objetivos asignados + 3 días. Agrupa por mes de finalización. Excluye OP incompletas o sin meta válida. Sin tardías se muestra —. Puede superar 100 %; un valor menor es mejor. No es el porcentaje de OP atrasadas.',
        Column(
          children: [
            if (visibles.isEmpty) const Text('Sin OP completas en el filtro'),
            for (var n = 0; n < visibles.length; n++)
              _barra(
                _graficas['Exceso promedio del plazo (%)']!.etiquetas[n],
                mensual[n].excesoPromedioPorcentaje,
                mensual
                    .map((m) => m.excesoPromedioPorcentaje)
                    .whereType<double>()
                    .fold<double>(1, math.max),
                CiclosColores.alerta(context),
                suffix: ' %',
              ),
          ],
        ),
      ),
      _card(
        'Cumplimiento por mes',
        'Porcentaje de OP completas que cumplieron su promesa histórica. Excluye órdenes sin parámetros. Misma selección de meses que el gráfico de atraso promedio.',
        Column(
          children: [
            const SizedBox(height: 8),
            if (visibles.isEmpty) const Text('Sin OP completas en el filtro'),
            for (var n = 0; n < visibles.length; n++)
              _barra(
                labels[n],
                mensual[n].cumplimientoTotal,
                100,
                CiclosColores.bien(context),
                objetivo: 85,
                suffix: '%',
              ),
            const Text(
              '│ Referencia: 85 %',
              style: TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
      _card(
        'Capacidad diaria · ${fechaCiclo(d.hoy)}',
        'Carga disponible hoy / capacidad diaria: verde ≤80 %, amarillo >80–100 %, rojo >100 %. Gris: sin capacidad comparable o día no hábil. Usa la pestaña Capacidad para elegir otro día, ver semanas y el desglose. Aplica cliente; no el período histórico.',
        Column(
          children: [
            for (final p in ProcesoCiclo.values)
              Builder(
                builder: (context) {
                  final carga = CargaCiclo.calcular(i.ordenes, p, d.hoy, d.hoy),
                      cap = i.capacidad(p, d.hoy, d.hoy, semanal: false);
                  final uso = cap == null ? null : 100 * carga.porAtender / cap;
                  final color =
                      uso == null
                          ? CiclosColores.neutro(context)
                          : uso <= 80
                          ? CiclosColores.bien(context)
                          : uso <= 100
                          ? CiclosColores.alerta(context)
                          : CiclosColores.error(context);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: color, size: 10),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.titulo,
                            style: const TextStyle(fontSize: 12, height: 1.2),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final usos = [
                                for (final proceso in ProcesoCiclo.values)
                                  if (i.capacidad(
                                        proceso,
                                        d.hoy,
                                        d.hoy,
                                        semanal: false,
                                      ) !=
                                      null)
                                    100 *
                                        CargaCiclo.calcular(
                                          i.ordenes,
                                          proceso,
                                          d.hoy,
                                          d.hoy,
                                        ).porAtender /
                                        i.capacidad(
                                          proceso,
                                          d.hoy,
                                          d.hoy,
                                          semanal: false,
                                        )!,
                              ];
                              final escala = usos.fold<double>(100, math.max);
                              return SizedBox(
                                height: 12,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (uso ?? 0) / escala,
                                        minHeight: 5,
                                        color: color,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).dividerColor.withValues(alpha: .12),
                                      ),
                                    ),
                                    Positioned(
                                      left:
                                          math.max(0, box.maxWidth - 1) *
                                          100 /
                                          escala,
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: .6),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              '${carga.porAtender} ${p.unidad} disponibles / ${cap ?? 'sin capacidad'}',
                          child: Text(
                            uso == null
                                ? 'Sin configurar'
                                : '${uso.toStringAsFixed(0)} %',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 5),
            const Text(
              'Línea: 100 % de capacidad · Ver desglose en Capacidad',
              style: TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final escala = MediaQuery.textScalerOf(context).scale(12) / 12;
        final ancho = c.maxWidth >= 1050 && escala <= 1.2;
        final ruta = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                CiclosColores.oscuro(context)
                    ? CiclosColores.panel
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ruta de una OP por proceso',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SelectorTipoGrafica(
                    titulo: 'Ruta de una OP por proceso',
                    onChanged: (tipo) => setState(() => _tipoRuta = tipo),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Duración de cada proceso y cumplimiento de su objetivo',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _selector('P50', !_p80, () => setState(() => _p80 = false)),
                  _selector('P80', _p80, () => setState(() => _p80 = true)),
                  _selector(
                    'Histórico',
                    !_actual,
                    () => setState(() => _actual = false),
                  ),
                  _selector(
                    'Actual',
                    _actual,
                    () => setState(() => _actual = true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_tipoRuta != null) ...[
                GraficaIntercambiable(
                  titulo: 'Duración por proceso',
                  datos: _graficas['Duración por proceso']!,
                  original: const SizedBox.shrink(),
                  selectorVisible: false,
                  tipoSeleccionado: _tipoRuta,
                  altura: 210,
                ),
                const SizedBox(height: 16),
                GraficaIntercambiable(
                  titulo: 'Cumplimiento por proceso',
                  datos: _graficas['Cumplimiento por proceso']!,
                  original: const SizedBox.shrink(),
                  selectorVisible: false,
                  tipoSeleccionado: _tipoRuta,
                  altura: 210,
                ),
              ] else ...[
                if (duraciones.any((v) => v != null && v > 0))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          for (var n = 0; n < 7; n++)
                            if ((duraciones[n] ?? 0) > 0)
                              Expanded(
                                flex: math.max(
                                  1,
                                  ((duraciones[n] ?? 0) * 100).round(),
                                ),
                                child: Tooltip(
                                  message:
                                      '${ProcesoCiclo.values[n].titulo}: ${duraciones[n]!.toStringAsFixed(1)} días',
                                  child: Container(
                                    alignment: Alignment.center,
                                    color:
                                        CiclosColores.paleta(context)[n %
                                            CiclosColores.paleta(
                                              context,
                                            ).length],
                                    child: FittedBox(
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: Text(
                                          duraciones[n]!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Suma de procesos: ${duraciones.whereType<double>().fold<double>(0, (a, b) => a + b).toStringAsFixed(1)} días · ${_p80 ? 'P80' : 'P50'}. No equivale al percentil del ciclo total.',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 12),
                for (var n = 0; n < 7; n++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          ProcesoCiclo.values[n].titulo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        LayoutBuilder(
                          builder: (context, r) {
                            final cumplimiento = i.cumplimientoProceso(
                              ProcesoCiclo.values[n],
                              compararActual: _actual,
                            );
                            Widget indicador(
                              double? valor,
                              double maximo,
                              Color color,
                              String texto,
                            ) => Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value:
                                        valor == null
                                            ? 0
                                            : (valor / maximo).clamp(0, 1),
                                    color: color,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: .12),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    texto,
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            );
                            final tiempo = indicador(
                              duraciones[n],
                              duraciones.whereType<double>().fold<double>(
                                1,
                                math.max,
                              ),
                              CiclosColores.paleta(context)[0],
                              duraciones[n] == null
                                  ? '—'
                                  : '${duraciones[n]!.toStringAsFixed(1)} d',
                            );
                            final cumple = indicador(
                              cumplimiento,
                              100,
                              cumplimiento == null
                                  ? Colors.grey
                                  : cumplimiento >= 85
                                  ? CiclosColores.bien(context)
                                  : cumplimiento >= 75
                                  ? CiclosColores.alerta(context)
                                  : CiclosColores.error(context),
                              cumplimiento == null
                                  ? '—'
                                  : '${cumplimiento.toStringAsFixed(1)} %',
                            );
                            return r.maxWidth < 400
                                ? Column(
                                  children: [
                                    tiempo,
                                    const SizedBox(height: 5),
                                    cumple,
                                  ],
                                )
                                : Row(
                                  children: [
                                    Expanded(child: tiempo),
                                    const SizedBox(width: 16),
                                    Expanded(child: cumple),
                                  ],
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Cumplimiento: referencia 85 % · — sin datos evaluables',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CiclosPrioridadesCard(indicadores: i),
            const SizedBox(height: 12),
            if (ancho)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final n in [3, 4, 5]) ...[
                    if (n != 3) const SizedBox(width: 12),
                    Expanded(child: tarjetas[n]),
                  ],
                ],
              )
            else
              for (final n in [3, 4, 5])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: tarjetas[n],
                ),
            ExpansionTile(
              title: const Text('Análisis de tiempos'),
              subtitle: const Text(
                'P50: la mitad termina en ese tiempo. P80: 8 de cada 10. Ver detalle y estilos de gráfica.',
              ),
              children: [
                if (ancho)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: ruta),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: tarjetas[1]),
                    ],
                  )
                else ...[
                  ruta,
                  const SizedBox(height: 12),
                  tarjetas[1],
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _selector(String text, bool selected, VoidCallback pressed) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InkWell(
      onTap: pressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              selected
                  ? CiclosColores.bien(context).withValues(alpha: .2)
                  : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );
  Widget _leyenda(Color color, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(Icons.circle, color: color, size: 9),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.2)),
        ),
      ],
    ),
  );
  Widget _controlMeses(int total, int offset) => SizedBox(
    height: 28,
    child: Row(
      children: [
        Expanded(
          child: Text(
            total == 0
                ? 'Sin meses'
                : '${math.min(6, total - offset)} de $total meses',
            style: const TextStyle(fontSize: 11, height: 1.2),
          ),
        ),
        IconButton(
          tooltip: 'Meses anteriores',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed:
              offset + 6 >= total ? null : () => setState(() => _mesPagina++),
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        IconButton(
          tooltip: 'Meses recientes',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed:
              _mesPagina == 0 ? null : () => setState(() => _mesPagina--),
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    ),
  );
  Widget _card(String title, String help, Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shadowColor: const Color(0xff173559).withValues(alpha: .12),
    surfaceTintColor: Colors.transparent,
    color: CiclosColores.oscuro(context) ? null : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            CiclosColores.oscuro(context)
                ? Border(
                  top: BorderSide(color: CiclosColores.bien(context), width: 3),
                )
                : Border.all(color: const Color(0xffdce4eb)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              CiclosColores.oscuro(context)
                  ? CiclosColores.superficie(context)
                  : const [Colors.white, Colors.white, Colors.white],
          stops: CiclosColores.oscuro(context) ? null : const [0, .4, 1],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 150),
            child: GraficaIntercambiable(
              key: ValueKey(title),
              titulo: title,
              inicial:
                  title == 'Duración por proceso'
                      ? TipoGrafica.columnas
                      : title == 'Exceso promedio del plazo (%)'
                      ? TipoGrafica.columnas
                      : title == 'Cumplimiento por mes'
                      ? TipoGrafica.lineas
                      : null,
              altura: title == 'Duración por proceso' ? 300 : 105,
              controles:
                  title == 'Duración por proceso'
                      ? Row(
                        children: [
                          _selector(
                            'P50',
                            !_p80,
                            () => setState(() => _p80 = false),
                          ),
                          _selector(
                            'P80',
                            _p80,
                            () => setState(() => _p80 = true),
                          ),
                          const Spacer(),
                          const Text(
                            'Días hábiles',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      )
                      : title == 'Exceso promedio del plazo (%)'
                      ? _navegacionMeses
                      : null,
              ayuda: help,
              datos: _graficas[title]!,
              original: child,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _barra(
    String label,
    double? value,
    double max,
    Color color, {
    double? objetivo,
    String suffix = '',
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Tooltip(
      message:
          '$label: ${value?.toStringAsFixed(1) ?? 'sin datos'}$suffix${objetivo == null ? '' : ' · Meta: ${objetivo.toStringAsFixed(1)}$suffix'}',
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, c) => Stack(
                    children: [
                      Container(
                        height: 8,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: .15),
                      ),
                      Container(
                        height: 8,
                        width: c.maxWidth * ((value ?? 0) / max).clamp(0, 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: .65), color],
                          ),
                        ),
                      ),
                      if (objetivo != null)
                        Positioned(
                          left: (c.maxWidth * (objetivo / max).clamp(0, 1) - 2)
                              .clamp(0, c.maxWidth),
                          child: Container(
                            height: 8,
                            width: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
            ),
          ),
          SizedBox(
            width: 68,
            child: Text(
              value == null ? '—' : '${value.toStringAsFixed(1)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Dona extends CustomPainter {
  _Dona(this.cumple, this.tarde, this.vacio, this.bien, this.alerta);
  final int cumple, tarde;
  final Color vacio, bien, alerta;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = vacio.withValues(alpha: .3);
    canvas.drawOval(rect, paint);
    if (cumple + tarde == 0) {
      return;
    }
    final arco = 2 * math.pi * cumple / (cumple + tarde);
    paint.color = bien;
    canvas.drawArc(rect, -math.pi / 2, arco, false, paint);
    paint.color = alerta;
    canvas.drawArc(rect, -math.pi / 2 + arco, 2 * math.pi - arco, false, paint);
  }

  @override
  bool shouldRepaint(covariant _Dona old) =>
      old.cumple != cumple ||
      old.tarde != tarde ||
      old.vacio != vacio ||
      old.bien != bien ||
      old.alerta != alerta;
}
