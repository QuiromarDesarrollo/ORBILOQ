#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Quita el cast innecesario en login_page.dart (v17)
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_cast_v17.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Corrigiendo el aviso de flutter analyze..."

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
      if (res is Err<void>) _error = res.message;
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

echo ""
echo "Listo. flutter analyze deberia salir: No issues found!"
