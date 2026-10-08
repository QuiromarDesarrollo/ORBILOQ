import 'models.dart';

class LineaRecepcionPendiente {
  const LineaRecepcionPendiente(this.lote, this.linea);
  final Lote lote;
  final LoteLinea linea;
}

class GrupoRecepcionPendiente {
  GrupoRecepcionPendiente(this.lineas);
  final List<LineaRecepcionPendiente> lineas;
  List<({String lineaId, int cantidad})> distribuir(int cantidad) {
    if (cantidad <= 0 || cantidad > cantidadPendiente) {
      throw const FormatException(
        'La cantidad supera el pendiente por recibir.',
      );
    }
    final ordenadas = [...lineas]..sort((a, b) {
      final c = a.lote.fechaEnvio.compareTo(b.lote.fechaEnvio);
      return c != 0 ? c : a.linea.id.compareTo(b.linea.id);
    });
    var restante = cantidad;
    final resultado = <({String lineaId, int cantidad})>[];
    for (final e in ordenadas) {
      if (restante == 0) break;
      final n =
          restante < e.linea.cantidadPendiente
              ? restante
              : e.linea.cantidadPendiente;
      resultado.add((lineaId: e.linea.id, cantidad: n));
      restante -= n;
    }
    return resultado;
  }

  int get cantidadPendiente =>
      lineas.fold(0, (s, e) => s + e.linea.cantidadPendiente);
  int get cantidadRecibida =>
      lineas.fold(0, (s, e) => s + (e.linea.cantidadRecibida ?? 0));
}

/// Agrupa la presentación, sin fusionar las entregas ni sus identificadores.
/// OC, cliente y reproceso se mantienen separados para evitar mezclar destinos.
List<GrupoRecepcionPendiente> agruparRecepcionPendiente(
  Iterable<LineaRecepcionPendiente> lineas,
) {
  final grupos =
      <
        (String, String, String, String, String, bool),
        List<LineaRecepcionPendiente>
      >{};
  for (final e in lineas) {
    if (!e.linea.enTransito || e.linea.cantidadPendiente <= 0) continue;
    final i = e.linea.item;
    final clave = (
      i.cliente,
      i.oc,
      i.op,
      i.codigo,
      i.talla,
      e.linea.esReproceso,
    );
    grupos.putIfAbsent(clave, () => []).add(e);
  }
  return grupos.values.map(GrupoRecepcionPendiente.new).toList();
}
