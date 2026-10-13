import 'reportes_admin_repository.dart';
import '../core/utils/fecha.dart';

Map<String, List<List<Object?>>> hojasTrazabilidadOp(List<FilaReporte> filas) {
  String fecha(dynamic v) =>
      v == null ? 'Sin registro' : formatFechaHora(fechaReporte(v));
  String completa(FilaReporte f, String clave, String campo) =>
      f[clave] == true ? fecha(f[campo]) : 'Parcial';
  final resumen = <String, FilaReporte>{};
  for (final f in filas) {
    resumen['${f['item_id']}'] = f;
  }
  return {
    'Trazabilidad OP': [
      [
        'OP',
        'Prenda',
        'Código',
        'Talla',
        'Cliente',
        'OC',
        'Cantidad OP por talla',
        'Entregado producción',
        'Recibido en bodega',
        'Empacado (reserva)',
        'Despachado / liberado (salida física)',
        'LE',
        'N° GUÍA',
        'PLACA',
        'Cantidad de piezas',
        'Prendas en esta LE',
        'Transportadora',
        'Recibido por cliente',
        'Placa o guía histórica',
        'Estado',
        'OC del despacho',
      ],
      for (final f in filas)
        [
          f['op'],
          f['prenda'],
          f['codigo'],
          f['talla'],
          f['cliente'],
          f['oc'],
          f['cantidad'],
          completa(f, 'produccion_completa', 'fecha_produccion'),
          completa(f, 'recepcion_completa', 'fecha_recibido'),
          f['despacho_id'] == null ? 'Pendiente' : fecha(f['fecha_despachado']),
          f['despacho_id'] == null || f['fase'] == 'empacado'
              ? 'Pendiente'
              : fecha(f['fecha_liberado']),
          f['le'],
          f['numero_guia'],
          f['placa'],
          f['piezas'],
          f['cantidad_le'],
          f['transportadora'],
          f['recibido_cliente'],
          f['placa_guia_historica'],
          f['fase'] == null
              ? 'Sin empaque'
              : f['fase'] == 'empacado'
              ? 'Reservado'
              : 'Liberado',
          f['oc_documento'] ?? (f['despacho_id'] == null ? null : f['oc']),
        ],
    ],
    'Resumen sin duplicados': [
      [
        'OP',
        'Prenda',
        'Código',
        'Talla',
        'Cliente',
        'OC',
        'Cantidad pedida',
        'Entregado producción (unidades)',
        'Recibido bodega (unidades)',
      ],
      for (final f in resumen.values)
        [
          f['op'],
          f['prenda'],
          f['codigo'],
          f['talla'],
          f['cliente'],
          f['oc'],
          f['cantidad'],
          f['entregado_produccion'],
          f['recibido_cantidad'],
        ],
    ],
    'Criterios': [
      ['Concepto', 'Definición'],
      [
        'Alcance',
        'Todas las OP activas o completadas no ocultas. Incluye prendas sin empaque. No aplica los filtros de las otras pestañas.',
      ],
      [
        'Fechas',
        'Zona America/Bogota (UTC-5). Empacado = reserva de las prendas. Despachado / liberado = confirmación de la salida física en Seguimiento; antes de liberar permanece Pendiente.',
      ],
      [
        'Entrega y recepción',
        'Fecha en que todas las tallas de la OP alcanzaron la cantidad pedida, según movimientos netos. Si vuelve a quedar incompleta, muestra Parcial.',
      ],
      [
        'Cantidades',
        'Una fila por prenda/talla/LE. Cantidad OP por talla se repite cuando hay varias LE; sumar únicamente en Resumen sin duplicados.',
      ],
      [
        'Piezas',
        'Empaques físicos distintos que contienen esa prenda/talla. Un empaque compartido aparece en varias filas: no sumar como total de piezas de la LE.',
      ],
      [
        'Históricos',
        'Sin registro indica que no existe una fecha recuperable. La placa o guía histórica se conserva sin asumir qué dato representa.',
      ],
    ],
  };
}
