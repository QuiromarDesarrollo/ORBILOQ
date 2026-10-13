import '../../../shared/widgets/wms_expandable_alert_dialog.dart';
import 'catalogo_tarjetas.dart';
import 'catalogo_form_widgets.dart';
import 'catalogo_tabla.dart';
import 'package:orbiloq_wms/shared/widgets/wms_alert.dart';
import '../../despacho/presentation/lista_empaque_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers.dart';
import '../../../application/auth_providers.dart';
import '../../../data/catalogos_repository.dart';
import '../../../data/empaques_repository.dart';
import 'empaque_editor.dart';
import '../../../data/error_crear_usuario.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showCatalogosDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const CatalogosDialog());
bool _admin(WidgetRef ref) =>
    !ref.read(usarSupabaseProvider) ||
    ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
String _errorTexto(Object e) =>
    e is PostgrestException
        ? e.message
        : e is FunctionException
        ? mensajeErrorCrearUsuario(e)
        : e is FormatException
        ? e.message.toString()
        : 'No se pudo completar la operación. Actualiza la lista antes de reintentar.';

class CatalogosDialog extends ConsumerStatefulWidget {
  const CatalogosDialog({super.key});
  @override
  ConsumerState<CatalogosDialog> createState() => _CatalogosState();
}

class _CatalogosState extends ConsumerState<CatalogosDialog> {
  final _selectorCatalogo = GlobalKey<FormFieldState<String>>();
  String _tipo = 'usuarios', _busqueda = '', _estado = 'Activos';
  List<Map<String, dynamic>> _filas = [];
  bool _cargando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!_admin(ref)) {
      setState(() => _error = 'Acceso exclusivo del administrador.');
      return;
    }
    final repo = ref.read(catalogosAdminProvider);
    if (repo == null) {
      setState(
        () =>
            _error =
                'Conecta la aplicación a Supabase de pruebas para administrar los catálogos.',
      );
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final filas =
          _tipo == 'empaques'
              ? await ref.read(empaquesRepositoryProvider)!.listar(todos: true)
              : await repo.listar(_tipo);
      if (mounted) setState(() => _filas = filas);
    } catch (e) {
      if (mounted) setState(() => _error = _errorTexto(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar(Map<String, dynamic>? fila) async {
    if (!_admin(ref)) return;
    final ok = await showWmsDialog<bool>(
      context,
      (_) =>
          _tipo == 'empaques'
              ? EmpaqueEditor(fila: fila)
              : _EditorCatalogo(tipo: _tipo, fila: fila),
    );
    if (ok == true && mounted) {
      ref.invalidate(causalesProvider);
      ref.invalidate(personalLogisticaProvider);
      ref.invalidate(personalProduccionProvider);
      ref.invalidate(personalAliadosProvider);
      ref.invalidate(ubicacionesProvider);
      if (ref.read(usarSupabaseProvider)) ref.invalidate(usuarioSesionProvider);
      await ref.read(wmsRepositoryProvider).refrescar().catchError((Object _) {
        /* El stream informa el fallo de recarga; no repetir lo ya guardado. */
      });
      await _cargar();
    }
  }

  Future<void> _eliminar(Map<String, dynamic> fila) async {
    if (_cargando || !_admin(ref)) return;
    final tipo = _tipo;
    final nombre =
        tipo == 'empaques'
            ? textoEmpaque(fila['nombre'])
            : '${fila['nombre'] ?? fila['codigo']}';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => WmsExpandableAlertDialog(
            icon: const Icon(Icons.block, color: Color(0xFFB42318), size: 36),
            title: Text('¿Desactivar a $nombre?'),
            content: Text(
              tipo == 'usuarios'
                  ? 'Ya no podrá iniciar sesión ni aparecerá al crear operaciones. Sus registros e historial se conservan y puedes reactivarlo desde la pestaña Inactivos.'
                  : 'Dejará de aparecer en operaciones nuevas. Sus registros e historial se conservan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  tipo == 'usuarios'
                      ? 'Desactivar usuario'
                      : 'Desactivar registro',
                ),
              ),
            ],
          ),
    );
    if (ok != true || !mounted || !_admin(ref)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (tipo == 'empaques') {
        await ref.read(empaquesRepositoryProvider)!.guardar({
          ...fila,
          'activo': false,
        }, fila);
      } else {
        await ref
            .read(catalogosAdminProvider)!
            .guardar(tipo, fila, nombre, false, fila['rol'] ?? 'produccion');
      }
      ref.invalidate(empaquesProvider);
      ref.invalidate(causalesProvider);
      ref.invalidate(personalLogisticaProvider);
      ref.invalidate(personalProduccionProvider);
      ref.invalidate(personalAliadosProvider);
      ref.invalidate(ubicacionesProvider);
      if (mounted) await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = _errorTexto(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(usarSupabaseProvider) &&
        ref.watch(usuarioSesionProvider).value?.rolCuenta != RolCuenta.admin) {
      return const WmsDialogShell(
        mobileCatalog: true,
        title: 'Administración',
        icon: Icons.lock_outline,
        iconColor: Colors.teal,
        child: Text('Acceso exclusivo del administrador.'),
      );
    }
    final visibles =
        _filas.where((f) {
          final activo = f['activo'] ?? f['activa'] ?? false;
          return (_estado == 'Todos' || activo == (_estado == 'Activos')) &&
              '${_tipo == 'empaques' ? textoEmpaque(f['nombre']) : f['nombre'] ?? f['codigo']} ${f['numero_usuario'] ?? ''} ${RolCuenta.etiquetas(f)} ${f['roles'] ?? f['rol'] ?? ''} ${textoEmpaque(f['categoria'])}'
                  .toLowerCase()
                  .contains(_busqueda.toLowerCase());
        }).toList();
    return WmsDialogShell(
      mobileCatalog: true,
      title:
          MediaQuery.sizeOf(context).width < 600
              ? 'Catálogos'
              : 'Administración de catálogos',
      subtitle:
          MediaQuery.sizeOf(context).width < 600
              ? null
              : 'Gestiona los registros que aparecen al crear operaciones.',
      maxWidth: 1080,
      icon: switch (_tipo) {
        'empaques' => Icons.inventory_2_outlined,
        'ubicaciones' => Icons.location_on_outlined,
        'causales_devolucion' => Icons.undo,
        'usuarios' => Icons.manage_accounts,
        _ => Icons.groups_outlined,
      },
      iconColor: Colors.teal,
      expand: true,
      footer:
          _tipo == 'destinatarios' || MediaQuery.sizeOf(context).width < 600
              ? null
              : Text(
                'Mostrando ${visibles.length} de ${_filas.length} registros',
                style: Theme.of(context).textTheme.bodySmall,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final catalogo = DropdownButtonFormField<String>(
                key: _selectorCatalogo,
                initialValue: _tipo,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      MediaQuery.sizeOf(context).width < 600
                          ? null
                          : 'Catálogo',
                ),
                items: [
                  for (final e in catalogosAdministrables.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                  DropdownMenuItem(
                    value: 'destinatarios',
                    enabled: ref.watch(usarSupabaseProvider),
                    child: const Text('Destinatarios'),
                  ),
                ],
                onChanged:
                    _cargando
                        ? null
                        : (v) {
                          if (v != null) {
                            setState(() {
                              _tipo = v;
                              _filas = [];
                            });
                            if (v != 'destinatarios') _cargar();
                          }
                        },
              );
              final buscar = TextField(
                decoration: InputDecoration(
                  hintText: switch (_tipo) {
                    'usuarios' => 'Nombre, número o perfil',
                    'empaques' => 'Nombre o categoría',
                    'ubicaciones' => 'Código de ubicación',
                    'causales_devolucion' => 'Nombre de la causal',
                    _ => 'Nombre de la persona',
                  },
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _busqueda = v),
              );
              if (_tipo == 'destinatarios') return catalogo;
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [catalogo, const SizedBox(height: 12), buscar],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 240, child: catalogo),
                  const SizedBox(width: 16),
                  Expanded(child: buscar),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (_tipo == 'destinatarios')
            const Expanded(
              child: ListaEmpaqueDialog(solicitud: '', integrado: true),
            )
          else ...[
            CatalogoToolbar(
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'Activos',
                      label: Text(
                        'Activos ${_filas.where((f) => (f['activo'] ?? f['activa']) == true).length}',
                      ),
                    ),
                    ButtonSegment(
                      value: 'Inactivos',
                      label: Text(
                        'Inactivos ${_filas.where((f) => (f['activo'] ?? f['activa']) != true).length}',
                      ),
                    ),
                    const ButtonSegment(value: 'Todos', label: Text('Todos')),
                  ],
                  selected: {_estado},
                  onSelectionChanged: (v) => setState(() => _estado = v.single),
                ),
                if (MediaQuery.sizeOf(context).width < 600)
                  IconButton.outlined(
                    tooltip: 'Actualizar',
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      MediaQuery.sizeOf(context).width < 600
                          ? ''
                          : 'Actualizar',
                    ),
                  ),
                FilledButton.icon(
                  onPressed:
                      _cargando ||
                              !_admin(ref) ||
                              ref.watch(catalogosAdminProvider) == null
                          ? null
                          : () => _editar(null),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Agregar ${catalogoSingular(_tipo).toLowerCase()}',
                  ),
                ),
              ],
            ),
            if (_cargando) const WmsLoadingStrip(),
            if (_error != null) AvisoFormulario(_error!),

            const SizedBox(height: 12),
            if (MediaQuery.sizeOf(context).width < 600)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${visibles.length} registros · ${_estado.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF57707C),
                  ),
                ),
              ),
            Expanded(
              child:
                  _tipo == 'usuarios'
                      ? UsuariosCatalogoTabla(
                        filas: visibles,
                        ocupado: _cargando,
                        onEditar: _editar,
                        onDesactivar: _eliminar,
                      )
                      : CatalogoTabla(
                        tipo: _tipo,
                        filas: visibles,
                        ocupado: _cargando,
                        onEditar: _editar,
                        onDesactivar: _eliminar,
                      ),
            ),
            const SizedBox(height: 12),
            if (MediaQuery.sizeOf(context).width >= 600)
              const Text(
                'Desactivar conserva los registros y su historial. Los nombres corregidos se usan en operaciones nuevas.',
                style: TextStyle(fontSize: 12, color: Color(0xFF57707C)),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EditorCatalogo extends ConsumerStatefulWidget {
  const _EditorCatalogo({required this.tipo, this.fila});
  final String tipo;
  final Map<String, dynamic>? fila;
  @override
  ConsumerState<_EditorCatalogo> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_EditorCatalogo> {
  late final _nombre = TextEditingController(
    text: widget.fila?['nombre'] ?? widget.fila?['codigo'] ?? '',
  );
  late final _numero = TextEditingController(
    text: widget.fila?['numero_usuario']?.toString() ?? '',
  );
  final _clave = TextEditingController();
  late bool _activo = widget.fila?['activo'] ?? widget.fila?['activa'] ?? true;
  late final Set<RolCuenta> _roles =
      widget.fila == null
          ? {RolCuenta.produccion}
          : RolCuenta.deFila(widget.fila!).toSet();
  List<String> get _valoresRoles =>
      RolCuenta.prioridad.where(_roles.contains).map((r) => r.valorBd).toList();
  String get _rol => _valoresRoles.firstOrNull ?? 'produccion';
  bool _ocupado = false;
  String? _error;
  bool get _usuario => widget.tipo == 'usuarios';
  @override
  void dispose() {
    _nombre.dispose();
    _numero.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_admin(ref) || _ocupado) return;
    if (_nombre.text.trim().isEmpty || _nombre.text.trim().length > 150) {
      setState(() => _error = 'Indica un nombre de 1 a 150 caracteres.');
      return;
    }
    if (_usuario &&
        widget.fila == null &&
        (!RegExp(r'^\d{1,30}$').hasMatch(_numero.text.trim()) ||
            _clave.text.length < 12 ||
            _clave.text.length > 128)) {
      setState(
        () =>
            _error =
                'Indica un número de usuario y una contraseña de 12 a 128 caracteres.',
      );
      return;
    }
    if (_usuario && _roles.isEmpty) {
      setState(() => _error = 'Selecciona al menos un perfil.');
      return;
    }
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => WmsExpandableAlertDialog(
            title: const Text('Confirmar cambios'),
            content: Text(
              '${widget.fila == null
                  ? 'Crear'
                  : _activo
                  ? 'Guardar'
                  : 'Desactivar'} «${_nombre.text.trim()}»${_usuario ? ' con perfiles ${RolCuenta.prioridad.where(_roles.contains).map((r) => r.etiqueta).join(', ')}' : ''}. ${!_activo ? 'Dejará de estar disponible para operaciones nuevas. Se conserva el historial.' : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
    if (confirmado != true || !mounted || !_admin(ref)) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final repo = ref.read(catalogosAdminProvider)!;
      bool recuperada = false;
      if (_usuario && widget.fila == null) {
        recuperada = await repo.crearUsuario(
          _numero.text.trim(),
          _nombre.text.trim(),
          _rol,
          _clave.text,
          roles: _valoresRoles,
        );
      } else {
        await repo.guardar(
          widget.tipo,
          widget.fila,
          _nombre.text.trim(),
          _activo,
          _rol,
          roles: _usuario ? _valoresRoles : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      mostrarAvisoSnack(
        context,
        SnackBar(
          content: Text(
            recuperada
                ? 'Alta recuperada. Se conserva la contraseña del primer intento.'
                : 'Cambios guardados.',
          ),
        ),
        tipo: TipoAviso.exito,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _errorTexto(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _formularioUsuario(BuildContext context) {
    final nuevo = widget.fila == null;
    final acceso = nuevo || (widget.fila?['auth_id'] != null && _activo);
    final numero = TextField(
      controller: _numero,
      enabled: !_ocupado && nuevo,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Número de usuario *',
        helperText:
            nuevo
                ? 'Único por usuario.'
                : 'Identificador de acceso. No editable.',
      ),
    );
    final perfil = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Perfiles *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Selecciona uno o varios. Sus permisos se combinan.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in RolCuenta.values)
              FilterChip(
                label: Text(r.etiqueta),
                selected: _roles.contains(r),
                onSelected:
                    _ocupado
                        ? null
                        : (v) => setState(() {
                          v ? _roles.add(r) : _roles.remove(r);
                        }),
              ),
          ],
        ),
        if (_roles.contains(RolCuenta.admin))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Administrador incluye acceso a todos los módulos.'),
          ),
      ],
    );
    return WmsDialogShell(
      mobileCatalog: true,
      title: nuevo ? 'Agregar usuario' : 'Editar usuario',
      subtitle:
          'Catálogo de usuarios${nuevo ? '' : ' · ${widget.fila?['nombre']}'}',
      footer: CatalogoActions(
        onSave: _ocupado ? null : _guardar,
        onCancel: _ocupado ? null : () => Navigator.pop(context),
        label: nuevo ? 'Crear usuario' : 'Guardar cambios',
      ),
      icon: Icons.person_outline,
      iconColor: const Color(0xFF093E52),
      maxWidth: 600,
      canClose: !_ocupado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nombre,
            enabled: !_ocupado,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              helperText: 'Así aparece en las operaciones nuevas.',
            ),
          ),
          const SizedBox(height: 20),
          numero,
          const SizedBox(height: 20),
          perfil,
          if (nuevo) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _clave,
              enabled: !_ocupado,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Contraseña inicial *',
                helperText: 'Entre 12 y 128 caracteres.',
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Acceso al sistema',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(acceso ? Icons.lock_open : Icons.lock_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acceso
                            ? 'Puede iniciar sesión'
                            : 'Sin acceso al sistema',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nuevo
                            ? 'Se creará una cuenta con los datos indicados.'
                            : 'Depende del estado activo y de la cuenta vinculada.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!nuevo) ...[
            const SizedBox(height: 24),
            CatalogoEstado(
              value: _activo,
              onChanged: _ocupado ? null : (v) => setState(() => _activo = v),
            ),
          ],
          if (_error != null) AvisoFormulario(_error!),
          if (_ocupado) const WmsLoadingStrip(label: 'Guardando usuario…'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child:
        _usuario
            ? _formularioUsuario(context)
            : WmsDialogShell(
              mobileCatalog: true,
              title:
                  '${widget.fila == null ? 'Agregar' : 'Editar'} ${catalogoSingular(widget.tipo)}',
              subtitle:
                  '${catalogosAdministrables[widget.tipo]}${widget.fila == null ? '' : ' · ${_nombre.text}'}',
              icon:
                  widget.tipo == 'ubicaciones'
                      ? Icons.location_on_outlined
                      : widget.tipo == 'causales_devolucion'
                      ? Icons.undo
                      : Icons.person_add_alt_1,
              iconColor: Theme.of(context).colorScheme.primary,
              maxWidth: 600,
              canClose: !_ocupado,
              footer: CatalogoActions(
                onSave: _ocupado ? null : _guardar,
                onCancel: _ocupado ? null : () => Navigator.pop(context),
                label:
                    widget.fila == null
                        ? 'Agregar ${catalogoSingular(widget.tipo)}'
                        : 'Guardar cambios',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nombre,
                    enabled: !_ocupado,
                    decoration: InputDecoration(
                      labelText:
                          widget.tipo == 'ubicaciones'
                              ? 'Código de ubicación *'
                              : widget.tipo == 'causales_devolucion'
                              ? 'Nombre de la causal *'
                              : 'Nombre completo *',
                      helperMaxLines: 3,
                      helperText:
                          widget.tipo == 'ubicaciones'
                              ? 'Como está marcado en la bodega. Ej.: Estante A1, Rack C3, Pasillo central.'
                              : widget.tipo == 'causales_devolucion'
                              ? 'Aparece como opción al registrar una devolución. Escríbela corta y clara.'
                              : 'Nombre y apellido, como lo reconoce el equipo en las operaciones.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  CatalogoEstado(
                    value: _activo,
                    onChanged:
                        _ocupado ? null : (v) => setState(() => _activo = v),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) AvisoFormulario(_error!),
                  if (_ocupado) const WmsLoadingStrip(),
                ],
              ),
            ),
  );
}

