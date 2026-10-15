import '../domain/ciclos.dart';

/// Prepara la instantánea en bloques de tiempo, cediendo al navegador para
/// mantener la animación y la navegación durante una carga grande.
Future<DatosCiclos> prepararCiclos(
  DatosCiclos datos, {
  bool Function()? cancelado,
}) async {
  final bloque = Stopwatch()..start();
  for (final orden in datos.ordenes) {
    if (cancelado?.call() ?? false) return datos;
    for (final proceso in ProcesoCiclo.values) {
      final medicion = datos.medir(orden, proceso);
      // Materializa los valores diferidos usados por todas las gráficas.
      medicion.esperada;
      medicion.duracion;
      medicion.cumplio;
    }
    datos.objetivoTotal(orden);
    if (bloque.elapsedMilliseconds >= 8) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      bloque.reset();
    }
  }
  return datos;
}
