import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';

final verEntregasProvider = StateProvider.autoDispose<bool>((ref) => false);
final entregasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    if (!ref.watch(usarSupabaseProvider)) return [];
    final result = <Map<String, dynamic>>[];
    int? antes;
    while (true) {
      final page =
          (await Supabase.instance.client.rpc(
                    'seguimiento_entregas_listar',
                    params: {'p_antes': antes},
                  )
                  as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
      result.addAll(page);
      if (page.length < 200) return result;
      antes = (page.last['le'] as num).toInt();
    }
  },
);
