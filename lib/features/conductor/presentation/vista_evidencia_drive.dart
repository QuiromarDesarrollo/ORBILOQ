import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../conductor_model.dart';
import '../conductor_repository.dart';
import '../../../shared/widgets/wms_loader.dart';
import 'conductor_design.dart';

class VistaEvidenciaDrive extends ConsumerStatefulWidget {
  const VistaEvidenciaDrive({
    super.key,
    required this.vehiculo,
    required this.enlace,
    required this.titulo,
    this.height = 190,
    this.soloImagen = false,
  });
  final String vehiculo, enlace, titulo;
  final double height;
  final bool soloImagen;
  @override
  ConsumerState<VistaEvidenciaDrive> createState() =>
      _VistaEvidenciaDriveState();
}

class _VistaEvidenciaDriveState extends ConsumerState<VistaEvidenciaDrive> {
  late Future<Uint8List?> carga;
  Future<Uint8List?> cargar() async {
    if (!enlaceDriveValido(widget.enlace)) return null;
    final client = ref.read(conductorRepositoryProvider).client;
    if (client == null) return null;
    final r = await client.functions.invoke(
      'conductor-evidencia',
      body: {
        'accion': 'preview',
        'vehiculo': widget.vehiculo,
        'enlace': widget.enlace,
      },
    );
    if (r.status != 200 || r.data is! Map || r.data['base64'] is! String) {
      return null;
    }
    return base64Decode(r.data['base64']);
  }

  @override
  void initState() {
    super.initState();
    carga = cargar();
  }

  @override
  void didUpdateWidget(covariant VistaEvidenciaDrive old) {
    super.didUpdateWidget(old);
    if (old.enlace != widget.enlace || old.vehiculo != widget.vehiculo) {
      carga = cargar();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(widget.soloImagen ? 8 : 12),
    decoration: BoxDecoration(
      color: ConductorDesign.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ConductorDesign.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.soloImagen)
          Text(
            widget.titulo,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        if (!widget.soloImagen) const SizedBox(height: 10),
        SizedBox(
          height:
              widget.soloImagen || enlaceDriveValido(widget.enlace)
                  ? widget.height
                  : null,
          child: FutureBuilder<Uint8List?>(
            future: carga,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const WmsLoadingPanel(
                  maxWidth: 140,
                  label: 'Cargando vista previa…',
                );
              }
              if (s.hasData && s.data!.isNotEmpty) {
                return InkWell(
                  onTap:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (ctx) => Dialog(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                  maxHeight: 700,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        tooltip: 'Cerrar vista previa',
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                    Flexible(
                                      child: InteractiveViewer(
                                        child: Image.memory(
                                          s.data!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                  child: Image.memory(
                    s.data!,
                    fit: BoxFit.contain,
                    semanticLabel: widget.titulo,
                    errorBuilder:
                        (_, _, _) => const Center(
                          child: Text('No se pudo mostrar la imagen'),
                        ),
                  ),
                );
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 32,
                      color: ConductorDesign.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      enlaceDriveValido(widget.enlace)
                          ? 'Vista previa no disponible'
                          : 'Sin archivo registrado',
                      textAlign: TextAlign.center,
                    ),
                    if (enlaceDriveValido(widget.enlace))
                      TextButton(
                        onPressed:
                            () => setState(() {
                              carga = cargar();
                            }),
                        child: const Text('Reintentar vista previa'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (!widget.soloImagen && enlaceDriveValido(widget.enlace))
          TextButton.icon(
            onPressed:
                () => launchUrl(
                  Uri.parse(widget.enlace),
                  mode: LaunchMode.externalApplication,
                ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir original en Drive'),
          ),
      ],
    ),
  );
}
