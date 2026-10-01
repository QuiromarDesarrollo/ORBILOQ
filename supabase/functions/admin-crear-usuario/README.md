# Alta de cuentas (solo proyecto de pruebas)

1. Aplicar `sql/pruebas/060_administrar_catalogos.sql` después de las migraciones 055, 057, 058 y 059.
2. En Supabase DEV, desplegar la Edge Function **admin-crear-usuario** con los archivos `index.ts` y `handler.mjs` de esta carpeta. Puede usarse el editor de Edge Functions del Dashboard o `supabase functions deploy admin-crear-usuario --project-ref <REF_DEV> --no-verify-jwt`. No desplegar en producción.
3. La función usa las variables de servidor `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` que provee Supabase. Nunca copiarlas al código Flutter ni a los `dart-define` de la app.
4. Usar `verify_jwt = false` como indica `supabase/config.toml` (en el Dashboard, desactivar el verificador JWT heredado para esta función). La identidad NO queda sin validar: la función comprueba obligatoriamente el token con `auth.getUser` y consulta el rol/estado en la base antes de cualquier operación. Esto admite tanto claves JWT modernas como las heredadas. No usa metadatos del usuario como prueba de rol.
5. Entrar como administrador y abrir **Administración → Usuarios → Agregar**. Se mantiene el acceso por número y contraseña con correo interno `<numero>@orbiloq.local`. Entregar la contraseña por un canal privado; no se guarda en auditorías ni se muestra en la lista.

Un alta interrumpida puede dejar una cuenta Auth sin perfil: no tendrá acceso a datos porque no existe un usuario activo vinculado. Reintentar el mismo número recupera únicamente cuentas marcadas por esta función, conserva su contraseña original y vuelve a validar al administrador. Nunca elimina cuentas ni intenta apropiarse de cuentas antiguas. Un número ya vinculado se edita, no se recrea.

Desactivar usuarios se aplica en la base de la aplicación: no elimina su cuenta Auth ni sus movimientos. Las políticas y RPC rechazan operaciones de cuentas inactivas incluso con un JWT no vencido. La UI revisa la sesión periódicamente. Una operación ya iniciada puede terminar antes de la desactivación.

Documentación oficial: [creación de usuarios en servidor](https://supabase.com/docs/reference/javascript/auth-admin-createuser), [validación de identidad en Edge Functions](https://supabase.com/docs/guides/functions/auth-legacy-jwt).
