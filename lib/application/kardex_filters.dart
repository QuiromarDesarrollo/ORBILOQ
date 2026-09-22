import '../domain/models.dart';

/// Filtros del kardex: búsqueda libre + cliente + estado, todos opcionales.
/// `null`/vacío en cualquiera de ellos significa "sin restricción en ese campo".
class KardexFilters {
  const KardexFilters({
    this.busqueda = '',
    this.cliente,
    this.estado,
  });

  final String busqueda;
  final String? cliente;
  final String? estado; // etiqueta de EstadoItem, o null = todos

  bool get hayFiltros => busqueda.trim().isNotEmpty || cliente != null || estado != null;

  KardexFilters copyWith({
    String? busqueda,
    Object? cliente = _sinCambio,
    Object? estado = _sinCambio,
  }) {
    return KardexFilters(
      busqueda: busqueda ?? this.busqueda,
      cliente: identical(cliente, _sinCambio) ? this.cliente : cliente as String?,
      estado: identical(estado, _sinCambio) ? this.estado : estado as String?,
    );
  }

  bool aplica(ItemKardex i) {
    if (cliente != null && i.item.cliente != cliente) return false;
    if (estado != null && i.estadoEtiqueta != estado) return false;
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      final texto = '${i.item.op} ${i.item.cliente} ${i.item.oc} ${i.item.codigo} '
              '${i.item.descripcion} ${i.item.talla}'
          .toLowerCase();
      if (!texto.contains(q)) return false;
    }
    return true;
  }
}

const _sinCambio = Object();

/// Valores disponibles en los desplegables de filtro.
class OpcionesFiltro {
  const OpcionesFiltro({required this.clientes, required this.estados});
  final List<String> clientes;
  final List<String> estados;
}

/// Totales agregados para las tarjetas de resumen, calculados sobre la lista
/// que se le pase (normalmente la ya filtrada, para que reaccionen a los
/// filtros activos).
class KardexResumen {
  const KardexResumen({
    required this.unidadesPedidas,
    required this.cantidadOrdenes,
    required this.enProduccion,
    required this.recibidoEnBodega,
    required this.pendientePorDespachar,
  });

  final int unidadesPedidas;
  final int cantidadOrdenes;
  final int enProduccion;
  final int recibidoEnBodega;
  final int pendientePorDespachar;

  double get porcentajeProduccion => unidadesPedidas == 0 ? 0 : enProduccion / unidadesPedidas * 100;
  double get porcentajeBodega => unidadesPedidas == 0 ? 0 : recibidoEnBodega / unidadesPedidas * 100;

  factory KardexResumen.desde(List<ItemKardex> items) {
    var pedidas = 0, prod = 0, bodega = 0, pendiente = 0;
    final ops = <String>{};
    for (final i in items) {
      pedidas += i.cantidadPedida;
      prod += i.producido;
      bodega += i.recibido;
      pendiente += i.pendienteDespacho;
      ops.add(i.item.op);
    }
    return KardexResumen(
      unidadesPedidas: pedidas,
      cantidadOrdenes: ops.length,
      enProduccion: prod,
      recibidoEnBodega: bodega,
      pendientePorDespachar: pendiente,
    );
  }
}
