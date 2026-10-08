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

Future<void> mostrarListaEmpaque(BuildContext context, String solicitud) =>
    showDialog<void>(
      context: context,
      builder: (_) => ListaEmpaqueDialog(solicitud: solicitud),
    );

class ListaEmpaqueDialog extends ConsumerStatefulWidget {
  const ListaEmpaqueDialog({super.key, required this.solicitud});
  final String solicitud;
  @override
  ConsumerState<ListaEmpaqueDialog> createState() => _ListaState();
}

class _ListaState extends ConsumerState<ListaEmpaqueDialog> {
  final remision = TextEditingController(),
      idOc = TextEditingController(),
      factura = TextEditingController(),
      siguiente = TextEditingController(),
      busqueda = TextEditingController();
  final api = Supabase.instance.client;
  List<Map<String, dynamic>> clientes = [];
  String? destino, error;
  Map<String, dynamic>? documento;
  bool ocupado = false;
  int revision = 0;
  bool enSeguimiento = false;
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
        d['pendiente'] == true
            ? (await api.rpc('le_clientes') as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : <Map<String, dynamic>>[];
    if (mounted) {
      setState(() {
        documento = d['pendiente'] == true ? null : d;
        revision = (d['ediciones'] as num?)?.toInt() ?? 0;
        enSeguimiento = d['fase'] == 'empacado';
        clientes = cs;
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
            'le_importar_clientes',
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
        mostrarAvisoSnack(context, 
          const SnackBar(
            content: Text(
              'Destinatario guardado. Ya está disponible en el catálogo.',
            ),
          ),
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
      await ref.read(wmsRepositoryProvider).refrescar();
    }
    final logo = await rootBundle.load(
      'assets/images/logo_quiromar_formato.jpg',
    );
    final bytes = await crearListaEmpaquePdf(
      documento!,
      logo: logo.buffer.asUint8List(),
      fuenteRegular: await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
      fuenteNegrita: await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'),
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
    return AlertDialog(
      title: Text(
        widget.solicitud.isEmpty
            ? 'Catálogo de destinatarios'
            : 'Lista de empaque nacional',
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.solicitud.isNotEmpty)
                Text(
                  enSeguimiento && documento == null
                      ? 'Las prendas están reservadas. Selecciona el destinatario y confirma la salida para descontarlas de Bodega y generar el PDF.'
                      : 'Salida confirmada. Descargar el PDF nuevamente no vuelve a descontar prendas.',
                ),
              if (ocupado) const LinearProgressIndicator(),
              if (error != null)
                AvisoFormulario(error!),
              if (documento != null)
                Text(
                  'LE ${documento!['numero']} · Documento emitido. Los datos se conservan para reimpresión.',
                )
              else ...[
                if (admin)
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
                                      (c) => AlertDialog(
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
                        child: const Text('Configurar consecutivo LE'),
                      ),
                    ],
                  ),
                TextField(
                  controller: busqueda,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Buscar destinatario, NIT, sede o dirección',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: destino,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Destinatario / sede',
                  ),
                  items: [
                    for (final e in opciones)
                      DropdownMenuItem(
                        value: '${e['id']}',
                        child: Text(
                          '${e['datos']['nombre']} · ${e['datos']['sede'] ?? ''} · ${e['datos']['ciudad']} · ${e['datos']['direccion']} · ${e['datos']['contacto']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      ocupado ? null : (v) => setState(() => destino = v),
                ),
                const Text(
                  'Se muestran hasta 100 coincidencias. Confirma la sede del cliente de este despacho.',
                ),
                if (destino != null)
                  Text(
                    (clientes.firstWhere((e) => e['id'] == destino)['datos']
                            as Map)
                        .entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                  ),
                if (widget.solicitud.isNotEmpty)
                  for (final f in [
                    (remision, 'Remisión'),
                    (idOc, 'ID OC'),
                    (factura, 'Factura'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: f.$1,
                        enabled: !ocupado,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: '${f.$2} (opcional)',
                        ),
                      ),
                    ),
                const Text(
                  'Los datos se fijan al emitir la lista. Los campos opcionales vacíos se imprimen en blanco.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
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
    );
  }
}
