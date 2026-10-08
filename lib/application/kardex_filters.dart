import 'dart:math' as math;

import '../domain/models.dart';

/// Identificadores de columna: la misma llave se usa para guardar el filtro
/// activo, para pedir sus opciones disponibles, y para saber qué valor de
/// cada [ItemKardex] le corresponde (ver `kardex_columnas.dart`).
abstract final class ColKardex {
  // Comunes a ambas vistas
  static const op = 'op';
  static const producto = 'producto';
  static const cliente = 'cliente';
  static const oc = 'oc';
  // Vista Producción
  static const cantidad = 'cantidad';
  static const entregado = 'entregado';
  static const pendiente = 'pendiente';
  static const noConforme = 'noConforme';
  static const estadoProduccion = 'estadoProduccion';
  static const fechaEntrega = 'fechaEntrega';
  static const fechaEsperada = 'fechaEsperada';
  static const diasFaltantes = 'diasFaltantes';
  // Vista Bodega
  static const pedidas = 'pedidas';
  static const produccion = 'produccion';
  static const pendienteProduccionBodega = 'pendienteProduccionBodega';
  static const bodega = 'bodega';
  static const despachadas = 'despachadas';
  static const noConformeBodega = 'noConformeBodega';
  static const estadoBodega = 'estadoBodega';
  static const fechaEntregaBodega = 'fechaEntregaBodega';
  static const fechaEsperadaBodega = 'fechaEsperadaBodega';
  static const diasFaltantesBodega = 'diasFaltantesBodega';
  static const fechaRecibido = 'fechaRecibido';
}

/// Filtros del kardex: búsqueda libre + filtros por columna (multi-selección
/// por cada una). Sirve para cualquiera de las dos vistas — cada vista solo
/// usa las columnas que le aplican (ver los mapas de extractores).
class KardexFilters {
  const KardexFilters({this.busqueda = '', this.columnas = const {}, this.desde, this.hasta});

  final String busqueda;
  final Map<String, Set<String>> columnas;
  final DateTime? desde;
  final DateTime? hasta;

  bool get hayFiltros =>
      desde != null || hasta != null || busqueda.trim().isNotEmpty || columnas.values.any((v) => v.isNotEmpty);

  Set<String> valoresDe(String columna) => columnas[columna] ?? const {};

  KardexFilters conBusqueda(String v) =>
      KardexFilters(busqueda: v, columnas: columnas, desde: desde, hasta: hasta);

  KardexFilters conFechas(DateTime? inicio, DateTime? fin) => KardexFilters(
    busqueda: busqueda, columnas: columnas, desde: inicio, hasta: fin);

  KardexFilters conColumna(String columna, Set<String> valores) {
    final nuevo = Map<String, Set<String>>.from(columnas);
    if (valores.isEmpty) {
      nuevo.remove(columna);
    } else {
      nuevo[columna] = valores;
    }
    return KardexFilters(busqueda: busqueda, columnas: nuevo, desde: desde, hasta: hasta);
  }

  bool aplica(
    ItemKardex i,
    Map<String, String Function(ItemKardex)> extractores, {
    Rol rol = Rol.produccion,
  }) {
    if (desde != null || hasta != null) {
      final fecha = switch (rol) {
        Rol.produccion => i.fechaEntrega,
        Rol.logistica => i.fechaRecepcion,
        Rol.despacho => i.fechaDespacho,
      };
      if (fecha == null) return false;
      DateTime dia(DateTime f) => DateTime(f.year, f.month, f.day);
      final d = dia(fecha.toLocal());
      if (desde != null && d.isBefore(dia(desde!))) return false;
      if (hasta != null && d.isAfter(dia(hasta!))) return false;
    }
    for (final entry in columnas.entries) {
      if (entry.value.isEmpty) continue;
      final extractor = extractores[entry.key];
      if (extractor == null) {
        continue; // columna no aplicable a esta vista: se ignora
      }
      if (!entry.value.contains(extractor(i))) return false;
    }
    final q = busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      final texto =
          '${i.item.op} ${i.item.cliente} ${i.item.oc} ${i.item.codigo} '
                  '${i.item.descripcion} ${i.item.talla}'
              .toLowerCase();
      if (!texto.contains(q)) return false;
    }
    return true;
  }
}

/// Valores distintos disponibles para cada columna, según los datos actuales.
class OpcionesFiltro {
  const OpcionesFiltro(this.porColumna);
  final Map<String, List<String>> porColumna;
  List<String> de(String columna) => porColumna[columna] ?? const [];
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
    required this.pendientePorEntregar,
    required this.totalNoConforme,
  });

  final int unidadesPedidas;
  final int cantidadOrdenes;
  final int enProduccion;
  final int recibidoEnBodega;

  /// Existencias recibidas aún en bodega, sin incluir unidades por recibir.
  /// Un saldo negativo en una línea no compensa existencias de otras líneas.
  final int pendientePorDespachar;

  /// Suma de [ItemKardex.pendienteProduccion] — lo que a Producción aún le
  /// falta entregar a Logística (distinto de "pendiente por despachar",
  /// que es un concepto de Bodega).
  final int pendientePorEntregar;

  /// Suma de [ItemKardex.pendienteReproceso] — unidades marcadas como no
  /// conformes que todavía no se han liberado.
  final int totalNoConforme;

  double get porcentajeProduccion =>
      unidadesPedidas == 0 ? 0 : enProduccion / unidadesPedidas * 100;
  double get porcentajeBodega =>
      unidadesPedidas == 0 ? 0 : recibidoEnBodega / unidadesPedidas * 100;

  factory KardexResumen.desde(List<ItemKardex> items) {
    var pedidas = 0,
        prod = 0,
        bodega = 0,
        pendienteDespacho = 0,
        pendienteEntrega = 0,
        noConforme = 0;
    final ops = <String>{};
    for (final i in items) {
      pedidas += i.cantidadPedida;
      prod += i.producido;
      bodega += i.recibido;
      pendienteDespacho += math.max(0, i.stockDisponible);
      pendienteEntrega += i.pendienteProduccion;
      noConforme += i.pendienteReproceso;
      ops.add(i.item.op);
    }
    return KardexResumen(
      unidadesPedidas: pedidas,
      cantidadOrdenes: ops.length,
      enProduccion: prod,
      recibidoEnBodega: bodega,
      pendientePorDespachar: pendienteDespacho,
      pendientePorEntregar: pendienteEntrega,
      totalNoConforme: noConforme,
    );
  }
}
