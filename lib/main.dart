import 'data/reportes_admin_repository.dart';
import 'dart:async';
import 'data/catalogos_repository.dart';
import 'data/supabase_importador_kardex.dart';
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
        reportesAdminProvider.overrideWith((ref)=>usarSupabase?SupabaseReportesAdminRepository(Supabase.instance.client):null),
        catalogosAdminProvider.overrideWith((ref)=>usarSupabase?SupabaseCatalogosRepository(Supabase.instance.client):null),
        catalogosRevisionProvider.overrideWith((ref) {
          if(!usarSupabase)return const Stream<int>.empty();
          final controller=StreamController<int>(); var version=0;
          var channel=Supabase.instance.client.channel('catalogos_cambios');
          for(final tabla in catalogosAdministrables.keys){
            channel=channel.onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:tabla,callback:(_){
              if(!controller.isClosed)controller.add(++version);
              ref.read(wmsRepositoryProvider).refrescar();
            });
          }
          channel.subscribe();
          final timer=Timer.periodic(const Duration(seconds:30),(_){if(!controller.isClosed)controller.add(++version);});
          ref.onDispose((){timer.cancel();Supabase.instance.client.removeChannel(channel);controller.close();});
          return controller.stream;
        }),
        importadorKardexProvider.overrideWith((ref) => usarSupabase ? SupabaseImportadorKardex(Supabase.instance.client) : null),
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
