import '../domain/models.dart';

String porcentajeFlujo(int cantidad, int base) {
  if (base <= 0) return '—';
  final valor = (cantidad * 100 / base)
      .toStringAsFixed(1)
      .replaceFirst(RegExp(r'\.0$'), '')
      .replaceAll('.', ',');
  return '$valor %';
}

/// Saldos actuales de las mismas líneas vigentes, ya filtradas por cliente.
/// No recorta movimientos por fecha: el Kardex incluye ajustes y devoluciones.
class FlujoAcumulado {
  FlujoAcumulado(Iterable<ItemKardex> lineas) {
    for (final k in lineas.where((k) => !k.eliminada)) {
      ordenes.add(k.item.op);
      pedidas += k.cantidadPedida;
      pendienteEntrega += k.pendienteProduccion;
      entregado += k.producido;
      recibido += k.recibido;
      despachado += k.despachado;
      // Revisar por línea evita que el stock de otra talla o OP oculte el déficit.
      if (k.despachado > k.recibido) {
        inconsistencias.add(k);
      }
    }
  }

  int entregado = 0;
  int pedidas = 0;
  int pendienteEntrega = 0;
  int recibido = 0;
  int despachado = 0;
  final ordenes = <String>{};
  final inconsistencias = <ItemKardex>[];
}
