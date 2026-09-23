#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Login por numero de usuario + rol fijo por sesion (v16)
# Requiere haber corrido antes orbiloq_wms_auth.sql y vinculado los 3 auth_id.
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_login_v16.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando el sistema de login..."

echo "  - lib/domain/sesion.dart"
mkdir -p "$(dirname 'lib/domain/sesion.dart')"
cat > 'lib/domain/sesion.dart' << 'ORBILOQ_EOF'
/// El rol real de la cuenta con la que se inició sesión. Distinto de [Rol]
/// (que representa qué pantalla se está viendo): un Administrador puede ver
/// tanto la pantalla de Producción como la de Logística.
enum RolCuenta {
  produccion('produccion', 'Producción'),
  logistica('logistica', 'Logística'),
  admin('admin', 'Administrador');

  const RolCuenta(this.valorBd, this.etiqueta);
  final String valorBd;
  final String etiqueta;

  static RolCuenta? desde(String valor) {
    for (final r in RolCuenta.values) {
      if (r.valorBd == valor) return r;
    }
    return null;
  }
}

/// Datos de la persona que inició sesión (leídos de la tabla `usuarios`).
class UsuarioSesion {
  const UsuarioSesion({
    required this.numeroUsuario,
    required this.nombre,
    required this.rolCuenta,
  });

  final String numeroUsuario;
  final String nombre;
  final RolCuenta rolCuenta;
}
ORBILOQ_EOF

echo "  - lib/data/auth_repository.dart"
mkdir -p "$(dirname 'lib/data/auth_repository.dart')"
cat > 'lib/data/auth_repository.dart' << 'ORBILOQ_EOF'
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';

/// Traduce "número de usuario" a un correo sintético interno, porque
/// Supabase Auth solo entiende correo/contraseña. La persona nunca ve
/// ni escribe un correo — solo su número y su contraseña.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static String emailDesdeUsuario(String numeroUsuario) => '${numeroUsuario.trim()}@orbiloq.local';

  Future<Result<void>> iniciarSesion(String numeroUsuario, String contrasena) async {
    if (numeroUsuario.trim().isEmpty || contrasena.isEmpty) {
      return const Err<void>('Ingresa tu usuario y contraseña.');
    }
    try {
      await _client.auth.signInWithPassword(
        email: emailDesdeUsuario(numeroUsuario),
        password: contrasena,
      );
      return const Ok<void>(null);
    } on AuthException catch (e) {
      return Err<void>(_mensajeAmigable(e));
    } catch (e) {
      return Err<void>('No se pudo iniciar sesión: $e');
    }
  }

  String _mensajeAmigable(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials') || m.contains('invalid_credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }
    return e.message;
  }

  Future<void> cerrarSesion() => _client.auth.signOut();
}
ORBILOQ_EOF

echo "  - lib/application/auth_providers.dart"
mkdir -p "$(dirname 'lib/application/auth_providers.dart')"
cat > 'lib/application/auth_providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/sesion.dart';

/// `true` cuando la app está conectada a Supabase (vs. modo de datos de
/// prueba en memoria). Se sobrescribe en main.dart. En modo memoria no hay
/// login: el comportamiento libre de antes se mantiene para desarrollo.
final usarSupabaseProvider = Provider<bool>((ref) => false);

/// `null` en modo memoria; en modo Supabase, la implementación real.
final authRepositoryProvider = Provider<AuthRepository?>((ref) => null);

/// Emite cada cambio de sesión (inicio/cierre) en tiempo real. Solo se debe
/// observar cuando `usarSupabaseProvider` es true.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// La sesión actual con los datos de `usuarios` (rol, nombre) ya resueltos.
/// `null` si no hay nadie autenticado.
final usuarioSesionProvider = FutureProvider<UsuarioSesion?>((ref) async {
  // Observar el stream hace que este provider se vuelva a calcular en cada
  // inicio/cierre de sesión, sin necesidad de refrescar la página.
  ref.watch(authStateProvider);

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final fila = await Supabase.instance.client
      .from('usuarios')
      .select('numero_usuario, nombre, rol')
      .eq('auth_id', user.id)
      .maybeSingle();

  if (fila == null) return null;
  final rol = RolCuenta.desde(fila['rol'] as String);
  if (rol == null) return null;

  return UsuarioSesion(
    numeroUsuario: (fila['numero_usuario'] as String?) ?? '',
    nombre: fila['nombre'] as String,
    rolCuenta: rol,
  );
});
ORBILOQ_EOF

