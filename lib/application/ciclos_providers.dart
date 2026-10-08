import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ciclos_repository.dart';
import '../domain/ciclos.dart';
import 'dashboard_acceso.dart';

final ciclosRepositoryProvider = Provider<CiclosRepository?>((ref) => null);
final ciclosProvider = FutureProvider.autoDispose<DatosCiclos>((ref) async {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Sin acceso a dashboards.');
  }
  final repo = ref.watch(ciclosRepositoryProvider);
  if (repo == null) {
    throw StateError('Conecta Supabase y aplica la migración 071 en pruebas.');
  }
  return repo.cargar();
});
