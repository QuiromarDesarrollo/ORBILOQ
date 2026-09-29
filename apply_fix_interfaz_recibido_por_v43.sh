#!/usr/bin/env bash
# ============================================================================
# ORBILOQ WMS - Fix: faltaba recibidoPor en la interfaz WmsRepository (v43)
# Ejecutar DESPUES de apply_aliados_no_conforme_v42.sh
# Ejecutar DESDE LA RAIZ del repo:
#   bash apply_fix_interfaz_recibido_por_v43.sh
# ============================================================================
set -e
if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: corre este script desde la raiz del repo (donde esta pubspec.yaml)"
  exit 1
fi
echo "Corrigiendo la interfaz WmsRepository..."

echo "  - lib/domain/wms_repository.dart"
mkdir -p "$(dirname 'lib/domain/wms_repository.dart')"
cat > 'lib/domain/wms_repository.dart' << 'ORBILOQ_EOF'
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
    required String recibidoPor,
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

  /// Lista ampliable de personas de Logística que pueden recibir una prenda
  /// liberada por Producción. Se puede agregar un nombre nuevo con
  /// [agregarPersonalLogistica].
  Future<List<String>> cargarPersonalLogistica();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Logística, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalLogistica(String nombre);

  /// Lista ampliable de personas de Producción que pueden entregar una
  /// prenda no conforme a Logística. Se puede agregar un nombre nuevo con
  /// [agregarPersonalProduccion].
  Future<List<String>> cargarPersonalProduccion();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Producción, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalProduccion(String nombre);

  /// Logística marca unidades como no conformes: se restan de lo entregado
  /// por Producción (independiente de cualquier lote) y quedan reflejadas
  /// en "Producto no conforme" hasta que se reprocesen.
  Future<Result<void>> registrarNoConforme({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String recibidoDeProduccion,
    String nota = '',
  });

  /// Producción libera (reprocesó) unidades no conformes: vuelven a sumar a
  /// lo entregado y bajan de "Producto no conforme". Puede ser parcial.
  Future<Result<void>> liberarNoConforme({
    required String itemId,
    required int cantidad,
    required String operario,
    required String recibidoPorLogistica,
    String nota = '',
  });

  /// Historial de liberaciones (más recientes primero), para control.
  Future<List<Liberacion>> cargarLiberaciones();

  /// Historial de reportes de producto no conforme (más recientes primero).
  Future<List<Devolucion>> cargarDevoluciones();

  /// Lista ampliable de personas de Aliados. Se puede agregar un nombre
  /// nuevo con [agregarPersonalAliado].
  Future<List<String>> cargarPersonalAliados();

  /// Agrega (o reutiliza si ya existe) un nombre en la lista de personal de
  /// Aliados, devolviendo el nombre normalizado guardado.
  Future<Result<String>> agregarPersonalAliado(String nombre);

  /// Producción envía unidades no conformes a un Aliado externo. Flujo
  /// independiente del de Logística — no pasa por lotes ni Recepción.
  Future<Result<void>> enviarNoConformeAliado({
    required String itemId,
    required int cantidad,
    required String causalId,
    required String operario,
    required String personaAliadoEntrega,
    String nota = '',
  });

  /// Producción libera (recibe de vuelta) un envío a Aliados. Solo actualiza
  /// el registro de trazabilidad — no crea lote ni toca Bodega.
  Future<Result<void>> liberarNoConformeAliado({
    required String id,
    required String operario,
    required String personaAliadoLibera,
    String nota = '',
  });

  /// Todas las solicitudes de Aliados (pendientes e historial), más
  /// recientes primero.
  Future<List<NoConformeAliado>> cargarNoConformesAliados();

  void dispose();
}
ORBILOQ_EOF

echo ""
echo "Listo. flutter analyze"
