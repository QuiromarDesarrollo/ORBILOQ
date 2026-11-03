/// Disponible en los proyectos existentes de DEV y producción de ORBILOQ.
/// Se conserva el nombre del getter por compatibilidad con los consumidores.
bool get inventarioEnPruebas => const {
  'igfuafcekcpugpmsoqbe.supabase.co',
  'cxrflhgnxvomcvxzugda.supabase.co',
}.contains(Uri.tryParse(const String.fromEnvironment('SUPABASE_URL'))?.host);
