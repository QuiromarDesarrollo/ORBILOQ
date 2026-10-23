import 'mantenimiento_preventivo.dart';
import 'kit_semanal.dart';
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

  final _autorizacionesDemo = <String, Map<String, dynamic>>{};
  final _tareasDemo = <Map<String, dynamic>>[];

  Future<Map<String, dynamic>> revisionSalida(
    String vehiculo, {
    bool detalle = false,
  }) async {
    if (demo) {
      final registros =
          _registros.where((r) => r['vehiculo_id'] == vehiculo).toList();
      final hoy = fechaKit(hoyColombia());
      final salida =
          registros
              .where(
                (r) =>
                    r['tipo'] == 'Inicio de jornada' &&
                    r['datos']['fecha'] == hoy,
              )
              .firstOrNull;
      return {
        'version': 2,
        'estado':
            salida == null
                ? 'Sin checklist de salida'
                : _autorizacionesDemo[salida['id']]?['estado'] ??
                    'Pendiente de aprobación',
        'observacion': _autorizacionesDemo[salida?['id']]?['observacion'],
        'tareas':
            _tareasDemo
                .where(
                  (t) =>
                      (t['vehiculo_id'] == vehiculo ||
                          registros.any((r) => r['id'] == t['registro_id'])) &&
                      (detalle || t['estado'] != 'Cerrada'),
                )
                .toList(),
        'checklists':
            registros
                .where(
                  (r) => [
                    'Inicio de jornada',
                    'Fin de jornada',
                    tipoKitSemanal,
                  ].contains(r['tipo']),
                )
                .toList(),
      };
    }
    try {
      return Map<String, dynamic>.from(
        await client!.rpc(
              'conductor_revision_resumen',
              params: {'p_vehiculo': vehiculo, 'p_detalle': detalle},
            )
            as Map,
      );
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      return {
        'estado': 'Aprobación pendiente de activación',
        'disponible': false,
      };
    }
  }

  Future<void> revisionAccion(
    String? registro,
    String accion,
    String texto, {
    String? punto,
    String? tarea,
  }) async {
    if (texto.trim().isEmpty || texto.length > 1000) {
      throw const FormatException(
        'Escribe una observación de hasta 1000 caracteres.',
      );
    }
    if (!demo) {
      await client!.rpc(
        'conductor_revision_accion',
        params: {
          'p_registro': registro,
          'p_accion': accion,
          'p_texto': texto,
          'p_punto': punto,
          'p_tarea': tarea,
        },
      );
      return;
    }
    final r = _registros.where((r) => r['id'] == registro).firstOrNull;
    if (accion == 'Autorizado' || accion == 'No autorizado') {
      if (r == null ||
          r['tipo'] != 'Inicio de jornada' ||
          r['datos']['fecha'] != fechaKit(hoyColombia())) {
        throw const FormatException('Solo se autoriza la salida de hoy.');
      }
      _autorizacionesDemo[r['id']] = {'estado': accion, 'observacion': texto};
    } else if (accion == 'Crear actividad' || accion == 'Por verificar') {
      throw const FormatException(
        'Usa el formulario de actividad con fecha y evidencia.',
      );
    } else {
      final t = _tareasDemo.firstWhere(
        (t) => t['id'] == tarea && t['registro_id'] == registro,
      );
      if (!['Pendiente', 'Por verificar', 'Cerrada'].contains(accion) ||
          (accion == 'Por verificar'
              ? t['estado'] != 'Pendiente'
              : t['estado'] != 'Por verificar')) {
        throw const FormatException('Transición de actividad inválida.');
      }
      t['estado'] = accion;
      t['respuesta'] = texto;
      t['actualizado'] = DateTime.now().toUtc().toIso8601String();
    }
  }

  Future<void> crearActividad(
    String registro,
    List<String> motivos,
    String descripcion,
    String fecha,
  ) async {
    if (!demo) {
      await client!.rpc(
        'conductor_actividad_crear',
        params: {
          'p_registro': registro,
          'p_motivos': motivos,
          'p_descripcion': descripcion,
          'p_fecha': fecha,
        },
      );
      return;
    }
    if (motivos.isEmpty ||
        descripcion.trim().isEmpty ||
        fecha.compareTo(fechaKit(hoyColombia())) < 0) {
      throw const FormatException(
        'Completa motivos, descripción y fecha límite.',
      );
    }
    final r = _registros.firstWhere((r) => r['id'] == registro);
    for (final motivo in motivos) {
      final valor = r['datos']['respuestas'][motivo];
      if (valor != 'Con novedad' &&
          !(valor is Map && valor['estado'] == 'Con novedad')) {
        throw const FormatException('Selecciona solo puntos con novedad.');
      }
      if (_tareasDemo.any(
        (t) =>
            t['registro_id'] == registro &&
            (t['motivos'] as List).contains(motivo),
      )) {
        throw const FormatException(
          'El punto ya tiene una actividad asignada para este checklist.',
        );
      }
    }
    _tareasDemo.add({
      'id': 'tarea-${_tareasDemo.length}',
      'registro_id': registro,
      'motivos': motivos,
      'punto': motivos.join(', '),
      'descripcion': descripcion,
      'fecha_limite': fecha,
      'estado': 'Pendiente',
    });
  }

  Future<void> crearActividadMantenimiento(
    String vehiculo,
    String? registro,
    List<String> motivos,
    String descripcion,
    String fecha,
    String tipo,
    String trabajo, {
    String? servicioId,
  }) async {
    if (!demo) {
      await client!.rpc(
        'conductor_actividad_mantenimiento_crear',
        params: {
          'p_vehiculo': vehiculo,
          'p_registro': registro,
          'p_motivos': motivos,
          'p_descripcion': descripcion,
          'p_fecha': fecha,
          'p_tipo': tipo,
          'p_trabajo': trabajo,
          'p_servicio': tipo == 'Mantenimiento preventivo' ? servicioId : null,
        },
      );
      return;
    }
    if (![
          'Mantenimiento preventivo',
          'Mantenimiento correctivo',
        ].contains(tipo) ||
        trabajo.trim().isEmpty ||
        descripcion.trim().isEmpty ||
        fecha.compareTo(fechaKit(hoyColombia())) < 0) {
      throw const FormatException(
        'Completa el mantenimiento y la fecha límite.',
      );
    }
    if (tipo == 'Mantenimiento preventivo' &&
        !serviciosPreventivos.any(
          (s) => s.id == servicioId && s.nombre == trabajo,
        )) {
      throw const FormatException(
        'Selecciona un mantenimiento preventivo válido.',
      );
    }
    if (registro != null) {
      final origen = _registros.firstWhere((r) => r['id'] == registro);
      if (origen['vehiculo_id'] != vehiculo)
        throw const FormatException('Vehículo incorrecto.');
      await crearActividad(registro, motivos, descripcion, fecha);
    } else {
      _vehiculos.firstWhere((v) => v.id == vehiculo);
      if (motivos.isNotEmpty)
        throw const FormatException(
          'La actividad independiente no tiene motivos del checklist.',
        );
      _tareasDemo.add({
        'id': 'tarea-${_tareasDemo.length}',
        'registro_id': null,
        'motivos': <String>[],
        'descripcion': descripcion,
        'fecha_limite': fecha,
        'estado': 'Pendiente',
      });
    }
    _tareasDemo.last.addAll({
      'vehiculo_id': vehiculo,
      'mantenimiento_tipo': tipo,
      'mantenimiento_trabajo': trabajo.trim(),
      'servicio_id': tipo == 'Mantenimiento preventivo' ? servicioId : null,
    });
  }

  Future<void> entregarActividad(
    String tarea,
    String texto,
    String evidencia,
  ) async {
    if (!demo) {
      await client!.rpc(
        'conductor_actividad_entregar',
        params: {'p_tarea': tarea, 'p_texto': texto, 'p_evidencia': evidencia},
      );
      return;
    }
    if (texto.trim().isEmpty || !enlaceDriveValido(evidencia)) {
      throw const FormatException('Describe la solución y adjunta una foto.');
    }
    final t = _tareasDemo.firstWhere((t) => t['id'] == tarea);
    if (t['mantenimiento_tipo'] != null) {
      throw const FormatException(
        'Completa el formulario de mantenimiento asignado.',
      );
    }
    if (t['estado'] == 'Por verificar' &&
        t['solucion'] == texto &&
        t['evidencia'] == evidencia) {
      return;
    }
    if (t['estado'] != 'Pendiente') {
      throw const FormatException('La actividad ya no está pendiente.');
    }
    t.addAll({
      'estado': 'Por verificar',
      'solucion': texto,
      'evidencia': evidencia,
      'entregado_en': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> flotaResumen() async {
    if (!demo) {
      final filas = await client!.rpc('conductor_flota_resumen');
      final lista =
          (filas as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      if (lista.isEmpty) return lista;
      final kits =
          await client!.rpc(
                'conductor_resumen_kit',
                params: {'p_vehiculos': lista.map((v) => v['id']).toList()},
              )
              as Map;
      return [
        for (final v in lista)
          {
            ...v,
            'datos': {
              ...Map<String, dynamic>.from(v['datos'] as Map? ?? {}),
              'kit_semanal': kits[v['id']] ?? <String, dynamic>{},
            },
          },
      ];
    }
    return [
      for (final v in _vehiculos)
        {
          'id': v.id,
          'placa': v.placa,
          'descripcion': v.descripcion,
          'km': v.km,
          'datos': v.datos,
          'conductor_nombre':
              v.datos['conductor_nombre'] ?? 'Conductor de demostración',
          'autorizacion': (await revisionSalida(v.id))['estado'],
          'inicio': _registros.any(
            (r) =>
                r['vehiculo_id'] == v.id &&
                r['tipo'] == 'Inicio de jornada' &&
                r['datos']['fecha'] == fechaKit(hoyColombia()),
          ),
          'fin': _registros.any(
            (r) =>
                r['vehiculo_id'] == v.id &&
                r['tipo'] == 'Fin de jornada' &&
                r['datos']['fecha'] == fechaKit(hoyColombia()),
          ),
          'pendientes':
              ((await revisionSalida(v.id))['tareas'] as List)
                  .where((t) => t['estado'] == 'Pendiente')
                  .length,
          'por_verificar':
              ((await revisionSalida(v.id))['tareas'] as List)
                  .where((t) => t['estado'] == 'Por verificar')
                  .length,
          'vencidas':
              ((await revisionSalida(v.id))['tareas'] as List)
                  .where(
                    (t) =>
                        t['estado'] == 'Pendiente' &&
                        t['fecha_limite'] != null &&
                        t['fecha_limite'].compareTo(fechaKit(hoyColombia())) <
                            0,
                  )
                  .length,
        },
    ];
  }

  Future<List<VehiculoConductor>> vehiculos() async {
    if (demo) return _vehiculos;
    final data = await client!
        .from('conductor_vehiculos')
        .select()
        .order('placa')
        .limit(100);
    if (data.isEmpty) return [];
    Map<String, dynamic> resumen = {};
    var kitDisponible = true;
    try {
      resumen = Map<String, dynamic>.from(
        await client!.rpc(
              'conductor_resumen_kit',
              params: {'p_vehiculos': data.map((v) => v['id']).toList()},
            )
            as Map,
      );
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      // La versión anterior sigue operativa hasta aplicar la migración 118.
      kitDisponible = false;
    }
    return data
        .map(
          (v) => VehiculoConductor.fromJson({
            ...v,
            'datos': {
              ...Map<String, dynamic>.from(v['datos'] as Map? ?? {}),
              'kit_semanal': resumen[v['id']] ?? <String, dynamic>{},
              'kit_semanal_disponible': kitDisponible,
            },
          }),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> historial(String id) async {
    final registros =
        demo
            ? _registros.where((e) => e['vehiculo_id'] == id).toList()
            : await _paginaHistorial(id, limite: 100);
    return _conOrigenMantenimiento(id, registros);
  }

  Future<List<Map<String, dynamic>>> _conOrigenMantenimiento(
    String vehiculo,
    List<Map<String, dynamic>> registros,
  ) async {
    // El RPC del conductor entrega únicamente fecha y tipo: no enriquecer
    // ese historial privado ni consultar detalles de las actividades.
    bool completo(Map<String, dynamic> r) =>
        r['tipo'].toString().startsWith('Mantenimiento') && r.containsKey('km');
    final vinculados = registros.where(
      (r) => completo(r) && (r['datos'] as Map?)?['actividad_id'] != null,
    );
    final tareas = <String, Map>{};
    if (vinculados.isNotEmpty) {
      final revision = await revisionSalida(vehiculo, detalle: true);
      for (final t in (revision['tareas'] as List? ?? []).whereType<Map>()) {
        tareas[t['id'].toString()] = t;
      }
    }
    return [
      for (final r in registros)
        if (!completo(r)) r else _registroConOrigen(r, tareas),
    ];
  }

  Map<String, dynamic> _registroConOrigen(
    Map<String, dynamic> r,
    Map<String, Map> tareas,
  ) {
    final datos = Map<String, dynamic>.from(r['datos'] as Map? ?? {});
    final actividad = datos['actividad_id']?.toString();
    final tarea = tareas[actividad];
    final checklist = tarea?['registro_id']?.toString();
    return {
      ...r,
      'datos': {
        ...datos,
        'origen_mantenimiento':
            actividad == null
                ? 'Independiente'
                : tarea == null
                ? 'Origen no disponible'
                : checklist == null || checklist.isEmpty
                ? 'Independiente'
                : 'Desde checklist',
        if (checklist != null && checklist.isNotEmpty)
          'checklist_origen_id': checklist,
        if (checklist != null && checklist.isNotEmpty)
          'novedades_origen':
              tarea?['motivos'] ??
              [if (tarea?['punto'] != null) tarea!['punto']],
      },
    };
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
      return _conOrigenMantenimiento(
        id,
        _registros
            .where(
              (r) =>
                  r['vehiculo_id'] == id &&
                  fechaRegistroConductor(r).compareTo(inicio) >= 0 &&
                  fechaRegistroConductor(r).compareTo(fin) <= 0,
            )
            .toList(),
      );
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
      if (pagina.length < 200) return _conOrigenMantenimiento(id, registros);
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
      Map<String, dynamic>? actividad;
      if (datos['actividad_id'] != null) {
        actividad = _tareasDemo.firstWhere(
          (t) => t['id'] == datos['actividad_id'],
        );
        if (actividad['vehiculo_id'] != id ||
            actividad['estado'] != 'Pendiente' ||
            actividad['mantenimiento_tipo'] != tipo ||
            actividad['mantenimiento_trabajo'] != datos['servicio'] ||
            (tipo == 'Mantenimiento preventivo' &&
                actividad['servicio_id'] != datos['servicio_id'])) {
          throw const FormatException(
            'La actividad no está pendiente o el mantenimiento no coincide con lo asignado.',
          );
        }
        if (!enlaceDriveValido(datos['enlace']?.toString() ?? '')) {
          throw const FormatException('Adjunta evidencia del mantenimiento.');
        }
      }
      _registros.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'vehiculo_id': id,
        'tipo': tipo,
        'km': km,
        'creado': DateTime.now().toIso8601String(),
        'datos': datos,
        'actor_nombre': 'Usuario de demostración',
      });
      if (actividad != null) {
        actividad.addAll({
          'estado': 'Por verificar',
          'solucion': datos['servicio'],
          'evidencia': datos['enlace'],
          'mantenimiento_registro_id': _registros.first['id'],
          'mantenimiento_datos': datos,
          'entregado_en': DateTime.now().toUtc().toIso8601String(),
        });
      }
      var datosVehiculo = {...v.datos};
      if (tipo == 'Documentos') datosVehiculo.addAll(datos);
      if (tipo == 'Mantenimiento preventivo' && datos['servicio_id'] != null) {
        final resumen = Map<String, dynamic>.from(
          v.datos['mantenimientos_preventivos'] as Map? ?? {},
        );
        final servicio = datos['servicio_id'].toString();
        final fin = '${datos['fecha_fin']}T${datos['hora_fin']}:00';
        final anterior = resumen[servicio]?['fin']?.toString();
        if (anterior == null || fin.compareTo(anterior) >= 0) {
          resumen[servicio] = {'fin': fin, 'km': km};
          datosVehiculo['mantenimientos_preventivos'] = resumen;
          if (servicio == 'aceite') datosVehiculo['proximo_aceite'] = km + 8000;
        }
      }
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
                          datos: datosVehiculo,
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

  Future<void> guardarKit(String id, Map<String, dynamic> datos) async {
    final fallo = validarKit(datos, hoyColombia());
    if (fallo != null) throw FormatException(fallo);
    if (!demo) {
      await client!.rpc(
        'conductor_registrar_kit',
        params: {'p_vehiculo': id, 'p_datos': datos},
      );
      return;
    }
    final v = _vehiculos.firstWhere((v) => v.id == id);
    _registros.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'vehiculo_id': id,
      'tipo': tipoKitSemanal,
      'km': v.km,
      'creado': DateTime.now().toUtc().toIso8601String(),
      'datos': datos,
      'actor_nombre': datos['inspector'],
    });
    final previo = Map<String, dynamic>.from(
      v.datos['kit_semanal'] as Map? ?? {},
    );
    if ((datos['fecha'] as String).compareTo(
          previo['fecha']?.toString() ?? '',
        ) >=
        0) {
      _vehiculos =
          _vehiculos
              .map(
                (e) =>
                    e.id != id
                        ? e
                        : VehiculoConductor(
                          id: e.id,
                          placa: e.placa,
                          descripcion: e.descripcion,
                          km: e.km,
                          datos: {...e.datos, 'kit_semanal': resumenKit(datos)},
                        ),
              )
              .toList();
    }
  }

  Future<List<Map<String, dynamic>>> conductoresActivos() async {
    if (demo) {
      return [
        {'numero_usuario': '2', 'nombre': 'Conductor de demostración'},
        {'numero_usuario': '3', 'nombre': 'Segundo conductor'},
      ];
    }
    final filas = await client!.rpc(
      'admin_catalogos_listar',
      params: {'p_tipo': 'usuarios'},
    );
    final conductores =
        (filas as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where(
              (u) =>
                  u['activo'] == true &&
                  ((u['roles'] as List?) ?? [u['rol']]).contains('conductor'),
            )
            .toList();
    conductores.sort(
      (a, b) => a['nombre'].toString().toLowerCase().compareTo(
        b['nombre'].toString().toLowerCase(),
      ),
    );
    return conductores;
  }

  Future<void> crearVehiculo(
    String placa,
    String descripcion,
    int km,
    String numero,
  ) async {
    if (demo) {
      final normalizada = placa.trim().toUpperCase();
      final indice = _vehiculos.indexWhere((v) => v.placa == normalizada);
      final anterior = indice < 0 ? null : _vehiculos[indice];
      if (anterior != null && km < anterior.km) {
        throw StateError('El kilometraje no puede disminuir');
      }
      final vehiculo = VehiculoConductor(
        id: anterior?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        placa: normalizada,
        descripcion: descripcion,
        km: km,
        datos: {...?anterior?.datos, 'conductor_nombre': 'Conductor $numero'},
      );
      if (indice < 0) {
        _vehiculos.add(vehiculo);
      } else {
        _vehiculos[indice] = vehiculo;
      }
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
