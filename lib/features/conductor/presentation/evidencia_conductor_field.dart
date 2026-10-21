import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../evidencia_conductor.dart';
import 'camara_conductor.dart';
import 'conductor_design.dart';

enum EstiloEvidencia { normal, foto, adicional }

class EvidenciaConductorField extends StatefulWidget {
  const EvidenciaConductorField({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.onBusy,
    this.enabled = true,
    this.obligatorio = false,
    this.soloFoto = false,
    this.estilo = EstiloEvidencia.normal,
    this.ayuda,
  });
  final EvidenciaSeleccionada controller;
  final String etiqueta;
  final ValueChanged<bool> onBusy;
  final bool enabled, obligatorio, soloFoto;
  final EstiloEvidencia estilo;
  final String? ayuda;
  @override
  State<EvidenciaConductorField> createState() =>
      _EvidenciaConductorFieldState();
}

class _EvidenciaConductorFieldState extends State<EvidenciaConductorField>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _ocupado = false;
  String? _error;

  void _busy(bool value) {
    if (!mounted) return;
    setState(() => _ocupado = value);
    widget.onBusy(value);
  }

  Future<void> _elegir(bool camara) async {
    _busy(true);
    setState(() => _error = null);
    try {
      ArchivoEvidencia? archivo;
      if (camara) {
        final bytes = await tomarFotoConductor(context);
        if (bytes != null) archivo = await prepararEvidencia('foto.jpg', bytes);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions:
              widget.soloFoto
                  ? ['jpg', 'jpeg', 'png', 'webp']
                  : ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'docx', 'xlsx'],
          withData: true,
        );
        if (result != null) {
          final f = result.files.single;
          if (f.size > maxEvidenciaBytes || f.bytes == null) {
            throw const FormatException(
              'No se pudo leer el archivo o supera los 10 MB.',
            );
          }
          archivo = await prepararEvidencia(f.name, f.bytes!);
        }
      }
      if (archivo != null && mounted) {
        widget.controller.seleccionar(archivo);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is FormatException
                      ? e.message
                      : 'No se pudo preparar la foto o el archivo. Inténtalo de nuevo.',
        );
      }
    } finally {
      _busy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _contenido(),
    );
  }

  Widget _contenido() {
    if (widget.estilo != EstiloEvidencia.normal) return _tarjeta();
    final enabled = widget.enabled && !_ocupado;
    final archivo = widget.controller.archivo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.etiqueta}${widget.obligatorio ? ' *' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? () => _elegir(true) : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Tomar foto'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? () => _elegir(false) : null,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  widget.soloFoto ? 'Elegir foto' : 'Seleccionar archivo',
                ),
              ),
            ],
          ),
          if (archivo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ConductorDesign.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (archivo.esFoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        archivo.bytes,
                        height: 170,
                        fit: BoxFit.contain,
                        semanticLabel: 'Vista previa de ${widget.etiqueta}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${archivo.nombre} · ${(archivo.bytes.length / 1024).ceil()} KB',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.controller.enlace == null
                        ? 'Lista para subir al guardar el registro.'
                        : 'Archivo subido. Se asociará al guardar el registro.',
                    style: const TextStyle(color: Color(0xFF177548)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: enabled ? widget.controller.descartar : null,
                      child: const Text('Quitar archivo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Preparando evidencia',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 10),
          FormField<bool>(
            validator:
                (_) =>
                    widget.obligatorio && widget.controller.archivo == null
                        ? 'Agrega la evidencia.'
                        : null,
            builder:
                (field) =>
                    field.hasError
                        ? Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                        : const SizedBox.shrink(),
          ),
          if (widget.controller.enlace != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    enabled
                        ? () => launchUrl(
                          Uri.parse(widget.controller.enlace!),
                          mode: LaunchMode.externalApplication,
                        )
                        : null,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver archivo en Drive'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta() {
    final foto = widget.estilo == EstiloEvidencia.foto;
    final archivo = widget.controller.archivo;
    final enabled = widget.enabled && !_ocupado;
    final estado = archivo == null ? 'Pendiente' : 'Lista';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: foto ? Colors.white : ConductorDesign.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: archivo == null ? ConductorDesign.line : ConductorDesign.cyan,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (foto) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.etiqueta,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estado,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          archivo == null
                              ? ConductorDesign.muted
                              : ConductorDesign.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 120,
                color: ConductorDesign.background,
                child:
                    archivo == null
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 28,
                              color: ConductorDesign.muted,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                widget.ayuda ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ConductorDesign.muted,
                                ),
                              ),
                            ),
                          ],
                        )
                        : Image.memory(
                          archivo.bytes,
                          fit: BoxFit.contain,
                          semanticLabel: 'Vista previa de ${widget.etiqueta}',
                        ),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: ConductorDesign.cyan,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.ayuda ?? widget.etiqueta,
                    style: const TextStyle(
                      color: ConductorDesign.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (archivo?.esFoto == true) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  archivo!.bytes,
                  height: 120,
                  fit: BoxFit.contain,
                  semanticLabel: 'Vista previa de ${widget.etiqueta}',
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          if (foto)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: enabled ? () => _elegir(true) : null,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Tomar'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Elegir foto ${widget.etiqueta.toLowerCase()}',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: enabled ? () => _elegir(false) : null,
                      child: const Icon(Icons.photo_library_outlined, size: 20),
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled ? () => _elegir(true) : null,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Tomar foto'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? () => _elegir(false) : null,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Adjuntar archivo'),
                ),
              ],
            ),
          if (archivo != null) ...[
            const SizedBox(height: 8),
            Text(
              '${archivo.nombre} · ${(archivo.bytes.length / 1024).ceil()} KB',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: ConductorDesign.muted,
              ),
            ),
            Text(
              widget.controller.enlace == null
                  ? 'Se subirá al guardar.'
                  : 'Subida completada.',
              style: const TextStyle(
                fontSize: 12,
                color: ConductorDesign.muted,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: enabled ? widget.controller.descartar : null,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Quitar'),
              ),
            ),
          ],
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Preparando evidencia',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FormField<bool>(
            validator:
                (_) =>
                    widget.obligatorio && archivo == null
                        ? 'Agrega la evidencia.'
                        : null,
            builder:
                (field) =>
                    field.hasError
                        ? Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
