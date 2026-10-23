import 'package:flutter/material.dart';
import 'conductor_design.dart';

class AvisoTransporte {
  const AvisoTransporte({
    required this.id,
    required this.titulo,
    required this.detalle,
    required this.accion,
    required this.icono,
    required this.abrir,
  });
  final String id, titulo, detalle, accion;
  final IconData icono;
  final VoidCallback abrir;
}

class BandejaNotificaciones extends StatefulWidget {
  const BandejaNotificaciones({
    super.key,
    required this.avisos,
    required this.leidas,
    required this.alLeer,
  });
  final List<AvisoTransporte> avisos;
  final Set<String> leidas;
  final VoidCallback alLeer;
  @override
  State<BandejaNotificaciones> createState() => _BandejaNotificacionesState();
}

class _BandejaNotificacionesState extends State<BandejaNotificaciones> {
  bool soloNuevas = false;
  @override
  Widget build(BuildContext context) {
    final visibles =
        widget.avisos
            .where((a) => !soloNuevas || !widget.leidas.contains(a.id))
            .toList();
    final pendientes =
        widget.avisos.where((a) => !widget.leidas.contains(a.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Notificaciones',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar notificaciones',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$pendientes sin leer',
            style: const TextStyle(color: ConductorDesign.muted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: !soloNuevas,
                onSelected: (_) => setState(() => soloNuevas = false),
              ),
              ChoiceChip(
                label: const Text('Sin leer'),
                selected: soloNuevas,
                onSelected: (_) => setState(() => soloNuevas = true),
              ),
              TextButton(
                onPressed:
                    pendientes == 0
                        ? null
                        : () {
                          setState(
                            () => widget.leidas.addAll(
                              widget.avisos.map((a) => a.id),
                            ),
                          );
                          widget.alLeer();
                        },
                child: const Text('Marcar todas como leídas'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
              visibles.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay notificaciones pendientes',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : ListView.separated(
                    itemCount: visibles.length,
                    separatorBuilder:
                        (_, _) => const Divider(height: 1, indent: 78),
                    itemBuilder: (context, index) {
                      final aviso = visibles[index];
                      final nueva = !widget.leidas.contains(aviso.id);
                      return Material(
                        color: nueva ? const Color(0xFFEDF5FA) : Colors.white,
                        child: InkWell(
                          onTap: () {
                            widget.leidas.add(aviso.id);
                            widget.alLeer();
                            Navigator.pop(context, aviso);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 23,
                                  backgroundColor: const Color(0xFFE5EDB5),
                                  child: Icon(
                                    aviso.icono,
                                    color: ConductorDesign.navy,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        aviso.titulo,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              nueva
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        aviso.detalle,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: ConductorDesign.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        aviso.accion,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ConductorDesign.navy,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (nueva)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8, top: 6),
                                    child: Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: ConductorDesign.cyan,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
