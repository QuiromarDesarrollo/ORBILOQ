import '../core/result.dart';
import 'models.dart';

/// Contrato de datos. Las reglas de negocio (límites, stock) deben aplicarse
/// dentro de cada implementación; en Supabase, mediante funciones RPC transaccionales.
abstract interface class WmsRepository {
  /// Emite el estado actual y cada cambio posterior.
  Stream<WmsSnapshot> watch();

  Future<void> refrescar();

  /// Producción entrega VARIOS productos de una sola vez, agrupados bajo un
  /// mismo lote (todo o nada: si uno de los productos no pasa validación,
  /// no se crea nada).
  Future<Result<Lote>> crearLote({
    required List<ItemCantidad> items,
    required String operario,
    String? numeroLote,
  });

  /// Logística recibe UNA línea (producto) dentro de un lote y la ubica en
  /// un estante.
  Future<Result<LoteLinea>> recibirLoteLinea({
    required String loteLineaId,
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

  /// Causales disponibles para marcar un producto como no conforme.
  Future<List<Causal>> cargarCausales();

  /// Logística marca unidades como no conformes: se restan de lo entregado
  /// por Producción (independiente de cualquier lote) y quedan reflejadas
  /// en "Producto no conforme" hasta que se reprocesen.
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    String nota = '',
  });

  /// Producción libera (reprocesó) unidades no conformes: vuelven a sumar a
  /// lo entregado y bajan de "Producto no conforme". Puede ser parcial.
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    String nota = '',
  });

  /// Historial de liberaciones (más recientes primero), para control.
  Future<List<Liberacion>> cargarLiberaciones();

  /// Historial de reportes de producto no conforme (más recientes primero).
  Future<List<Devolucion>> cargarDevoluciones();

  void dispose();
}
