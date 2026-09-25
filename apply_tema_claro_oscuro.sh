#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Tema claro para el Kardex + interruptor claro/oscuro
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_tema_claro_oscuro.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi

echo "Aplicando tema claro + interruptor de tema..."

echo "  - lib/core/theme/app_theme.dart"
mkdir -p "$(dirname 'lib/core/theme/app_theme.dart')"
cat > 'lib/core/theme/app_theme.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryNavy = Color(0xFF173559);
  static const secondaryNavy = Color(0xFF1F436E);
  static const actionGreen = Color(0xFF2E8B57);
  static const actionOrange = Color(0xFFF37021);
  static const alertRed = Color(0xFFD32F2F);
  static const accentCyan = Color(0xFF00A8CC);
  static const background = Color(0xFFF4F6F9);

  // ---- Paleta del rediseño del Kardex (pantalla principal) ----
  static const tealPrimary = Color(0xFF0F766E);
  static const tealDark = Color(0xFF0B5750);
  static const tealSoft = Color(0xFFE6F4F2);
  static const slate900 = Color(0xFF0F172A);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate50 = Color(0xFFF8FAFC);
  static const cardBorder = Color(0xFFE5E9F0);
  static const amberChip = Color(0xFFB45309);
  static const amberChipBg = Color(0xFFFFF7ED);
  static const redChipBg = Color(0xFFFEF2F2);
  static const greenChipBg = Color(0xFFECFDF5);
  static const blueChipBg = Color(0xFFEFF6FF);
  static const blueChip = Color(0xFF1D4ED8);

  // ---- Paleta oscura (rediseño del Kardex, tema dark) ----
  static const darkBg = Color(0xFF0B1220);
  static const darkHeader = Color(0xFF0E1729);
  static const darkCard = Color(0xFF141B2D);
  static const darkCardBorder = Color(0xFF232D42);
  static const darkInput = Color(0xFF0F1729);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF8895AC);
  static const darkTextMuted = Color(0xFF5B6B85);
  static const tealAccent = Color(0xFF2DD4BF);
  static const chipRedBgDark = Color(0xFF3B1219);
  static const chipRedDark = Color(0xFFFCA5A5);
  static const chipGreenBgDark = Color(0xFF0F2E22);
  static const chipGreenDark = Color(0xFF6EE7B7);
  static const chipNeutralBgDark = Color(0xFF1B2438);
  static const chipNeutralDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryNavy),
        scaffoldBackgroundColor: AppColors.background,
      );

  /// Tema del Kardex (pantalla principal), en su variante oscura o clara,
  /// con [AppPalette] enganchada como [ThemeExtension] para que cualquier
  /// widget pueda leerla con `palOf(context)`.
  static ThemeData kardex(TemaModo modo) {
    final pal = modo == TemaModo.claro ? AppPalette.claro : AppPalette.oscuro;
    return ThemeData(
      useMaterial3: true,
      brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: pal.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealPrimary,
        brightness: modo == TemaModo.claro ? Brightness.light : Brightness.dark,
      ),
      extensions: [pal],
    );
  }
}

/// Modo de color de la pantalla del Kardex. No afecta el login ni ninguna
/// funcionalidad: solo cambia qué [AppPalette] se usa.
enum TemaModo { oscuro, claro }

