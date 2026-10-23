import 'ficha_vehiculo.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'conductor_model.dart';

String fechaRegistroConductor(Map<String, dynamic> registro) {
  final fecha = registro['datos']?['fecha']?.toString() ?? '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha) &&
      DateTime.tryParse(fecha)?.toIso8601String().substring(0, 10) == fecha) {
    return fecha;
  }
  final creado = DateTime.tryParse(registro['creado']?.toString() ?? '');
  return creado == null
      ? 'Sin fecha'
      : creado
          .toUtc()
          .subtract(const Duration(hours: 5))
          .toIso8601String()
          .substring(0, 10);
}

class JornadaConductor {
  JornadaConductor(this.fecha, this.registros);
  final String fecha;
  final List<Map<String, dynamic>> registros;
  bool get inicio => registros.any((r) => r['tipo'] == 'Inicio de jornada');
  bool get fin => registros.any((r) => r['tipo'] == 'Fin de jornada');
  int get inspecciones => (inicio ? 1 : 0) + (fin ? 1 : 0);
}

List<JornadaConductor> agruparJornadasConductor(
  List<Map<String, dynamic>> registros,
) {
  final grupos = <String, List<Map<String, dynamic>>>{};
  for (final r in registros) {
    grupos.putIfAbsent(fechaRegistroConductor(r), () => []).add(r);
  }
  return (grupos.keys.toList()..sort((a, b) => b.compareTo(a)))
      .map((fecha) => JornadaConductor(fecha, grupos[fecha]!))
      .toList();
}

final etiquetasDatosConductor = <String, String>{
  'origen_mantenimiento': 'Origen del mantenimiento',
  'checklist_origen_id': 'Checklist de origen',
  'novedades_origen': 'Novedades del checklist',
  for (final grupo in fichaVehiculoCampos.values)
    for (final campo in grupo) campo.key: campo.label,
  'conductor_documento': 'Número de documento del conductor',
  'foto_conductor': 'Foto del conductor · enlace Drive',
  for (final d in documentosFicha.entries) ...{
    'doc_${d.key}': '${d.value} · enlace Drive',
    '${d.key}_desde': '${d.value} · Vigencia desde',
    '${d.key}_expedido': '${d.value} · Expedición',
    '${d.key}_valor': '${d.value} · Valor COP',
    '${d.key}_observaciones': '${d.value} · Observaciones',
  },
  'fecha': 'Fecha de actividad',
  'fecha_inicio': 'Fecha de inicio',
  'hora_inicio': 'Hora de inicio',
  'fecha_fin': 'Fecha fin',
  'hora_fin': 'Hora fin',
  'servicio_id': 'Código del servicio',
  'hora_mantenimiento': 'Hora del mantenimiento',
  'resultado': 'Resultado de inspección',
  'notas': 'Novedades / observaciones',
  'siniestro': '¿Ocurrió un siniestro?',
  'hecho': 'Descripción del siniestro',
  'galones': 'Galones del tanqueo',
  'km_tanqueo': 'Kilometraje del tanqueo',
  'cantidad': 'Cantidad (según actividad)',
  'valor': 'Valor · COP',
  'estacion': 'Estación de servicio',
  'servicio': 'Servicio / mantenimiento realizado',
  'taller': 'Taller o responsable',
  'fluido': 'Fluido repuesto',
  'proximo_km': 'Próximo control · km',
  'proxima_fecha': 'Próximo control · fecha',
  'proximo_aceite': 'Próximo cambio de aceite · km',
  'licencia_transito': 'Número de licencia de tránsito',
  'SOAT': 'Vencimiento SOAT',
  'Revisión tecnicomecánica': 'Vencimiento tecnicomecánica',
  'Licencia de conducción': 'Vencimiento licencia de conducción',
  'Extintor': 'Vencimiento extintor',
  'enlace': 'Evidencia / factura · enlace Drive',
  'foto_frontal': 'Foto frontal · enlace Drive',
  'foto_lateral': 'Foto lateral · enlace Drive',
  'foto_lateral_derecho': 'Foto lateral derecho · enlace Drive',
  'foto_lateral_izquierdo': 'Foto lateral izquierdo · enlace Drive',
  'foto_trasera': 'Foto trasera · enlace Drive',
  'foto_tablero': 'Foto tablero · enlace Drive',
  'evidencia_siniestro': 'Evidencia del siniestro · enlace Drive',
};

bool _tieneContenido(Object? valor) {
  if (valor == null) return false;
  if (valor is String) return valor.trim().isNotEmpty;
  if (valor is Map) return valor.values.any(_tieneContenido);
  if (valor is Iterable) return valor.any(_tieneContenido);
  return true; // Cero y false son respuestas, no celdas vacías.
}

Map<String, Object?> aplanarDatosConductor(Map datos, [String prefijo = '']) {
  final salida = <String, Object?>{};
  for (final e in datos.entries) {
    if (!_tieneContenido(e.value)) continue;
    final key = '$prefijo${e.key}';
    if (e.value is Map && (e.value as Map).isNotEmpty) {
      salida.addAll(aplanarDatosConductor(e.value as Map, '$key / '));
    } else {
      salida[key] =
          e.value is List || e.value is Map ? jsonEncode(e.value) : e.value;
    }
  }
  return salida;
}

