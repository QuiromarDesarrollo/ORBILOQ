import 'package:supabase_flutter/supabase_flutter.dart';

typedef FilaReporte = Map<String, dynamic>;

abstract class ReportesAdminRepository {
  Future<FilaReporte> resumen();
  Future<List<FilaReporte>> cargar(String tipo);
}

class SupabaseReportesAdminRepository implements ReportesAdminRepository {
  SupabaseReportesAdminRepository(this.client);
  final SupabaseClient client;
  @override
  Future<FilaReporte> resumen() async => Map<String, dynamic>.from(
      await client.rpc('admin_reporte_resumen') as Map);
  @override
  Future<List<FilaReporte>> cargar(String tipo) async {
    // El corte viene del servidor: el reloj del dispositivo puede estar desfasado.
    final corte = (await resumen())['actualizado_en'] as String;
    var cursor = '';
    final todas = <FilaReporte>[];
    while (true) {
      final pagina = (await client.rpc('admin_reporte_pagina', params: {
        'p_tipo': tipo,
        'p_despues': cursor,
        'p_corte': corte,
      }) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      todas.addAll(pagina);
      if (pagina.length < 1000) break;
      final siguiente = pagina.last['registro'] as String;
      if (siguiente == cursor) {
        throw StateError('No se pudo completar el reporte.');
      }
      cursor = siguiente;
    }
    todas.sort((a, b) => '${b['fecha']}'.compareTo('${a['fecha']}'));
    return todas;
  }
}

/// Fecha de los reportes en la zona del taller (UTC-5), independiente del equipo.
DateTime? fechaReporte(dynamic valor) {
  final fecha = DateTime.tryParse('$valor');
  if (fecha == null) return null;
  final bogota = fecha.toUtc().subtract(const Duration(hours: 5));
  return DateTime(bogota.year, bogota.month, bogota.day, bogota.hour,
      bogota.minute, bogota.second);
}

List<FilaReporte> filtrarReporte(
  List<FilaReporte> filas, {
  String op = '',
  String persona = '',
  String cliente = '',
  String causal = '',
  String tipo = '',
  DateTime? desde,
  DateTime? hasta,
}) =>
    filas.where((f) {
      bool contiene(String campo, String filtro) => '${f[campo] ?? ''}'
          .toLowerCase()
          .contains(filtro.trim().toLowerCase());
      final fecha = fechaReporte(f['fecha']);
      return contiene('op', op) &&
          contiene('persona', persona) &&
          contiene('cliente', cliente) &&
          contiene('causal', causal) &&
          contiene('tipo', tipo) &&
          (desde == null ||
              (fecha != null &&
                  !fecha.isBefore(
                      DateTime(desde.year, desde.month, desde.day)))) &&
          (hasta == null ||
              (fecha != null &&
                  fecha.isBefore(
                      DateTime(hasta.year, hasta.month, hasta.day + 1))));
    }).toList();

List<FilaReporte> resumirNoConforme(List<FilaReporte> filas, String dimension) {
  final grupos = <String, FilaReporte>{};
  for (final f in filas) {
    final fecha = fechaReporte(f['fecha']);
    final etiqueta = dimension == 'mes'
        ? (fecha == null
            ? 'Sin fecha'
            : '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}')
        : ('${f[dimension] ?? ''}'.trim().isEmpty
            ? 'Sin registrar'
            : '${f[dimension]}');
    final g = grupos.putIfAbsent(
        etiqueta, () => {'grupo': etiqueta, 'reportes': 0, 'unidades': 0});
    g['reportes'] = (g['reportes'] as int) + 1;
    g['unidades'] =
        (g['unidades'] as int) + ((f['cantidad'] as num?)?.toInt() ?? 0);
  }
  return grupos.values.toList()
    ..sort((a, b) => dimension == 'mes'
        ? '${a['grupo']}'.compareTo('${b['grupo']}')
        : (b['unidades'] as int).compareTo(a['unidades'] as int));
}
