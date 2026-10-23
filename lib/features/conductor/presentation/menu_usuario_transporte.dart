import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_alert.dart';
import 'conductor_design.dart';

class MenuUsuarioTransporte extends ConsumerWidget {
  const MenuUsuarioTransporte({
    super.key,
    required this.onPerfil,
    this.administrador = false,
    this.oscuro = false,
  });
  final VoidCallback onPerfil;
  final bool administrador, oscuro;

  Future<void> _salir(BuildContext context, WidgetRef ref) async {
    if (!ref.read(usarSupabaseProvider)) {
      await mostrarAviso(
        context,
        'Estás en el modo de demostración. No hay una sesión activa que cerrar.',
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider)?.cerrarSesion();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (context.mounted) {
        await mostrarAviso(
          context,
          'No se pudo cerrar la sesión. Vuelve a intentarlo.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario =
        ref.watch(usarSupabaseProvider)
            ? ref.watch(usuarioSesionProvider).asData?.value
            : null;
    final rol = administrador ? 'Administrador' : 'Conductor';
    final nombre = usuario?.nombre.trim() ?? '';
    final etiqueta = nombre.isEmpty ? rol : nombre;
    final color = oscuro ? Colors.white : ConductorDesign.navy;
    final amplio =
        MediaQuery.sizeOf(context).width >= 900 &&
        MediaQuery.textScalerOf(context).scale(14) < 21;
    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      position: PopupMenuPosition.under,
      color: const Color(0xFFEAF1F0),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (opcion) {
        if (opcion == 'perfil') onPerfil();
        if (opcion == 'salir') _salir(context, ref);
      },
      itemBuilder:
          (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(rol, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'perfil',
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 20,
                    color: ConductorDesign.navy,
                  ),
                  SizedBox(width: 12),
                  Text('Perfil'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'salir',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Color(0xFFB42318)),
                  SizedBox(width: 12),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ),
            ),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: ConductorDesign.lime,
              foregroundColor: ConductorDesign.navy,
              child: Text(
                etiqueta.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (amplio) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(rol, style: TextStyle(color: color, fontSize: 11)),
                  ],
                ),
              ),
            ],
            Icon(Icons.expand_more, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
