import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/application/auth_providers.dart';
import 'package:orbiloq_wms/application/providers.dart';
import 'package:orbiloq_wms/domain/wms_repository.dart';
import 'package:orbiloq_wms/domain/models.dart';
import 'package:orbiloq_wms/domain/sesion.dart';
import 'package:orbiloq_wms/features/admin/presentation/dashboard_ejecutivo_page.dart';
import 'dashboard_atencion_test.dart' show demoAtencion;
import 'dashboard_ejecutivo_test.dart' show ReportesDashboardPrueba;

class RepoManual implements WmsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
  int lecturas = 0, suscripciones = 0;
  WmsSnapshot actual = WmsSnapshot(kardex: demoAtencion, lotes: []);
  final eventos = StreamController<WmsSnapshot>.broadcast();
  @override
  Future<WmsSnapshot> cargarSnapshot() async {
    lecturas++;
    return actual;
  }

  @override
  Stream<WmsSnapshot> watch() {
    suscripciones++;
    return eventos.stream;
  }
}

void main() {
  testWidgets(
    'Revalidar sesión cada 30 segundos no recarga; cambiar permisos sí revoca acceso',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RepoManual();
      final reportes = ReportesDashboardPrueba();
      var rol = RolCuenta.admin;
      var numero = '1';
      Completer<UsuarioSesion?>? pendiente;
      final container = ProviderContainer(
        overrides: [
          usarSupabaseProvider.overrideWithValue(true),
          usuarioSesionProvider.overrideWith(
            (ref) async =>
                pendiente != null
                    ? pendiente.future
                    : UsuarioSesion(
                      numeroUsuario: numero,
                      nombre: 'Admin',
                      rolCuenta: rol,
                    ),
          ),
          wmsRepositoryProvider.overrideWithValue(repo),
          reportesAdminProvider.overrideWithValue(reportes),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.eventos.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardEjecutivoPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(reportes.llamadas, 4);
      expect(repo.lecturas, 1);
      // Incluye la fase AsyncLoading con valor previo y una nueva instancia
      // del mismo perfil: ambas ocurren en la revalidación real de Supabase.
      for (var i = 0; i < 3; i++) {
        pendiente = Completer<UsuarioSesion?>();
        container.invalidate(usuarioSesionProvider);
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('Consultando movimientos…'), findsNothing);
        expect(find.text('4 activas · 1 completas'), findsOneWidget);
        pendiente.complete(
          UsuarioSesion(
            numeroUsuario: numero,
            nombre: 'Admin $i',
            rolCuenta: rol,
          ),
        );
        await tester.pumpAndSettle();
        pendiente = null;
        expect(reportes.llamadas, 4);
        expect(repo.lecturas, 1);
      }
      await tester.tap(find.text('Actualizar datos'));
      await tester.pumpAndSettle();
      expect(reportes.llamadas, 8);
      expect(repo.lecturas, 2);
      numero = '2';
      container.invalidate(usuarioSesionProvider);
      await tester.pumpAndSettle();
      expect(reportes.llamadas, 12);
      expect(repo.lecturas, 3);
      rol = RolCuenta.logistica;
      container.invalidate(usuarioSesionProvider);
      await tester.pumpAndSettle();
      expect(find.text('Acceso exclusivo del administrador.'), findsOneWidget);
      expect(find.text('4 activas · 1 completas'), findsNothing);
      expect(reportes.llamadas, 12);
      expect(repo.lecturas, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Eventos, filtros y cambio de vista no recargan; botón sí consulta todo',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RepoManual();
      final reportes = ReportesDashboardPrueba();
      addTearDown(() async {
        await repo.eventos.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usarSupabaseProvider.overrideWithValue(false),
            wmsRepositoryProvider.overrideWithValue(repo),
            reportesAdminProvider.overrideWithValue(reportes),
          ],
          child: const MaterialApp(home: DashboardEjecutivoPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.lecturas, 1);
      expect(repo.suscripciones, 0);
      expect(reportes.llamadas, 4);
      expect(find.text('4 activas · 1 completas'), findsOneWidget);
      repo.actual = WmsSnapshot(kardex: [], lotes: []);
      repo.eventos.add(repo.actual);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('4 activas · 1 completas'), findsOneWidget);
      await tester.tap(find.text('Últimas 12 semanas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Últimas 4 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vista detallada'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vista compacta'));
      await tester.pumpAndSettle();
      expect(repo.lecturas, 1);
      expect(reportes.llamadas, 4);
      await tester.tap(find.text('Actualizar datos'));
      await tester.pumpAndSettle();
      expect(repo.lecturas, 2);
      expect(reportes.llamadas, 8);
      expect(repo.suscripciones, 0);
      expect(find.text('0 activas · 0 completas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.pump(const Duration(minutes: 10));
      expect(repo.lecturas, 2);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(repo.lecturas, 2);
      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(repo.lecturas, 2);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.lecturas, 3);
      expect(reportes.llamadas, 12);
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(repo.lecturas, 4);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 15));
      expect(repo.lecturas, 4);
      expect(reportes.llamadas, 16);
      await tester.tap(find.text('Actualizar datos'));
      await tester.pumpAndSettle();
      expect(repo.lecturas, 5);
      // Salir con el switch encendido cancela el temporizador.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 10));
      expect(repo.lecturas, 5);
      expect(tester.takeException(), isNull);
    },
  );
}

