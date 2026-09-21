import '../core/result.dart';
import 'models.dart';

/// Contrato de datos. Las reglas de negocio (límites, stock) deben aplicarse
/// dentro de cada implementación; en Supabase, mediante funciones RPC transaccionales.
abstract interface class WmsRepository {
  /// Emite el estado actual y cada cambio posterior.
  Stream<WmsSnapshot> watch();

  Future<void> refrescar();

  /// Producción entrega un lote a bodega (crea remisión en tránsito).
  Future<Result<Remision>> entregarLote({
    required String itemId,
    required int cantidad,
    required String operario,
    String? numeroRemision,
  });

  /// Logística recibe una remisión y la ubica en un estante.
  Future<Result<Remision>> recibirLote({
    required String remisionId,
    required int cantidad,
    required String ubicacion,
    String nota = '',
  });

  /// Logística despacha unidades desde una ubicación.
  Future<Result<void>> despachar({
    required String itemId,
    required int cantidad,
    required String ubicacion,
  });

  void dispose();
}
