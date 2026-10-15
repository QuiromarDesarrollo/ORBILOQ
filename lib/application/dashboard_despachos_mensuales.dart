import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';
import 'dashboard_acceso.dart';

typedef FiltroDespachosMensuales =
    ({String desde, String hasta, String? cliente, String corte});

final despachosMensualesProvider = FutureProvider.autoDispose.family<
  List<Map<String, dynamic>>,
  FiltroDespachosMensuales
>((ref, filtro) async {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Sin acceso al dashboard');
  }
  if (!ref.watch(usarSupabaseProvider)) return [];
  final datos = await Supabase.instance.client.rpc(
    'dashboard_despachos_mensuales',
    params: {
      'p_desde': filtro.desde,
      'p_hasta': filtro.hasta,
      'p_cliente': filtro.cliente,
      'p_corte': filtro.corte,
    },
  );
  return (datos as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});

final facturacionSemanalProvider = FutureProvider.autoDispose.family<
  List<Map<String, dynamic>>,
  FiltroDespachosMensuales
>((ref, filtro) async {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Sin acceso al dashboard');
  }
  if (!ref.watch(usarSupabaseProvider)) return [];
  final datos = await Supabase.instance.client.rpc(
    'dashboard_facturacion_semanal',
    params: {
      'p_desde': filtro.desde,
      'p_hasta': filtro.hasta,
      'p_cliente': filtro.cliente,
      'p_corte': filtro.corte,
    },
  );
  return (datos as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});

final puntualidadMensualProvider = FutureProvider.autoDispose.family<
  List<Map<String, dynamic>>,
  FiltroDespachosMensuales
>((ref, filtro) async {
  if (!(ref.watch(dashboardAccesoProvider).$2?.puedeVerDashboards ?? false)) {
    throw StateError('Sin acceso al dashboard');
  }
  if (!ref.watch(usarSupabaseProvider)) return [];
  final datos = await Supabase.instance.client.rpc(
    'dashboard_puntualidad_mensual',
    params: {
      'p_desde': filtro.desde,
      'p_hasta': filtro.hasta,
      'p_cliente': filtro.cliente,
      'p_corte': filtro.corte,
    },
  );
  return (datos as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
});
