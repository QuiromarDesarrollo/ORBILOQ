import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';
import 'excel_kardex.dart';

class SupabaseImportadorKardex {
  SupabaseImportadorKardex(this.client);
  final SupabaseClient client;
  Future<ArchivoKardex> exportar(Rol vista) async {
    final data = Map<String, dynamic>.from(
        await client.rpc('admin_exportar_kardex') as Map);
    final filas = (data['filas'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    for (final f in filas) {
      final item = ItemKardex(
          item: ItemOrden(
              id: f['item_orden_id'],
              op: f['numero_op'],
              codigo: f['codigo'],
              descripcion: f['descripcion'],
              talla: f['talla'],
              cliente: f['cliente'],
              oc: f['oc'],
              cantidadPedida: (f['cantidad_pedida'] as num).toInt()),
          producido: (f['producido'] as num).toInt(),
          recibido: (f['recibido'] as num).toInt(),
          despachado: (f['despachado'] as num).toInt(),
          ubicaciones: const {},
          pendienteReproceso: (f['pendiente_reproceso'] as num).toInt(),
          pendienteAliados: (f['pendiente_aliados'] as num).toInt(),
          fechaEsperadaProduccion:
              DateTime.tryParse(f['fecha_esperada_produccion'] ?? ''),
          fechaEsperadaLogistica:
              DateTime.tryParse(f['fecha_esperada_logistica'] ?? ''));
      f['pendiente'] = item.pendienteProduccion;
      f['estado'] = vista == Rol.produccion
          ? item.estadoProduccion.etiqueta
          : item.estadoLogistica.etiqueta;
      final fecha = vista == Rol.produccion
          ? item.fechaEsperadaProduccion
          : item.fechaEsperadaLogistica;
      final ahora = DateTime.now();
      f['dias'] = fecha
          ?.difference(DateTime(ahora.year, ahora.month, ahora.day))
          .inDays;
    }
    return ArchivoKardex(vista, data['version'] as String, filas);
  }

  Future<Map<String, dynamic>> importar(ArchivoKardex archivo, String motivo,
          {required bool confirmar}) async =>
      Map<String, dynamic>.from(
          await client.rpc('admin_importar_kardex', params: {
        'p_vista': archivo.vista.name,
        'p_version': archivo.version,
        'p_filas': archivo.filas,
        'p_motivo': motivo,
        'p_confirmar': confirmar,
      }) as Map);
}
