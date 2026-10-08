import 'package:flutter/material.dart';

/// Aviso centrado sobre cualquier formulario abierto. Se cierra explícitamente
/// para que los errores no desaparezcan antes de poder leerlos.
Future<void> mostrarAviso(
  BuildContext context,
  String mensaje, {
  bool error = false,
}) => mostrarAvisoContenido(context, Text(mensaje), error: error);

Future<void> mostrarAvisoContenido(
  BuildContext context,
  Widget contenido, {
  bool error = false,
  SnackBarAction? accion,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          icon: Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color:
                error
                    ? Theme.of(ctx).colorScheme.error
                    : Theme.of(ctx).colorScheme.primary,
            size: 36,
          ),
          title: Text(error ? 'Revisa esta información' : 'Aviso'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 17, height: 1.45),
                child: contenido,
              ),
            ),
          ),
          actions: [
            if (accion != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  accion.onPressed();
                },
                child: Text(accion.label),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar aviso'),
            ),
          ],
        ),
  );
}

Future<void> mostrarAvisoSnack(BuildContext context, SnackBar aviso) =>
    mostrarAvisoContenido(context, aviso.content, accion: aviso.action);

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
    if (oldWidget.mensaje != widget.mensaje) _mostrar();
  }

  void _mostrar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarAviso(context, widget.mensaje, error: widget.error);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