/// Tabla de usuarios con desplazamiento horizontal solo en pantallas estrechas.
class UsuariosCatalogoTabla extends StatelessWidget {
  const UsuariosCatalogoTabla({
    super.key,
    required this.filas,
    required this.ocupado,
    required this.onEditar,
    required this.onDesactivar,
  });
  final List<Map<String, dynamic>> filas;
  final bool ocupado;
  final ValueChanged<Map<String, dynamic>> onEditar, onDesactivar;

  Widget _etiqueta(String texto, Color color, Color fondo, IconData icono) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) {
      return const Center(child: Text('No hay usuarios con estos filtros.'));
    }
    return LayoutBuilder(
      builder:
          (context, c) =>
              c.maxWidth < 600
                  ? CatalogoTarjetas(
                    tipo: 'usuarios',
                    filas: filas,
                    ocupado: ocupado,
                    onEditar: onEditar,
                    onDesactivar: onDesactivar,
                  )
                  : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: c.maxWidth < 900 ? 900 : c.maxWidth,
                      height: c.maxHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Container(
                                color: const Color(0xFFF3F7F9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'NOMBRE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: .6,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'NÚMERO',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'PERFIL',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'ACCESO',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'ESTADO',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'ACCIONES',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: filas.length,
                                  separatorBuilder:
                                      (_, _) => const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Color(0xFFF0F4F6),
                                      ),
                                  itemBuilder: (context, i) {
                                    final f = filas[i];
                                    final activo = f['activo'] == true;
                                    final acceso =
                                        activo && f['auth_id'] != null;
                                    final nombre = '${f['nombre'] ?? ''}';
                                    final partes =
                                        nombre
                                            .trim()
                                            .split(RegExp(r'\s+'))
                                            .where((v) => v.isNotEmpty)
                                            .toList();
                                    final iniciales =
                                        partes
                                            .take(2)
                                            .map((p) => p.characters.first)
                                            .join()
                                            .toUpperCase();
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: const Color(
                                                    0xFFE3EDF1,
                                                  ),
                                                  child: Text(
                                                    iniciales,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF093E52),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    nombre,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${f['numero_usuario'] ?? '—'}',
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(RolCuenta.etiquetas(f)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _etiqueta(
                                                acceso
                                                    ? 'Con acceso'
                                                    : 'Sin acceso',
                                                acceso
                                                    ? const Color(0xFF2457A0)
                                                    : const Color(0xFF64748B),
                                                acceso
                                                    ? const Color(0xFFEDF3FF)
                                                    : const Color(0xFFF1F5F9),
                                                acceso
                                                    ? Icons.lock_open
                                                    : Icons.lock_outline,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _etiqueta(
                                                activo ? 'Activo' : 'Inactivo',
                                                activo
                                                    ? const Color(0xFF047857)
                                                    : const Color(0xFF64748B),
                                                activo
                                                    ? const Color(0xFFE6F4EE)
                                                    : const Color(0xFFF1F5F9),
                                                Icons.circle,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 100,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  tooltip: 'Editar $nombre',
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  onPressed:
                                                      ocupado
                                                          ? null
                                                          : () => onEditar(f),
                                                ),
                                                IconButton(
                                                  tooltip: 'Desactivar $nombre',
                                                  icon: const Icon(
                                                    Icons.block,
                                                    size: 18,
                                                  ),
                                                  color: const Color(
                                                    0xFFB42318,
                                                  ),
                                                  onPressed:
                                                      ocupado || !activo
                                                          ? null
                                                          : () =>
                                                              onDesactivar(f),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
