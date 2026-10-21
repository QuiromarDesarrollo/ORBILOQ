import '../../../shared/widgets/wms_loader.dart';
import '../../../shared/widgets/catalogo_ubicacion_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/auth_providers.dart';
import '../../../data/inventario_repository.dart';
import '../../../data/despachos_oc_repository.dart';
import '../../../data/excel_inventario.dart';
import '../../../data/excel_operativo_async.dart';
import '../../../domain/sesion.dart';
import '../../../shared/widgets/boton_plantilla_excel.dart';
import '../../../shared/widgets/wms_dialog.dart';

class ImportarInventarioDialog extends ConsumerStatefulWidget {
  const ImportarInventarioDialog({super.key});
  @override
  ConsumerState<ImportarInventarioDialog> createState() => _ImportarState();
}

class _ImportarState extends ConsumerState<ImportarInventarioDialog> {
  String? _nombre, _error;
  String _estante = '';
  List<Map<String, dynamic>> _filas = [];

  Future<void> _validarArchivo() async {
    _preview = null;
    _filas = [
      for (final fila in _archivo!['filas'] as List)
        {
          ...Map<String, dynamic>.from(fila as Map),
          'estante':
              '${fila['estante'] ?? ''}'.trim().isEmpty
                  ? _estante
                  : fila['estante'],
        },
    ];
    if (_filas.any((f) => '${f['estante']}'.trim().isEmpty)) {
      throw const FormatException(
        'Selecciona un estante predeterminado para las filas sin estante.',
      );
    }
    _solicitud = nuevaSolicitudDespacho();
    final repo = ref.read(inventarioRepositoryProvider);
    if (repo == null) {
      throw const FormatException('Conecta con la base de pruebas.');
    }
    _preview = Map<String, dynamic>.from(
      await repo
              .ejecutar('inventario_importar_excel', {
                'p_solicitud': _solicitud,
                'p_archivo': _nombre,
                'p_filas': _filas,
                'p_confirmar': false,
              })
              .timeout(const Duration(seconds: 30))
          as Map,
    );
  }