echo "  - lib/features/auth/presentation/login_page.dart"
mkdir -p "$(dirname 'lib/features/auth/presentation/login_page.dart')"
cat > 'lib/features/auth/presentation/login_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.errorInicial});

  final String? errorInicial;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usuarioCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _cargando = false;
  bool _verContrasena = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorInicial;
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      setState(() => _error = 'No hay conexión a la base de datos configurada.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    final res = await repo.iniciarSesion(_usuarioCtrl.text, _contrasenaCtrl.text);

    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (res is Err<void>) _error = (res as Err<void>).message;
      // Si fue Ok, el cambio de sesión lo detecta authStateProvider solo y
      // la app pasa a la pantalla principal automáticamente.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkCardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration:
                          BoxDecoration(color: AppColors.tealPrimary, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ORBILOQ WMS',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ingresa con tu usuario y contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration:
                          BoxDecoration(color: AppColors.chipRedBgDark, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.chipRedDark, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(color: AppColors.chipRedDark, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _usuarioCtrl,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.username],
                    style: const TextStyle(color: AppColors.darkTextPrimary),
                    decoration: _decoracion('Usuario', Icons.badge_outlined),
                    onSubmitted: (_) => _ingresar(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _contrasenaCtrl,
                    obscureText: !_verContrasena,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(color: AppColors.darkTextPrimary),
                    decoration: _decoracion('Contraseña', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_verContrasena ? Icons.visibility_off : Icons.visibility,
                            size: 18, color: AppColors.darkTextMuted),
                        onPressed: () => setState(() => _verContrasena = !_verContrasena),
                      ),
                    ),
                    onSubmitted: (_) => _ingresar(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _cargando ? null : _ingresar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _cargando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracion(String label, IconData icono) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        prefixIcon: Icon(icono, color: AppColors.darkTextMuted, size: 20),
        filled: true,
        fillColor: AppColors.darkInput,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkCardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkCardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tealAccent)),
      );
}
ORBILOQ_EOF

echo "  - lib/app.dart"
mkdir -p "$(dirname 'lib/app.dart')"
cat > 'lib/app.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/auth_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/kardex/presentation/kardex_page.dart';

class OrbiloqWmsApp extends ConsumerWidget {
  const OrbiloqWmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);

    return MaterialApp(
      title: 'ORBILOQ WMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // En modo de datos de prueba (sin Supabase configurado) no hay login:
      // se entra directo al kardex, igual que antes.
      home: usarSupabase ? const _PuertaDeEntrada() : const KardexPage(),
    );
  }
}

/// Decide entre la pantalla de login y el kardex según si hay una sesión
/// válida. Reacciona sola a inicios y cierres de sesión.
class _PuertaDeEntrada extends ConsumerWidget {
  const _PuertaDeEntrada();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(usuarioSesionProvider);
    return sesion.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.tealAccent)),
      ),
      error: (e, _) => LoginPage(errorInicial: 'Error verificando la sesión: $e'),
      data: (usuario) => usuario == null ? const LoginPage() : const KardexPage(),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/sesion.dart';
import '../domain/wms_repository.dart';
import 'auth_providers.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

// ------------------------------------------------------------------- rol

class RolNotifier extends Notifier<Rol> {
  @override
  Rol build() {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    if (!usarSupabase) return Rol.produccion; // modo memoria: sin login, libre como antes

    final sesion = ref.watch(usuarioSesionProvider).value;
    if (sesion == null) return Rol.produccion; // aún cargando / sin sesión
    return switch (sesion.rolCuenta) {
      RolCuenta.produccion => Rol.produccion,
      RolCuenta.logistica => Rol.logistica,
      RolCuenta.admin => Rol.produccion, // el admin arranca en Producción y puede cambiar
    };
  }

