import 'package:flutter/material.dart';
import '../evidencia_conductor.dart';
import 'conductor_design.dart';

const fotosVehiculoConductor = {
  'frontal': ('Frontal', 'Frente completo y placa'),
  'lateral_derecho': ('Lateral derecho', 'Costado derecho completo'),
  'lateral_izquierdo': ('Lateral izquierdo', 'Costado izquierdo completo'),
  'trasera': ('Trasera', 'Parte trasera y placa'),
  'tablero': ('Tablero', 'Kilometraje visible'),
};

/// Presentación de evidencias; los archivos y el guardado pertenecen al formulario.
class ObservacionesEvidenciaConductor extends StatelessWidget {
  const ObservacionesEvidenciaConductor({
    super.key,
    required this.fotos,
    required this.fotoBuilder,
    required this.observaciones,
    required this.adicional,
    this.tituloAdicional = 'Evidencia adicional',
    this.adicionalObligatorio = false,
  });
  final List<EvidenciaSeleccionada> fotos;
  final Widget Function(String lado, String titulo, String ayuda) fotoBuilder;
  final Widget observaciones, adicional;
  final String tituloAdicional;
  final bool adicionalObligatorio;

  @override
  Widget build(BuildContext context) => Card(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final amplio = constraints.maxWidth >= 760;
        return Padding(
          padding: EdgeInsets.all(amplio ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge(fotos),
                builder: (context, _) {
                  final listas = fotos.where((f) => f.archivo != null).length;
                  final contador = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5CF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '$listas de ${fotos.length} fotos',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ConductorDesign.navy,
                      ),
                    ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F4FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: ConductorDesign.cyan,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Observaciones y evidencia',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ConductorDesign.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  fotos.isEmpty
                                      ? 'Notas y archivos del registro'
                                      : 'Fotos del vehículo y notas del recorrido',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: ConductorDesign.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (fotos.isNotEmpty &&
                              constraints.maxWidth >= 520) ...[
                            const SizedBox(width: 12),
                            contador,
                          ],
                        ],
                      ),
                      if (fotos.isNotEmpty) ...[
                        if (constraints.maxWidth < 520) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: contador,
                          ),
                        ],
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: listas / fotos.length,
                            color: ConductorDesign.lime,
                            backgroundColor: ConductorDesign.line,
                            semanticsLabel:
                                'Fotos seleccionadas: $listas de ${fotos.length}',
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 24),
                _label('Fotos del vehículo'),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, grid) {
                    // Mantiene objetivos táctiles de 44 px, incluso con texto ampliado.
                    final escala =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final columnas =
                        grid.maxWidth >= 960 * escala
                            ? 5
                            : grid.maxWidth >= 320 * escala
                            ? 2
                            : 1;
                    final ancho =
                        (grid.maxWidth - 12 * (columnas - 1)) / columnas;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final e in fotosVehiculoConductor.entries)
                          SizedBox(
                            width: ancho,
                            child: fotoBuilder(e.key, e.value.$1, e.value.$2),
                          ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, body) {
                  final evidencia = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(
                        '$tituloAdicional (${adicionalObligatorio ? 'obligatoria' : 'opcional'})',
                      ),
                      const SizedBox(height: 10),
                      adicional,
                    ],
                  );
                  if (body.maxWidth >= 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: observaciones),
                        const SizedBox(width: 24),
                        Expanded(child: evidencia),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      observaciones,
                      const SizedBox(height: 8),
                      evidencia,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _label(String texto) => Text(
    texto.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: ConductorDesign.muted,
    ),
  );
}
