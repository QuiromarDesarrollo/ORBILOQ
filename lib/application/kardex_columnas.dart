import '../domain/models.dart';
import 'kardex_filters.dart';

typedef ExtractorColumna = String Function(ItemKardex);

String _fechaOTexto(DateTime? d) {
  if (d == null) return 'Sin fecha';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Qué valor de texto le corresponde a cada columna de la vista Producción,
/// tanto para filtrar como para listar las opciones disponibles.
final Map<String, ExtractorColumna> columnasProduccion = {
  ColKardex.op: (i) => i.item.op,
  ColKardex.producto: (i) => i.item.descripcion,
  ColKardex.cliente: (i) => i.item.cliente,
  ColKardex.cantidad: (i) => '${i.cantidadPedida}',
  ColKardex.entregado: (i) => '${i.producido}',
  ColKardex.pendiente: (i) => '${i.pendienteProduccion}',
  ColKardex.noConforme: (i) => '${i.pendienteReproceso}',
  ColKardex.estadoProduccion: (i) => i.estadoProduccion.etiqueta,
  ColKardex.fechaEntrega: (i) => _fechaOTexto(i.fechaEntrega),
  // Aún sin fuente de datos real: todas las filas muestran lo mismo hasta
  // que se conecte de dónde sale esta fecha.
  ColKardex.fechaEsperada: (i) => 'Sin fecha',
};

/// Igual, pero para la vista Bodega (columnas que ya existían).
final Map<String, ExtractorColumna> columnasBodega = {
  ColKardex.op: (i) => i.item.op,
  ColKardex.producto: (i) => i.item.descripcion,
  ColKardex.cliente: (i) => i.item.cliente,
  ColKardex.pedidas: (i) => '${i.cantidadPedida}',
  ColKardex.produccion: (i) => '${i.producido}',
  ColKardex.bodega: (i) => '${i.recibido}',
  ColKardex.despachadas: (i) => '${i.despachado}',
  ColKardex.estadoBodega: (i) => i.estadoEtiqueta,
};
