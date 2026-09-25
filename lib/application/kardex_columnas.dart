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
  ColKardex.fechaEsperada: (i) => _fechaOTexto(i.fechaEsperadaProduccion),
  ColKardex.diasFaltantes: (i) => _diasFaltantesTexto(i.fechaEsperadaProduccion),
};

/// Igual, pero para la vista Bodega.
final Map<String, ExtractorColumna> columnasBodega = {
  ColKardex.op: (i) => i.item.op,
  ColKardex.producto: (i) => i.item.descripcion,
  ColKardex.cliente: (i) => i.item.cliente,
  ColKardex.pedidas: (i) => '${i.cantidadPedida}',
  ColKardex.produccion: (i) => '${i.producido}',
  ColKardex.pendienteProduccionBodega: (i) => '${i.pendienteProduccion}',
  ColKardex.bodega: (i) => '${i.recibido}',
  ColKardex.despachadas: (i) => '${i.despachado}',
  ColKardex.noConformeBodega: (i) => '${i.pendienteReproceso}',
  ColKardex.estadoBodega: (i) => i.estadoLogistica.etiqueta,
  ColKardex.fechaEntregaBodega: (i) => _fechaOTexto(i.fechaEntrega),
  ColKardex.fechaEsperadaBodega: (i) => _fechaOTexto(i.fechaEsperadaLogistica),
  ColKardex.diasFaltantesBodega: (i) => _diasFaltantesTexto(i.fechaEsperadaLogistica),
};

String _diasFaltantesTexto(DateTime? esperada) {
  if (esperada == null) return 'Sin fecha';
  final hoy = DateTime.now();
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final soloEsperada = DateTime(esperada.year, esperada.month, esperada.day);
  final dias = soloEsperada.difference(soloHoy).inDays;
  if (dias < 0) return 'Vencido ${-dias}d';
  if (dias == 0) return 'HOY';
  return 'Faltan ${dias}d';
}
