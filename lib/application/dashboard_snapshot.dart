import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_acceso.dart';
import 'providers.dart';
import '../domain/models.dart';

/// Se conserva durante la visita; solo se vuelve a consultar al invalidarlo.
/// No observa el stream compartido del kardex.
final dashboardSnapshotProvider = FutureProvider.autoDispose<WmsSnapshot>((
  ref,
) {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Acceso exclusivo de Administración y Gerencia.');
  }
  return ref.read(wmsRepositoryProvider).cargarSnapshot();
});
