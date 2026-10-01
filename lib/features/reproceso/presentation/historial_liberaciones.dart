import 'package:flutter/material.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/historial_agrupado.dart';

class HistorialLiberaciones extends StatelessWidget {
  const HistorialLiberaciones({super.key, required this.liberaciones});
  final List<Liberacion> liberaciones;
  @override
  Widget build(BuildContext context) => HistorialAgrupado(
      grupos: agruparHistorial(
          liberaciones,
          (l) => l.item,
          (l) => EventoHistorial(
              id: l.id,
              fecha: l.fecha,
              cantidad: l.cantidad,
              titulo: 'Liberación · ${l.cantidad} Uds',
              detalle:
                  'Liberado por: ${l.operario}\nRecibido por Logística: ${l.recibidoPorLogistica.isEmpty ? 'Sin registrar' : l.recibidoPorLogistica}'
                  '${l.nota.isEmpty ? '' : '\nNota: ${l.nota}'}')));
}
