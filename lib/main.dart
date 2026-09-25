import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'application/auth_providers.dart';
import 'application/providers.dart';
import 'data/auth_repository.dart';
import 'data/in_memory_wms_repository.dart';
import 'data/supabase_importador_fechas.dart';
import 'data/supabase_importador_ordenes.dart';
import 'data/supabase_wms_repository.dart';

/// Credenciales de Supabase, pasadas al compilar con:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
///
/// Si no se pasan (quedan vacías), la app arranca con datos de prueba en
/// memoria — útil para desarrollar la interfaz sin depender de la base real.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final usarSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  if (usarSupabase) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          if (usarSupabase) {
            final repo = SupabaseWmsRepository(Supabase.instance.client);
            ref.onDispose(repo.dispose);
            return repo;
          }
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
        importadorOrdenesProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return SupabaseImportadorOrdenes(Supabase.instance.client);
        }),
        importadorFechasProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return SupabaseImportadorFechas(Supabase.instance.client);
        }),
        usarSupabaseProvider.overrideWithValue(usarSupabase),
        authRepositoryProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return AuthRepository(Supabase.instance.client);
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
