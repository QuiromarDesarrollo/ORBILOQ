import '../data/reportes_admin_repository.dart';
import '../domain/models.dart';
import 'dashboard_tendencias.dart';

String clienteDashboard(Object? valor) =>
    '$valor'.trim().isEmpty || valor == null
        ? 'Sin cliente registrado'
        : '$valor'.trim();
bool _enRango(FilaReporte f, DateTime corte, DateTime? desde) {
  final fecha = DateTime.tryParse('${f['fecha']}');
  if (fecha == null || fecha.toUtc().isAfter(corte.toUtc())) return false;
  final local = fechaReporte(f['fecha'])!;
  return desde == null ||
      !DateTime.utc(local.year, local.month, local.day).isBefore(desde);
}

int _cantidad(FilaReporte f) {
  final v = num.tryParse('${f['cantidad']}');
  return v == null || !v.isFinite || v <= 0 || v != v.truncateToDouble()
      ? 0
      : v.toInt();
}

bool _operativo(FilaReporte f) {
  final raw = f['datos_crudos'];
  return raw is! Map || raw['admin_correccion_id'] == null;
}

Map<String, int> volumenClientes(
  List<FilaReporte> filas, {
  required DateTime corte,
  required int semanas,
  String tipo = 'despacho',
}) {
  final desde =
      calcularTendencias(
        [],
        corte: corte,
        semanas: semanas,
      ).semanas.first.inicio;
  final grupos = <String, int>{};
  for (final f in filas) {
    if (f['tipo'] != tipo || !_operativo(f) || !_enRango(f, corte, desde)) {
      continue;
    }
    final n = _cantidad(f);
    if (n == 0) continue;
    final cliente = clienteDashboard(f['cliente']);
    grupos[cliente] = (grupos[cliente] ?? 0) + n;
  }
  return Map.fromEntries(
    grupos.entries.toList()..sort((a, b) {
      final orden = b.value.compareTo(a.value);
      return orden == 0 ? a.key.compareTo(b.key) : orden;
    }),
  );
}

class CausalComparada {
  CausalComparada(this.nombre);
  final String nombre;
  int recientes = 0, historico = 0;
}

List<CausalComparada> compararCausales(
  List<FilaReporte> filas,
  DateTime corte,
) {
  final desde =
      calcularTendencias([], corte: corte, semanas: 4).semanas.first.inicio;
  final grupos = <String, CausalComparada>{};
  final vistos = <String>{};
  for (final f in filas) {
    if (!_enRango(f, corte, null)) continue;
    if (f['registro'] != null && !vistos.add('${f['registro']}')) continue;
    final n = _cantidad(f);
    if (n == 0) continue;
    final nombre = '${f['causal'] ?? ''}'.trim();
    final c = grupos.putIfAbsent(
      nombre,
      () => CausalComparada(nombre.isEmpty ? 'Sin causal registrada' : nombre),
    );
    c.historico += n;
    if (_enRango(f, corte, desde)) c.recientes += n;
  }
  return grupos.values.toList()..sort((a, b) {
    final orden = b.historico.compareTo(a.historico);
    return orden == 0 ? a.nombre.compareTo(b.nombre) : orden;
  });
}

class SaludCliente {
  SaludCliente(this.nombre);
  final String nombre;
  int entregado = 0, noConforme = 0, sinFecha = 0;
  final activas = <String>{}, vencidas = <String>{}, proximas = <String>{};
  double? get tasa => entregado == 0 ? null : noConforme * 100 / entregado;
  int get nivel =>
      vencidas.isNotEmpty || (tasa ?? 0) > 5
          ? 2
          : proximas.isNotEmpty ||
              sinFecha > 0 ||
              tasa == null ||
              (tasa ?? 0) > 2
          ? 1
          : 0;
  String get motivo => [
    if (vencidas.isNotEmpty) '${vencidas.length} OP vencida(s)',
    if (proximas.isNotEmpty) '${proximas.length} OP vence(n) en 3 días o menos',
    if (sinFecha > 0) '$sinFecha etapa(s) pendiente(s) sin fecha',
    if (tasa == null) 'Sin entregas para calcular tasa NC',
    if ((tasa ?? 0) > 2) 'Tasa NC superior al 2 %',
    if (nivel == 0) 'Sin alertas en los criterios evaluados',
  ].join(' · ');
}

List<SaludCliente> saludClientes(
  List<ItemKardex> kardex,
  List<FilaReporte> movimientos,
  List<FilaReporte> nc, {
  required DateTime corte,
  required int semanas,
}) {
  final desde =
      calcularTendencias(
        [],
        corte: corte,
        semanas: semanas,
      ).semanas.first.inicio;
  final hoyLocal = fechaReporte(corte.toUtc().toIso8601String())!;
  final hoy = DateTime.utc(hoyLocal.year, hoyLocal.month, hoyLocal.day);
  final grupos = <String, SaludCliente>{};
  SaludCliente grupo(Object? nombre) {
    final k = clienteDashboard(nombre);
    return grupos.putIfAbsent(k, () => SaludCliente(k));
  }

  for (final f in [...movimientos, ...nc]) {
    if (_enRango(f, corte, null)) grupo(f['cliente']);
  }
  for (final k in kardex.where((k) => !k.eliminada)) {
    final c = grupo(k.item.cliente);
    void evaluar(int pendiente, DateTime? fecha) {
      if (pendiente <= 0) return;
      c.activas.add(k.item.op);
      if (fecha == null) {
        c.sinFecha++;
        return;
      }
      final dias =
          DateTime.utc(
            fecha.year,
            fecha.month,
            fecha.day,
          ).difference(hoy).inDays;
      if (dias < 0) {
        c.vencidas.add(k.item.op);
      } else if (dias <= 3) {
        c.proximas.add(k.item.op);
      }
    }

    evaluar(k.pendienteProduccion, k.fechaEsperadaProduccion);
    evaluar(k.pendienteDespacho, k.fechaEsperadaLogistica);
  }
  final entregado = volumenClientes(
    movimientos,
    corte: corte,
    semanas: semanas,
    tipo: 'entrega_produccion',
  );
  for (final e in entregado.entries) {
    grupo(e.key).entregado = e.value;
  }
  final vistos = <String>{};
  for (final f in nc) {
    if (!_enRango(f, corte, desde)) continue;
    if (f['registro'] != null && !vistos.add('${f['registro']}')) continue;
    grupo(f['cliente']).noConforme += _cantidad(f);
  }
  return grupos.values.toList()..sort((a, b) {
    final nivel = b.nivel.compareTo(a.nivel);
    return nivel == 0 ? a.nombre.compareTo(b.nombre) : nivel;
  });
}
