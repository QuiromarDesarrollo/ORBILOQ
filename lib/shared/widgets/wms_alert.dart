import 'package:flutter/material.dart';

enum TipoAviso { informacion, exito, advertencia, error }

/// Mensajes centrados con cierre explícito, incluso sobre otro formulario.
Future<void> mostrarAviso(
  BuildContext context,
  String mensaje, {
  bool error = false,
  TipoAviso tipo = TipoAviso.informacion,
}) => mostrarAvisoContenido(context, Text(mensaje), error: error, tipo: tipo);

Future<void> mostrarAvisoContenido(
  BuildContext context,
  Widget contenido, {
  bool error = false,
  TipoAviso tipo = TipoAviso.informacion,
  SnackBarAction? accion,
}) async {
  if (!context.mounted) return;
  final efectivo = error ? TipoAviso.error : tipo;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final dark = theme.brightness == Brightness.dark;
      final (titulo, icono, tono) = switch (efectivo) {
        TipoAviso.exito => (
          'Operación completada',
          Icons.check_rounded,
          const Color(0xFF16804A),
        ),
        TipoAviso.advertencia => (
          'Revisa antes de continuar',
          Icons.priority_high_rounded,
          const Color(0xFFAD6600),
        ),
        TipoAviso.error => (
          'No se pudo completar',
          Icons.close_rounded,
          const Color(0xFFC33442),
        ),
        TipoAviso.informacion => (
          'Aviso',
          Icons.info_outline_rounded,
          const Color(0xFF176888),
        ),
      };
      return Dialog(
        key: const ValueKey('aviso-global'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 78, 24, 24),
                    decoration: BoxDecoration(
                      color: dark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .15),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DefaultTextStyle.merge(
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          child: contenido,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (accion != null)
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  accion.onPressed();
                                },
                                child: Text(accion.label),
                              ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: tono,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar aviso'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.alphaBlend(
                        tono.withValues(alpha: .12),
                        dark ? theme.colorScheme.surface : Colors.white,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tono,
                        boxShadow: [
                          BoxShadow(
                            color: tono.withValues(alpha: .25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(icono, size: 52, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 56,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Cerrar aviso',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> mostrarAvisoSnack(
  BuildContext context,
  SnackBar aviso, {
  TipoAviso tipo = TipoAviso.informacion,
}) => mostrarAvisoContenido(
  context,
  aviso.content,
  accion: aviso.action,
  tipo: tipo,
);

/// Adaptador de los resultados de formularios que almacenan su aviso en estado.
class AvisoFormulario extends StatefulWidget {
  const AvisoFormulario(this.mensaje, {super.key, this.error = true});
  final String mensaje;
  final bool error;
  @override
  State<AvisoFormulario> createState() => _AvisoFormularioState();
}

class _AvisoFormularioState extends State<AvisoFormulario> {
  @override
  void initState() {
    super.initState();
    _mostrar();
  }

  @override
  void didUpdateWidget(AvisoFormulario oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mensaje != widget.mensaje || oldWidget.error != widget.error) {
      _mostrar();
    }
  }

  void _mostrar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        mostrarAviso(
          context,
          widget.mensaje,
          tipo: widget.error ? TipoAviso.error : TipoAviso.exito,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
