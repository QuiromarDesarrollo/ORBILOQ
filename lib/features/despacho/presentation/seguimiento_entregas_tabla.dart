import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/seguimiento_entregas.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../shared/widgets/wms_alert.dart';

class SeguimientoPanel extends ConsumerWidget {
  const SeguimientoPanel({super.key, required this.pendientes});
  final Widget pendientes;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liberados = ref.watch(verEntregasProvider);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: const Color(0xfff4f8f9),
          child: Row(
            children: [
              for (final paso in [
                ('1', 'Reservada'),
                ('2', 'Liberada'),
                ('3', 'En tránsito'),
                ('4', 'Entregada'),
              ])
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xff123e4f),
                        child: Text(
                          paso.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(paso.$2, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Por liberar'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Liberados'),
                icon: Icon(Icons.local_shipping_outlined),
              ),
            ],
            selected: {liberados},
            onSelectionChanged:
                (v) => ref.read(verEntregasProvider.notifier).state = v.single,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: liberados ? 1 : 0,
            children: [pendientes, const TablaEntregas()],
          ),
        ),
      ],
    );
  }
}

const estadosEntrega = {
  'en_transito': 'En tránsito',
  'entregado': 'Entregado',
  'devuelto_cliente': 'Devuelto por el cliente',
  'devolucion_parcial': 'Devolución parcial',
};

Color colorEstadoEntrega(BuildContext context, String estado) {
  final oscuro = Theme.of(context).brightness == Brightness.dark;
  return switch (estado) {
    'entregado' => oscuro ? Colors.green.shade300 : AppColors.actionGreen,
    'devolucion_parcial' =>
      oscuro ? Colors.orange.shade300 : Colors.orange.shade800,
    'devuelto_cliente' => oscuro ? Colors.red.shade300 : AppColors.alertRed,
    _ => oscuro ? Colors.amber.shade300 : Colors.amber.shade800,
  };
}

Widget indicadorEstadoEntrega(BuildContext context, String estado) =>
    StatusChip(
      label: estadosEntrega[estado] ?? 'En tránsito',
      color: colorEstadoEntrega(context, estado),
    );

class _Fila {
  _Fila(this.d)
    : transporte = TextEditingController(text: '${d['transportadora'] ?? ''}'),
      guia = TextEditingController(text: '${d['numero_guia'] ?? ''}'),
      placa = TextEditingController(text: '${d['placa'] ?? ''}'),
      obs = TextEditingController(text: '${d['observaciones'] ?? ''}'),
      recibido = DateTime.tryParse('${d['recibido']}'),
      estado =
          d['estado'] as String? ??
          (d['recibido'] == null ? 'en_transito' : 'entregado'),
      le = d['evidencia_le'] as Map?,
      evidenciaGuia = d['evidencia_guia'] as Map?;
  final Map<String, dynamic> d;
  final TextEditingController transporte, guia, placa, obs;
  DateTime? recibido;
  String estado;
  Map? le, evidenciaGuia;
  bool ocupado = false, cambiado = false;
  void dispose() {
    transporte.dispose();
    guia.dispose();
    placa.dispose();
    obs.dispose();
  }
}

class TablaEntregas extends ConsumerStatefulWidget {
  const TablaEntregas({super.key});
  @override
  ConsumerState<TablaEntregas> createState() => _TablaState();
}

class _TablaState extends ConsumerState<TablaEntregas> {
  final filas = <String, _Fila>{};
  StateSetter? _modal;
  DateTimeRange? rangoRecibido;
  void redibujar(VoidCallback cambio) {
    if (!mounted) return;
    setState(cambio);
    _modal?.call(() {});
  }

  String buscar = '';
  String filtroEstado = '';
  String fecha(DateTime? d) =>
      d == null
          ? 'Sin fecha'
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  void dispose() {
    for (final f in filas.values) {
      f.dispose();
    }

    super.dispose();
  }

