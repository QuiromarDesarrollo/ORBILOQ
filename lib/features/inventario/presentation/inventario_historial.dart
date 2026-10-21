import '../../../shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import '../../../data/inventario_repository.dart';
import '../../../shared/widgets/historial_agrupado.dart';

/// Misma búsqueda, fechas y tarjetas desplegables que los demás historiales.
class InventarioHistorial extends StatefulWidget {
  const InventarioHistorial({super.key, required this.repo});
  final InventarioRepository repo;
  @override
  State<InventarioHistorial> createState() => _InventarioHistorialState();
}

class _InventarioHistorialState extends State<InventarioHistorial> {
  late Future<List<InventarioFila>> _datos;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _datos = widget.repo.filas('inventario_historial_transferencias', {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<InventarioFila>>(
    future: _datos,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const WmsLoadingPanel();
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar el historial de inventario.'),
              TextButton(
                onPressed: () => setState(_cargar),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      final agrupados = <String, List<InventarioFila>>{};
      for (final fila in snapshot.data ?? <InventarioFila>[]) {
        agrupados.putIfAbsent('${fila['item_id']}', () => []).add(fila);
      }
      return HistorialAgrupado(
        etiquetaTotal: 'Transferidas',
        grupos: [
          for (final entrada in agrupados.entries)
            GrupoHistorial(
              id: entrada.key,
              op: '${entrada.value.first['numero_op']}',
              titulo:
                  'OP ${entrada.value.first['numero_op']} · ${entrada.value.first['producto']} · Talla ${entrada.value.first['talla']}',
              detalle:
                  '${entrada.value.first['cliente']} · Ficha ${entrada.value.first['ficha']}',
              eventos: [
                for (final e in entrada.value)
                  EventoHistorial(
                    id: '${e['id']}',
                    titulo: '${e['tipo']}',
                    detalle:
                        'Estante: ${e['estante_origen']} → ${e['estante_destino']}\nResponsable: ${e['responsable'] ?? 'Sin registro'}\nMotivo: ${e['motivo']}',
                    fecha: DateTime.tryParse('${e['fecha']}'),
                    cantidad: (e['cantidad'] as num).toInt(),
                    categoriaCantidad:
                        e['reversion'] == true
                            ? 'Devueltas a OP'
                            : 'Transferidas',
                    color: e['reversion'] == true ? Colors.orange : Colors.teal,
                  ),
              ],
            ),
        ],
      );
    },
  );
}
