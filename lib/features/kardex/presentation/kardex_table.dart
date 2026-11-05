import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import '../../../domain/cumplimiento.dart';
import 'eliminar_linea_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../application/auth_providers.dart';
import '../../../domain/sesion.dart';
import '../../../domain/edicion_admin.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'observacion_dialog.dart';
import 'edicion_admin_dialog.dart';

// Columnas para el rol Producción (Taller). Todas tienen filtro por columna.
const List<double> _kAnchosProduccion = [
  100,
  160,
  150,
  95,
  140,
  95,
  140,
  170,
  110,
  110,
  220,
];
const List<String> kEtiquetasProduccion = [
  'OP / OBS.',
  'PRODUCTO',
  'CLIENTE / OC',
  'CANTIDAD',
  'ENTREGADO A LOGÍSTICA',
  'PENDIENTE',
  'PRODUCTO NO CONFORME',
  'ESTADOS',
  'ÚLTIMA ENTREGA',
  'FECHA PACTADA',
  'CUMPLIMIENTO',
];
// A qué columna de filtro corresponde cada encabezado de Producción (por
// índice). `null` = sin filtro en esa columna.
const List<String?> kColumnasProduccion = [
  ColKardex.op,
  ColKardex.producto,
  ColKardex.cliente,
  ColKardex.cantidad,
  ColKardex.entregado,
  ColKardex.pendiente,
  ColKardex.noConforme,
  ColKardex.estadoProduccion,
  ColKardex.fechaEntrega,
  ColKardex.fechaEsperada,
  ColKardex.diasFaltantes,
];

// Columnas para el rol Logística (Bodega). Todas tienen filtro por columna.
const List<double> _kAnchosBodega = [
  100,
  150,
  150,
  90,
  135,
  135,
  85,
  120,
  120,
  95,
  100,
  100,
  220,
  95,
];
const List<String> kEtiquetasBodega = [
  'OP / OBS.',
  'PRODUCTO',
  'CLIENTE / OC',
  'PEDIDAS',
  'ENTREGADO POR PRODUCCIÓN',
  'PENDIENTE POR PRODUCCIÓN',
  'BODEGA',
  'DESPACHADAS',
  'PRODUCTO NO CONFORME',
  'ESTADOS',
  'FECHA DE DESPACHO',
  'FECHA PACTADA',
  'CUMPLIMIENTO',
  'INVENTARIO',
];
const List<String?> kColumnasBodega = [
  ColKardex.op,
  ColKardex.producto,
  ColKardex.cliente,
  ColKardex.pedidas,
  ColKardex.produccion,
  ColKardex.pendienteProduccionBodega,
  ColKardex.bodega,
  ColKardex.despachadas,
  ColKardex.noConformeBodega,
  ColKardex.estadoBodega,
  ColKardex.fechaEntregaBodega,
  ColKardex.fechaEsperadaBodega,
  ColKardex.diasFaltantesBodega,
  ColKardex.inventario,
];

const _kPaletaProducto = [
  Color(0xFF2DD4BF),
  Color(0xFF60A5FA),
  Color(0xFFA78BFA),
  Color(0xFFFBBF24),
  Color(0xFFF472B6),
  Color(0xFFFB923C),
  Color(0xFF34D399),
  Color(0xFF94A3B8),
];

Color _colorProducto(String codigo) =>
    _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '',
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada, con columnas distintas según el rol.
class KardexTable extends ConsumerStatefulWidget {
  const KardexTable({super.key, this.integrada = false});
  final bool integrada;

  @override
  ConsumerState<KardexTable> createState() => _KardexTableState();
}

class _KardexTableState extends ConsumerState<KardexTable> {
  final _scrollHorizontal = ScrollController();