  Future<void> tarea(_Fila f, Future<void> Function() accion) async {
    redibujar(() => f.ocupado = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) {
        await mostrarAviso(
          context,
          e is PostgrestException
              ? e.message
              : e is FormatException
              ? e.message
              : 'No se pudo completar la operación: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) redibujar(() => f.ocupado = false);
    }
  }

  Future<void> adjuntar(_Fila f, String tipo) => tarea(f, () async {
    final archivo = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (archivo == null) return;
    final a = archivo.files.single;
    if (a.bytes == null || a.size > 10 * 1024 * 1024 || a.size == 0) {
      throw const FormatException('Adjunta un PDF o imagen de hasta 10 MB.');
    }
    final ext = a.extension!.toLowerCase();
    final mime =
        {
          'pdf': 'application/pdf',
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
        }[ext];
    if (mime == null) throw const FormatException('Formato no permitido.');
    final path =
        '${f.d['id']}/${f.d['revision']}/$tipo/${nuevaSolicitudDespacho()}.$ext';
    await Supabase.instance.client.storage
        .from('seguimiento-evidencias')
        .uploadBinary(
          path,
          a.bytes!,
          fileOptions: FileOptions(contentType: mime),
        );
    if (!mounted) return;
    redibujar(() {
      final valor = {'path': path, 'nombre': a.name};
      if (tipo == 'evidencia_le') {
        f.le = valor;
      } else {
        f.evidenciaGuia = valor;
      }
      f.cambiado = true;
    });
  });
  Future<void> abrir(_Fila f, Map a) => tarea(f, () async {
    final url = await Supabase.instance.client.storage
        .from('seguimiento-evidencias')
        .createSignedUrl('${a['path']}', 300);
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw const FormatException('No se pudo abrir el archivo.');
    }
  });
  Future<void> guardar(_Fila f) => tarea(f, () async {
    final version = await Supabase.instance.client.rpc(
      'seguimiento_entregas_guardar_v87',
      params: {
        'p_id': f.d['id'],
        'p_revision': f.d['revision'],
        'p_version': f.d['version'],
        'p_datos': {
          'estado': f.estado,
          'transportadora': f.transporte.text,
          'placa_guia': f.d['placa_guia'] ?? '',
          'numero_guia': f.guia.text,
          'placa': f.placa.text,
          'recibido': f.recibido?.toIso8601String().substring(0, 10),
          'evidencia_le': f.le,
          'evidencia_guia': f.evidenciaGuia,
          'observaciones': f.obs.text,
        },
      },
    );
    f.d['version'] = version;
    f.cambiado = false;
    ref.invalidate(entregasProvider);
    if (mounted) {
      await mostrarAviso(
        context,
        'Seguimiento de LE ${f.d['le']} guardado.',
        tipo: TipoAviso.exito,
      );
    }
  });
  Widget campo(
    _Fila f,
    TextEditingController c,
    String label,
    int max, {
    int lineas = 1,
  }) => TextField(
    controller: c,
    enabled: !f.ocupado,
    maxLength: max,
    minLines: lineas,
    maxLines: lineas,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      counterText: '',
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) => redibujar(() => f.cambiado = true),
  );
  Widget evidencia(_Fila f, String tipo, Map? a) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tipo == 'evidencia_le' ? 'Evidencia LE' : 'Evidencia guía',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (a != null)
          TextButton(
            onPressed: f.ocupado ? null : () => abrir(f, a),
            child: Text(
              '${a['nombre']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin archivo adjunto'),
          ),
        TextButton.icon(
          onPressed: f.ocupado ? null : () => adjuntar(f, tipo),
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(a == null ? 'Adjuntar archivo' : 'Reemplazar archivo'),
        ),
        if (a != null)
          TextButton.icon(
            key: ValueKey('quitar-$tipo'),
            onPressed:
                f.ocupado
                    ? null
                    : () => redibujar(() {
                      if (tipo == 'evidencia_le') {
                        f.le = null;
                      } else {
                        f.evidenciaGuia = null;
                      }
                      f.cambiado = true;
                    }),
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            label: const Text('Quitar adjunto'),
          ),
      ],
    ),
  );
  Widget pareja(Widget a, Widget b, bool compacta) =>
      compacta
          ? Column(children: [a, const SizedBox(height: 14), b])
          : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          );

  Future<void> editar(_Fila f) async {
    var pantallaCompleta = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, cambiar) {
              _modal = cambiar;
              final colores = Theme.of(ctx).colorScheme;
              final compacta = MediaQuery.sizeOf(ctx).width < 650;
              return PopScope(
                canPop: !f.ocupado,
                child: Dialog(
                  backgroundColor: Colors.white,
                  insetPadding: EdgeInsets.all(pantallaCompleta ? 0 : 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      pantallaCompleta ? 0 : 18,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth:
                          pantallaCompleta ? MediaQuery.sizeOf(ctx).width : 0,
                      maxWidth:
                          pantallaCompleta ? MediaQuery.sizeOf(ctx).width : 760,
                      maxHeight:
                          MediaQuery.sizeOf(ctx).height -
                          MediaQuery.viewInsetsOf(ctx).bottom -
                          (pantallaCompleta ? 0 : 32),
                    ),
                    child: Column(
                      mainAxisSize:
                          pantallaCompleta
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                          decoration: const BoxDecoration(
                            color: Color(0xfff4f8f9),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                color: colores.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seguimiento · LE ${f.d['le']}',
                                      style: Theme.of(ctx).textTheme.titleLarge,
                                    ),
                                    Text(
                                      '${f.d['cliente']}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    pantallaCompleta
                                        ? 'Restaurar tamaño'
                                        : 'Ampliar pantalla',
                                icon: Icon(
                                  pantallaCompleta
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                ),
                                onPressed:
                                    () => cambiar(
                                      () =>
                                          pantallaCompleta = !pantallaCompleta,
                                    ),
                              ),
                              IconButton(
                                tooltip: 'Cerrar formulario',
                                onPressed:
                                    f.ocupado ? null : () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      '${(f.d['cajas'] as num) + (f.d['empaques'] as num)} piezas · ${f.d['cajas']} cajas / ${f.d['empaques']} empaques',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Despacho: ${fecha(DateTime.parse('${f.d['fecha']}').toUtc().subtract(const Duration(hours: 5)))}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'TRANSPORTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                pareja(
                                  campo(f, f.transporte, 'Transportadora', 150),
                                  campo(f, f.guia, 'N° de guía', 150),
                                  compacta,
                                ),
                                const SizedBox(height: 14),
                                campo(f, f.placa, 'Placa', 150),
                                if ('${f.d['placa_guia'] ?? ''}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Dato histórico (placa o guía): ${f.d['placa_guia']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                const Text(
                                  'ENTREGA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: f.estado,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Estado del envío',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final e in estadosEntrega.entries)
                                      DropdownMenuItem(
                                        value: e.key,
                                        child: indicadorEstadoEntrega(
                                          context,
                                          e.key,
                                        ),
                                      ),
                                  ],
                                  onChanged:
                                      f.ocupado
                                          ? null
                                          : (v) => redibujar(() {
                                            f.estado = v!;
                                            f.cambiado = true;
                                          }),
                                ),
                                if ((f.estado == 'devuelto_cliente' ||
                                    f.estado == 'devolucion_parcial'))
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Este estado no reingresa prendas a Bodega. La recepción de una devolución debe registrar las cantidades que realmente regresaron.',
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha de recibido',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 2,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed:
                                              f.ocupado
                                                  ? null
                                                  : () => calendario(f),
                                          icon: const Icon(
                                            Icons.calendar_month,
                                          ),
                                          label: Text(fecha(f.recibido)),
                                        ),
                                      ),
                                      if (f.recibido != null)
                                        IconButton(
                                          tooltip: 'Quitar fecha',
                                          onPressed:
                                              f.ocupado
                                                  ? null
                                                  : () => redibujar(() {
                                                    f.recibido = null;
                                                    f.cambiado = true;
                                                  }),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'EVIDENCIAS · ${(f.le == null ? 0 : 1) + (f.evidenciaGuia == null ? 0 : 1)} DE 2',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                pareja(
                                  evidencia(f, 'evidencia_le', f.le),
                                  evidencia(
                                    f,
                                    'evidencia_guia',
                                    f.evidenciaGuia,
                                  ),
                                  compacta,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Adjuntos opcionales · PDF o imagen · Máximo 10 MB por archivo',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                campo(
                                  f,
                                  f.obs,
                                  'Observaciones',
                                  3000,
                                  lineas: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.cambiado
                                      ? 'Cambios sin guardar'
                                      : 'Todo guardado',
                                  style: TextStyle(
                                    color:
                                        f.cambiado
                                            ? colores.error
                                            : colores.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed:
                                    f.ocupado || !f.cambiado
                                        ? null
                                        : () => guardar(f),
                                icon: Icon(
                                  f.ocupado
                                      ? Icons.hourglass_top
                                      : Icons.save_outlined,
                                ),
                                label: const Text('Guardar cambios'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    _modal = null;
    if (mounted) setState(() {});
  }

  Future<void> calendario(_Fila f) async {
    final hoy = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final fin = DateTime(hoy.year, hoy.month, hoy.day);
    final v = await showDatePicker(
      context: context,
      initialDate: f.recibido ?? fin,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Seleccionar fecha de recibido',
    );
    if (v != null && mounted) {
      redibujar(() {
        f.recibido = v;
        f.cambiado = true;
      });
    }
  }

  Future<void> actualizar() async {
    if (filas.values.any((f) => f.ocupado)) return;
    if (filas.values.any((f) => f.cambiado)) {
      final descartar = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => WmsExpandableAlertDialog(
              title: const Text('Hay cambios sin guardar'),
              content: const Text(
                '¿Descartar los cambios y actualizar los despachos?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continuar editando'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Descartar y actualizar'),
                ),
              ],
            ),
      );
      if (descartar != true) return;
    }
    for (final f in filas.values) {
      f.dispose();
    }
    filas.clear();
    ref.invalidate(entregasProvider);
  }

  Future<void> filtrarFecha() async {
    final seleccion = await showDateRangePicker(
      context: context,
      initialDateRange: rangoRecibido,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: 'Filtrar por fecha de recibido',
      saveText: 'Aplicar',
    );
    if (seleccion != null && mounted) {
      redibujar(() => rangoRecibido = seleccion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(entregasProvider);
    final colores = Theme.of(context).colorScheme;
    return ListView(
      children: [
        LayoutBuilder(
          builder:
              (ctx, limites) => Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width:
                        limites.maxWidth > 750
                            ? limites.maxWidth - 280
                            : limites.maxWidth,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar LE o cliente',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged:
                          (v) =>
                              redibujar(() => buscar = v.toLowerCase().trim()),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: filtrarFecha,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      rangoRecibido == null
                          ? 'Fecha de recibido'
                          : '${fecha(rangoRecibido!.start)} – ${fecha(rangoRecibido!.end)}',
                    ),
                  ),
                  if (rangoRecibido != null)
                    IconButton(
                      tooltip: 'Quitar filtro de recibido',
                      onPressed: () => redibujar(() => rangoRecibido = null),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                    ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: actualizar,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final estado in {'': 'Todas', ...estadosEntrega}.entries)
                ChoiceChip(
                  label: Text(
                    '${estado.value} · ${(datos.valueOrNull ?? []).where((d) => estado.key.isEmpty || (filas['${d['id']}:${d['revision']}']?.estado ?? d['estado'] ?? (d['recibido'] == null ? 'en_transito' : 'entregado')) == estado.key).length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: filtroEstado == estado.key,
                  onSelected: (_) => redibujar(() => filtroEstado = estado.key),
                ),
            ],
          ),
        ),
        datos.when(
          skipLoadingOnRefresh: false,
          loading: () => const WmsLoadingPanel(),
          error:
              (e, _) =>
                  Center(child: Text('No se pudo cargar Seguimiento. $e')),
          data: (lista) {
            final visibles =
                lista
                    .map(
                      (d) => filas.putIfAbsent(
                        '${d['id']}:${d['revision']}',
                        () => _Fila(Map.of(d)),
                      ),
                    )
                    .where(
                      (f) =>
                          '${f.d['le']} ${f.d['cliente']}'
                              .toLowerCase()
                              .contains(buscar) &&
                          recibidoEnRango(f.recibido, rangoRecibido) &&
                          (filtroEstado.isEmpty || f.estado == filtroEstado),
                    )
                    .toList();
            if (visibles.isEmpty) {
              return const Center(
                child: Text('No hay despachos que coincidan con los filtros.'),
              );
            }
            return LayoutBuilder(
              builder: (ctx, limites) {
                final columnas = (limites.maxWidth / 300).floor().clamp(1, 5);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    mainAxisExtent:
                        190 +
                        (MediaQuery.textScalerOf(ctx).scale(14) - 14).clamp(
                              0,
                              40,
                            ) *
                            7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (ctx, i) {
                    final f = visibles[i];
                    final tono = colorEstadoEntrega(ctx, f.estado);
                    return Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: tono.withValues(alpha: .22)),
                      ),
                      child: InkWell(
                        onTap: () => editar(f),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: tono,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'LE ${f.d['le']}',
                                      style: Theme.of(
                                        ctx,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: tono,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${f.d['cliente']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colores.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(f.d['cajas'] as num) + (f.d['empaques'] as num)} piezas · ${f.d['cajas']} cajas · ${f.d['empaques']} empaques',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Despacho: ${fecha(DateTime.parse('${f.d['fecha']}').toUtc().subtract(const Duration(hours: 5)))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colores.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                'Recibido: ${fecha(f.recibido)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colores.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: indicadorEstadoEntrega(
                                        context,
                                        f.estado,
                                      ),
                                    ),
                                  ),
                                  if (f.cambiado)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Tooltip(
                                        message: 'Cambios sin guardar',
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: colores.error,
                                        ),
                                      ),
                                    ),
                                  Icon(
                                    Icons.attach_file,
                                    size: 16,
                                    color: colores.onSurfaceVariant,
                                  ),
                                  Text(
                                    '${(f.le == null ? 0 : 1) + (f.evidenciaGuia == null ? 0 : 1)}/2',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// El rango incluye ambos extremos; las LE sin fecha solo aparecen sin filtro.
bool recibidoEnRango(DateTime? fecha, DateTimeRange? rango) {
  if (rango == null) return true;
  if (fecha == null) return false;
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  return !dia.isBefore(DateUtils.dateOnly(rango.start)) &&
      !dia.isAfter(DateUtils.dateOnly(rango.end));
}
