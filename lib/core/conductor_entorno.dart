/// Entornos autorizados de ORBILOQ; los permisos siguen siendo por usuario.
bool conductorHabilitado([
  String url = const String.fromEnvironment('SUPABASE_URL'),
]) =>
    url.isEmpty ||
    const {
      'igfuafcekcpugpmsoqbe.supabase.co',
      'cxrflhgnxvomcvxzugda.supabase.co',
    }.contains(Uri.tryParse(url)?.host);
