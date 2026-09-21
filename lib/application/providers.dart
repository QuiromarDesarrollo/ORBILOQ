import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/fecha.dart';
import '../domain/models.dart';
import '../domain/wms_repository.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() => Rol.produccion;

  void cambiar(Rol rol) {
    if (rol == state) return;
    state = rol;
    // La fecha filtrada depende del perfil (entrega vs recepción).
    ref.read(kardexFiltersProvider.notifier).limpiarFechas();
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setOps(Set<String> v) => state = state.copyWith(ops: v);
  void setOcs(Set<String> v) => state = state.copyWith(ocs: v);
  void setClientes(Set<String> v) => state = state.copyWith(clientes: v);
  void setFechas(Set<DateTime> v) => state = state.copyWith(fechas: v);
  void limpiarFechas() => state = state.copyWith(fechas: const {});
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  final rol = ref.watch(rolProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where((i) => filtros.aplica(i, rol)).toList(growable: false);
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  final rol = ref.watch(rolProvider);

  List<String> unicos(String Function(ItemKardex) f) => (kardex.map(f).toSet().toList()..sort());

  final fechas = kardex
      .map((i) => fechaSegunRol(i, rol))
      .whereType<DateTime>()
      .map(soloFecha)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  return OpcionesFiltro(
    ops: unicos((i) => i.item.op),
    ocs: unicos((i) => i.item.oc),
    clientes: unicos((i) => i.item.cliente),
    fechas: fechas,
  );
});
