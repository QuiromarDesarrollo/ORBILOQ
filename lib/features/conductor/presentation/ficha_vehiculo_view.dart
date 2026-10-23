import 'vista_evidencia_drive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../conductor_model.dart';
import '../ficha_vehiculo.dart';
import 'conductor_design.dart';

class FichaVehiculoView extends StatefulWidget {
  const FichaVehiculoView({
    super.key,
    required this.vehiculo,
    required this.conductor,
    required this.onEditar,
    required this.onHistorial,
  });
  final VehiculoConductor vehiculo;
  final String conductor;
  final VoidCallback onEditar, onHistorial;
  @override
  State<FichaVehiculoView> createState() => _FichaVehiculoViewState();
}

class _FichaVehiculoViewState extends State<FichaVehiculoView> {
  int tab = 0;
  String valor(CampoFichaVehiculo campo) {
    final raw = widget.vehiculo.datos[campo.key]?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Sin registrar';
    if (campo.fecha) {
      final d = DateTime.tryParse(raw);
      if (d != null) return DateFormat('dd/MM/yyyy').format(d);
    }
    return raw;
  }

  Widget campos(List<Widget> children, {int maxColumnas = 4}) => LayoutBuilder(
    builder: (context, c) {
      final grande = MediaQuery.textScalerOf(context).scale(14) >= 21;
      final columnas =
          grande
              ? 1
              : (c.maxWidth >= 1050
                      ? 4
                      : c.maxWidth >= 760
                      ? 3
                      : c.maxWidth >= 440
                      ? 2
                      : 1)
                  .clamp(1, maxColumnas);
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final child in children)
            SizedBox(
              width: (c.maxWidth - (columnas - 1) * 10) / columnas,
              child: child,
            ),
        ],
      );
    },
  );

  Widget conFoto(Widget foto, Widget contenido) => LayoutBuilder(
    builder:
        (context, c) =>
            c.maxWidth >= 680 && MediaQuery.textScalerOf(context).scale(14) < 21
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 250, child: foto),
                    const SizedBox(width: 18),
                    Expanded(child: contenido),
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [foto, const SizedBox(height: 12), contenido],
                ),
  );

  Widget dato(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: ConductorDesign.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: ConductorDesign.muted, fontSize: 12),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  Widget documento(String id, String nombre) {
    final datos = widget.vehiculo.datos;
    final hasta = DateTime.tryParse(datos[nombre]?.toString() ?? '');
    final desde = DateTime.tryParse(datos['${id}_desde']?.toString() ?? '');
    final hoy = DateTime.now();
    final dias = hasta == null ? null : diasRestantes(hasta, hoy);
    final futuro = desde != null && diasRestantes(desde, hoy) > 0;
    final estado =
        dias == null
            ? 'Sin registrar'
            : dias < 0
            ? 'Vencido'
            : futuro
            ? 'Vigencia futura'
            : dias == 0
            ? 'Vence hoy'
            : dias <= 30
            ? 'Vence en $dias días'
            : 'Vigente';
    return ConductorPanel(
      title: nombre,
      icon: Icons.description_outlined,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConductorBadge(
            estado,
            warning: dias == null || dias <= 30 || futuro,
            error: dias != null && dias < 0,
          ),
        ),
        const SizedBox(height: 12),
        conFoto(
          VistaEvidenciaDrive(
            vehiculo: widget.vehiculo.id,
            enlace: datos['doc_$id']?.toString() ?? '',
            titulo: 'Vista previa · $nombre',
            height: 130,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              campos([
                dato(
                  'Vigencia desde',
                  valor(CampoFichaVehiculo('${id}_desde', '', fecha: true)),
                ),
                dato(
                  'Vigencia hasta',
                  valor(CampoFichaVehiculo(nombre, '', fecha: true)),
                ),
                dato(
                  'Expedido',
                  valor(CampoFichaVehiculo('${id}_expedido', '', fecha: true)),
                ),
                dato(
                  'Valor · COP',
                  valor(CampoFichaVehiculo('${id}_valor', '')),
                ),
              ], maxColumnas: 2),
              const SizedBox(height: 12),
              dato(
                'Observaciones',
                valor(CampoFichaVehiculo('${id}_observaciones', '')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehiculo;
    final foto = v.datos['foto_frontal']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConductorPanel(
          title: v.placa,
          icon: Icons.local_shipping_outlined,
          children: [
            conFoto(
              VistaEvidenciaDrive(
                vehiculo: v.id,
                enlace: foto,
                titulo: 'Foto del vehículo',
                height: 140,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    v.descripcion,
                    style: const TextStyle(color: ConductorDesign.muted),
                  ),
                  const SizedBox(height: 12),
                  campos([
                    dato(
                      'Odómetro actual',
                      '${NumberFormat.decimalPattern('es_CO').format(v.km)} km',
                    ),
                    dato('Conductor asignado', widget.conductor),
                  ], maxColumnas: 2),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onEditar,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar ficha y documentos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onHistorial,
                        icon: const Icon(Icons.history),
                        label: const Text('Ver historial'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(const ['Datos', 'Conductor', 'Documentos'][i]),
                  selected: tab == i,
                  onSelected: (_) => setState(() => tab = i),
                ),
            ],
          ),
        ),
        if (tab == 0)
          for (final grupo in fichaVehiculoCampos.entries)
            ConductorPanel(
              title: grupo.key,
              children: [
                campos([
                  for (final campo in grupo.value)
                    dato(campo.label, valor(campo)),
                ]),
              ],
            ),
        if (tab == 1)
          ConductorPanel(
            title: 'Conductor actual',
            icon: Icons.person_outline,
            children: [
              conFoto(
                VistaEvidenciaDrive(
                  vehiculo: v.id,
                  enlace: v.datos['foto_conductor']?.toString() ?? '',
                  titulo: 'Foto del conductor',
                  height: 130,
                ),
                campos([
                  dato('Nombre', widget.conductor),
                  dato(
                    'Número de documento',
                    valor(const CampoFichaVehiculo('conductor_documento', '')),
                  ),
                ], maxColumnas: 2),
              ),
              const SizedBox(height: 12),
              documento('licencia', 'Licencia de conducción'),
              const SizedBox(height: 12),
              const Text(
                'La asignación la gestiona el administrador entre jornadas. Los registros anteriores conservan la persona que los realizó.',
                style: TextStyle(color: ConductorDesign.muted),
              ),
            ],
          ),
        if (tab == 2) ...[
          for (final d in documentosFicha.entries) documento(d.key, d.value),
        ],
      ],
    );
  }
}
