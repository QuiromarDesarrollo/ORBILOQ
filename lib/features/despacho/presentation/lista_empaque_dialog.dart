import '../../../domain/destinatario_internacional.dart';
import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../data/seguimiento_entregas.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../admin/presentation/destinatario_editor.dart';
import '../../../shared/widgets/wms_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/descargar_pdf.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../domain/sesion.dart';
import '../../../data/lista_empaque_pdf.dart';

final listaEmpaqueApiProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

Future<void> mostrarListaEmpaque(BuildContext context, String solicitud) =>
    showDialog<void>(
      context: context,
      builder: (_) => ListaEmpaqueDialog(solicitud: solicitud),
    );

class ListaEmpaqueDialog extends ConsumerStatefulWidget {
  const ListaEmpaqueDialog({
    super.key,
    required this.solicitud,
    this.integrado = false,
  });
  final String solicitud;
  final bool integrado;
  @override
  ConsumerState<ListaEmpaqueDialog> createState() => _ListaState();
}

class _ListaState extends ConsumerState<ListaEmpaqueDialog> {
  final remision = TextEditingController(),
      idOc = TextEditingController(),
      factura = TextEditingController(),
      siguiente = TextEditingController(),
      busqueda = TextEditingController();
  SupabaseClient get api => ref.read(listaEmpaqueApiProvider);
  List<Map<String, dynamic>> clientes = [];
  String? destino, error;
  Map<String, dynamic>? documento;
  dynamic numeroLe;
  bool ocupado = false;
  int revision = 0;
  bool enSeguimiento = false;
  Map<String, dynamic>? destinatarioEmpacado;
  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    for (final c in [remision, idOc, factura, siguiente, busqueda]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> tarea(Future<void> Function() f) async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> cargar() => tarea(() async {
    final d =
        widget.solicitud.isEmpty
            ? <String, dynamic>{'pendiente': true}
            : Map<String, dynamic>.from(
              await api.rpc(
                    'le_documento',
                    params: {'p_solicitud': widget.solicitud},
                  )
                  as Map,
            );
    final cs =
        d['pendiente'] == true && d['destinatario_id'] == null
            ? (await api.rpc('le_clientes') as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : <Map<String, dynamic>>[];
    if (mounted) {
      setState(() {
        documento = d['pendiente'] == true ? null : d;
        numeroLe = d['numero'] ?? d['le_numero'];
        revision = (d['ediciones'] as num?)?.toInt() ?? 0;
        enSeguimiento = d['fase'] == 'empacado';
        clientes = cs;
        destinatarioEmpacado =
            d['destinatario_empaque'] is Map
                ? Map<String, dynamic>.from(d['destinatario_empaque'] as Map)
                : null;
        if (d['destinatario_id'] != null) destino = '${d['destinatario_id']}';
      });
    }
  });
  Future<void> crearDestinatario() async {
    final ok = await showWmsDialog<bool>(
      context,
      (_) => DestinatarioEditor(
        guardar: (datos) async {
          // El RPC existente valida permisos de administrador y guarda en PostgreSQL.
          // Recibe datos del formulario, sin archivo Excel.
          await api.rpc(
            esDestinatarioInternacional(datos)
                ? 'le_importar_clientes_internacionales'
                : 'le_importar_clientes',
            params: {
              'p_filas': [datos],
            },
          );
        },
      ),
    );
    if (ok == true && mounted) {
      await cargar();
      if (mounted) {
        mostrarAvisoSnack(
          context,
          const SnackBar(
            content: Text(
              'Destinatario guardado. Ya está disponible en el catálogo.',
            ),
          ),
          tipo: TipoAviso.exito,
        );
      }
    }
  }

  Future<void> generar() => tarea(() async {
    if (documento == null) {
      if (destino == null) {
        throw const FormatException('Selecciona un destinatario');
      }
      final d = Map<String, dynamic>.from(
        await api.rpc(
              enSeguimiento ? 'seguimiento_confirmar' : 'le_documento',
              params: {
                if (enSeguimiento) ...{
                  'p_id': widget.solicitud,
                  'p_revision': revision,
                } else
                  'p_solicitud': widget.solicitud,
                'p_destinatario': destino,
                'p_datos': {
                  'remision': remision.text.trim(),
                  'id_oc': idOc.text.trim(),
                  'factura': factura.text.trim(),
                },
                if (!enSeguimiento) 'p_emitir': true,
              },
            )
            as Map,
      );
      if (mounted) setState(() => documento = d);
      ref.invalidate(historialDespachosProvider);
      ref.invalidate(entregasProvider);
      if (enSeguimiento) ref.read(verEntregasProvider.notifier).state = true;
      await ref.read(wmsRepositoryProvider).refrescar().catchError((Object _) {
        /* El stream informa el fallo de recarga; no repetir lo ya guardado. */
      });
    }
    final logo = await rootBundle.load(
      'assets/images/logo_quiromar_formato.jpg',
    );
    final bytes = await crearListaEmpaquePdf(
      documento!,
      logo: logo.buffer.asUint8List(),
      fuenteRegular: await rootBundle.load(
        'assets/fonts/LiberationSans-Regular.ttf',
      ),
      fuenteNegrita: await rootBundle.load(
        'assets/fonts/LiberationSans-Bold.ttf',
      ),
    );
    await descargarPdf(bytes, 'Lista_empaque_${documento!['numero']}.pdf');
  });
  @override
  Widget build(BuildContext context) {
    final admin =
        ref.watch(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
    final opciones = [
      ...clientes.where((e) => e['id'] == destino),
      ...clientes
          .where((e) => e['id'] != destino)
          .where(
            (e) =>
                e['id'] == destino ||
                (e['datos'] as Map).values
                    .join(' ')
                    .toLowerCase()
                    .contains(busqueda.text.toLowerCase()),
          )
          .take(99),
    ];
    final contenido = SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.solicitud.isNotEmpty)
              Text(
                enSeguimiento && documento == null
                    ? 'Las prendas están reservadas. Revisa el destinatario y confirma la salida para descontarlas de Bodega y generar el PDF.'
                    : 'Salida confirmada. Descargar el PDF nuevamente no vuelve a descontar prendas.',
              ),
            if (ocupado) const WmsLoadingStrip(),
            if (error != null) AvisoFormulario(error!),
            if (documento != null)
              Text(
                'LE ${documento!['numero']} · Documento emitido. Los datos se conservan para reimpresión.',
              )
            else ...[
              if (admin && widget.solicitud.isEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: ocupado ? null : crearDestinatario,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Nuevo destinatario'),
                    ),
                    TextButton(
                      onPressed:
                          ocupado
                              ? null
                              : () => showDialog<void>(
                                context: context,
                                builder:
                                    (c) => WmsExpandableAlertDialog(
                                      title: const Text(
                                        'Próximo consecutivo LE',
                                      ),
                                      content: TextField(
                                        controller: siguiente,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Confirmado por la empresa',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            Navigator.pop(c);
                                            await tarea(() async {
                                              final n = int.tryParse(
                                                siguiente.text,
                                              );
                                              if (n == null || n < 1) {
                                                throw const FormatException(
                                                  'Número inválido',
                                                );
                                              }
                                              await api.rpc(
                                                'le_configurar',
                                                params: {'p_siguiente': n},
                                              );
                                            });
                                          },
                                          child: const Text('Guardar'),
                                        ),
                                      ],
                                    ),
                              ),
                      child: const Text('Consecutivo LE'),
                    ),
                  ],
                ),
              if (destinatarioEmpacado != null) ...[
                const Text(
                  '1 · REVISA EL DESTINO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${destinatarioEmpacado!['nombre']} · ${destinatarioEmpacado!['sede'] ?? ''}',
                ),
                Text(
                  '${destinatarioEmpacado!['ciudad'] ?? ''} · ${destinatarioEmpacado!['direccion'] ?? ''}',
                ),
                const Text(
                  'Para cambiarlo, vuelve a Corregir despacho y genera los rótulos actualizados.',
                ),
              ] else ...[
                TextField(
                  controller: busqueda,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Nombre, NIT, sede o dirección',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se muestran hasta 100 coincidencias.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (opciones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay destinatarios con esta búsqueda.'),
                  ),
                for (final e in opciones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color:
                          destino == '${e['id']}'
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .06)
                              : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color:
                              destino == '${e['id']}'
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap:
                            ocupado
                                ? null
                                : () => setState(() => destino = '${e['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                destino == '${e['id']}'
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${e['datos']['nombre'] ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (esDestinatarioInternacional(
                                      e['datos'] as Map,
                                    ))
                                      Text(
                                        'Internacional · ${e['datos']['pais_destino'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    Text(
                                      'NIT ${e['datos']['nit'] ?? ''} · Sede ${e['datos']['sede'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '${e['datos']['direccion'] ?? ''} · ${e['datos']['ciudad'] ?? ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              if (widget.solicitud.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '2 · DATOS PARA LA LISTA (OPCIONALES)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder:
                      (context, c) => Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final f in [
                            (remision, 'Remisión'),
                            (idOc, 'ID OC del cliente'),
                            (factura, 'Factura'),
                          ])
                            SizedBox(
                              width:
                                  c.maxWidth < 500
                                      ? c.maxWidth
                                      : (c.maxWidth - 20) / 3,
                              child: TextField(
                                controller: f.$1,
                                enabled: !ocupado,
                                maxLength: 150,
                                decoration: InputDecoration(
                                  labelText: '${f.$2} · opcional',
                                  counterText: '',
                                  isDense: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                ),
                const SizedBox(height: 12),
                if (enSeguimiento)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff4dd),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Al confirmar, las prendas salen del inventario de bodega y la LE pasa a Liberados.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Los datos se fijan al emitir la lista. Los campos opcionales vacíos se imprimen en blanco.',
              ),
            ],
          ],
        ),
      ),
    );
    if (widget.integrado) return contenido;
    return WmsDialogShell(
      mobileCatalog: true,
      title:
          widget.solicitud.isEmpty
              ? 'Catálogo de destinatarios'
              : enSeguimiento && documento == null
              ? 'Confirmar salida${numeroLe == null ? '' : ' · LE $numeroLe'}'
              : 'Lista de empaque nacional',
      subtitle:
          widget.solicitud.isEmpty
              ? 'Administra los destinatarios y sus sedes.'
              : 'Revisa el destino y genera la lista de empaque nacional.',
      icon: Icons.local_shipping_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      maxWidth: 720,
      canClose: !ocupado,
      footer: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            destino == null ? 'Sin selección' : '1 seleccionado',
            style: const TextStyle(fontSize: 12),
          ),
          TextButton(
            onPressed: ocupado ? null : () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (widget.solicitud.isNotEmpty)
            FilledButton.icon(
              onPressed: ocupado ? null : generar,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                documento == null
                    ? (enSeguimiento
                        ? 'Confirmar salida y generar PDF'
                        : 'Generar PDF')
                    : 'Descargar PDF',
              ),
            ),
        ],
      ),
      child: contenido,
    );
  }
}
