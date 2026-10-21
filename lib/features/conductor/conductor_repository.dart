import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/auth_providers.dart';
import '../../core/conductor_entorno.dart';
import 'conductor_model.dart';
import 'historial_conductor.dart';

final conductorRepositoryProvider = Provider<ConductorRepository>((ref) {
  if (!conductorHabilitado()) throw StateError('Módulo exclusivo de pruebas.');
  return ConductorRepository(
    ref.watch(usarSupabaseProvider) ? Supabase.instance.client : null,
  );
});

class ConductorRepository {
  ConductorRepository(this.client);
  final SupabaseClient? client;
  final List<Map<String, dynamic>> _registros = [];
  List<VehiculoConductor> _vehiculos = [
    const VehiculoConductor(
      id: 'demo',
      placa: 'DEMO 01',
      descripcion: 'Vehículo de demostración',
      km: 48250,
      datos: {'proximo_aceite': '49000'},
    ),
  ];
  bool get demo => client == null;

  Future<List<VehiculoConductor>> vehiculos() async {
    if (demo) return _vehiculos;
    final data = await client!
        .from('conductor_vehiculos')
        .select()
        .order('placa')
        .limit(100);
    return data.map(VehiculoConductor.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> historial(String id) async {
    if (demo) return _registros.where((e) => e['vehiculo_id'] == id).toList();
    return _paginaHistorial(id, limite: 100);
  }

  Future<List<Map<String, dynamic>>> _paginaHistorial(
    String id, {
    String? desde,
    String? hasta,
    int offset = 0,
    int limite = 200,
  }) async {
    final data = await client!.rpc(
      'conductor_historial',
      params: {
        'p_vehiculo': id,
        'p_desde': desde,
        'p_hasta': hasta,
        'p_offset': offset,
        'p_limite': limite,
      },
    );
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> historialPeriodo(
    String id,
    DateTime desde,
    DateTime hasta,
  ) async {
    final inicio = desde.toIso8601String().substring(0, 10);
    final fin = hasta.toIso8601String().substring(0, 10);
    if (desde.isAfter(hasta)) {
      throw const FormatException('Rango de fechas inválido.');
    }
    if (demo) {
      return _registros
          .where(
            (r) =>
                r['vehiculo_id'] == id &&
                fechaRegistroConductor(r).compareTo(inicio) >= 0 &&
                fechaRegistroConductor(r).compareTo(fin) <= 0,
          )
          .toList();
    }
    final registros = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final pagina = await _paginaHistorial(
        id,
        desde: inicio,
        hasta: fin,
        offset: offset,
      );
      registros.addAll(pagina);
      if (pagina.length < 200) return registros;
    }
  }

  Future<void> guardar(
    String id,
    String tipo,
    int km,
    Map<String, dynamic> datos,
  ) async {
    if (demo) {
      final v = _vehiculos.firstWhere((v) => v.id == id);
      final fallo = validarRegistroConductor(
        tipo: tipo,
        km: km,
        ultimoKm: v.km,
        respuestas: Map<String, String>.from(datos['respuestas'] as Map? ?? {}),
        notas: datos['notas']?.toString() ?? '',
        enlace: datos['enlace']?.toString() ?? '',
      );
      if (fallo != null) throw StateError(fallo);
      if (tipo == 'Inicio de jornada' || tipo == 'Fin de jornada') {
        final hoy = DateTime.now().toIso8601String().substring(0, 10);
        datos = {...datos, 'fecha': hoy};
        final jornada = _registros.where(
          (e) => e['vehiculo_id'] == id && e['datos']['fecha'] == hoy,
        );
        if (jornada.any((e) => e['tipo'] == tipo)) {
          throw StateError('Inspección ya registrada.');
        }
        if (tipo == 'Fin de jornada' &&
            !jornada.any((e) => e['tipo'] == 'Inicio de jornada')) {
          throw StateError('Primero registra el inicio.');
        }
      }
      _registros.insert(0, {
        'vehiculo_id': id,
        'tipo': tipo,
        'km': km,
        'creado': DateTime.now().toIso8601String(),
        'datos': datos,
        'actor_nombre': 'Usuario de demostración',
      });
      _vehiculos =
          _vehiculos
              .map(
                (v) =>
                    v.id != id
                        ? v
                        : VehiculoConductor(
                          id: v.id,
                          placa: v.placa,
                          descripcion: v.descripcion,
                          km: km,
                          datos:
                              tipo == 'Documentos'
                                  ? {...v.datos, ...datos}
                                  : v.datos,
                        ),
              )
              .toList();
      return;
    }
    await client!.rpc(
      'conductor_registrar',
      params: {'p_vehiculo': id, 'p_tipo': tipo, 'p_km': km, 'p_datos': datos},
    );
  }

  Future<void> crearVehiculo(
    String placa,
    String descripcion,
    int km,
    String numero,
  ) async {
    if (demo) {
      _vehiculos.add(
        VehiculoConductor(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          placa: placa,
          descripcion: descripcion,
          km: km,
        ),
      );
      return;
    }
    await client!.rpc(
      'conductor_asignar_vehiculo',
      params: {
        'p_placa': placa,
        'p_descripcion': descripcion,
        'p_km': km,
        'p_numero': numero,
      },
    );
  }
}
