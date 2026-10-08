import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/ciclos.dart';

class CiclosRepository {
  CiclosRepository(this.client);
  final SupabaseClient client;
  Future<DatosCiclos> cargar() async {
    final estado = Map<String, dynamic>.from(
      await client.rpc('ciclos_estado') as Map,
    );
    final revision = '${estado['revision']}';
    final ordenes = <OrdenCiclo>[];
    var cursor = '';
    while (true) {
      final pagina =
          (await client.rpc(
                    'ciclos_pagina',
                    params: {'p_despues': cursor, 'p_revision': revision},
                  )
                  as List)
              .map((v) => OrdenCiclo.json(Map<String, dynamic>.from(v as Map)))
              .toList();
      ordenes.addAll(pagina);
      if (pagina.length < 1000) break;
      if (pagina.last.op == cursor) {
        throw StateError('No se pudo completar la lectura.');
      }
      cursor = pagina.last.op;
    }
    return DatosCiclos(
      ordenes,
      [
        for (final v in estado['parametros'] as List)
          ParametroCiclo.json(Map<String, dynamic>.from(v as Map)),
      ],
      leerFechaCiclo(estado['hoy'])!,
      revision,
    );
  }

  Future<Map<String, dynamic>> importar(
    List<Map<String, dynamic>> filas,
    String revision,
    bool confirmar,
    String archivo,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
          'ciclos_importar',
          params: {
            'p_filas': filas,
            'p_revision': revision,
            'p_confirmar': confirmar,
            'p_archivo': archivo,
          },
        )
        as Map,
  );
  Future<void> configurar(
    ProcesoCiclo p,
    DateTime desde,
    int dias,
    int? diaria,
    int? semanal,
    String revision, {
    int? umbralCola,
  }) async {
    await client.rpc(
      'ciclos_configurar',
      params: {
        'p_proceso': p.name,
        'p_desde': fechaCiclo(desde),
        'p_dias': dias,
        'p_diaria': diaria,
        'p_semanal': semanal,
        'p_cola': umbralCola,
        'p_revision': revision,
      },
    );
  }
}