  void cambiar(Rol rol) {
    if (rol == state) return;
    if (ref.read(usarSupabaseProvider)) {
      final esAdmin = ref.read(usuarioSesionProvider).value?.rolCuenta == RolCuenta.admin;
      if (!esAdmin) return; // Producción/Logística no pueden cambiarse su propio rol
    }
    state = rol;
  }
}

final rolProvider = NotifierProvider<RolNotifier, Rol>(RolNotifier.new);

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setBusqueda(String v) => state = state.copyWith(busqueda: v);
  void setCliente(String? v) => state = state.copyWith(cliente: v);
  void setEstado(String? v) => state = state.copyWith(estado: v);
  void setOps(Set<String> v) => state = state.copyWith(ops: v);
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where(filtros.aplica).toList(growable: false);
});

final kardexResumenProvider = Provider<KardexResumen>((ref) {
  // Reacciona a lo que esté visible según los filtros activos.
  return KardexResumen.desde(ref.watch(kardexFiltradoProvider));
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  List<String> unicos(String Function(ItemKardex) f) => (kardex.map(f).toSet().toList()..sort());
  return OpcionesFiltro(
    clientes: unicos((i) => i.item.cliente),
    estados: unicos((i) => i.estadoEtiqueta),
    ops: unicos((i) => i.item.op),
  );
});

// ----------------------------------------------------------- paginación

const kardexFilasPorPagina = 25;

class KardexPaginaNotifier extends Notifier<int> {
  @override
  int build() {
    // Cualquier cambio en los filtros vuelve a la página 1, para no quedar
    // "perdido" en una página que ya no existe tras filtrar.
    ref.listen(kardexFiltersProvider, (_, __) => state = 0);
    return 0;
  }

  void ir(int pagina) => state = pagina;
}

final kardexPaginaProvider = NotifierProvider<KardexPaginaNotifier, int>(KardexPaginaNotifier.new);

final kardexPaginaActualProvider = Provider<List<ItemKardex>>((ref) {
  final filtrado = ref.watch(kardexFiltradoProvider);
  final pagina = ref.watch(kardexPaginaProvider);
  final desde = pagina * kardexFilasPorPagina;
  if (desde >= filtrado.length) return const [];
  final hasta = (desde + kardexFilasPorPagina).clamp(0, filtrado.length);
  return filtrado.sublist(desde, hasta);
});
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_page.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_page.dart')"
cat > 'lib/features/kardex/presentation/kardex_page.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/sesion.dart';
import '../../despacho/presentation/despacho_dialog.dart';
import '../../importacion/presentation/importar_ordenes_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../ubicaciones/presentation/ubicaciones_dialog.dart';
import 'kardex_filters_bar.dart';
import 'kardex_summary_cards.dart';
import 'kardex_table.dart';

class KardexPage extends ConsumerStatefulWidget {
  const KardexPage({super.key});

