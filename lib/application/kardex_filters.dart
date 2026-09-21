import '../core/utils/fecha.dart';
import '../domain/models.dart';

/// Fecha relevante según el perfil: entrega (producción) o recepción (bodega).
DateTime? fechaSegunRol(ItemKardex i, Rol rol) =>
    rol == Rol.produccion ? i.fechaEntrega : i.fechaRecepcion;

/// Filtros del kardex. Un conjunto vacío significa "TODOS".
class KardexFilters {
  const KardexFilters({
    this.ops = const {},
    this.ocs = const {},
    this.clientes = const {},
    this.fechas = const {},
  });

  final Set<String> ops;
  final Set<String> ocs;
  final Set<String> clientes;
  final Set<DateTime> fechas; // solo fecha, sin hora

  bool get hayFiltros =>
      ops.isNotEmpty || ocs.isNotEmpty || clientes.isNotEmpty || fechas.isNotEmpty;

  KardexFilters copyWith({
    Set<String>? ops,
    Set<String>? ocs,
    Set<String>? clientes,
    Set<DateTime>? fechas,
  }) {
    return KardexFilters(
      ops: ops ?? this.ops,
      ocs: ocs ?? this.ocs,
      clientes: clientes ?? this.clientes,
      fechas: fechas ?? this.fechas,
    );
  }

  bool aplica(ItemKardex i, Rol rol) {
    if (ops.isNotEmpty && !ops.contains(i.item.op)) return false;
    if (ocs.isNotEmpty && !ocs.contains(i.item.oc)) return false;
    if (clientes.isNotEmpty && !clientes.contains(i.item.cliente)) return false;
    if (fechas.isNotEmpty) {
      final f = fechaSegunRol(i, rol);
      if (f == null || !fechas.contains(soloFecha(f))) return false;
    }
    return true;
  }
}

/// Valores disponibles en los desplegables de filtro.
class OpcionesFiltro {
  const OpcionesFiltro({
    required this.ops,
    required this.ocs,
    required this.clientes,
    required this.fechas,
  });

  final List<String> ops;
  final List<String> ocs;
  final List<String> clientes;
  final List<DateTime> fechas;
}
