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
