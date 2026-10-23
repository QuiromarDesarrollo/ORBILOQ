import '../domain/models.dart';
import '../shared/widgets/historial_agrupado.dart';
import '../core/utils/fecha.dart';

/// Cada fila conserva la cantidad y la fecha del movimiento, nunca el saldo
/// acumulado de la línea. Los ajustes negativos se mantienen para cuadrar el libro.
List<GrupoHistorial> historialRecepcionesDiarias(
  List<Movimiento> movimientos,
  WmsSnapshot snapshot,
) {
  final items = {
    for (final k in snapshot.kardex) k.item.id: k.item,
    for (final l in snapshot.lotes)
      for (final e in l.lineas) e.item.id: e.item,
  };
  final lotes = {for (final l in snapshot.lotes) l.id: l};
  final porLinea = {
    for (final l in snapshot.lotes)
      for (final e in l.lineas) e.id: l,
  };
  final eventos = <String, List<EventoHistorial>>{};
  for (var i = 0; i < movimientos.length; i++) {
    final m = movimientos[i];
    if (m.tipo != TipoMovimiento.recepcion) continue;
    final lote = porLinea[m.loteLineaId] ?? lotes[m.loteId];
    eventos
        .putIfAbsent(m.itemId, () => [])
        .add(
          EventoHistorial(
            id: 'recepcion-$i-${m.itemId}-${m.fecha.toIso8601String()}',
            titulo:
                m.cantidad < 0
                    ? 'Ajuste de recepción · ${m.cantidad} uds'
                    : 'Recepción · ${m.cantidad} uds',
            cantidad: m.cantidad,
            fecha: m.fecha,
            detalle:
                'Producción entregó: ${lote == null ? 'Sin registro vinculado' : formatFechaHora(lote.fechaEnvio.toLocal())}\n'
                'Bodega recibió: ${formatFechaHora(m.fecha.toLocal())}\n'
                'Lote: ${lote?.id ?? m.loteId ?? 'Sin registro'}'
                '${m.ubicacion == null ? '' : '\nEstante del movimiento: ${m.ubicacion}'}'
                '${m.nota.isEmpty ? '' : '\nObservación del movimiento: ${m.nota}'}',
          ),
        );
  }
  return [
    for (final entry in eventos.entries)
      if (items.containsKey(entry.key))
        grupoDeItem(items[entry.key]!, entry.value)
      else
        GrupoHistorial(
          id: entry.key,
          op: '—',
          titulo: 'Referencia no disponible',
          detalle:
              'Identificador: ${entry.key} · Se conserva el movimiento en el total.',
          eventos: entry.value,
        ),
  ];
}
