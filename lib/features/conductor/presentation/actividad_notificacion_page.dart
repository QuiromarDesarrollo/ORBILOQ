import '../../../shared/widgets/wms_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/wms_loader.dart';
import '../conductor_repository.dart';
import '../conductor_model.dart';
import '../kit_semanal.dart';
import 'actividad_conductor_form.dart';
import 'conductor_design.dart';
import 'transporte_scaffold.dart';

String plazoActividad(Map tarea, DateTime hoy) {
  if (tarea['estado'] != 'Pendiente') {
    return tarea['estado']?.toString() ?? 'Sin estado';
  }
  final fecha = DateTime.tryParse(tarea['fecha_limite']?.toString() ?? '');
  if (fecha == null) return 'Pendiente · Sin fecha límite';
  final dias = diasRestantes(fecha, hoy);
  if (dias == 1) return 'Pendiente · Vence mañana';
  if (dias == 0) return 'Pendiente · Vence hoy';
  if (dias < 0) {
    return 'Pendiente · Vencida hace ${-dias} ${dias == -1 ? 'día' : 'días'}';
  }
  return 'Pendiente · Vence en $dias días';
}

/// Resuelve la actividad por ID al abrir una alerta, evitando usar su estado antiguo.
class ActividadNotificacionPage extends ConsumerStatefulWidget {
  const ActividadNotificacionPage({
    super.key,
    required this.vehiculo,
    required this.actividad,
  });
  final String vehiculo, actividad;
  @override
  ConsumerState<ActividadNotificacionPage> createState() =>
      _ActividadNotificacionPageState();
}

class _ActividadNotificacionPageState
    extends ConsumerState<ActividadNotificacionPage> {
  bool cargando = true;
  String? error;
  Map<String, dynamic>? tarea;
  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final datos = await ref
          .read(conductorRepositoryProvider)
          .revisionSalida(widget.vehiculo);
      final encontrada =
          (datos['tareas'] as List? ?? [])
              .where((t) => t['id'].toString() == widget.actividad)
              .firstOrNull;
      if (mounted) {
        setState(
          () =>
              tarea =
                  encontrada == null
                      ? null
                      : Map<String, dynamic>.from(encontrada),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'No se pudo consultar la actividad. Reintenta la carga.',
        );
      }
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!cargando && error == null && tarea?['estado'] == 'Pendiente') {
      return ActividadConductorForm(vehiculo: widget.vehiculo, tarea: tarea);
    }
    return Theme(
      data: ConductorDesign.theme(),
      child: TransporteScaffold(
        appBar: AppBar(title: const Text('Actividad')),
        body:
            cargando
                ? const WmsLoadingPanel(label: 'Abriendo actividad…')
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: ConductorPanel(
                        title:
                            tarea?['descripcion']?.toString() ??
                            'Actividad no disponible',
                        children: [
                          if (error != null) ...[
                            AvisoFormulario(error!),
                            TextButton(
                              onPressed: cargar,
                              child: const Text('Reintentar'),
                            ),
                          ] else if (tarea == null)
                            const Text(
                              'Esta actividad ya no aparece entre tus pendientes. Puede haber sido cerrada o haber cambiado la asignación del vehículo. Vuelve para actualizar las alertas.',
                            )
                          else ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConductorBadge(
                                plazoActividad(tarea!, hoyColombia()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Motivos: ${(tarea!['motivos'] as List? ?? [tarea!['punto']]).where((m) => m != null).join(', ')}',
                            ),
                            if (tarea!['solucion'] != null)
                              Text(
                                'Solución registrada: ${tarea!['solucion']}',
                              ),
                            if (tarea!['estado'] == 'Por verificar')
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'Ya enviaste esta actividad. Está pendiente de verificación por el administrador.',
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
