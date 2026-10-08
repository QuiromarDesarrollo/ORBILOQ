import '../domain/cumplimiento.dart';
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
  ColKardex.oc: (i) => i.item.oc.trim().isEmpty ? 'Sin OC' : i.item.oc.trim(),
  ColKardex.cantidad: (i) => '${i.cantidadPedida}',
  ColKardex.entregado: (i) => '${i.producido}',
  ColKardex.pendiente: (i) => '${i.pendienteProduccion}',
  ColKardex.noConforme: (i) => '${i.pendienteReproceso}',
  ColKardex.estadoProduccion: (i) => i.estadoProduccion.etiqueta,
  ColKardex.fechaEntrega: (i) => _fechaOTexto(i.fechaEntrega),
  ColKardex.fechaEsperada: (i) => _fechaOTexto(i.fechaEsperadaProduccion),
  ColKardex.diasFaltantes: (i) => i.cumplimientoProduccion().detalle,
};

/// Igual, pero para la vista Bodega.
final Map<String, ExtractorColumna> columnasLogistica = {
  ColKardex.op: (i) => i.item.op,
  ColKardex.producto: (i) => i.item.descripcion,
  ColKardex.cliente: (i) => i.item.cliente,
  ColKardex.oc: (i) => i.item.oc.trim().isEmpty ? 'Sin OC' : i.item.oc.trim(),
  ColKardex.pedidas: (i) => '${i.cantidadPedida}',
  ColKardex.produccion: (i) => '${i.producido}',
  ColKardex.pendienteProduccionBodega: (i) => '${i.pendienteProduccion}',
  ColKardex.bodega: (i) => '${i.stockDisponible}',
  ColKardex.despachadas: (i) => '${i.despachado}',
  ColKardex.noConformeBodega: (i) => '${i.pendienteReproceso}',
  ColKardex.estadoBodega: (i) => i.estadoLogistica.etiqueta,
  ColKardex.fechaEntregaBodega: (i) => _fechaOTexto(i.fechaDespacho),
  ColKardex.fechaEsperadaBodega: (i) => _fechaOTexto(i.fechaEsperadaLogistica),
  ColKardex.diasFaltantesBodega: (i) => i.cumplimientoLogistica().detalle,
};

final Map<String, ExtractorColumna> columnasBodega = {
  for (final e in columnasLogistica.entries)
    if (![
      ColKardex.despachadas,
      ColKardex.fechaEntregaBodega,
      ColKardex.fechaEsperadaBodega,
      ColKardex.diasFaltantesBodega,
    ].contains(e.key))
      e.key: e.value,
  ColKardex.fechaRecibido: (i) => _fechaOTexto(i.fechaRecepcion),
};

final Map<String, ExtractorColumna> columnasDespacho = {
  for (final e in columnasLogistica.entries)
    if (![
      ColKardex.produccion,
      ColKardex.pendienteProduccionBodega,
      ColKardex.noConformeBodega,
    ].contains(e.key))
      e.key: e.value,
};
