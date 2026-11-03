import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbiloq_wms/features/conductor/borrador_local.dart';
import 'package:orbiloq_wms/features/conductor/conductor_model.dart';
import 'package:orbiloq_wms/features/conductor/conductor_repository.dart';
import 'package:orbiloq_wms/features/conductor/evidencia_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/registro_conductor.dart';
import 'package:orbiloq_wms/features/conductor/presentation/kit_semanal_page.dart';

class Memory extends BorradorLocalStore {
  final rows = <String, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> leer(String key) async => rows[key];
  @override
  Future<void> guardar(String key, Map<String, dynamic> data) async {
    if (fail) throw StateError('Sin espacio');
    rows[key] = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  }

  @override
  Future<void> eliminar(String key) async => rows.remove(key);
}

const vehicle = VehiculoConductor(
  id: 'v1',
  placa: 'TEST01',
  descripcion: 'Prueba',
  km: 100,
);

void main() {
  for (final width in [390.0, 800.0]) {
    testWidgets(
      'Recupera checklist, fotos y categoría; aísla usuario a $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Memory();
        Future<void> open({String user = 'u1', bool weekly = false}) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                conductorRepositoryProvider.overrideWithValue(
                  ConductorRepository(null),
                ),
                transporteBorradorUsuarioProvider.overrideWithValue(user),
                transporteBorradorStoreProvider.overrideWithValue(store),
              ],
              child: MaterialApp(
                home:
                    weekly
                        ? const KitSemanalPage(vehiculo: vehicle)
                        : const RegistroConductorPage(
                          vehiculo: vehicle,
                          tipo: 'Inicio de jornada',
                        ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await open();
        dynamic state = tester.state(find.byType(RegistroConductorPage));
        final data = Map<String, dynamic>.from(state.draftSnapshot() as Map);
        final photo =
            EvidenciaSeleccionada()..seleccionar(
              ArchivoEvidencia(
                'foto.jpg',
                'image/jpeg',
                Uint8List.fromList([1, 2, 3]),
              ),
            );
        data['campos'] = {'km': '125', 'observaciones': 'Revisar espejo'};
        data['categoria'] = 2;
        data['respuestas'] = {'Frenos': 'Bueno'};
        data['evidencias'] = {'foto_frente': photo.borrador()};
        state.restoreDraft(data);
        expect(await state.flushDraft(), true);
        await open();
        state = tester.state(find.byType(RegistroConductorPage));
        final restored = state.draftSnapshot() as Map;
        expect(restored['categoria'], 2);
        expect(restored['campos']['km'], '125');
        expect(restored['respuestas']['Frenos'], 'Bueno');
        expect(
          restored['evidencias']['foto_frente']['bytes'],
          base64Encode([1, 2, 3]),
        );
        expect(find.textContaining('Avance recuperado'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await open(user: 'u2');
        state = tester.state(find.byType(RegistroConductorPage));
        expect((state.draftSnapshot() as Map)['respuestas'], isEmpty);
        await open(weekly: true);
        state = tester.state(find.byType(KitSemanalPage));
        state.restoreDraft({
          'inspector': 'Conductor',
          'lugar': 'Parqueadero',
          'notas': 'Pendiente',
          'categoria': 1,
          'respuestas': {
            'Gato': {'estado': 'Con novedad', 'detalle': 'Revisar'},
          },
          'detalles': {'Gato': 'Revisar'},
        });
        expect(await state.flushDraft(), true);
        await open(weekly: true);
        state = tester.state(find.byType(KitSemanalPage));
        expect((state.draftSnapshot() as Map)['lugar'], 'Parqueadero');
        expect((state.draftSnapshot() as Map)['detalles']['Gato'], 'Revisar');
        store.fail = true;
        final changed = Map<String, dynamic>.from(state.draftSnapshot() as Map)
          ..['notas'] = 'Nuevo';
        state.restoreDraft(changed);
        expect(await state.flushDraft(), false);
        await tester.pumpAndSettle();
        expect(find.text('Reintentar'), findsOneWidget);
        expect(state.draftCanLeave, false);
        store.fail = false;
        expect(await state.flushDraft(), true);
        await state.completeDraft();
        await open(weekly: true);
        state = tester.state(find.byType(KitSemanalPage));
        expect((state.draftSnapshot() as Map)['respuestas'], isEmpty);
        expect(tester.takeException(), isNull);
        photo.dispose();
      },
    );
  }
}
