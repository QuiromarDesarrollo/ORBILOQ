import 'package:orbiloq_wms/shared/widgets/wms_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/providers.dart';
import '../../../application/auth_providers.dart';
import '../../../data/catalogos_repository.dart';
import '../../../data/error_crear_usuario.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/wms_dialog.dart';

Future<void> showCatalogosDialog(BuildContext context) =>
    showWmsDialog<void>(context, (_) => const CatalogosDialog());
bool _admin(WidgetRef ref) =>
    !ref.read(usarSupabaseProvider) ||
    ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
String _errorTexto(Object e) => e is PostgrestException
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
  String _tipo = 'usuarios', _busqueda = '', _estado = 'Todos';
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
      setState(() => _error =
          'Conecta la aplicación a Supabase de pruebas para administrar los catálogos.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final filas = await repo.listar(_tipo);
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
        context, (_) => _EditorCatalogo(tipo: _tipo, fila: fila));
    if (ok == true && mounted) {
      ref.invalidate(causalesProvider);
      ref.invalidate(personalLogisticaProvider);
      ref.invalidate(personalProduccionProvider);
      ref.invalidate(personalAliadosProvider);
      ref.invalidate(ubicacionesProvider);
      if (ref.read(usarSupabaseProvider)) ref.invalidate(usuarioSesionProvider);
      await ref.read(wmsRepositoryProvider).refrescar();
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(usarSupabaseProvider) &&
        ref.watch(usuarioSesionProvider).value?.rolCuenta != RolCuenta.admin) {
      return const WmsDialogShell(title: 'Administración', icon: Icons.lock_outline,
        iconColor: Colors.teal, child: Text('Acceso exclusivo del administrador.'));
    }
    final visibles = _filas.where((f) {
      final activo = f['activo'] ?? f['activa'] ?? false;
      return (_estado == 'Todos' || activo == (_estado == 'Activos')) &&
          '${f['nombre'] ?? f['codigo']} ${f['numero_usuario'] ?? ''}'
              .toLowerCase()
              .contains(_busqueda.toLowerCase());
    }).toList();
    return WmsDialogShell(
        title: 'Administración de catálogos',
        icon: Icons.manage_accounts,
        iconColor: Colors.teal,
        expand: true,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
              initialValue: _tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Catálogo'),
              items: [
                for (final e in catalogosAdministrables.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value))
              ],
              onChanged: _cargando
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _tipo = v;
                          _filas = [];
                        });
                        _cargar();
                      }
                    }),
          const SizedBox(height: 8),
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o número',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _busqueda = v)),
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                    value: _estado,
                    items: [
                      for (final s in ['Todos', 'Activos', 'Inactivos'])
                        DropdownMenuItem(value: s, child: Text(s))
                    ],
                    onChanged: (v) => setState(() => _estado = v!)),
                OutlinedButton.icon(
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar')),
                FilledButton.icon(
                    onPressed: _cargando ||
                            !_admin(ref) ||
                            ref.watch(catalogosAdminProvider) == null
                        ? null
                        : () => _editar(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar')),
              ]),
          if (_cargando) const WmsLoadingStrip(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const Text(
              'Desactivar conserva los registros y su historial. Los nombres corregidos se usan en operaciones nuevas.'),
          Expanded(
              child: ListView.builder(
                  itemCount: visibles.length,
                  itemBuilder: (context, i) {
                    final f = visibles[i];
                    final activo = f['activo'] ?? f['activa'] ?? false;
                    return ListTile(
                        title: Text(f['nombre'] ?? f['codigo'] ?? ''),
                        subtitle: Text(
                            '${activo ? 'Activo' : 'Inactivo'}${_tipo == 'usuarios' ? ' · Usuario ${f['numero_usuario'] ?? 'sin número'} · ${f['rol']} · ${f['auth_id'] == null ? 'Sin cuenta de acceso' : 'Con acceso'}' : ''}'),
                        trailing: IconButton(
                            tooltip: 'Editar registro',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _cargando || !_admin(ref)
                                ? null
                                : () => _editar(f)));
                  })),
          Text('${visibles.length} registros'),
        ]));
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
      text: widget.fila?['nombre'] ?? widget.fila?['codigo'] ?? '');
  final _numero = TextEditingController(), _clave = TextEditingController();
  late bool _activo = widget.fila?['activo'] ?? widget.fila?['activa'] ?? true;
  late String _rol = widget.fila?['rol'] ?? 'produccion';
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
      setState(() => _error =
          'Indica un número de usuario y una contraseña de 12 a 128 caracteres.');
      return;
    }
    final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Confirmar cambios'),
                content: Text(
                    '${widget.fila == null ? 'Crear' : _activo ? 'Guardar' : 'Desactivar'} «${_nombre.text.trim()}»${_usuario ? ' con rol $_rol' : ''}. ${!_activo ? 'Dejará de estar disponible para operaciones nuevas. Se conserva el historial.' : ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirmar'))
                ]));
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
            _numero.text.trim(), _nombre.text.trim(), _rol, _clave.text);
      } else {
        await repo.guardar(
            widget.tipo, widget.fila, _nombre.text.trim(), _activo, _rol);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(recuperada
              ? 'Alta recuperada. Se conserva la contraseña del primer intento.'
              : 'Cambios guardados.')));
    } catch (e) {
      if (mounted) setState(() => _error = _errorTexto(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_ocupado,
      child: WmsDialogShell(
          title:
              '${widget.fila == null ? 'Agregar' : 'Editar'} · ${catalogosAdministrables[widget.tipo]}',
          icon: Icons.edit_note,
          iconColor: Colors.teal,
          canClose: !_ocupado,
          maxWidth: 620,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                controller: _nombre,
                enabled: !_ocupado,
                decoration: InputDecoration(
                    labelText: widget.tipo == 'ubicaciones'
                        ? 'Código del estante'
                        : 'Nombre')),
            if (_usuario && widget.fila == null) ...[
              TextField(
                  controller: _numero,
                  enabled: !_ocupado,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Número de usuario')),
              TextField(
                  controller: _clave,
                  enabled: !_ocupado,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                      labelText: 'Contraseña inicial (mínimo 12 caracteres)')),
            ],
            if (_usuario)
              DropdownButtonFormField<String>(
                  initialValue: _rol,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: [
                    for (final r in RolCuenta.values)
                      DropdownMenuItem(
                          value: r.valorBd, child: Text(r.etiqueta))
                  ],
                  onChanged:
                      _ocupado ? null : (v) => setState(() => _rol = v!)),
            if (!_usuario || widget.fila != null)
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _activo,
                  onChanged:
                      _ocupado ? null : (v) => setState(() => _activo = v)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_ocupado) const WmsLoadingStrip(),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _ocupado ? null : _guardar,
                child: const Text('Guardar cambios')),
          ])));
}