/// Paleta de colores del Kardex, como [ThemeExtension]: cada widget la lee
/// con `palOf(context)` en vez de usar directamente `AppColors.darkXxx`, así
/// el mismo código sirve para el tema oscuro y el claro.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardBorder,
    required this.input,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.chipRedBg,
    required this.chipRed,
    required this.chipGreenBg,
    required this.chipGreen,
    required this.chipNeutralBg,
    required this.warning,
    required this.info,
  });

  final Color bg;
  final Color header;
  final Color card;
  final Color cardBorder;
  final Color input;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color chipRedBg;
  final Color chipRed;
  final Color chipGreenBg;
  final Color chipGreen;
  final Color chipNeutralBg;

  /// Color de advertencia (ámbar) para cifras/chips de atención, como
  /// "Producto no conforme" o "HOY". Distinto del rojo de alerta.
  final Color warning;

  /// Azul informativo, para cifras como "Recibido en bodega".
  final Color info;

  static const oscuro = AppPalette(
    bg: AppColors.darkBg,
    header: AppColors.darkHeader,
    card: AppColors.darkCard,
    cardBorder: AppColors.darkCardBorder,
    input: AppColors.darkInput,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    accent: AppColors.tealAccent,
    chipRedBg: AppColors.chipRedBgDark,
    chipRed: AppColors.chipRedDark,
    chipGreenBg: AppColors.chipGreenBgDark,
    chipGreen: AppColors.chipGreenDark,
    chipNeutralBg: AppColors.chipNeutralBgDark,
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
  );

  static const claro = AppPalette(
    bg: Color(0xFFF3F5F9),
    header: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardBorder: AppColors.slate200,
    input: Color(0xFFF8FAFC),
    textPrimary: AppColors.slate900,
    textSecondary: AppColors.slate600,
    textMuted: AppColors.slate400,
    accent: AppColors.tealPrimary,
    chipRedBg: AppColors.redChipBg,
    chipRed: Color(0xFFB91C1C),
    chipGreenBg: AppColors.greenChipBg,
    chipGreen: Color(0xFF047857),
    chipNeutralBg: Color(0xFFF1F5F9),
    warning: AppColors.amberChip,
    info: AppColors.blueChip,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? header,
    Color? card,
    Color? cardBorder,
    Color? input,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? chipRedBg,
    Color? chipRed,
    Color? chipGreenBg,
    Color? chipGreen,
    Color? chipNeutralBg,
    Color? warning,
    Color? info,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      header: header ?? this.header,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      input: input ?? this.input,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      chipRedBg: chipRedBg ?? this.chipRedBg,
      chipRed: chipRed ?? this.chipRed,
      chipGreenBg: chipGreenBg ?? this.chipGreenBg,
      chipGreen: chipGreen ?? this.chipGreen,
      chipNeutralBg: chipNeutralBg ?? this.chipNeutralBg,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      header: Color.lerp(header, other.header, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      input: Color.lerp(input, other.input, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      chipRedBg: Color.lerp(chipRedBg, other.chipRedBg, t)!,
      chipRed: Color.lerp(chipRed, other.chipRed, t)!,
      chipGreenBg: Color.lerp(chipGreenBg, other.chipGreenBg, t)!,
      chipGreen: Color.lerp(chipGreen, other.chipGreen, t)!,
      chipNeutralBg: Color.lerp(chipNeutralBg, other.chipNeutralBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Atajo para leer la paleta activa desde cualquier widget con [context].
AppPalette palOf(BuildContext context) => Theme.of(context).extension<AppPalette>() ?? AppPalette.oscuro;

/// Decoración estándar de campos de texto.
InputDecoration wmsInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}
ORBILOQ_EOF

echo "  - lib/application/providers.dart"
mkdir -p "$(dirname 'lib/application/providers.dart')"
cat > 'lib/application/providers.dart' << 'ORBILOQ_EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/supabase_importador_fechas.dart';
import '../data/supabase_importador_ordenes.dart';
import '../domain/models.dart';
import '../domain/sesion.dart';
import '../domain/wms_repository.dart';
import 'auth_providers.dart';
import 'kardex_columnas.dart';
import 'kardex_filters.dart';

/// Debe sobrescribirse en `main.dart` (o en tests) con la implementación deseada.
final wmsRepositoryProvider = Provider<WmsRepository>(
  (ref) => throw UnimplementedError('Sobrescribe wmsRepositoryProvider en main.dart'),
);

/// Solo disponible cuando la app corre contra Supabase; `null` en modo memoria
/// (la importación de Excel no tiene sentido sin una base de datos real detrás).
final importadorOrdenesProvider = Provider<SupabaseImportadorOrdenes?>((ref) => null);

/// Igual, para el Excel de fechas esperadas.
final importadorFechasProvider = Provider<SupabaseImportadorFechas?>((ref) => null);

final wmsSnapshotProvider = StreamProvider<WmsSnapshot>(
  (ref) => ref.watch(wmsRepositoryProvider).watch(),
);

final kardexProvider = Provider<List<ItemKardex>>(
  (ref) => ref.watch(wmsSnapshotProvider).value?.kardex ?? const <ItemKardex>[],
);

/// Causales disponibles para reportar un producto como no conforme.
final causalesProvider = FutureProvider<List<Causal>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarCausales(),
);

/// Lista ampliable de personas de Logística que pueden recibir una prenda
/// liberada por Producción. Se invalida tras agregar un nombre nuevo.
final personalLogisticaProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarPersonalLogistica(),
);

/// Lista ampliable de personas de Producción que pueden entregar una prenda
/// no conforme a Logística. Se invalida tras agregar un nombre nuevo.
final personalProduccionProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wmsRepositoryProvider).cargarPersonalProduccion(),
);

// ------------------------------------------------------------------ tema

/// Modo de color de la pantalla del Kardex (oscuro/claro). Solo cambia el
/// estilo visual, no afecta ninguna funcionalidad. Arranca en oscuro, el
/// tema de siempre.
class TemaNotifier extends Notifier<TemaModo> {
  @override
  TemaModo build() => TemaModo.oscuro;

  void alternar() => state = state == TemaModo.oscuro ? TemaModo.claro : TemaModo.oscuro;
}