/// Una fila por registro: no se pierden actividades ni campos adicionales.
/// Los archivos se exportan como URL, nunca como bytes ni imágenes incrustadas.
Uint8List generarExcelHistorialConductor(
  VehiculoConductor vehiculo,
  List<JornadaConductor> jornadas,
) {
  if (jornadas.isEmpty) {
    throw const FormatException('Selecciona al menos un día.');
  }
  final registros =
      jornadas.expand((j) => j.registros).toList()..sort(
        (a, b) => (a['creado'] ?? '').toString().compareTo(
          (b['creado'] ?? '').toString(),
        ),
      );
  final planos =
      registros
          .map((r) => aplanarDatosConductor(r['datos'] as Map? ?? {}))
          .toList();
  for (final datos in planos) {
    for (final key in ['valor', 'km_tanqueo', 'proximo_km', 'proximo_aceite']) {
      final numero = num.tryParse(datos[key]?.toString() ?? '');
      if (numero != null && numero.isFinite) datos[key] = numero;
    }
  }
  final campos =
      <String>{
        ...etiquetasDatosConductor.keys,
        for (final categoria in checklistConductor.entries)
          for (final pregunta in categoria.value) 'respuestas / $pregunta',
        for (final datos in planos) ...datos.keys,
      }.toList();
  final libro = Excel.createExcel();
  final defecto = libro.getDefaultSheet()!;
  void hoja(String nombre, List<List<Object?>> filas) {
    final columnas = [
      for (var c = 0; c < filas.first.length; c++)
        if (filas.skip(1).any((fila) => _tieneContenido(fila[c]))) c,
    ];
    filas = [
      for (final fila in filas) [for (final c in columnas) fila[c]],
    ];
    if (filas.length > 1048576 || filas.first.length > 16384) {
      throw const FormatException(
        'El reporte supera el límite de Excel. Reduce el período.',
      );
    }
    final sheet = libro[nombre];
    for (final fila in filas) {
      sheet.appendRow(
        fila.map((valor) {
          if (valor is int) return IntCellValue(valor);
          if (valor is num) return DoubleCellValue(valor.toDouble());
          final texto =
              valor is bool ? (valor ? 'Sí' : 'No') : valor?.toString() ?? '';
          if (texto.length > 32767) {
            throw const FormatException(
              'Un dato supera el tamaño de celda permitido por Excel.',
            );
          }
          // TextCellValue evita ejecutar fórmulas suministradas por el usuario.
          return TextCellValue(texto);
        }).toList(),
      );
    }
    for (var c = 0; c < filas.first.length; c++) {
      sheet.setColumnWidth(c, c == 0 ? 16 : 28);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#0B3545'),
        textWrapping: TextWrapping.WrapText,
      );
    }
    sheet.setRowHeight(0, 42);
  }

  hoja('Jornadas', [
    [
      'Fecha',
      'Placa',
      'Vehículo',
      'Inicio de jornada',
      'Fin de jornada',
      'Inspecciones completadas',
      'Total de registros',
    ],
    for (final j in jornadas)
      [
        j.fecha,
        vehiculo.placa,
        vehiculo.descripcion,
        j.inicio ? 'Registrado' : 'Pendiente',
        j.fin ? 'Registrado' : 'Pendiente',
        j.inspecciones,
        j.registros.length,
      ],
  ]);
  final grupos = <String, List<int>>{};
  for (var i = 0; i < registros.length; i++) {
    final tipo = registros[i]['tipo']?.toString().trim() ?? '';
    final grupo = switch (tipo) {
      'Inicio de jornada' || 'Fin de jornada' => 'Checklist',
      'Novedad' || 'Novedades' => 'Novedades',
      'Checklist semanal de carretera' => 'Kit semanal',
      '' => 'Otros registros',
      _ => tipo,
    };
    grupos.putIfAbsent(grupo, () => []).add(i);
  }
  // Orden estable y nombres válidos aun si aparecen nuevos tipos de actividad.
  final tipos =
      grupos.keys.toList()..sort((a, b) {
        const prioridad = ['Checklist', 'Registro diario', 'Novedades'];
        final pa = prioridad.indexOf(a), pb = prioridad.indexOf(b);
        if (pa >= 0 || pb >= 0) {
          return (pa < 0 ? 3 : pa).compareTo(pb < 0 ? 3 : pb);
        }
        return a.compareTo(b);
      });
  final nombres = {'jornadas', defecto.toLowerCase()};
  for (final tipo in tipos) {
    var base = tipo.replaceAll(RegExp(r'[\x00-\x1F\[\]:*?/\\]'), ' ').trim();
    base = base.replaceAll(RegExp(r"^'+|'+$"), '');
    if (base.isEmpty) base = 'Otros registros';
    if (base.length > 31) base = base.substring(0, 31);
    var nombre = base;
    var numero = 2;
    while (!nombres.add(nombre.toLowerCase())) {
      final sufijo = ' (${numero++})';
      nombre =
          '${base.substring(0, base.length > 31 - sufijo.length ? 31 - sufijo.length : base.length)}$sufijo';
    }
    hoja(nombre, [
      [
        'Fecha',
        'Placa',
        'Vehículo',
        'ID del registro',
        'ID del vehículo',
        'Conductor / usuario',
        'ID del usuario',
        'Tipo de registro',
        'Kilometraje',
        'Marca temporal (UTC)',
        for (final key in campos)
          etiquetasDatosConductor[key] ??
              key.replaceFirst('respuestas / ', 'Checklist · '),
      ],
      for (final i in grupos[tipo]!)
        [
          fechaRegistroConductor(registros[i]),
          vehiculo.placa,
          vehiculo.descripcion,
          registros[i]['id'],
          registros[i]['vehiculo_id'],
          registros[i]['actor_nombre'],
          registros[i]['actor_id'],
          registros[i]['tipo'],
          registros[i]['km'],
          registros[i]['creado'],
          for (final key in campos) planos[i][key],
        ],
    ]);
  }
  libro.delete(defecto);
  libro.setDefaultSheet('Jornadas');
  return Uint8List.fromList(libro.encode()!);
}
