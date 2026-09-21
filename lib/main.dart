import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/in_memory_wms_repository.dart';

/// Punto de composición: aquí se decide qué implementación de datos se usa.
/// Para conectar Supabase, sustituir [InMemoryWmsRepository] por
/// `SupabaseWmsRepository` sin tocar el resto de la app.
void main() {
  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
