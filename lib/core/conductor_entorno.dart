/// El módulo permanece deshabilitado en producción.
bool conductorHabilitado([
  String url = const String.fromEnvironment('SUPABASE_URL'),
]) =>
    url.isEmpty ||
    Uri.tryParse(url)?.host == 'igfuafcekcpugpmsoqbe.supabase.co';
