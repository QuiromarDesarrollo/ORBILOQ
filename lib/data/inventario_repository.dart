import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../application/auth_providers.dart';
import '../core/inventario_entorno.dart';

typedef InventarioFila = Map<String, dynamic>;

class InventarioRepository {
  InventarioRepository(this.client);
  final SupabaseClient client;

  Future<dynamic> ejecutar(String funcion, InventarioFila parametros) async =>
      await client.rpc(funcion, params: parametros);

  Future<InventarioFila> listar(String buscar, int pagina) async =>
      Map<String, dynamic>.from(
        await _leer('inventario_listar', {
              'p_buscar': buscar,
              'p_pagina': pagina,
            })
            as Map,
      );

  Future<List<InventarioFila>> filas(
    String funcion,
    InventarioFila parametros,
  ) async =>
      (await _leer(funcion, parametros) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  // Solo lecturas: una escritura lenta puede haber sido confirmada en servidor.
  Future<dynamic> _leer(String funcion, InventarioFila parametros) => ejecutar(
    funcion,
    parametros,
  ).timeout(
    const Duration(seconds: 20),
    onTimeout:
        () =>
            throw TimeoutException(
              'La consulta de inventario tardó demasiado. Revisa la conexión y pulsa Reintentar.',
            ),
  );
}

final inventarioRepositoryProvider = Provider<InventarioRepository?>(
  (ref) =>
      ref.watch(usarSupabaseProvider) && inventarioEnPruebas
          ? InventarioRepository(Supabase.instance.client)
          : null,
);
