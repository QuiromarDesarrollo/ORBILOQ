import 'package:orbiloq_wms/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/data/catalogos_repository.dart';
import 'package:orbiloq_wms/data/in_memory_wms_repository.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/admin/presentation/catalogos_dialog.dart';
import 'package:orbiloq_wms/shared/widgets/catalogo_ubicacion_dropdown.dart';
import 'package:orbiloq_wms/shared/widgets/addable_person_dropdown.dart';
import 'package:orbiloq_wms/core/result.dart';

class _Catalogos extends CatalogosRepository {
  final filas = <Map<String, dynamic>>[
    {
      'id': '1',
      'nombre': 'Ana',
      'numero_usuario': '001',
      'rol': 'produccion',
      'activo': true,
      'auth_id': 'auth',
      'version': 'v1'
    }
  ];
  int lecturas = 0, guardados = 0, altas = 0;
  @override
  Future<List<Map<String, dynamic>>> listar(String tipo) async {
    lecturas++;
    return filas.map((f) => Map<String, dynamic>.from(f)).toList();
  }

  @override
  Future<void> guardar(String tipo, Map<String, dynamic>? anterior,
      String nombre, bool activo, String rol) async {
    guardados++;
    filas[0] = {...filas[0], 'nombre': nombre, 'activo': activo, 'rol': rol};
  }

  @override
  Future<bool> crearUsuario(
      String numero, String nombre, String rol, String contrasena) async {
    altas++;
    return false;
  }
}

void main() {
  test('Revalidar la sesión conserva la vista elegida por el administrador', () async {
    final container=ProviderContainer(overrides:[usarSupabaseProvider.overrideWithValue(true),usuarioSesionProvider.overrideWith((ref)async=>const UsuarioSesion(numeroUsuario:'1',nombre:'Admin',rolCuenta:RolCuenta.admin))]);
    addTearDown(container.dispose);
    await container.read(usuarioSesionProvider.future);
    container.read(rolProvider.notifier).cambiar(Rol.logistica);
    container.invalidate(usuarioSesionProvider);
    await container.read(usuarioSesionProvider.future);
    expect(container.read(rolProvider),Rol.logistica);
  });
  testWidgets('Editar y desactivar exige confirmación, pantalla móvil',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalogos = _Catalogos(), repo = InMemoryWmsRepository.seeded();
    addTearDown(repo.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(false),
      catalogosAdminProvider.overrideWithValue(catalogos),
      wmsRepositoryProvider.overrideWithValue(repo)
    ], child: const MaterialApp(home: Scaffold(body: CatalogosDialog()))));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar registro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ana corregida');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(catalogos.guardados, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(catalogos.guardados, 0);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(catalogos.guardados, 1);
    expect(catalogos.filas.first['activo'], false);
    expect(find.text('Ana corregida'), findsOneWidget);
  });
  testWidgets('Crear una cuenta requiere datos válidos y confirmación', (tester) async {
    final cat=_Catalogos(),repo=InMemoryWmsRepository.seeded();addTearDown(repo.dispose);
    await tester.pumpWidget(ProviderScope(overrides:[usarSupabaseProvider.overrideWithValue(false),catalogosAdminProvider.overrideWithValue(cat),wmsRepositoryProvider.overrideWithValue(repo)],child:const MaterialApp(home:Scaffold(body:CatalogosDialog()))));
    await tester.pumpAndSettle();await tester.tap(find.text('Agregar'));await tester.pumpAndSettle();
    Finder campo(String label)=>find.byWidgetPredicate((w)=>w is TextField && w.decoration?.labelText==label);
    await tester.enterText(campo('Nombre'),'Nueva persona');
    await tester.enterText(campo('Número de usuario'),'003');
    await tester.enterText(campo('Contraseña inicial (mínimo 12 caracteres)'),'Clave-segura-2026');
    await tester.tap(find.text('Guardar cambios'));await tester.pumpAndSettle();expect(cat.altas,0);
    await tester.tap(find.text('Confirmar'));await tester.pumpAndSettle();expect(cat.altas,1);
  });
  testWidgets('Un operario no puede cargar catálogos de administración',
      (tester) async {
    final cat = _Catalogos();
    await tester.pumpWidget(ProviderScope(overrides: [
      usarSupabaseProvider.overrideWithValue(true),
      catalogosAdminProvider.overrideWithValue(cat),
      usuarioSesionProvider.overrideWith((ref) async => const UsuarioSesion(
          numeroUsuario: '2',
          nombre: 'Operario',
          rolCuenta: RolCuenta.produccion))
    ], child: const MaterialApp(home: Scaffold(body: CatalogosDialog()))));
    await tester.pumpAndSettle();
    expect(cat.lecturas, 0);
    expect(find.text('Acceso exclusivo del administrador.'), findsOneWidget);
  });
  testWidgets(
      'Estantes vienen del catálogo; una selección retirada se reemplaza',
      (tester) async {
    String elegido = 'ESTANTE ANTIGUO';
    await tester.pumpWidget(ProviderScope(
        overrides: [
          ubicacionesProvider.overrideWith((ref) async => ['ESTANTE NUEVO'])
        ],
        child: MaterialApp(
            home: Scaffold(
                body: CatalogoUbicacionDropdown(
                    label: 'Estante',
                    value: elegido,
                    onChanged: (v) => elegido = v)))));
    await tester.pumpAndSettle();
    expect(elegido, 'ESTANTE NUEVO');
    expect(find.text('ESTANTE NUEVO'), findsOneWidget);
  });
  testWidgets('Un nombre retirado limpia la selección sin romper el formulario',
      (tester) async {
    String? elegido = 'TYPO';
    await tester.pumpWidget(ProviderScope(
        overrides: [
          personalLogisticaProvider
              .overrideWith((ref) async => ['NOMBRE CORRECTO'])
        ],
        child: MaterialApp(
            home: Scaffold(
                body: AddablePersonDropdown(
                    label: 'Persona',
                    valor: elegido,
                    onChanged: (v) => elegido = v,
                    itemsProvider: personalLogisticaProvider,
                    onAgregar: (_, v) async => Ok(v),
                    tituloDialogo: 'Agregar')))));
    await tester.pumpAndSettle();
    expect(elegido, isNull);
  });
}
