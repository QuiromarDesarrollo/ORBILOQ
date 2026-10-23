import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';

void main() {
  for (final privado in [false, true]) {
    test(
      'Origen del mantenimiento respeta historial ${privado ? 'privado' : 'administrativo'}',
      () async {
        var consultasRevision = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          httpClient: MockClient((request) async {
            Object respuesta;
            if (request.url.path.endsWith('/conductor_historial')) {
              respuesta = [
                for (final id in [
                  'check',
                  'independiente',
                  'directo',
                  'sin-vinculo',
                ])
                  {
                    'id': id,
                    'tipo': 'Mantenimiento correctivo',
                    if (!privado) 'km': 100,
                    'datos': {
                      'fecha': '2026-10-23',
                      if (!privado && id != 'directo') 'actividad_id': id,
                    },
                  },
              ];
            } else {
              consultasRevision++;
              expect(
                request.url.path.endsWith('/conductor_revision_resumen'),
                true,
              );
              expect((jsonDecode(request.body) as Map)['p_detalle'], true);
              respuesta = {
                'version': 2,
                'tareas': [
                  {
                    'id': 'check',
                    'registro_id': 'checklist-1',
                    'estado': 'Cerrada',
                    'motivos': ['Luces altas'],
                  },
                  {
                    'id': 'independiente',
                    'registro_id': null,
                    'estado': 'Cerrada',
                  },
                ],
              };
            }
            return http.Response(
              jsonEncode(respuesta),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        final repo = ConductorRepository(client);
        for (final registros in [
          await repo.historial('v'),
          await repo.historialPeriodo(
            'v',
            DateTime(2026, 10),
            DateTime(2026, 10, 23),
          ),
        ]) {
          if (privado) {
            expect(
              registros.every((r) => (r['datos'] as Map).keys.length == 1),
              true,
            );
          } else {
            expect(
              registros.map((r) => r['datos']['origen_mantenimiento']).toList(),
              [
                'Desde checklist',
                'Independiente',
                'Independiente',
                'Origen no disponible',
              ],
            );
            expect(
              registros.first['datos']['checklist_origen_id'],
              'checklist-1',
            );
            expect(registros.first['datos']['novedades_origen'], [
              'Luces altas',
            ]);
          }
        }
        expect(consultasRevision, privado ? 0 : 2);
        await client.dispose();
      },
    );
  }
}
