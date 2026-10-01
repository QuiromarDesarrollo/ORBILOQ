import 'models.dart';

enum CampoAdmin {
  numeroOp('numero_op', 'Número de OP', compartido: true),
  observacion('observacion_op', 'Observación'),
  descripcion('descripcion', 'Producto'),
  codigo('codigo', 'Código'),
  talla('talla', 'Talla'),
  cliente('cliente', 'Cliente', compartido: true),
  oc('oc', 'OC'),
  cantidad('cantidad_pedida', 'Cantidad pedida', numero: true),
  producido('producido', 'Entregado por Producción', numero: true),
  recibido('recibido', 'Recibido en Bodega',
      numero: true, lote: true, ubicacion: true),
  despachado('despachado', 'Despachado', numero: true, ubicacion: true),
  noConforme('pendiente_reproceso', 'Producto no conforme',
      numero: true, ubicacion: true),
  fechaEntrega('fecha_ultima_entrega', 'Fecha de entrega', fecha: true),
  fechaProduccion('fecha_esperada_produccion', 'Fecha esperada de Producción',
      fecha: true, compartido: true),
  fechaLogistica('fecha_esperada_logistica', 'Fecha esperada de Logística',
      fecha: true, compartido: true);

  const CampoAdmin(this.id, this.etiqueta,
      {this.numero = false,
      this.fecha = false,
      this.lote = false,
      this.ubicacion = false,
      this.compartido = false});
  final String id;
  final String etiqueta;
  final bool numero, fecha, lote, ubicacion, compartido;
}

Map<String, dynamic> valoresAdmin(ItemKardex k) => {
      'numero_op': k.item.op,
      'observacion_op': k.item.observacionOp,
      'descripcion': k.item.descripcion,
      'codigo': k.item.codigo,
      'talla': k.item.talla,
      'cliente': k.item.cliente,
      'oc': k.item.oc,
      'cantidad_pedida': k.cantidadPedida,
      'producido': k.producido,
      'recibido': k.recibido,
      'despachado': k.despachado,
      'pendiente_reproceso': k.pendienteReproceso,
      'fecha_ultima_entrega': fechaAdmin(k.fechaEntrega),
      'fecha_esperada_produccion': fechaAdmin(k.fechaEsperadaProduccion),
      'fecha_esperada_logistica': fechaAdmin(k.fechaEsperadaLogistica),
    };

String? fechaAdmin(DateTime? fecha) => fecha == null
    ? null
    : '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

/// El servidor entrega la versión y la vuelve a verificar al confirmar.
class ContextoEdicionAdmin {
  ContextoEdicionAdmin.fromJson(Map<String, dynamic> json)
      : version = json['version'] as String,
        valores = Map<String, dynamic>.from(json['valores'] as Map),
        lotes = _lista(json['lotes']),
        ubicaciones = _lista(json['ubicaciones']),
        historial = _lista(json['historial']),
        filasOrden = (json['filas_orden'] as num).toInt();
  final String version;
  final Map<String, dynamic> valores;
  final List<Map<String, dynamic>> lotes, ubicaciones, historial;
  final int filasOrden;
  static List<Map<String, dynamic>> _lista(dynamic v) =>
      [for (final x in (v as List? ?? [])) Map<String, dynamic>.from(x as Map)];
}

class CambioAdmin {
  const CambioAdmin(
      {required this.itemId,
      required this.campo,
      required this.valor,
      required this.motivo,
      required this.version,
      this.loteId,
      this.ubicacionId});
  final String itemId, motivo, version;
  final CampoAdmin campo;
  final Object? valor;
  final String? loteId, ubicacionId;
  Map<String, dynamic> parametros(bool confirmar) => {
        'p_item_id': itemId,
        'p_campo': campo.id,
        'p_valor': valor,
        'p_motivo': motivo,
        'p_version': version,
        'p_lote_item_id': loteId,
        'p_ubicacion_id': ubicacionId,
        'p_confirmar': confirmar,
      };
}
