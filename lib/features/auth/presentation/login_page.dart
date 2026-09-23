import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/auth_providers.dart';
import '../../../core/result.dart';

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

  // Paleta propia de esta pantalla (coherente con el resto de la app, pero
  // con más matices de los que trae AppColors para lograr el degradado).
  static const _navyDeep = Color(0xFF0B1220);
  static const _navyMid = Color(0xFF13203A);
  static const _tealBright = Color(0xFF34D399);
  static const _tealPrimary = Color(0xFF0F766E);
  static const _slate900 = Color(0xFF0F172A);
  static const _slate500 = Color(0xFF64748B);
  static const _slate200 = Color(0xFFE2E8F0);

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
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 900;
          final panelMarca = _PanelMarca(navyDeep: _navyDeep, navyMid: _navyMid, tealBright: _tealBright);
          final panelForm = _PanelFormulario(
            tealPrimary: _tealPrimary,
            slate900: _slate900,
            slate500: _slate500,
            slate200: _slate200,
            usuarioCtrl: _usuarioCtrl,
            contrasenaCtrl: _contrasenaCtrl,
            cargando: _cargando,
            verContrasena: _verContrasena,
            error: _error,
            onVerContrasena: () => setState(() => _verContrasena = !_verContrasena),
            onIngresar: _ingresar,
          );

          if (ancho) {
            return Row(
              children: [
                Expanded(flex: 5, child: panelMarca),
                Expanded(flex: 6, child: Center(child: panelForm)),
              ],
            );
          }
          // Pantallas angostas: la franja de marca queda arriba, compacta.
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 260, child: panelMarca),
                Padding(padding: const EdgeInsets.all(24), child: panelForm),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Panel oscuro con el logo y el mensaje de marca.
class _PanelMarca extends StatelessWidget {
  const _PanelMarca({required this.navyDeep, required this.navyMid, required this.tealBright});

  final Color navyDeep;
  final Color navyMid;
  final Color tealBright;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDeep, navyMid],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                ),
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_orbiloq.png',
                      width: 190,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.inventory_2_outlined,
                        size: 90,
                        color: tealBright,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                  children: [
                    const TextSpan(text: 'Eficiencia en\n', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'movimiento', style: TextStyle(color: tealBright)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sistema de gestión de almacenes para una operación\nlogística precisa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel claro con el formulario de acceso.
class _PanelFormulario extends StatelessWidget {
  const _PanelFormulario({
    required this.tealPrimary,
    required this.slate900,
    required this.slate500,
    required this.slate200,
    required this.usuarioCtrl,
    required this.contrasenaCtrl,
    required this.cargando,
    required this.verContrasena,
    required this.error,
    required this.onVerContrasena,
    required this.onIngresar,
  });

  final Color tealPrimary;
  final Color slate900;
  final Color slate500;
  final Color slate200;
  final TextEditingController usuarioCtrl;
  final TextEditingController contrasenaCtrl;
  final bool cargando;
  final bool verContrasena;
  final String? error;
  final VoidCallback onVerContrasena;
  final VoidCallback onIngresar;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCESO SEGURO',
              style: TextStyle(color: tealPrimary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenido de nuevo',
              style: TextStyle(color: slate900, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa tus credenciales para gestionar el inventario.',
              style: TextStyle(color: slate500, fontSize: 14),
            ),
            const SizedBox(height: 28),
            if (error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            _etiqueta('USUARIO', slate500),
            const SizedBox(height: 6),
            TextField(
              controller: usuarioCtrl,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.username],
              style: TextStyle(color: slate900),
              decoration: _decoracion('Ingresa tu usuario', Icons.person_outline, slate200, slate500),
              onSubmitted: (_) => onIngresar(),
            ),
            const SizedBox(height: 18),
            _etiqueta('CONTRASEÑA', slate500),
            const SizedBox(height: 6),
            TextField(
              controller: contrasenaCtrl,
              obscureText: !verContrasena,
              autofillHints: const [AutofillHints.password],
              style: TextStyle(color: slate900),
              decoration: _decoracion('Ingresa tu contraseña', Icons.lock_outline, slate200, slate500).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(verContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20, color: slate500),
                  onPressed: onVerContrasena,
                ),
              ),
              onSubmitted: (_) => onIngresar(),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cargando ? null : onIngresar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: cargando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: slate200),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('ORBILOQ WMS', style: TextStyle(color: slate500, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text('¿Olvidaste tu clave?', style: TextStyle(color: tealPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) =>
      Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6));

  InputDecoration _decoracion(String hint, IconData icono, Color borde, Color iconColor) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: iconColor.withValues(alpha: 0.7), fontSize: 14),
        prefixIcon: Icon(icono, color: iconColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borde)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borde)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
      );
}
