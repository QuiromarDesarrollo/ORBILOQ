/// Proyectos existentes de ORBILOQ; los permisos se verifican en el servidor.
bool masivaHabilitada([
  String url = const String.fromEnvironment('SUPABASE_URL'),
]) =>
    url.isEmpty ||
    const {
      'igfuafcekcpugpmsoqbe.supabase.co',
      'cxrflhgnxvomcvxzugda.supabase.co',
    }.contains(Uri.tryParse(url)?.host);

String masivaNombreEntorno([
  String url = const String.fromEnvironment('SUPABASE_URL'),
]) => switch (Uri.tryParse(url)?.host) {
  'cxrflhgnxvomcvxzugda.supabase.co' => 'PRODUCCIÓN',
  'igfuafcekcpugpmsoqbe.supabase.co' => 'ENTORNO DE PRUEBAS',
  _ => 'VISTA LOCAL',
};