final temaProvider = NotifierProvider<TemaNotifier, TemaModo>(TemaNotifier.new);

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

/// El mapa de "columna -> valor" que le corresponde a la vista actual.
final extractoresColumnaProvider = Provider<Map<String, ExtractorColumna>>((ref) {
  final rol = ref.watch(rolProvider);
  return rol == Rol.produccion ? columnasProduccion : columnasBodega;
});

// --------------------------------------------------------------- filtros

class KardexFiltersNotifier extends Notifier<KardexFilters> {
  @override
  KardexFilters build() => const KardexFilters();

  void setBusqueda(String v) => state = state.conBusqueda(v);
  void setColumna(String columna, Set<String> valores) => state = state.conColumna(columna, valores);
  void limpiar() => state = const KardexFilters();
}

final kardexFiltersProvider =
    NotifierProvider<KardexFiltersNotifier, KardexFilters>(KardexFiltersNotifier.new);

final kardexFiltradoProvider = Provider<List<ItemKardex>>((ref) {
  final kardex = ref.watch(kardexProvider);
  final filtros = ref.watch(kardexFiltersProvider);
  final extractores = ref.watch(extractoresColumnaProvider);
  if (!filtros.hayFiltros) return kardex;
  return kardex.where((i) => filtros.aplica(i, extractores)).toList(growable: false);
});

final kardexResumenProvider = Provider<KardexResumen>((ref) {
  // Reacciona a lo que esté visible según los filtros activos.
  return KardexResumen.desde(ref.watch(kardexFiltradoProvider));
});

