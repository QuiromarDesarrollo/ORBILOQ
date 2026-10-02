import '../domain/models.dart';
import '../data/reportes_admin_repository.dart';

const etapasDashboard = [
  'En Producción',
  'Por Recibir',
  'Por Despachar',
  'Completo',
];

List<int> contarEtapas(List<ItemKardex> filas) {
  final etapas = <String, int>{};
  for (final k in filas.where((k) => !k.eliminada)) {
    final etapa =
        k.pendienteProduccion > 0 ||
                k.pendienteReproceso > 0 ||
                k.pendienteAliados > 0
            ? 0
            : k.pendienteRecibir > 0
            ? 1
            : k.pendienteDespacho > 0
            ? 2
            : 3;
    final anterior = etapas[k.item.op];
    if (anterior == null || etapa < anterior) etapas[k.item.op] = etapa;
  }
  return List.generate(4, (i) => etapas.values.where((e) => e == i).length);
}

class AlertaDashboard {
  const AlertaDashboard(this.titulo, this.detalle, this.dias, this.urgente);
  final String titulo, detalle;
  final int dias;
  final bool urgente;
}

DateTime _dia(DateTime d) => DateTime.utc(d.year, d.month, d.day);

List<AlertaDashboard> calcularAtencion(
  List<ItemKardex> kardex,
  List<FilaReporte> auditoria, {
  required DateTime corte,
  int proximos = 3,
  int antiguedad = 7,
}) {
  final hoy = _dia(fechaReporte(corte.toUtc().toIso8601String())!);
  final alertas = <AlertaDashboard>[];
  final fechas = <String, DateTime>{};
  final pendientes = <String, int>{};
  for (final k in kardex.where((k) => !k.eliminada)) {
    void evaluar(String etapa, int cantidad, DateTime? fecha) {
      if (cantidad <= 0 || fecha == null) return;
      final clave = 'OP ${k.item.op} · $etapa · ${k.item.cliente}';
      final dia = _dia(fecha);
      final dias = dia.difference(hoy).inDays;
      if (dias > proximos) return;
      if (fechas[clave] == null || dia.isBefore(fechas[clave]!)) {
        fechas[clave] = dia;
      }
      pendientes[clave] = (pendientes[clave] ?? 0) + cantidad;
    }

    evaluar('Producción', k.pendienteProduccion, k.fechaEsperadaProduccion);
    evaluar('Despacho', k.pendienteDespacho, k.fechaEsperadaLogistica);
  }
  for (final e in fechas.entries) {
    final dias = e.value.difference(hoy).inDays;
    alertas.add(
      AlertaDashboard(
        e.key,
        '${pendientes[e.key]} uds. en líneas con fecha próxima o vencida · ${dias < 0
            ? 'fecha más antigua vencida hace ${-dias} días'
            : dias == 0
            ? 'vence hoy'
            : 'vence en $dias días'}',
        -dias,
        dias <= 0,
      ),
    );
  }
  final ultimaActividad = <String, DateTime>{};
  final itemsAliados = <Object, Object>{};
  for (final f in auditoria.where((f) => f['origen'] == 'Aliados')) {
    final raw = f['datos_crudos'];
    if (raw is Map && raw['id'] != null && raw['item_orden_id'] != null) {
      itemsAliados[raw['id']] = raw['item_orden_id'];
    }
  }
  final vistos = <String>{};
  for (final f in auditoria) {
    final registro = f['registro'];
    if (registro != null && !vistos.add('$registro')) continue;
    final fecha = DateTime.tryParse('${f['fecha']}');
    if (fecha == null || fecha.toUtc().isAfter(corte.toUtc())) continue;
    final dia = _dia(fechaReporte(f['fecha'])!);
    final raw = f['datos_crudos'];
    if (raw is! Map) continue;
    final origen = f['origen'];
    if (origen == 'Sobrantes' && raw['estado'] == 'pendiente') {
      final dias = hoy.difference(dia).inDays;
      if (dias > antiguedad) {
        alertas.add(
          AlertaDashboard(
            'OP ${f['op']} · Sobrante pendiente',
            '${f['cliente']} · ${f['codigo']} · ${raw['cantidad']} uds. · $dias días sin resolver',
            dias,
            true,
          ),
        );
      }
    }
    final grupo = switch (origen) {
      'Logística' || 'Liberaciones' => 'Logística',
      'Aliados' || 'Liberaciones Aliados' => 'Aliados',
      _ => null,
    };
    // Liberaciones de Aliados puede no incluir item_orden_id: se enlaza
    // por solicitud con el reporte original, sin inferir una línea por OP.
    Object? item = raw['item_orden_id'];
    if (grupo == 'Aliados' && item == null && raw['solicitud_id'] != null) {
      item = itemsAliados[raw['solicitud_id']];
    }
    if (grupo == null || item == null) continue;
    final clave = '$grupo:$item';
    if (ultimaActividad[clave] == null ||
        dia.isAfter(ultimaActividad[clave]!)) {
      ultimaActividad[clave] = dia;
    }
  }
  for (final k in kardex.where((k) => !k.eliminada)) {
    for (final grupo in ['Logística', 'Aliados']) {
      final cantidad =
          grupo == 'Logística' ? k.pendienteReproceso : k.pendienteAliados;
      final fecha = ultimaActividad['$grupo:${k.id}'];
      if (cantidad <= 0 || fecha == null) continue;
      final dias = hoy.difference(fecha).inDays;
      if (dias > antiguedad) {
        alertas.add(
          AlertaDashboard(
            'OP ${k.item.op} · No conforme de $grupo',
            '${k.item.cliente} · ${k.item.codigo} · $cantidad uds. pendientes · $dias días sin reportes ni liberaciones',
            dias,
            true,
          ),
        );
      }
    }
  }
  alertas.sort((a, b) {
    final urgencia = (b.urgente ? 1 : 0).compareTo(a.urgente ? 1 : 0);
    if (urgencia != 0) return urgencia;
    final dias = b.dias.compareTo(a.dias);
    return dias != 0 ? dias : a.titulo.compareTo(b.titulo);
  });
  return alertas;
}
