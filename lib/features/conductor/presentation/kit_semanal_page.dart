import '../../../shared/widgets/wms_alert.dart';
import 'transporte_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth_providers.dart';
import '../../../domain/sesion.dart';
import '../conductor_model.dart';
import '../conductor_repository.dart';
import '../kit_semanal.dart';
import 'conductor_design.dart';
import 'borrador_transporte_mixin.dart';

class KitSemanalPage extends ConsumerStatefulWidget {
  const KitSemanalPage({super.key, required this.vehiculo});
  final VehiculoConductor vehiculo;
  @override
  ConsumerState<KitSemanalPage> createState() => _KitSemanalState();
}

class _KitSemanalState extends ConsumerState<KitSemanalPage>
    with BorradorTransporteMixin<KitSemanalPage> {
  bool get ocupado => guardando || draftLoading;
  @override
  String get draftKey => 'kit-semanal|${widget.vehiculo.id}';
  @override
  bool get draftBusy => ocupado;
  @override
  bool get draftWeekly => true;
  @override
  Map<String, dynamic> draftSnapshot() => {
    'inspector': inspector.text,
    'lugar': lugar.text,
    'notas': notas.text,
    'fecha': fecha.toIso8601String(),
    'categoria': categoria,
    'respuestas': respuestas,
    'detalles': detalles.map((k, v) => MapEntry(k, v.text)),
  };
  @override
  void restoreDraft(Map<String, dynamic> data) {
    inspector.text = data['inspector'] as String? ?? '';
    lugar.text = data['lugar'] as String? ?? '';
    notas.text = data['notas'] as String? ?? '';
    fecha = DateTime.tryParse('${data['fecha']}') ?? hoyColombia();
    categoria = ((data['categoria'] as num?)?.toInt() ?? 0).clamp(
      0,
      categorias.length - 1,
    );
    respuestas.clear();
    for (final entry in (data['respuestas'] as Map? ?? {}).entries) {
      respuestas[entry.key as String] = Map<String, dynamic>.from(
        entry.value as Map,
      );
    }
    for (final entry in (data['detalles'] as Map? ?? {}).entries) {
      detalles
          .putIfAbsent(entry.key as String, TextEditingController.new)
          .text = entry.value as String;
    }
    modificado = true;
  }

  final inspector = TextEditingController(),
      lugar = TextEditingController(),
      notas = TextEditingController();
  final respuestas = <String, Map<String, dynamic>>{};
  final detalles = <String, TextEditingController>{};
  DateTime fecha = hoyColombia();
  bool guardando = false, modificado = false;
  String? error;
  int categoria = 0;
  List<String> get categorias =>
      catalogoKit.map((p) => p['categoria'] as String).toSet().toList();
  @override
  void initState() {
    super.initState();
    inspector.text =
        ref.read(usuarioSesionProvider).value?.nombre ?? 'Administrador';
    for (final controller in [inspector, lugar, notas]) {
      controller.addListener(saveDraft);
    }
  }

  @override
  void dispose() {
    inspector.dispose();
    lugar.dispose();
    notas.dispose();
    for (final c in detalles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> guardar() async {
    if (ocupado) return;
    final datos = <String, dynamic>{
      'inspector': inspector.text.trim(),
      'fecha': fechaKit(fecha),
      'lugar': lugar.text.trim(),
      'notas': notas.text.trim(),
      'respuestas': respuestas,
    };
    final fallo = validarKit(datos, hoyColombia());
    if (fallo != null) {
      setState(() => error = fallo);
      return;
    }
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await ref
          .read(conductorRepositoryProvider)
          .guardarKit(widget.vehiculo.id, datos);
      await completeDraft();
      if (mounted) {
        setState(() => modificado = false);
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error =
                  'No se pudo guardar la revisión. Tus respuestas siguen aquí. Verifica la conexión y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> salir() async {
    if (ocupado) return;
    if (draftEnabled) {
      await leaveDraft();
      return;
    }
    if (modificado) {
      final descartar = await confirmarAviso(
        context,
        'Las respuestas aún no se han guardado.',
        titulo: '¿Descartar esta revisión?',
        confirmar: 'Descartar',
        cancelar: 'Continuar revisión',
      );
      if (descartar != true) return;
    }
    if (mounted) {
      setState(() => modificado = false);
      Navigator.pop(context);
    }
  }

  Widget punto(Map<String, dynamic> p) {
    final nombre = p['nombre'] as String;
    final r = respuestas[nombre] ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            r['estado'] == 'Con novedad'
                ? const Color(0xFFFFFAF0)
                : const Color(0xFFF5F8FA),
        border: Border.all(
          color:
              r['estado'] == 'Con novedad'
                  ? const Color(0xFFE8C98C)
                  : ConductorDesign.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final opciones = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final estado in [
                    'Buen estado',
                    'Con novedad',
                    if (p['opcional'] == true) 'No aplica',
                  ])
                    ChoiceChip(
                      label: Text(estado),
                      selected: r['estado'] == estado,
                      onSelected:
                          ocupado
                              ? null
                              : (_) => setState(() {
                                modificado = true;
                                respuestas[nombre] = {
                                  'estado': estado,
                                  if (estado == 'Con novedad')
                                    'detalle': detalles[nombre]?.text ?? '',
                                  if (estado != 'No aplica' &&
                                      r['vencimiento'] != null)
                                    'vencimiento': r['vencimiento'],
                                };
                              }),
                    ),
                ],
              );
              final titulo = Text(
                nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ConductorDesign.ink,
                ),
              );
              if (constraints.maxWidth >= 720 &&
                  MediaQuery.textScalerOf(context).scale(14) < 21) {
                return Row(
                  children: [
                    Expanded(child: titulo),
                    const SizedBox(width: 16),
                    opciones,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titulo, const SizedBox(height: 10), opciones],
              );
            },
          ),
          if (r['estado'] == 'Con novedad')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: detalles.putIfAbsent(
                  nombre,
                  () => TextEditingController(),
                ),
                enabled: !ocupado,
                maxLength: 120,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Detalle de la novedad *',
                ),
                onChanged: (s) {
                  respuestas[nombre]!['detalle'] = s;
                  modificado = true;
                  saveDraft();
                },
              ),
            ),
          if (p['vencimiento'] == true &&
              r['estado'] != null &&
              r['estado'] != 'No aplica')
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    r['vencimiento']?.toString() ?? 'Vencimiento (si aplica)',
                  ),
                  onPressed:
                      ocupado
                          ? null
                          : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(
                                    r['vencimiento']?.toString() ?? '',
                                  ) ??
                                  fecha,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null && mounted) {
                              setState(() {
                                modificado = true;
                                respuestas[nombre]!['vencimiento'] = fechaKit(
                                  d,
                                );
                              });
                            }
                          },
                ),
                if (r['vencimiento'] != null)
                  IconButton(
                    tooltip: 'Quitar vencimiento',
                    onPressed:
                        ocupado
                            ? null
                            : () => setState(() {
                              modificado = true;
                              respuestas[nombre]!.remove('vencimiento');
                            }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(usarSupabaseProvider) &&
        ref.watch(usuarioSesionProvider).value?.tieneRol(RolCuenta.admin) !=
            true) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Solo el administrador puede revisar el kit de carretera.',
          ),
        ),
      );
    }
    final buenos =
        respuestas.values.where((r) => r['estado'] == 'Buen estado').length;
    final novedades =
        respuestas.values.where((r) => r['estado'] == 'Con novedad').length;
    final noAplica =
        respuestas.values.where((r) => r['estado'] == 'No aplica').length;
    return Theme(
      data: ConductorDesign.theme(),
      child: PopScope(
        canPop: !ocupado && (draftEnabled ? draftCanLeave : !modificado),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) salir();
        },
        child: TransporteScaffold(
          loadingLabel:
              guardando
                  ? 'Guardando revisión semanal del kit de carretera…'
                  : null,
          appBar: AppBar(
            title: const Text('Kit de carretera · semanal'),
            leading: IconButton(
              onPressed: ocupado ? null : salir,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    draftStatus(),
                    Text(
                      '${widget.vehiculo.placa} · ${widget.vehiculo.descripcion}',
                      style: const TextStyle(
                        color: ConductorDesign.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Una revisión por semana (lunes a domingo). Puedes registrar una nueva revisión para documentar correcciones. Este formulario complementa la inspección diaria.',
                    ),
                    const SizedBox(height: 20),
                    ConductorPanel(
                      title: 'A. Datos de inspección',
                      children: [
                        TextField(
                          controller: inspector,
                          enabled: !ocupado,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del inspector *',
                          ),
                          onChanged: (_) => modificado = true,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            'Fecha de inspección: ${fechaKit(fecha)}',
                          ),
                          onPressed:
                              ocupado
                                  ? null
                                  : () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          fecha.isBefore(
                                                    lunesKit(hoyColombia()),
                                                  ) ||
                                                  fecha.isAfter(hoyColombia())
                                              ? hoyColombia()
                                              : fecha,
                                      firstDate: lunesKit(hoyColombia()),
                                      lastDate: hoyColombia(),
                                    );
                                    if (d != null && mounted) {
                                      setState(() {
                                        fecha = d;
                                        modificado = true;
                                      });
                                    }
                                  },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: lugar,
                          enabled: !ocupado,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Lugar de inspección (opcional)',
                            hintText: 'Sede, parqueadero o taller',
                          ),
                          onChanged: (_) => modificado = true,
                        ),
                      ],
                    ),
                    ConductorPanel(
                      title:
                          'B. Lista de inspección · ${catalogoKit.length} puntos',
                      children: [
                        const Text(
                          'Selecciona el estado de cada elemento. Si marcas Con novedad, describe el detalle. Deja el vencimiento vacío si el empaque no lo indica.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ConductorBadge('Buen estado: $buenos'),
                            ConductorBadge(
                              'Con novedad: $novedades',
                              warning: novedades > 0,
                            ),
                            ConductorBadge('No aplica: $noAplica'),
                            ConductorBadge(
                              'Pendientes: ${catalogoKit.length - respuestas.length}',
                              warning: respuestas.length < catalogoKit.length,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: respuestas.length / catalogoKit.length,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConductorPanel(
                          title: 'Categorías de revisión',
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final (i, nombre) in categorias.indexed)
                                  ChoiceChip(
                                    key: ValueKey('kit-categoria-$i'),
                                    label: Text(
                                      '${i + 1}. $nombre · ${catalogoKit.where((p) => p['categoria'] == nombre && respuestas.containsKey(p['nombre'])).length}/${catalogoKit.where((p) => p['categoria'] == nombre).length}',
                                    ),
                                    selected: categoria == i,
                                    onSelected:
                                        ocupado
                                            ? null
                                            : (_) =>
                                                setState(() => categoria = i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        ConductorPanel(
                          title: categorias[categoria],
                          children: [
                            if (categorias[categoria] == 'Señalización')
                              const Text(
                                'Revisa dos triángulos con soportes o las lámparas amarillas alternativas. Usa No aplica únicamente para la alternativa que no llevas.',
                              ),
                            for (final p in catalogoKit.where(
                              (p) => p['categoria'] == categorias[categoria],
                            ))
                              punto(p),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                      categoria > 0 && !ocupado
                                          ? () => setState(() => categoria--)
                                          : null,
                                  child: const Text('Anterior'),
                                ),
                                FilledButton(
                                  onPressed:
                                      categoria < categorias.length - 1 &&
                                              !ocupado
                                          ? () => setState(() => categoria++)
                                          : null,
                                  child: const Text('Siguiente categoría'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    ConductorPanel(
                      title: 'C. Observaciones generales',
                      children: [
                        TextField(
                          controller: notas,
                          enabled: !ocupado,
                          maxLength: 1000,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Recomendaciones, elementos faltantes o acciones correctivas...',
                          ),
                          onChanged: (_) => modificado = true,
                        ),
                      ],
                    ),
                    Text(
                      'Control interno de Grupo Quiromar. El artículo 30 de la Ley 769 de 2002 establece el equipo mínimo de carretera; no enumera estos ${catalogoKit.length} puntos. La sección 10 contiene elementos adicionales recomendados.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ConductorDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AvisoFormulario(error!),
                    ),
                  FilledButton.icon(
                    onPressed: ocupado ? null : guardar,
                    icon: const Icon(Icons.check),
                    label: Text(
                      guardando
                          ? 'Guardando revisión…'
                          : 'Guardar revisión semanal',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
