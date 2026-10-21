import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';

final verEntregasProvider = StateProvider.autoDispose<bool>((ref) => false);
final entregasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    if (!ref.watch(usarSupabaseProvider)) return [];
    final result = <Map<String, dynamic>>[];
    int? antes;
    var correoDisponible = true;
    while (true) {
      dynamic respuesta;
      try {
        respuesta = await Supabase.instance.client.rpc(
          correoDisponible
              ? 'seguimiento_entregas_listar_v117'
              : 'seguimiento_entregas_listar',
          params: {'p_antes': antes},
        );
      } on PostgrestException catch (e) {
        if (!correoDisponible || e.code != 'PGRST202') rethrow;
        // El cliente sigue permitiendo consultar entregas antes de aplicar 117.
        correoDisponible = false;
        respuesta = await Supabase.instance.client.rpc(
          'seguimiento_entregas_listar',
          params: {'p_antes': antes},
        );
      }
      final page =
          (respuesta as List)
              .map(
                (x) => {
                  ...Map<String, dynamic>.from(x as Map),
                  'correo_disponible': correoDisponible,
                },
              )
              .toList();
      result.addAll(page);
      if (page.length < 200) return result;
      antes = (page.last['le'] as num).toInt();
    }
  },
);