  @override
  ConsumerState<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends ConsumerState<KardexPage> {
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    await ref.read(wmsRepositoryProvider).refrescar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos sincronizados'),
        backgroundColor: AppColors.actionGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolProvider);
    final snapshot = ref.watch(wmsSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkHeader,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: AppColors.darkHeader,
        shape: const Border(bottom: BorderSide(color: AppColors.darkCardBorder)),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.tealPrimary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
                    children: [
                      TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.tealAccent),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkTextSecondary,
              side: const BorderSide(color: AppColors.darkCardBorder),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _sincronizando ? null : _sincronizar,
            icon: _sincronizando
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync, size: 18),
            label: Text(_sincronizando ? 'Sincronizando...' : 'Sincronizar BD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealPrimary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          _SelectorPerfil(rol: rol),
          const SizedBox(width: 20),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.tealAccent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: const TextStyle(color: AppColors.darkTextPrimary)),
        ),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.remisionesEnTransito),
              const SizedBox(height: 20),
              const KardexSummaryCards(),
              const SizedBox(height: 20),
              const KardexFiltersBar(),
              const SizedBox(height: 16),
              const KardexTable(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón-píldora "PERFIL DE TRABAJO" que abre un menú con los roles
/// disponibles. Solo muestra los 2 que funcionan hoy (Producción y Bodega).
class _SelectorPerfil extends ConsumerWidget {
  const _SelectorPerfil({required this.rol});

  final Rol rol;

  IconData _icono(Rol r) => r == Rol.produccion ? Icons.content_cut : Icons.warehouse_outlined;
  String _etiqueta(Rol r) => r == Rol.produccion ? 'Producción' : 'Bodega';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final sesion = usarSupabase ? ref.watch(usuarioSesionProvider).value : null;
    final esAdmin = !usarSupabase || sesion?.rolCuenta == RolCuenta.admin;

    final pastilla = esAdmin
        ? _pastillaDesplegable(context, ref)
        : _pastillaFija(sesion?.nombre ?? _etiqueta(rol));

    if (!usarSupabase) return pastilla; // modo memoria: sin sesión que cerrar

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pastilla,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, size: 18, color: AppColors.darkTextMuted),
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
        ),
      ],
    );
  }

  /// Producción o Logística: no pueden cambiar de rol, solo ven quiénes son.
  Widget _pastillaFija(String nombre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tealPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
          const SizedBox(width: 8),
          Text(nombre, style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Rol>(
      color: AppColors.darkCard,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.darkCardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        const PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkTextMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? AppColors.tealAccent : AppColors.darkTextSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? AppColors.tealAccent : AppColors.darkTextPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.tealAccent),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.tealPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icono(rol), size: 16, color: AppColors.tealAccent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.tealAccent),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.rol, required this.enTransito});

  final Rol rol;
  final int enTransito;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary),
            ),
            SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion)
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              )
            else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir remisión ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.local_shipping_outlined,
                texto: 'Despacho por orden',
                onPressed: () => showDespachoDialog(context),
              ),
              _BotonAccion(
                icono: Icons.domain_outlined,
                texto: 'Estantes y tickets',
                onPressed: () => showUbicacionesDialog(context),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icono, required this.texto, required this.onPressed});

  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.tealAccent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/main.dart"
mkdir -p "$(dirname 'lib/main.dart')"
cat > 'lib/main.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'application/auth_providers.dart';
import 'application/providers.dart';
import 'data/auth_repository.dart';
import 'data/in_memory_wms_repository.dart';
import 'data/supabase_importador_ordenes.dart';
import 'data/supabase_wms_repository.dart';

/// Credenciales de Supabase, pasadas al compilar con:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxxx
///
/// Si no se pasan (quedan vacías), la app arranca con datos de prueba en
/// memoria — útil para desarrollar la interfaz sin depender de la base real.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final usarSupabase = _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  if (usarSupabase) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        wmsRepositoryProvider.overrideWith((ref) {
          if (usarSupabase) {
            final repo = SupabaseWmsRepository(Supabase.instance.client);
            ref.onDispose(repo.dispose);
            return repo;
          }
          final repo = InMemoryWmsRepository.seeded();
          ref.onDispose(repo.dispose);
          return repo;
        }),
        importadorOrdenesProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return SupabaseImportadorOrdenes(Supabase.instance.client);
        }),
        usarSupabaseProvider.overrideWithValue(usarSupabase),
        authRepositoryProvider.overrideWith((ref) {
          if (!usarSupabase) return null;
          return AuthRepository(Supabase.instance.client);
        }),
      ],
      child: const OrbiloqWmsApp(),
    ),
  );
}
ORBILOQ_EOF

echo ""
echo "Listo. Siguiente paso:"
echo "  flutter analyze"
echo "  flutter test"
echo "  flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
