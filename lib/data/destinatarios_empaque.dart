import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';

final destinatariosEmpaqueProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      if (!ref.watch(usarSupabaseProvider)) return [];
      final rows =
          await Supabase.instance.client.rpc('destinatarios_para_empaque')
              as List;
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    });