  @override
  void dispose() {
    _scrollHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe during build, never from a layout callback: provider updates
    // must not schedule another layout while mobile cards are being measured.
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final rol = ref.watch(rolProvider);
    final esAdmin =
        !ref.watch(usarSupabaseProvider) ||
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    final extraer = ref.watch(extractoresColumnaProvider);
    return LayoutBuilder(
      builder:
          (context, constraints) => _buildTable(
            context,
            constraints,
            filas,
            total,
            pagina,
            rol,
            esAdmin,
            extraer,
          ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    BoxConstraints constraints,
    List<ItemKardex> filas,
    int total,
    int pagina,
    Rol rol,
    bool esAdmin,
    Map<String, String Function(ItemKardex)> extraer,
  ) {
    final esProduccion = rol == Rol.produccion;
    final anchosCompletos = [
      ...(esProduccion ? _kAnchosProduccion : _kAnchosBodega),
      if (esAdmin) 76.0,
    ];
    final etiquetasCompletas = [
      ...(esProduccion ? kEtiquetasProduccion : kEtiquetasBodega),
      if (esAdmin) 'ACCIONES',
    ];
    final columnasCompletas = [
      ...(esProduccion ? kColumnasProduccion : kColumnasBodega),
      if (esAdmin) null,
    ];
    final indices = [
      for (var i = 0; i < columnasCompletas.length; i++)
        if (esProduccion ||
            (rol == Rol.logistica
                ? ![7, 11, 12].contains(i)
                : ![4, 5, 8].contains(i)))
          i,
    ];
    // Mantener los índices de las columnas existentes y colocar Inventario junto a Bodega.
    if (!esProduccion) {
      indices.remove(13);
      indices.insert(indices.indexOf(6) + 1, 13);
    }
    if (rol == Rol.logistica) {
      etiquetasCompletas[10] = 'ÚLTIMA RECEPCIÓN';
      columnasCompletas[10] = ColKardex.fechaRecibido;
    }
    final anchoDisponible = constraints.maxWidth - (widget.integrada ? 0 : 2);
    final escalaTexto = MediaQuery.textScalerOf(context).scale(14) / 14;
    final minimos = <int, double>{};
    for (final i in indices) {
      var palabraMasAncha = 0.0;
      for (final palabra in etiquetasCompletas[i].split(RegExp(r'\s+'))) {
        final medida = TextPainter(
          text: TextSpan(
            text: palabra,
            style: DefaultTextStyle.of(context).style.merge(
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .1,
              ),
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (medida.width > palabraMasAncha) palabraMasAncha = medida.width;
        medida.dispose();
      }
      // Padding, filtro y margen de redondeo: ninguna palabra se divide.
      minimos[i] = (palabraMasAncha.ceilToDouble() + 36).clamp(
        i == 1
            ? 220.0
            : i == 2
            ? 160.0
            : columnasCompletas[i] == null
            ? 76.0
            : 70.0,
        double.infinity,
      );
    }
    // El encabezado OP es corto, pero la celda también contiene el icono
    // de observaciones y el número completo. Reservar ambos antes de repartir.
    for (final fila in filas) {
      final medidaOp = TextPainter(
        text: TextSpan(
          text: '#${fila.item.op}',
          style: DefaultTextStyle.of(context).style.merge(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final anchoOp = medidaOp.width.ceilToDouble() + 16 + 16 + 6 + 4;
      if (anchoOp > minimos[0]!) minimos[0] = anchoOp;
      medidaOp.dispose();
    }
    final minimoTabla = minimos.values.fold<double>(0, (s, v) => s + v);
    final vistaCompacta =
        anchoDisponible < minimoTabla ||
        anchoDisponible < 1100 * escalaTexto.clamp(1.0, 1.5);
    if (!vistaCompacta) {
      final pesos = {
        for (final i in indices)
          i:
              i == 1
                  ? 3.0
                  : i == 2
                  ? 2.0
                  : columnasCompletas[i] == null
                  ? 0.0
                  : anchosCompletos[i] / 120,
      };
      final pesoTotal = pesos.values.fold<double>(0, (s, v) => s + v);
      for (final i in indices) {
        anchosCompletos[i] =
            minimos[i]! +
            (anchoDisponible - minimoTabla) * pesos[i]! / pesoTotal;
      }
    }
    final anchos = [for (final i in indices) anchosCompletos[i]];
    final etiquetas = [for (final i in indices) etiquetasCompletas[i]];
    final columnas = [for (final i in indices) columnasCompletas[i]];
    final totalPaginas =
        total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = anchos.fold<double>(0, (a, b) => a + b);
    final pal = palOf(context);

    if (vistaCompacta) {
      final campos = columnas.whereType<String>().toList();
      final labels = etiquetas.take(campos.length).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Sin resultados para los filtros aplicados.'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'FILTRAR POR COLUMNA',
              style: TextStyle(
                fontSize: 10,
                color: pal.textSecondary,
                letterSpacing: .4,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                for (var n = 0; n < labels.length; n++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: pal.card,
                        border: Border.all(color: pal.cardBorder),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _EncabezadoConFiltro(
                        columna: campos[n],
                        etiqueta: labels[n],
                        esOp: n == 0,
                        compacto: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final item in filas)
            _TarjetaOperativa(
              item: item,
              rol: rol,
              anchoDisponible: constraints.maxWidth,
              esAdmin: esAdmin,
              extraer: extraer,
            ),
          _BarraPaginacion(
            pagina: pagina,
            totalPaginas: totalPaginas,
            total: total,
            filas: filas.length,
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(widget.integrada ? 0 : 12),
        border: widget.integrada ? null : Border.all(color: pal.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Scrollbar(
            controller: _scrollHorizontal,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _scrollHorizontal,
              padding: const EdgeInsets.only(bottom: 12),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: anchoTabla,
                child: Column(
                  children: [
                    Container(
                      color: pal.header,
                      child: Row(
                        children: [
                          for (var i = 0; i < etiquetas.length; i++)
                            _Celda(
                              i,
                              anchos,
                              columnas[i] == null
                                  ? Text(
                                    etiquetas[i],
                                    softWrap: true,
                                    style: TextStyle(
                                      color:
                                          esCorporativo(context)
                                              ? Colors.white
                                              : pal.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      letterSpacing: 0.1,
                                      height: 1.2,
                                    ),
                                  )
                                  : _EncabezadoConFiltro(
                                    columna:
                                        columnas[i] == ColKardex.cliente
                                            ? ColKardex.oc
                                            : columnas[i]!,
                                    etiqueta: etiquetas[i],
                                    esOp: columnas[i] == ColKardex.op,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: pal.cardBorder),
                    if (filas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: pal.textMuted),
                          ),
                        ),
                      )
                    else
                      for (final item in filas)
                        _KardexRow(
                          item: item,
                          anchos: anchosCompletos,
                          indices: indices,
                          rol: rol,
                          esProduccion: esProduccion,
                        ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: pal.cardBorder),
          _BarraPaginacion(
            pagina: pagina,
            totalPaginas: totalPaginas,
            total: total,
            filas: filas.length,
          ),
        ],
      ),
    );
  }
}

/// Composición compacta compartida, con los datos propios de cada área.
class _TarjetaOperativa extends StatelessWidget {
  const _TarjetaOperativa({
    required this.item,
    required this.rol,
    required this.anchoDisponible,
    required this.esAdmin,
    required this.extraer,
  });

  final ItemKardex item;
  final Rol rol;
  final double anchoDisponible;
  final bool esAdmin;
  final Map<String, String Function(ItemKardex)> extraer;

  String _valor(String columna) => extraer[columna]?.call(item) ?? '';

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = oscuro ? pal.card : Colors.white;
    final escalaTexto = MediaQuery.textScalerOf(context).scale(12) / 12;
    // Mantener cifras, fechas y palabras completas con texto ampliado.
    // 56 = márgenes de la tarjeta, padding del contenido y separación.
    final apilarParejas = (anchoDisponible - 56) / 2 / escalaTexto < 120;
    final apilarAcciones = apilarParejas && escalaTexto >= 1.6;
    final esProduccion = rol == Rol.produccion;
    final esBodega = rol == Rol.logistica;
    final columnaEstado =
        esProduccion ? ColKardex.estadoProduccion : ColKardex.estadoBodega;
    final estado = esProduccion ? item.estadoProduccion : item.estadoLogistica;
    final (colorEstado, fondoEstado, iconoEstado) = switch (estado) {
      EstadoProduccion.completado || EstadoLogistica.completado => (
        pal.chipGreen,
        pal.chipGreenBg,
        Icons.check_circle_outline,
      ),
      EstadoProduccion.parcialPorRetardo => (
        pal.chipRed,
        pal.chipRedBg,
        Icons.warning_amber_outlined,
      ),
      _ => (AppColors.petroleo, AppColors.celesteSuave, Icons.hourglass_bottom),
    };
    final cumplimiento =
        esProduccion
            ? item.cumplimientoProduccion()
            : item.cumplimientoLogistica();
    final (
      colorCumplimiento,
      fondoCumplimiento,
      iconoCumplimiento,
    ) = switch (cumplimiento.resultado) {
      ResultadoCumplimiento.aTiempo => (
        pal.chipGreen,
        pal.chipGreenBg,
        Icons.check_circle_outline,
      ),
      ResultadoCumplimiento.vencido => (
        pal.chipRed,
        pal.chipRedBg,
        Icons.warning_amber_outlined,
      ),
      ResultadoCumplimiento.conRetraso || ResultadoCumplimiento.pendiente => (
        pal.warning,
        oscuro ? pal.chipNeutralBg : AppColors.amberChipBg,
        Icons.schedule,
      ),
      ResultadoCumplimiento.sinDatos => (
        pal.textSecondary,
        pal.chipNeutralBg,
        Icons.event_outlined,
      ),
    };
    final unidadesAvance = switch (rol) {
      Rol.produccion => item.producido,
      Rol.logistica => item.recibido,
      Rol.despacho => item.despachado,
    };
    final tituloAvance = switch (rol) {
      Rol.produccion => 'Avance de entrega',
      Rol.logistica => 'Avance de recepción',
      Rol.despacho => 'Avance de despacho',
    };
    final avance =
        item.cantidadPedida > 0 ? unidadesAvance / item.cantidadPedida : 0.0;
    final colorAvance = avance >= 1 ? pal.chipGreen : pal.info;
    final colorPendiente =
        item.pendienteProduccion > 0 ? pal.chipRed : pal.textPrimary;
    final colorNoConforme =
        item.pendienteReproceso > 0 ? pal.warning : pal.textPrimary;
    final metricas = <Widget>[
      _metrica(
        esProduccion ? 'CANTIDAD' : 'PEDIDAS',
        esProduccion ? ColKardex.cantidad : ColKardex.pedidas,
        Icons.bar_chart,
        pal.info,
        pal.info.withValues(alpha: .10),
      ),
      _metrica(
        esProduccion
            ? 'ENTREGADO A LOGÍSTICA'
            : esBodega
            ? 'ENTREGADO POR PRODUCCIÓN'
            : 'DESPACHADAS',
        esProduccion
            ? ColKardex.entregado
            : esBodega
            ? ColKardex.produccion
            : ColKardex.despachadas,
        Icons.local_shipping_outlined,
        pal.chipGreen,
        pal.chipGreenBg,
      ),
      if (!esProduccion) ...[
        _metrica(
          'BODEGA',
          ColKardex.bodega,
          Icons.inventory_2_outlined,
          pal.textPrimary,
          pal.chipNeutralBg,
        ),
        _metrica(
          'INVENTARIO',
          ColKardex.inventario,
          Icons.shelves,
          pal.textPrimary,
          pal.chipNeutralBg,
        ),
      ],
      if (esProduccion || esBodega) ...[
        _metrica(
          esProduccion ? 'PENDIENTE' : 'PENDIENTE POR PRODUCCIÓN',
          esProduccion
              ? ColKardex.pendiente
              : ColKardex.pendienteProduccionBodega,
          Icons.schedule,
          colorPendiente,
          pal.chipNeutralBg,
          detalle: item.pendienteProduccion == 0 ? 'Sin pendientes' : null,
        ),
        _metrica(
          'PRODUCTO NO CONFORME',
          esProduccion ? ColKardex.noConforme : ColKardex.noConformeBodega,
          Icons.warning_amber_outlined,
          colorNoConforme,
          pal.chipNeutralBg,
          detalle: item.pendienteReproceso == 0 ? 'Sin novedades' : null,
        ),
      ],
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      color: fondo,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pal.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.petroleo,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _etiqueta(
                        'OP ${item.item.op}',
                        AppColors.petroleo,
                        AppColors.lima,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: _etiqueta(
                        _valor(columnaEstado),
                        colorEstado,
                        fondoEstado,
                        icono: iconoEstado,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.item.descripcion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final texto in [
                      item.item.codigo,
                      'Talla ${item.item.talla}',
                      item.item.oc.trim().isEmpty
                          ? 'Sin OC'
                          : 'OC ${item.item.oc}',
                    ])
                      _etiqueta(
                        texto,
                        Colors.white,
                        Colors.white.withValues(alpha: .14),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: pal.info.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: pal.info,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rotulo('CLIENTE / OC', pal.textMuted),
                          const SizedBox(height: 3),
                          Text(
                            item.item.cliente,
                            style: TextStyle(
                              color: pal.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      tituloAvance,
                      style: TextStyle(fontSize: 11, color: pal.textSecondary),
                    ),
                    Text(
                      '$unidadesAvance de ${item.cantidadPedida} · '
                      '${(avance * 100).toStringAsFixed(0)} %',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorAvance,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: avance.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  color: colorAvance,
                  backgroundColor: pal.chipNeutralBg,
                  semanticsLabel:
                      '$tituloAvance: $unidadesAvance de '
                      '${item.cantidadPedida} unidades',
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < metricas.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _pareja(metricas[i], metricas[i + 1], apilar: apilarParejas),
                ],
                const SizedBox(height: 12),
                if (esBodega)
                  _fecha('ÚLTIMA RECEPCIÓN', ColKardex.fechaRecibido, pal)
                else ...[
                  _pareja(
                    _fecha(
                      'FECHA PACTADA',
                      esProduccion
                          ? ColKardex.fechaEsperada
                          : ColKardex.fechaEsperadaBodega,
                      pal,
                    ),
                    _fecha(
                      esProduccion ? 'ÚLTIMA ENTREGA' : 'FECHA DE DESPACHO',
                      esProduccion
                          ? ColKardex.fechaEntrega
                          : ColKardex.fechaEntregaBodega,
                      pal,
                    ),
                    apilar: apilarParejas,
                    separador: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: pal.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: fondoCumplimiento,
                      border: Border.all(
                        color: colorCumplimiento.withValues(alpha: .25),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          iconoCumplimiento,
                          size: 17,
                          color: colorCumplimiento,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Cumplimiento: ',
                              children: [
                                TextSpan(
                                  text: _valor(
                                    esProduccion
                                        ? ColKardex.diasFaltantes
                                        : ColKardex.diasFaltantesBodega,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              color: colorCumplimiento,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Divider(height: 24, color: pal.cardBorder),
                Flex(
                  direction: apilarAcciones ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment:
                      apilarAcciones
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: apilarAcciones ? 0 : 1,
                      fit: apilarAcciones ? FlexFit.loose : FlexFit.tight,
                      child: FilledButton.icon(
                        onPressed: () => showObservacionDialog(context, item),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lima,
                          foregroundColor: AppColors.petroleo,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.comment_outlined, size: 17),
                        label: const Text(
                          'Observaciones',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (esAdmin) ...[
                      SizedBox(
                        width: apilarAcciones ? 0 : 8,
                        height: apilarAcciones ? 8 : 0,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: pal.cardBorder),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: _AccionesFila(item: item),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String texto, Color color) => Text(
    texto,
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: .25,
    ),
  );

  Widget _etiqueta(String texto, Color color, Color fondo, {IconData? icono}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _pareja(
    Widget izquierda,
    Widget derecha, {
    Widget? separador,
    bool apilar = false,
  }) =>
      apilar
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(child: izquierda),
              const SizedBox(height: 8),
              IntrinsicHeight(child: derecha),
            ],
          )
          : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: izquierda),
                separador ?? const SizedBox(width: 8),
                Expanded(child: derecha),
              ],
            ),
          );

  Widget _metrica(
    String etiqueta,
    String columna,
    IconData icono,
    Color color,
    Color fondo, {
    String? detalle,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 5),
            Expanded(child: _rotulo(etiqueta, color)),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 5),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              _valor(columna),
              style: TextStyle(
                color: color,
                fontSize: 23,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detalle != null)
              Text(detalle, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ],
    ),
  );

  Widget _fecha(String etiqueta, String columna, AppPalette pal) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: pal.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rotulo(etiqueta, pal.textMuted),
        const SizedBox(height: 4),
        Text(
          _valor(columna),
          style: TextStyle(
            color: pal.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Encabezado de columna con el ícono de embudo que abre el filtro de
/// selección múltiple (búsqueda + casillas), para cualquier columna.
class _EncabezadoConFiltro extends ConsumerWidget {
  const _EncabezadoConFiltro({
    required this.columna,
    required this.etiqueta,
    this.esOp = false,
    this.compacto = false,
  });

  final String columna;
  final String etiqueta;
  final bool esOp;
  final bool compacto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final activo = filtros.valoresDe(columna).isNotEmpty;
    final pal = palOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            etiqueta,
            softWrap: true,
            style: TextStyle(
              color:
                  !compacto && esCorporativo(context)
                      ? Colors.white
                      : pal.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final r = await showMultiSelectFilter<String>(
              context,
              title:
                  columna == ColKardex.oc
                      ? 'Filtrar por OC'
                      : 'Filtrar por $etiqueta',
              options: opciones.de(columna),
              selected: filtros.valoresDe(columna),
              labelOf: esOp ? (v) => '#$v' : (v) => v,
            );
            if (r != null) {
              ref.read(kardexFiltersProvider.notifier).setColumna(columna, r);
            }
          },
          child: Icon(
            Icons.filter_alt,
            size: 14,
            color:
                !compacto && esCorporativo(context)
                    ? (activo ? AppColors.lima : const Color(0xFFC5DFEB))
                    : activo
                    ? pal.accent
                    : pal.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BarraPaginacion extends ConsumerWidget {
  const _BarraPaginacion({
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.filas,
  });

  final int pagina;
  final int totalPaginas;
  final int total;
  final int filas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kardexPaginaProvider.notifier);
    final desde = total == 0 ? 0 : pagina * kardexFilasPorPagina + 1;
    final hasta = pagina * kardexFilasPorPagina + filas;
    final pal = palOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            'Mostrando $desde-$hasta de $total registros',
            style: TextStyle(fontSize: 12, color: pal.textSecondary),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.textSecondary,
                  side: BorderSide(color: pal.cardBorder),
                ),
              ),
              ElevatedButton.icon(
                onPressed:
                    pagina + 1 < totalPaginas
                        ? () => notifier.ir(pagina + 1)
                        : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: pal.cardBorder,
                  disabledForegroundColor: pal.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(
    this.col,
    this.anchos,
    this.child, {
    this.alignment = Alignment.centerLeft,
  });

  final int col;
  final List<double> anchos;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: anchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends ConsumerWidget {
  const _KardexRow({
    required this.item,
    required this.anchos,
    required this.esProduccion,
    required this.indices,
    required this.rol,
  });
  final List<int> indices;
  final Rol rol;

  final ItemKardex item;
  final List<double> anchos;
  final bool esProduccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = palOf(context);
    final esAdmin =
        !ref.watch(usarSupabaseProvider) ||
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    final celdas = [
      _celdaOp(pal),
      _celdaProducto(pal),
      _celdaClienteOc(pal),
      if (esProduccion) ..._celdasProduccion(pal) else ..._celdasBodega(pal),
    ];
    return _FilaConHover(
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pal.cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final i in indices)
              if (i < celdas.length) celdas[i],
            if (esAdmin)
              _Celda(celdas.length, anchos, _AccionesFila(item: item)),
          ],
        ),
      ),
    );
  }

  Widget _celdaOp(AppPalette pal) {
    final o = item.item;
    return _Celda(
      0,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder:
                (context) => InkWell(
                  onTap: () => showObservacionDialog(context, item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: pal.textMuted,
                    ),
                  ),
                ),
          ),
          Flexible(
            child: Text(
              '#${o.op}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: pal.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _celdaProducto(AppPalette pal) {
    final o = item.item;
    return _Celda(
      1,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: _colorProducto(o.codigo),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: Builder(
              builder:
                  (context) => InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _mostrarProductoCompleto(context, o),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          o.descripcion,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'Talla ${o.talla}',
                          style: TextStyle(fontSize: 11, color: pal.textMuted),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarProductoCompleto(BuildContext context, ItemOrden o) {
    final pal = palOf(context);
    showDialog<void>(
      context: context,
      builder:
          (_) => WmsExpandableAlertDialog(
            backgroundColor: pal.card,
            title: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _colorProducto(o.codigo),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Producto',
                    style: TextStyle(color: pal.textPrimary),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.descripcion,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _filaDato('Código', o.codigo, pal),
                _filaDato('Talla', o.talla, pal),
                _filaDato('OP', o.op, pal),
                if (o.oc.isNotEmpty) _filaDato('OC', o.oc, pal),
                _filaDato('Cliente', o.cliente, pal),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CERRAR'),
              ),
            ],
          ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, AppPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: pal.textSecondary),
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: valor, style: TextStyle(color: pal.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _celdaClienteOc(AppPalette pal) {
    final o = item.item;
    return _Celda(
      2,
      anchos,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            o.cliente,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: pal.textPrimary,
            ),
          ),
          if (o.oc.isNotEmpty)
            Text(
              'OC ${o.oc}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: pal.textMuted),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- vista Producción

  List<Widget> _celdasProduccion(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(
        3,
        anchos,
        Text(
          '${item.cantidadPedida}',
          style: TextStyle(fontSize: 13, color: pal.textPrimary),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        4,
        anchos,
        Text(
          '${item.producido}',
          style: TextStyle(
            fontSize: 13,
            color: pal.chipGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        5,
        anchos,
        Text(
          '${item.pendienteProduccion}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        6,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(7, anchos, _celdaEstado(pal)),
      _Celda(8, anchos, _chipFecha(item.fechaEntrega, pal)),
      _Celda(9, anchos, _chipFecha(item.fechaEsperadaProduccion, pal)),
      _Celda(10, anchos, _chipCumplimiento(item.cumplimientoProduccion(), pal)),
    ];
  }

  Widget _celdaEstado(AppPalette pal) {
    final e = item.estadoProduccion;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoProduccion.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoProduccion.parcialPorRetardo:
        color = pal.chipRed;
        fondo = pal.chipRedBg;
        icono = Icons.warning_amber_outlined;
      case EstadoProduccion.parcialPorEntregar:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chipFecha(DateTime? fecha, AppPalette pal) {
    if (fecha == null) {
      return _chip(
        'Sin fecha',
        pal.textMuted,
        pal.chipNeutralBg,
        Icons.event_outlined,
      );
    }
    return _chip(
      _fechaCorta(fecha),
      pal.textSecondary,
      pal.chipNeutralBg,
      Icons.event_outlined,
    );
  }

  // ------------------------------------------------------- vista Bodega

  List<Widget> _celdasBodega(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(
        3,
        anchos,
        Text(
          '${item.cantidadPedida}',
          style: TextStyle(fontSize: 13, color: pal.textPrimary),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        4,
        anchos,
        Text(
          '${item.producido}',
          style: TextStyle(
            fontSize: 13,
            color: pal.chipGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        5,
        anchos,
        Text(
          '${item.pendienteProduccion}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        6,
        anchos,
        Text(
          '${item.stockDisponible}',
          style: TextStyle(fontSize: 13, color: pal.info),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        7,
        anchos,
        Text(
          '${item.despachado}',
          style: TextStyle(fontSize: 13, color: pal.warning),
        ),
        alignment: Alignment.center,
      ),
      _Celda(
        8,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(9, anchos, _celdaEstadoLogistica(pal)),
      _Celda(
        10,
        anchos,
        _chipFecha(
          rol == Rol.logistica ? item.fechaRecepcion : item.fechaDespacho,
          pal,
        ),
      ),
      _Celda(11, anchos, _chipFecha(item.fechaEsperadaLogistica, pal)),
      _Celda(12, anchos, _chipCumplimiento(item.cumplimientoLogistica(), pal)),
      _Celda(
        13,
        anchos,
        Tooltip(
          message:
              'Unidades en inventario: libres y reservadas, sin salidas ni reversiones',
          child: Text(
            '${item.stockInventario}',
            style: TextStyle(
              fontSize: 13,
              color: item.stockInventario > 0 ? pal.chipGreen : pal.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        alignment: Alignment.center,
      ),
    ];
  }

  Widget _chipCumplimiento(Cumplimiento valor, AppPalette pal) {
    final (color, fondo, icono) = switch (valor.resultado) {
      ResultadoCumplimiento.aTiempo => (
        pal.chipGreen,
        pal.chipGreenBg,
        Icons.check_circle_outline,
      ),
      ResultadoCumplimiento.conRetraso => (
        pal.warning,
        pal.chipNeutralBg,
        Icons.schedule,
      ),
      ResultadoCumplimiento.vencido => (
        pal.chipRed,
        pal.chipRedBg,
        Icons.warning_amber_outlined,
      ),
      ResultadoCumplimiento.pendiente => (
        pal.warning,
        pal.chipNeutralBg,
        Icons.hourglass_bottom,
      ),
      ResultadoCumplimiento.sinDatos => (
        pal.textMuted,
        pal.chipNeutralBg,
        Icons.event_outlined,
      ),
    };
    return _chip(valor.detalle, color, fondo, icono);
  }

  Widget _celdaEstadoLogistica(AppPalette pal) {
    final e = item.estadoLogistica;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoLogistica.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoLogistica.pendienteRecibir:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
      case EstadoLogistica.pendientePorDespachar:
        color = pal.warning;
        fondo = pal.chipNeutralBg;
        icono = Icons.local_shipping_outlined;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hover estrictamente visual: conserva las acciones de cada celda.
class _FilaConHover extends StatefulWidget {
  const _FilaConHover({required this.child});
  final Widget child;
  @override
  State<_FilaConHover> createState() => _FilaConHoverState();
}

class _FilaConHoverState extends State<_FilaConHover> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      color:
          _hover
              ? palOf(context).accent.withValues(alpha: 0.065)
              : Colors.transparent,
      child: widget.child,
    ),
  );
}

class _AccionesFila extends StatelessWidget {
  const _AccionesFila({required this.item});
  final ItemKardex item;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Acciones de la fila',
    icon: Icon(Icons.more_vert, color: palOf(context).accent, size: 21),
    onSelected: (accion) {
      if (accion == 'editar') {
        showEdicionAdminDialog(context, item, CampoAdmin.cantidad);
      } else if (accion == 'eliminar') {
        showWmsEliminarLinea(context, item);
      }
    },
    itemBuilder:
        (_) => const [
          PopupMenuItem(
            value: 'editar',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Editar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'eliminar',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ],
  );
}