  Future<void> _cambiarEstante(String valor) async {
    if (_intentado || _ocupado) return;
    setState(() {
      _estante = valor;
      _preview = null;
      _error = null;
    });
    if (_archivo == null) return;
    setState(() => _ocupado = true);
    try {
      await _validarArchivo();
    } catch (e) {
      if (mounted) _error = e is PostgrestException ? e.message : '$e';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Map<String, dynamic>? _archivo, _preview;
  bool _ocupado = false, _intentado = false;
  String _solicitud = nuevaSolicitudDespacho();
  bool get _permitido {
    final user = ref.read(usuarioSesionProvider).valueOrNull;
    return user?.tieneRol(RolCuenta.admin) == true ||
        user?.tieneRol(RolCuenta.logistica) == true;
  }

  Future<void> _elegir() async {
    if (!_permitido || _ocupado || _intentado) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _archivo = null;
      _preview = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (picked == null) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        throw const FormatException('No se pudo leer el archivo.');
      }
      final archivo = await leerInventarioAsync(file.bytes!);
      if (!mounted) return;
      _nombre = file.name;
      _archivo = archivo;
      await _validarArchivo();
    } catch (e) {
      _error = e is PostgrestException ? e.message : '$e';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmar() async {
    if (!_permitido ||
        _ocupado ||
        _preview == null ||
        _preview!['repetido'] == true) {
      return;
    }
    setState(() {
      _ocupado = true;
      _intentado = true;
      _error = null;
    });
    try {
      final resultado = await ref
          .read(inventarioRepositoryProvider)!
          .ejecutar('inventario_importar_excel', {
            'p_solicitud': _solicitud,
            'p_archivo': _nombre,
            'p_filas': _filas,
            'p_confirmar': true,
          });
      if (mounted) {
        Navigator.pop(context, Map<String, dynamic>.from(resultado as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is PostgrestException
                      ? e.message
                      : 'No se pudo confirmar la respuesta. Reintenta la misma carga: no se sumará dos veces.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _paso(String numero, String titulo, String ayuda, Widget contenido) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0B3545),
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ayuda.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ayuda,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF627985),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  contenido,
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(usuarioSesionProvider);
    final filas = (_preview?['filas'] as List? ?? []);
    final confirmar = FilledButton.icon(
      onPressed:
          _ocupado ||
                  _preview == null ||
                  _preview!['repetido'] == true ||
                  !_permitido
              ? null
              : _confirmar,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0B3545),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      icon: const Icon(Icons.check_circle_outline, size: 19),
      label: Text(
        _ocupado
            ? 'Procesando…'
            : _intentado
            ? 'Reintentar misma carga'
            : 'Confirmar entrada de inventario',
      ),
    );
    final cancelar = OutlinedButton(
      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
      onPressed: _ocupado ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    );
    return PopScope(
      canPop: !_ocupado,
      child: WmsDialogShell(
        title: 'Entrada de inventario por Excel',
        subtitle: 'Se suma al stock · Sin OP de producción',
        icon: Icons.upload_file,
        iconColor: const Color(0xFF0B3545),
        expand: true,
        maxWidth: 1000,
        canClose: !_ocupado,
        footer: LayoutBuilder(
          builder: (context, size) {
            final estado = Text(
              _nombre ?? 'Ningún archivo seleccionado',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF627985)),
            );
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child:
                  size.maxWidth < 650
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          estado,
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [cancelar, confirmar],
                          ),
                        ],
                      )
                      : Row(
                        children: [
                          Expanded(child: estado),
                          const SizedBox(width: 16),
                          cancelar,
                          const SizedBox(width: 10),
                          confirmar,
                        ],
                      ),
            );
          },
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _paso(
                    '1',
                    'Descarga la plantilla',
                    'Llénala con tus prendas y guárdala como .xlsx.',
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButtonTheme(
                        data: OutlinedButtonThemeData(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0B3545),
                          ),
                        ),
                        child: BotonPlantillaExcel(
                          generar: () async => ExcelInventario.plantilla(),
                          nombre: 'inventario',
                          habilitado: !_ocupado,
                        ),
                      ),
                    ),
                  ),
                  _paso(
                    '2',
                    'Elige el estante predeterminado',
                    'Se usa cuando el archivo no trae la columna ESTANTE o la celda está vacía.',
                    IgnorePointer(
                      ignoring: _ocupado || _intentado,
                      child: CatalogoUbicacionDropdown(
                        label: 'Estante predeterminado',
                        value: _estante,
                        onChanged: _cambiarEstante,
                      ),
                    ),
                  ),
                  _paso(
                    '3',
                    'Sube el archivo',
                    '',
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCAD9DF)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.upload_file_outlined,
                              color: Color(0xFF0B3545),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _nombre == null
                                ? 'Selecciona tu archivo de inventario'
                                : _nombre!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _archivo == null
                                ? 'Formato .xlsx'
                                : 'Hoja: ${_archivo!['hoja']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF627985),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed:
                                _ocupado || _intentado || !_permitido
                                    ? null
                                    : _elegir,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC8DB00),
                              foregroundColor: const Color(0xFF0B3545),
                            ),
                            icon: const Icon(Icons.upload_file, size: 19),
                            label: const Text('Seleccionar Excel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF285887),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Las filas repetidas se suman por cliente, ficha, código, talla y estante. El archivo completo se valida antes de guardar.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF285887),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_ocupado)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: WmsLoadingStrip(
                        label: 'Procesando archivo de inventario…',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_preview?['repetido'] == true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Este contenido ya fue importado. No se volverá a sumar al inventario.',
                      ),
                    ),
                  if (filas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vista previa de la entrada',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_archivo!['filas_leidas']} filas leídas · ${filas.length} filas agrupadas · ${_preview!['unidades']} unidades por sumar',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: filas.length,
              itemBuilder: (_, i) {
                final r = filas[i] as Map;
                return Card(
                  elevation: 0,
                  color: const Color(0xFFF5F8F9),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${r['ficha']} · ${r['cliente']}'),
                    subtitle: Text(
                      '${r['codigo']} · ${r['descripcion']} · Talla ${r['talla']} · Estante ${r['estante']}',
                    ),
                    trailing: Text(
                      '+${r['cantidad']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF147347),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
