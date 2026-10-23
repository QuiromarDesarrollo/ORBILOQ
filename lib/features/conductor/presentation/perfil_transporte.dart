import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../application/auth_providers.dart';
import '../../../shared/widgets/wms_alert.dart';
import '../conductor_model.dart';
import '../kit_semanal.dart';
import 'conductor_design.dart';
import 'vista_evidencia_drive.dart';

/// El vehículo recibido debe pertenecer al usuario del perfil, nunca al vehículo
/// seleccionado para administrar la flota.
class PerfilTransporte extends ConsumerWidget {
  const PerfilTransporte({
    super.key,
    this.vehiculo,
    this.administrador = false,
  });
  final VehiculoConductor? vehiculo;
  final bool administrador;

  Widget _dato(String titulo, String valor) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ConductorDesign.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 12, color: ConductorDesign.muted),
        ),
        const SizedBox(height: 5),
        SelectableText(
          valor,
          style: const TextStyle(fontSize: 14, color: ConductorDesign.ink),
        ),
      ],
    ),
  );

  Widget _campos(List<Widget> hijos, {int columnas = 2}) => LayoutBuilder(
    builder: (context, c) {
      final n =
          c.maxWidth < 420 || MediaQuery.textScalerOf(context).scale(14) > 21
              ? 1
              : columnas;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final h in hijos)
            SizedBox(width: (c.maxWidth - 12 * (n - 1)) / n, child: h),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario =
        ref.watch(usarSupabaseProvider)
            ? ref.watch(usuarioSesionProvider).value
            : null;
    final nombre =
        usuario?.nombre ?? (administrador ? 'Administrador' : 'Conductor');
    final datos = vehiculo?.datos ?? <String, dynamic>{};
    String valor(String key, {bool fecha = false}) {
      final texto = datos[key]?.toString().trim() ?? '';
      if (texto.isEmpty) return 'Sin registrar';
      final d = fecha ? DateTime.tryParse(texto) : null;
      return d == null ? texto : DateFormat('dd/MM/yyyy').format(d);
    }

    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2);
    final iniciales =
        partes.map((s) => s.characters.first).join().toUpperCase();
    final vence = DateTime.tryParse(
      datos['Licencia de conducción']?.toString() ?? '',
    );
    final desde = DateTime.tryParse(datos['licencia_desde']?.toString() ?? '');
    final dias = vence == null ? null : diasRestantes(vence, hoyColombia());
    final futura = desde != null && diasRestantes(desde, hoyColombia()) > 0;
    final estado =
        dias == null
            ? 'Sin registrar'
            : dias < 0
            ? 'Vencida'
            : futura
            ? 'Vigencia futura'
            : dias == 0
            ? 'Vence hoy'
            : dias <= 30
            ? 'Vence en $dias días'
            : 'Vigente';
    final foto = datos['foto_conductor']?.toString() ?? '';
    final licencia = datos['doc_licencia']?.toString() ?? '';
    final cabecera = Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: ConductorDesign.navy,
          child: Text(
            iniciales,
            style: const TextStyle(
              color: ConductorDesign.lime,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    administrador ? 'Administrador' : 'Conductor',
                    style: const TextStyle(color: ConductorDesign.muted),
                  ),
                  if (vehiculo != null) ConductorBadge(vehiculo!.placa),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final salir = OutlinedButton.icon(
      onPressed: () async {
        if (!ref.read(usarSupabaseProvider)) {
          await mostrarAviso(
            context,
            'Estás en el modo de demostración. No hay una sesión activa que cerrar.',
          );
          return;
        }
        try {
          await ref.read(authRepositoryProvider)?.cerrarSesion();
        } catch (_) {
          if (context.mounted) {
            await mostrarAviso(
              context,
              'No se pudo cerrar la sesión. Vuelve a intentarlo.',
              error: true,
            );
          }
        }
      },
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Cerrar sesión'),
    );
    final camposLicencia = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campos([
          _dato('Vigencia desde', valor('licencia_desde', fecha: true)),
          _dato('Vigencia hasta', valor('Licencia de conducción', fecha: true)),
          _dato('Expedido', valor('licencia_expedido', fecha: true)),
          _dato('Valor · COP', valor('licencia_valor')),
        ]),
        const SizedBox(height: 12),
        _dato('Observaciones', valor('licencia_observaciones')),
      ],
    );
    final preview =
        vehiculo != null && licencia.isNotEmpty
            ? VistaEvidenciaDrive(
              vehiculo: vehiculo!.id,
              enlace: licencia,
              titulo: 'Vista previa de la licencia',
              height: 130,
            )
            : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ConductorDesign.background,
                border: Border.all(color: ConductorDesign.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 34,
                    color: ConductorDesign.muted,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Vista previa de la licencia',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sin archivo registrado',
                    style: TextStyle(
                      fontSize: 12,
                      color: ConductorDesign.muted,
                    ),
                  ),
                ],
              ),
            );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${administrador ? 'Administrador' : 'Conductor'} / Perfil',
              style: const TextStyle(
                color: ConductorDesign.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mi perfil',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder:
                      (context, c) =>
                          c.maxWidth >= 600 &&
                                  MediaQuery.textScalerOf(context).scale(14) <
                                      21
                              ? Row(
                                children: [
                                  Expanded(child: cabecera),
                                  const SizedBox(width: 16),
                                  salir,
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  cabecera,
                                  const SizedBox(height: 16),
                                  salir,
                                ],
                              ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConductorPanel(
              title: 'Datos personales',
              icon: Icons.person_outline,
              children: [
                _campos([
                  _dato('Nombre', nombre),
                  _dato('Número de documento', valor('conductor_documento')),
                  foto.isEmpty || vehiculo == null
                      ? _dato('Foto del conductor', 'Sin registrar')
                      : VistaEvidenciaDrive(
                        vehiculo: vehiculo!.id,
                        enlace: foto,
                        titulo: 'Foto del conductor',
                        height: 100,
                      ),
                ], columnas: 3),
              ],
            ),
            const SizedBox(height: 16),
            ConductorPanel(
              title: 'Licencia de conducción',
              icon: Icons.description_outlined,
              trailing: ConductorBadge(
                estado,
                warning: dias == null || dias <= 30 || futura,
                error: dias != null && dias < 0,
              ),
              children: [
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder:
                      (context, c) =>
                          c.maxWidth >= 640 &&
                                  MediaQuery.textScalerOf(context).scale(14) <
                                      21
                              ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 210, child: preview),
                                  const SizedBox(width: 16),
                                  Expanded(child: camposLicencia),
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  preview,
                                  const SizedBox(height: 12),
                                  camposLicencia,
                                ],
                              ),
                ),
                if (dias == null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF946000),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            administrador
                                ? 'No hay información de licencia vinculada a tu perfil.'
                                : 'Aún no hay datos de tu licencia. Pide al administrador que los registre para que aparezcan aquí.',
                            style: const TextStyle(
                              color: Color(0xFF946000),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
