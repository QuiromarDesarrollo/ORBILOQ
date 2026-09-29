#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Fix: el contador 'Faltan X Uds' no se refrescaba al liberar (v49)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_refresco_contador_v49.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Aplicando el fix del refresco..."

echo "  - lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart"
mkdir -p "$(dirname 'lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart')"
cat > 'lib/features/aliados_no_conforme/presentation/aliados_no_conforme_dialog.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fecha.dart';
import '../../../domain/models.dart';
import '../../../domain/qr_prenda.dart';
import '../../../shared/widgets/addable_person_dropdown.dart';
import '../../../shared/widgets/feedback_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showAliadosNoConformeDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const AliadosNoConformeDialog());

class AliadosNoConformeDialog extends StatelessWidget {
  const AliadosNoConformeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WmsDialogShell(
      title: 'PRODUCTOS NO CONFORME DE ALIADOS',
      icon: Icons.handshake_outlined,
      iconColor: AppColors.primaryNavy,
      expand: true,
      maxWidth: 1000,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryNavy,
              labelPadding: EdgeInsets.symmetric(vertical: 4),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              tabs: [
                Tab(height: 38, icon: Icon(Icons.outbox_outlined, size: 16), text: 'ENVIAR A ALIADO'),
                Tab(height: 38, icon: Icon(Icons.hourglass_top_outlined, size: 16), text: 'PENDIENTES'),
                Tab(height: 38, icon: Icon(Icons.history, size: 16), text: 'HISTORIAL'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(children: [_EnviarTab(), _PendientesTab(), _HistorialTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CausalDropdownAliados extends ConsumerWidget {
  const _CausalDropdownAliados({required this.valor, required this.onChanged});

  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final causales = ref.watch(causalesProvider);
    return causales.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('No se pudieron cargar las causales: $e', style: const TextStyle(color: AppColors.alertRed)),
      data: (lista) => DropdownButtonFormField<String>(
        initialValue: valor,
        decoration: wmsInput('Causal de la no conformidad', icon: Icons.report_problem_outlined),
        items: [for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nombre))],
        onChanged: onChanged,
      ),
    );
  }
}

// ================================================================ pestaña 1: enviar

class _EnviarTab extends ConsumerStatefulWidget {
  const _EnviarTab();

  @override
  ConsumerState<_EnviarTab> createState() => _EnviarTabState();
}

class _EnviarTabState extends ConsumerState<_EnviarTab> {
  final _opCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  List<ItemKardex> _resultados = [];
  String? _errorBusqueda;
  ItemKardex? _seleccionado;
  String? _causalId;
  String? _personaAliado;
  String _operario = WmsConstantes.operarios.first;
  bool _enviando = false;
  FeedbackMessage? _msg;

  @override
  void dispose() {
    _opCtrl.dispose();
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  /// Reconoce si lo que se escribió/escaneó es un QR de prenda o un número
  /// de OP simple — misma lógica que ya usa Recepción.
  void _procesarEntrada(String raw) {
    final texto = raw.trim();
    final kardex = ref.read(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[];
    setState(() {
      _seleccionado = null;
      if (texto.isEmpty) {
        _errorBusqueda = 'Escanea una prenda o escribe un número de OP.';
        _resultados = [];
        return;
      }

      final qr = QrPrenda.tryParse(texto);
      if (qr != null) {
        final encontrado = kardex.where((k) => k.item.op == qr.op && k.item.codigo == qr.codigo).toList();
        if (encontrado.isEmpty) {
          _errorBusqueda = 'No se encontró esa prenda.';
          _resultados = [];
          return;
        }
        _resultados = encontrado;
        _errorBusqueda = null;
        _seleccionado = encontrado.first;
        return;
      }

      // No es un QR: se interpreta como número de OP. Esto es 100%
      // informativo — no depende de lo entregado ni de ningún otro número
      // del inventario, así que se puede reportar sobre cualquier OP/talla.
      _resultados = kardex.where((k) => k.item.op == texto).toList();
      _errorBusqueda = _resultados.isEmpty ? 'No se encontraron tallas para la OP $texto.' : null;
    });
  }

  Future<void> _enviar() async {
    final k = _seleccionado;
    if (k == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim());
    if (_causalId == null) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona una causal.'));
      return;
    }
    if (_personaAliado == null || _personaAliado!.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona a quién de Aliados se le entrega la prenda.'));
      return;
    }
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0.'));
      return;
    }

    setState(() {
      _enviando = true;
      _msg = null;
    });
    final res = await ref.read(wmsRepositoryProvider).enviarNoConformeAliado(
          itemId: k.id,
          cantidad: cantidad,
          causalId: _causalId!,
          operario: _operario,
          personaAliadoEntrega: _personaAliado!,
          nota: _notaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      switch (res) {
        case Ok():
          _msg = FeedbackMessage.ok('${cantidad}u de ${k.item.descripcion} (${k.item.talla}) enviadas a $_personaAliado.');
          _seleccionado = null;
          _causalId = null;
          _personaAliado = null;
          _cantidadCtrl.clear();
          _notaCtrl.clear();
          _resultados = [];
          _opCtrl.clear();
          ref.invalidate(noConformesAliadosProvider);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
          DropdownButtonFormField<String>(
            initialValue: _operario,
            decoration: wmsInput('Enviado por (Producción)', icon: Icons.person_outline),
            items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() => _operario = v ?? _operario),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opCtrl,
                  autofocus: true,
                  decoration: wmsInput('Escanear prenda o buscar por OP', icon: Icons.qr_code_scanner),
                  onSubmitted: (v) => _procesarEntrada(v),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _procesarEntrada(_opCtrl.text),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('BUSCAR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
          if (_errorBusqueda != null) ...[
            const SizedBox(height: 8),
            Text(_errorBusqueda!, style: const TextStyle(color: AppColors.alertRed)),
          ],
          if (_resultados.isNotEmpty && _seleccionado == null) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  for (final r in _resultados)
                    ListTile(
                      onTap: () => setState(() => _seleccionado = r),
                      leading: const Icon(Icons.checkroom, color: AppColors.primaryNavy),
                      title: Text('${r.item.codigo} — ${r.item.descripcion} (Talla ${r.item.talla})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('OP: ${r.item.op} | OC: ${r.item.oc}'),
                    ),
                ],
              ),
            ),
          ],
          if (_seleccionado != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OP: ${_seleccionado!.item.op} - ${_seleccionado!.item.descripcion} (${_seleccionado!.item.talla})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _seleccionado = null)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CausalDropdownAliados(valor: _causalId, onChanged: (v) => setState(() => _causalId = v)),
                    const SizedBox(height: 10),
                    AddablePersonDropdown(
                      label: 'A quién de Aliados se le entrega *',
                      valor: _personaAliado,
                      onChanged: (v) => setState(() => _personaAliado = v),
                      itemsProvider: personalAliadosProvider,
                      onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                      tituloDialogo: 'Agregar persona de Aliados',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: wmsInput('Cantidad a reportar'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _notaCtrl, decoration: wmsInput('Nota (opcional)', icon: Icons.notes)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: _enviando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.outbox_outlined, color: Colors.white, size: 20),
                        label: const Text('ENVIAR A ALIADO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================ pestaña 2: pendientes

class _PendientesTab extends ConsumerStatefulWidget {
  const _PendientesTab();

  @override
  ConsumerState<_PendientesTab> createState() => _PendientesTabState();
}

class _PendientesTabState extends ConsumerState<_PendientesTab> {
  final Map<String, String?> _personaMap = {};
  final Map<String, String> _operarioMap = {};
  final Map<String, TextEditingController> _cantidadCtrls = {};
  final Map<String, bool> _liberando = {};

  /// Solicitudes que se acaban de completar EN ESTA SESIÓN — se siguen
  /// mostrando aquí, en verde y sin controles, hasta que se cierre y se
  /// vuelva a abrir el diálogo (ahí ya solo viven en Historial).
  final Set<String> _recienCompletadas = {};
  FeedbackMessage? _msg;

  @override
  void dispose() {
    for (final c in _cantidadCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlPara(NoConformeAliado a) {
    return _cantidadCtrls.putIfAbsent(a.id, () => TextEditingController(text: '${a.cantidadPendiente}'));
  }

  Future<void> _liberar(NoConformeAliado a) async {
    final persona = _personaMap[a.id];
    if (persona == null || persona.trim().isEmpty) {
      setState(() => _msg = const FeedbackMessage.error('Selecciona quién de Aliados realizó la liberación.'));
      return;
    }
    final cantidad = int.tryParse(_ctrlPara(a).text.trim());
    if (cantidad == null || cantidad <= 0) {
      setState(() => _msg = const FeedbackMessage.error('Ingresa una cantidad mayor a 0 para liberar.'));
      return;
    }
    if (cantidad > a.cantidadPendiente) {
      setState(() => _msg =
          FeedbackMessage.error('LÍMITE EXCEDIDO: solo quedan ${a.cantidadPendiente} Uds pendientes por liberar.'));
      return;
    }

    setState(() {
      _msg = null;
      _liberando[a.id] = true;
    });
    final res = await ref.read(wmsRepositoryProvider).liberarNoConformeAliado(
          id: a.id,
          cantidad: cantidad,
          operario: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
          personaAliadoLibera: persona,
        );
    if (!mounted) return;
    setState(() {
      _liberando[a.id] = false;
      switch (res) {
        case Ok():
          final quedan = a.cantidadPendiente - cantidad;
          _msg = FeedbackMessage.ok(
            quedan > 0
                ? '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — quedan $quedan Uds pendientes.'
                : '${cantidad}u de ${a.item.descripcion} (${a.item.talla}) liberadas — solicitud completada.',
          );
          if (quedan <= 0) _recienCompletadas.add(a.id);
          _personaMap.remove(a.id);
          _cantidadCtrls.remove(a.id)?.dispose();
          // noConformesAliadosProvider/liberacionesAliadosProvider son
          // FutureProvider normales — a diferencia del kardex principal, no
          // se refrescan solos; hay que pedírselo explícitamente o el
          // contador de "Faltan X Uds" se queda con el valor viejo.
          ref.invalidate(noConformesAliadosProvider);
          ref.invalidate(liberacionesAliadosProvider);
        case Err(:final message):
          _msg = FeedbackMessage.error(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(noConformesAliadosProvider);
    return todas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.alertRed))),
      data: (lista) {
        // Pendientes de verdad + las que se acaban de completar en esta
        // sesión (para que se vean pasar por el estado verde antes de irse).
        final visibles = lista.where((a) => a.pendiente || _recienCompletadas.contains(a.id)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_msg != null) ...[FeedbackBanner(message: _msg!), const SizedBox(height: 12)],
            Expanded(
              child: visibles.isEmpty
                  ? const Center(child: Text('No hay envíos a Aliados pendientes por liberar.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (_, i) {
                        final a = visibles[i];
                        final completada = !a.pendiente;

                        if (completada) {
                          // Solo lectura: sin desplegables, sin campo de
                          // cantidad, sin botón — nada de esto se puede
                          // ajustar una vez completada.
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              color: Colors.green.shade50,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: AppColors.actionGreen, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.actionGreen, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                        ),
                                        const StatusChip(label: 'COMPLETADO', color: AppColors.actionGreen),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Liberado: ${a.cantidadLiberada} de ${a.cantidad} Uds | Causal: ${a.causal}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final parcial = a.cantidadLiberada > 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: Colors.amber.shade50,
                            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.amber.shade700), borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                      ),
                                      // Contador bien visible de lo que falta por liberar.
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade700,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Faltan ${a.cantidadPendiente} Uds',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    parcial
                                        ? 'Solicitado: ${a.cantidad} Uds | Ya liberado: ${a.cantidadLiberada} Uds | Causal: ${a.causal}'
                                        : '${a.cantidad} Uds | Causal: ${a.causal}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud} | ${formatFechaHora(a.fechaSolicitud)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  if (a.notaSolicitud.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                      child: Text('Nota: ${a.notaSolicitud}',
                                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    ),
                                  ],
                                  const Divider(),
                                  DropdownButtonFormField<String>(
                                    initialValue: _operarioMap[a.id] ?? WmsConstantes.operarios.first,
                                    decoration: wmsInput('Liberado por (Producción)', icon: Icons.person_outline),
                                    items: [for (final o in WmsConstantes.operarios) DropdownMenuItem(value: o, child: Text(o))],
                                    onChanged: (v) => setState(() => _operarioMap[a.id] = v ?? WmsConstantes.operarios.first),
                                  ),
                                  const SizedBox(height: 10),
                                  AddablePersonDropdown(
                                    label: 'Quién de Aliados liberó *',
                                    valor: _personaMap[a.id],
                                    onChanged: (v) => setState(() => _personaMap[a.id] = v),
                                    itemsProvider: personalAliadosProvider,
                                    onAgregar: (ref, nombre) => ref.read(wmsRepositoryProvider).agregarPersonalAliado(nombre),
                                    tituloDialogo: 'Agregar persona de Aliados',
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _ctrlPara(a),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: wmsInput('Cantidad a liberar (máx ${a.cantidadPendiente} Uds)'),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: (_liberando[a.id] ?? false) ? null : () => _liberar(a),
                                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      label: const Text('LIBERAR'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionGreen, foregroundColor: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}


// ============================================================ pestaña 3: historial

class _HistorialTab extends ConsumerWidget {
  const _HistorialTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudes = ref.watch(noConformesAliadosProvider);
    final liberaciones = ref.watch(liberacionesAliadosProvider);

    if (solicitudes.isLoading || liberaciones.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (solicitudes.hasError) {
      return Center(child: Text('Error: ${solicitudes.error}', style: const TextStyle(color: AppColors.alertRed)));
    }
    if (liberaciones.hasError) {
      return Center(child: Text('Error: ${liberaciones.error}', style: const TextStyle(color: AppColors.alertRed)));
    }

    final lista = solicitudes.requireValue;
    final todasLiberaciones = liberaciones.requireValue;

    if (lista.isEmpty) {
      return const Center(child: Text('Aún no hay solicitudes de Aliados.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final a = lista[i];
        final eventos = todasLiberaciones.where((l) => l.solicitudId == a.id).toList()
          ..sort((x, y) => x.fecha.compareTo(y.fecha)); // más antigua primero, orden natural de entrega
        return Card(
          color: a.pendiente ? Colors.amber.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('OP: ${a.item.op} - ${a.item.descripcion} (${a.item.talla})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                    ),
                    StatusChip(
                      label: a.pendiente ? 'PENDIENTE' : 'LIBERADO',
                      color: a.pendiente ? Colors.amber.shade800 : AppColors.actionGreen,
                    ),
                  ],
                ),
                Text('Solicitado: ${a.cantidad} Uds | Causal: ${a.causal}', style: const TextStyle(fontSize: 12)),
                Text(
                  'Entregado a: ${a.personaAliadoEntrega} | Enviado por: ${a.usuarioSolicitud} | ${formatFechaHora(a.fechaSolicitud)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (a.notaSolicitud.isNotEmpty)
                  Text('Nota: ${a.notaSolicitud}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                if (eventos.isNotEmpty) ...[
                  const Divider(),
                  for (final ev in eventos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(
                            label: ev.tipo == 'completa' ? 'ENTREGA COMPLETA' : 'ENTREGA PARCIAL',
                            color: ev.tipo == 'completa' ? AppColors.actionGreen : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ev.cantidad} Uds | ${ev.operario} ← ${ev.personaAliado} | ${formatFechaHora(ev.fecha)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze"