final opcionesFiltroProvider = Provider<OpcionesFiltro>((ref) {
  final kardex = ref.watch(kardexProvider);
  final extractores = ref.watch(extractoresColumnaProvider);
  final porColumna = <String, List<String>>{};
  for (final entry in extractores.entries) {
    porColumna[entry.key] = (kardex.map(entry.value).toSet().toList()..sort());
  }
  return OpcionesFiltro(porColumna);
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

echo "  - lib/app.dart"
mkdir -p "$(dirname 'lib/app.dart')"
cat > 'lib/app.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/auth_providers.dart';
import 'application/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/kardex/presentation/kardex_page.dart';

class OrbiloqWmsApp extends ConsumerWidget {
  const OrbiloqWmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usarSupabase = ref.watch(usarSupabaseProvider);
    final modoTema = ref.watch(temaProvider);

    return MaterialApp(
      title: 'ORBILOQ WMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.kardex(modoTema),
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
    final pal = palOf(context);
    return sesion.when(
      loading: () => Scaffold(
        backgroundColor: pal.bg,
        body: Center(child: CircularProgressIndicator(color: pal.accent)),
      ),
      error: (e, _) => LoginPage(errorInicial: 'Error verificando la sesión: $e'),
      data: (usuario) => usuario == null ? const LoginPage() : const KardexPage(),
    );
  }
}
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
import '../../importacion_fechas/presentation/importar_fechas_dialog.dart';
import '../../no_conforme/presentation/no_conforme_dialog.dart';
import '../../produccion/presentation/entrega_produccion_dialog.dart';
import '../../recepcion/presentation/recepcion_dialog.dart';
import '../../reproceso/presentation/reproceso_dialog.dart';
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
    final pal = palOf(context);
    final modoTema = ref.watch(temaProvider);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.header,
        foregroundColor: pal.textPrimary,
        elevation: 0,
        toolbarHeight: 72,
        surfaceTintColor: pal.header,
        shape: Border(bottom: BorderSide(color: pal.cardBorder)),
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
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pal.textPrimary),
                    children: [
                      const TextSpan(text: 'ORBILOQ '),
                      TextSpan(
                        text: '| KARDEX MAESTRO',
                        style: TextStyle(fontWeight: FontWeight.w500, color: pal.accent),
                      ),
                    ],
                  ),
                ),
                Text(
                  'CONTROL OPERATIVO DE BODEGA Y PRODUCCIÓN',
                  style: TextStyle(fontSize: 10, color: pal.textMuted, letterSpacing: 0.4),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: modoTema == TemaModo.claro ? 'Cambiar a tema oscuro' : 'Cambiar a tema claro',
            onPressed: () => ref.read(temaProvider.notifier).alternar(),
            icon: Icon(
              modoTema == TemaModo.claro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: () => showImportarOrdenesDialog(context),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Importar Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.textSecondary,
              side: BorderSide(color: pal.cardBorder),
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
        loading: () => Center(child: CircularProgressIndicator(color: pal.accent)),
        error: (e, _) => Center(
          child: Text('Error cargando datos: $e', style: TextStyle(color: pal.textPrimary)),
        ),
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(rol: rol, enTransito: s.lotesConPendientes),
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
    final pal = palOf(context);

    final pastilla = esAdmin
        ? _pastillaDesplegable(context, ref, pal)
        : _pastillaFija(sesion?.nombre ?? _etiqueta(rol), pal);

    if (!usarSupabase) return pastilla; // modo memoria: sin sesión que cerrar

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pastilla,
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: Icon(Icons.logout, size: 18, color: pal.textMuted),
          onPressed: () => ref.read(authRepositoryProvider)?.cerrarSesion(),
        ),
      ],
    );
  }

  /// Producción o Logística: no pueden cambiar de rol, solo ven quiénes son.
  Widget _pastillaFija(String nombre, AppPalette pal) {
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
          Icon(_icono(rol), size: 16, color: pal.accent),
          const SizedBox(width: 8),
          Text(nombre, style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Administrador (o modo memoria sin login): puede alternar entre vistas.
  Widget _pastillaDesplegable(BuildContext context, WidgetRef ref, AppPalette pal) {
    return PopupMenuButton<Rol>(
      color: pal.card,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: pal.cardBorder),
      ),
      onSelected: (r) => ref.read(rolProvider.notifier).cambiar(r),
      itemBuilder: (context) => [
        PopupMenuItem<Rol>(
          enabled: false,
          height: 32,
          child: Text(
            'PERFIL DE TRABAJO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pal.textMuted, letterSpacing: 0.5),
          ),
        ),
        for (final r in Rol.values)
          PopupMenuItem<Rol>(
            value: r,
            child: Row(
              children: [
                Icon(_icono(r), size: 18, color: r == rol ? pal.accent : pal.textSecondary),
                const SizedBox(width: 10),
                Text(_etiqueta(r),
                    style: TextStyle(
                      color: r == rol ? pal.accent : pal.textPrimary,
                      fontWeight: r == rol ? FontWeight.bold : FontWeight.normal,
                    )),
                if (r == rol) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16, color: pal.accent),
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
            Icon(_icono(rol), size: 16, color: pal.accent),
            const SizedBox(width: 8),
            Text(_etiqueta(rol),
                style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: pal.accent),
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
    final pal = palOf(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Órdenes activas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pal.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Producción, bodega y despachos en un solo tablero',
              style: TextStyle(fontSize: 13, color: pal.textSecondary),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (rol == Rol.produccion) ...[
              _BotonAccion(
                icono: Icons.history,
                texto: 'Entregar lote y ver historial',
                onPressed: () => showEntregaProduccionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Productos no conforme',
                onPressed: () => showReprocesoDialog(context),
              ),
            ] else ...[
              _BotonAccion(
                icono: Icons.move_to_inbox_outlined,
                texto: 'Recibir lote ($enTransito)',
                onPressed: () => showRecepcionDialog(context),
              ),
              _BotonAccion(
                icono: Icons.report_gmailerrorred_outlined,
                texto: 'Producto no conforme',
                onPressed: () => showNoConformeDialog(context),
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
              _BotonAccion(
                icono: Icons.event_available_outlined,
                texto: 'Importar fechas',
                onPressed: () => showImportarFechasDialog(context),
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
        foregroundColor: palOf(context).accent,
        side: const BorderSide(color: AppColors.tealPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_filters_bar.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_filters_bar.dart')"
cat > 'lib/features/kardex/presentation/kardex_filters_bar.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

/// Barra de filtros: búsqueda libre + cliente + estado (tema oscuro).
class KardexFiltersBar extends ConsumerStatefulWidget {
  const KardexFiltersBar({super.key});

  @override
  ConsumerState<KardexFiltersBar> createState() => _KardexFiltersBarState();
}

class _KardexFiltersBarState extends ConsumerState<KardexFiltersBar> {
  late final TextEditingController _busquedaCtrl;

  @override
  void initState() {
    super.initState();
    _busquedaCtrl = TextEditingController(text: ref.read(kardexFiltersProvider).busqueda);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final notifier = ref.read(kardexFiltersProvider.notifier);
    final rol = ref.watch(rolProvider);
    final colEstado = rol == Rol.produccion ? ColKardex.estadoProduccion : ColKardex.estadoBodega;
    final pal = palOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final estrecho = constraints.maxWidth < 760;
          final campos = <Widget>[
            SizedBox(
              width: estrecho ? double.infinity : 320,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: notifier.setBusqueda,
                style: TextStyle(color: pal.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por OP, cliente, OC o producto',
                  hintStyle: TextStyle(color: pal.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 20, color: pal.textMuted),
                  filled: true,
                  fillColor: pal.input,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: pal.accent),
                  ),
                ),
              ),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 200,
              etiquetaTodos: 'Todos los clientes',
              valor: filtros.valoresDe(ColKardex.cliente).firstOrNull,
              opciones: opciones.de(ColKardex.cliente),
              onChanged: (v) => notifier.setColumna(ColKardex.cliente, v == null ? {} : {v}),
            ),
            _Desplegable(
              ancho: estrecho ? double.infinity : 190,
              etiquetaTodos: 'Todos los estados',
              valor: filtros.valoresDe(colEstado).firstOrNull,
              opciones: opciones.de(colEstado),
              onChanged: (v) => notifier.setColumna(colEstado, v == null ? {} : {v}),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _busquedaCtrl.clear();
                notifier.limpiar();
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Limpiar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: pal.textSecondary,
                side: BorderSide(color: pal.cardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ];

          return Wrap(spacing: 12, runSpacing: 12, children: campos);
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.ancho,
    required this.etiquetaTodos,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final double ancho;
  final String etiquetaTodos;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return SizedBox(
      width: ancho,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pal.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pal.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            isDense: true,
            value: valor,
            dropdownColor: pal.card,
            hint: Text(etiquetaTodos, style: TextStyle(fontSize: 13, color: pal.textSecondary)),
            icon: Icon(Icons.expand_more, size: 18, color: pal.textMuted),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(etiquetaTodos, style: TextStyle(fontSize: 13, color: pal.textPrimary)),
              ),
              for (final o in opciones)
                DropdownMenuItem<String?>(
                  value: o,
                  child: Text(o, style: TextStyle(fontSize: 13, color: pal.textPrimary), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_summary_cards.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_summary_cards.dart')"
cat > 'lib/features/kardex/presentation/kardex_summary_cards.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';

class KardexSummaryCards extends ConsumerWidget {
  const KardexSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(kardexResumenProvider);
    final esProduccion = ref.watch(rolProvider) == Rol.produccion;
    final pal = palOf(context);

    final tarjetas = <_SummaryCard>[
      _SummaryCard(
        titulo: 'UNIDADES PEDIDAS',
        valor: '${r.unidadesPedidas}',
        subtitulo: '+${r.cantidadOrdenes} órdenes',
        subtituloColor: pal.textSecondary,
        icono: Icons.bar_chart_rounded,
        acento: AppColors.tealPrimary,
      ),
      _SummaryCard(
        titulo: esProduccion ? 'ENTREGADO A LOGÍSTICA' : 'ENTREGADO POR PRODUCCIÓN',
        valor: '${r.enProduccion}',
        subtitulo: '${r.porcentajeProduccion.toStringAsFixed(1)}% del total',
        subtituloColor: pal.textSecondary,
        icono: Icons.autorenew_rounded,
        acento: AppColors.blueChip,
      ),
      _SummaryCard(
        titulo: esProduccion ? 'PENDIENTE POR ENTREGAR' : 'PENDIENTE POR PRODUCCIÓN',
        valor: '${r.pendientePorEntregar}',
        subtitulo: r.pendientePorEntregar > 0 ? 'Requiere seguimiento' : 'Al día',
        subtituloColor: r.pendientePorEntregar > 0 ? pal.chipRed : pal.chipGreen,
        icono: Icons.local_shipping_rounded,
        acento: AppColors.actionOrange,
      ),
      _SummaryCard(
        titulo: 'PRODUCTO NO CONFORME',
        valor: '${r.totalNoConforme}',
        subtitulo: r.totalNoConforme > 0 ? 'Pendiente por reprocesar' : 'Al día',
        subtituloColor: r.totalNoConforme > 0 ? pal.chipRed : pal.chipGreen,
        icono: Icons.report_problem_rounded,
        acento: AppColors.alertRed,
      ),
      if (!esProduccion) ...[
        _SummaryCard(
          titulo: 'RECIBIDO EN BODEGA',
          valor: '${r.recibidoEnBodega}',
          subtitulo: '${r.porcentajeBodega.toStringAsFixed(1)}% del total',
          subtituloColor: pal.textSecondary,
          icono: Icons.warehouse_rounded,
          acento: AppColors.actionGreen,
        ),
        _SummaryCard(
          titulo: 'PENDIENTE POR DESPACHAR',
          valor: '${r.pendientePorDespachar}',
          subtitulo: r.pendientePorDespachar > 0 ? 'Requiere seguimiento' : 'Al día',
          subtituloColor: r.pendientePorDespachar > 0 ? pal.chipRed : pal.chipGreen,
          icono: Icons.inventory_2_rounded,
          acento: AppColors.accentCyan,
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final n = tarjetas.length;
        final anchoTarjeta = constraints.maxWidth >= 900
            ? (constraints.maxWidth - (n - 1) * 16) / n
            : constraints.maxWidth >= 500
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final t in tarjetas) SizedBox(width: anchoTarjeta, child: t)],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.subtituloColor,
    required this.icono,
    required this.acento,
  });

  final String titulo;
  final String valor;
  final String subtitulo;
  final Color subtituloColor;
  final IconData icono;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: acento.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icono, size: 16, color: acento),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: pal.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 12, color: subtituloColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "  - lib/features/kardex/presentation/kardex_table.dart"
mkdir -p "$(dirname 'lib/features/kardex/presentation/kardex_table.dart')"
cat > 'lib/features/kardex/presentation/kardex_table.dart' << 'ORBILOQ_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/kardex_filters.dart';
import '../../../application/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/multi_select_filter.dart';
import 'observacion_dialog.dart';

// Columnas para el rol Producción (Taller). Todas tienen filtro por columna.
const List<double> _kAnchosProduccion = [100, 160, 150, 95, 140, 95, 140, 170, 110, 110, 115];
const List<String> _kEtiquetasProduccion = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'CANTIDAD',
  'ENTREGADO A LOGÍSTICA', 'PENDIENTE', 'PRODUCTO NO CONFORME',
  'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA', 'DÍAS FALTANTES',
];
// A qué columna de filtro corresponde cada encabezado de Producción (por
// índice). `null` = sin filtro en esa columna.
const List<String?> _kColumnasProduccion = [
  ColKardex.op, ColKardex.producto, ColKardex.cliente, ColKardex.cantidad,
  ColKardex.entregado, ColKardex.pendiente, ColKardex.noConforme,
  ColKardex.estadoProduccion, ColKardex.fechaEntrega, ColKardex.fechaEsperada, ColKardex.diasFaltantes,
];

// Columnas para el rol Logística (Bodega). Todas tienen filtro por columna.
const List<double> _kAnchosBodega = [100, 150, 150, 90, 135, 135, 85, 120, 120, 95, 100, 100, 105];
const List<String> _kEtiquetasBodega = [
  'OP / OBS.', 'PRODUCTO', 'CLIENTE / OC', 'PEDIDAS',
  'ENTREGADO POR PRODUCCIÓN', 'PENDIENTE POR PRODUCCIÓN', 'BODEGA', 'DESPACHADAS',
  'PRODUCTO NO CONFORME', 'ESTADOS', 'FECHA DE ENTREGA', 'FECHA ESPERADA', 'DÍAS FALTANTES',
];
const List<String?> _kColumnasBodega = [
  ColKardex.op, ColKardex.producto, ColKardex.cliente, ColKardex.pedidas,
  ColKardex.produccion, ColKardex.pendienteProduccionBodega, ColKardex.bodega, ColKardex.despachadas,
  ColKardex.noConformeBodega, ColKardex.estadoBodega, ColKardex.fechaEntregaBodega,
  ColKardex.fechaEsperadaBodega, ColKardex.diasFaltantesBodega,
];

const _kPaletaProducto = [
  Color(0xFF2DD4BF), Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFFFBBF24),
  Color(0xFFF472B6), Color(0xFFFB923C), Color(0xFF34D399), Color(0xFF94A3B8),
];

Color _colorProducto(String codigo) => _kPaletaProducto[codigo.hashCode.abs() % _kPaletaProducto.length];

const _mesesEs = [
  '', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
String _fechaCorta(DateTime d) => '${d.day} ${_mesesEs[d.month]}';

/// Tabla del kardex, paginada, con columnas distintas según el rol.
class KardexTable extends ConsumerWidget {
  const KardexTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(kardexPaginaActualProvider);
    final total = ref.watch(kardexFiltradoProvider).length;
    final pagina = ref.watch(kardexPaginaProvider);
    final rol = ref.watch(rolProvider);
    final esProduccion = rol == Rol.produccion;
    final anchos = esProduccion ? _kAnchosProduccion : _kAnchosBodega;
    final etiquetas = esProduccion ? _kEtiquetasProduccion : _kEtiquetasBodega;
    final columnas = esProduccion ? _kColumnasProduccion : _kColumnasBodega;
    final totalPaginas = total == 0 ? 1 : ((total - 1) ~/ kardexFilasPorPagina) + 1;
    final anchoTabla = anchos.fold<double>(0, (a, b) => a + b);
    final pal = palOf(context);

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: anchoTabla,
              child: Column(
                children: [
                  Container(
                    color: pal.header,
                    child: Row(
                      children: [
                        for (var i = 0; i < etiquetas.length; i++)
                          _Celda(
                            i,
                            anchos,
                            columnas[i] == null
                                ? Text(
                                    etiquetas[i],
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      letterSpacing: 0.1,
                                      height: 1.2,
                                    ),
                                  )
                                : _EncabezadoConFiltro(
                                    columna: columnas[i]!,
                                    etiqueta: etiquetas[i],
                                    esOp: columnas[i] == ColKardex.op,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: pal.cardBorder),
                  if (filas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Sin resultados para los filtros aplicados.',
                            style: TextStyle(color: pal.textMuted)),
                      ),
                    )
                  else
                    for (final item in filas) _KardexRow(item: item, anchos: anchos, esProduccion: esProduccion),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: pal.cardBorder),
          _BarraPaginacion(pagina: pagina, totalPaginas: totalPaginas, total: total, filas: filas.length),
        ],
      ),
    );
  }
}

/// Encabezado de columna con el ícono de embudo que abre el filtro de
/// selección múltiple (búsqueda + casillas), para cualquier columna.
class _EncabezadoConFiltro extends ConsumerWidget {
  const _EncabezadoConFiltro({required this.columna, required this.etiqueta, this.esOp = false});

  final String columna;
  final String etiqueta;
  final bool esOp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(kardexFiltersProvider);
    final opciones = ref.watch(opcionesFiltroProvider);
    final activo = filtros.valoresDe(columna).isNotEmpty;
    final pal = palOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            etiqueta,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pal.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final r = await showMultiSelectFilter<String>(
              context,
              title: 'Filtrar por $etiqueta',
              options: opciones.de(columna),
              selected: filtros.valoresDe(columna),
              labelOf: esOp ? (v) => '#$v' : (v) => v,
            );
            if (r != null) ref.read(kardexFiltersProvider.notifier).setColumna(columna, r);
          },
          child: Icon(
            Icons.filter_alt,
            size: 14,
            color: activo ? pal.accent : pal.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BarraPaginacion extends ConsumerWidget {
  const _BarraPaginacion({
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.filas,
  });

  final int pagina;
  final int totalPaginas;
  final int total;
  final int filas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(kardexPaginaProvider.notifier);
    final desde = total == 0 ? 0 : pagina * kardexFilasPorPagina + 1;
    final hasta = pagina * kardexFilasPorPagina + filas;
    final pal = palOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $desde-$hasta de $total registros',
            style: TextStyle(fontSize: 12, color: pal.textSecondary),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: pagina > 0 ? () => notifier.ir(pagina - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.textSecondary,
                  side: BorderSide(color: pal.cardBorder),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pagina + 1 < totalPaginas ? () => notifier.ir(pagina + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: pal.cardBorder,
                  disabledForegroundColor: pal.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(this.col, this.anchos, this.child, {this.alignment = Alignment.centerLeft});

  final int col;
  final List<double> anchos;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: anchos[col],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _KardexRow extends StatelessWidget {
  const _KardexRow({required this.item, required this.anchos, required this.esProduccion});

  final ItemKardex item;
  final List<double> anchos;
  final bool esProduccion;

  @override
  Widget build(BuildContext context) {
    final pal = palOf(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _celdaOp(pal),
          _celdaProducto(pal),
          _celdaClienteOc(pal),
          if (esProduccion) ..._celdasProduccion(pal) else ..._celdasBodega(pal),
        ],
      ),
    );
  }

  Widget _celdaOp(AppPalette pal) {
    final o = item.item;
    return _Celda(
      0,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) => InkWell(
              onTap: () => showObservacionDialog(context, item),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.chat_bubble_outline, size: 16, color: pal.textMuted),
              ),
            ),
          ),
          Text('#${o.op}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: pal.accent)),
        ],
      ),
    );
  }

  Widget _celdaProducto(AppPalette pal) {
    final o = item.item;
    return _Celda(
      1,
      anchos,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(color: _colorProducto(o.codigo), borderRadius: BorderRadius.circular(3)),
          ),
          Flexible(
            child: Builder(
              builder: (context) => InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _mostrarProductoCompleto(context, o),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.textPrimary)),
                    Text('Talla ${o.talla}', style: TextStyle(fontSize: 11, color: pal.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarProductoCompleto(BuildContext context, ItemOrden o) {
    final pal = palOf(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: pal.card,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _colorProducto(o.codigo), borderRadius: BorderRadius.circular(3)),
            ),
            Expanded(
              child: Text('Producto', style: TextStyle(color: pal.textPrimary)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              o.descripcion,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.textPrimary),
            ),
            const SizedBox(height: 12),
            _filaDato('Código', o.codigo, pal),
            _filaDato('Talla', o.talla, pal),
            _filaDato('OP', o.op, pal),
            if (o.oc.isNotEmpty) _filaDato('OC', o.oc, pal),
            _filaDato('Cliente', o.cliente, pal),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CERRAR')),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, AppPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: pal.textSecondary),
          children: [
            TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: valor, style: TextStyle(color: pal.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _celdaClienteOc(AppPalette pal) {
    final o = item.item;
    return _Celda(
      2,
      anchos,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.cliente,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pal.textPrimary)),
          if (o.oc.isNotEmpty)
            Text('OC ${o.oc}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: pal.textMuted)),
        ],
      ),
    );
  }

  // ------------------------------------------------------- vista Producción

  List<Widget> _celdasProduccion(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: TextStyle(fontSize: 13, color: pal.textPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: TextStyle(fontSize: 13, color: pal.accent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(
        6,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(7, anchos, _celdaEstado(pal)),
      _Celda(8, anchos, _chipFecha(item.fechaEntrega, pal)),
      _Celda(9, anchos, _chipFecha(item.fechaEsperadaProduccion, pal)),
      _Celda(10, anchos, _chipDiasFaltantes(item.fechaEsperadaProduccion, pal)),
    ];
  }

  Widget _celdaEstado(AppPalette pal) {
    final e = item.estadoProduccion;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoProduccion.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoProduccion.parcialPorRetardo:
        color = pal.chipRed;
        fondo = pal.chipRedBg;
        icono = Icons.warning_amber_outlined;
      case EstadoProduccion.parcialPorEntregar:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chipFecha(DateTime? fecha, AppPalette pal) {
    if (fecha == null) {
      return _chip('Sin fecha', pal.textMuted, pal.chipNeutralBg, Icons.event_outlined);
    }
    return _chip(_fechaCorta(fecha), pal.textSecondary, pal.chipNeutralBg, Icons.event_outlined);
  }

  // ------------------------------------------------------- vista Bodega

  List<Widget> _celdasBodega(AppPalette pal) {
    final noConforme = item.pendienteReproceso;
    return [
      _Celda(3, anchos, Text('${item.cantidadPedida}', style: TextStyle(fontSize: 13, color: pal.textPrimary)),
          alignment: Alignment.center),
      _Celda(4, anchos, Text('${item.producido}', style: TextStyle(fontSize: 13, color: pal.accent)),
          alignment: Alignment.center),
      _Celda(
        5,
        anchos,
        Text('${item.pendienteProduccion}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: item.pendienteProduccion > 0 ? pal.chipRed : pal.textMuted,
            )),
        alignment: Alignment.center,
      ),
      _Celda(6, anchos, Text('${item.recibido}', style: TextStyle(fontSize: 13, color: pal.info)),
          alignment: Alignment.center),
      _Celda(7, anchos, Text('${item.despachado}', style: TextStyle(fontSize: 13, color: pal.warning)),
          alignment: Alignment.center),
      _Celda(
        8,
        anchos,
        Text(
          '$noConforme',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: noConforme > 0 ? pal.warning : pal.textMuted,
          ),
        ),
        alignment: Alignment.center,
      ),
      _Celda(9, anchos, _celdaEstadoLogistica(pal)),
      _Celda(10, anchos, _chipFecha(item.fechaEntrega, pal)),
      _Celda(11, anchos, _chipFecha(item.fechaEsperadaLogistica, pal)),
      _Celda(12, anchos, _chipDiasFaltantes(item.fechaEsperadaLogistica, pal)),
    ];
  }

  Widget _chipDiasFaltantes(DateTime? esperada, AppPalette pal) {
    if (esperada == null) {
      return _chip('Sin fecha', pal.textMuted, pal.chipNeutralBg, Icons.hourglass_empty);
    }
    final hoy = DateTime.now();
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final soloEsperada = DateTime(esperada.year, esperada.month, esperada.day);
    final dias = soloEsperada.difference(soloHoy).inDays;
    if (dias < 0) {
      return _chip('Vencido ${-dias}d', pal.chipRed, pal.chipRedBg, Icons.warning_amber_outlined);
    }
    if (dias == 0) {
      return _chip('HOY', pal.warning, pal.chipNeutralBg, Icons.today_outlined);
    }
    return _chip('Faltan ${dias}d', pal.textSecondary, pal.chipNeutralBg, Icons.hourglass_bottom);
  }

  Widget _celdaEstadoLogistica(AppPalette pal) {
    final e = item.estadoLogistica;
    final Color color;
    final Color fondo;
    final IconData icono;
    switch (e) {
      case EstadoLogistica.completado:
        color = pal.chipGreen;
        fondo = pal.chipGreenBg;
        icono = Icons.check_circle_outline;
      case EstadoLogistica.pendienteRecibir:
        color = pal.textSecondary;
        fondo = pal.chipNeutralBg;
        icono = Icons.hourglass_bottom;
      case EstadoLogistica.pendientePorDespachar:
        color = pal.warning;
        fondo = pal.chipNeutralBg;
        icono = Icons.local_shipping_outlined;
    }
    return _chip(e.etiqueta, color, fondo, icono);
  }

  Widget _chip(String texto, Color color, Color fondo, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
ORBILOQ_EOF

echo "Listo. Revisa el diff con: git diff --stat"
