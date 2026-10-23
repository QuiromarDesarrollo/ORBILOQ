# Restablecer contraseña desde Usuarios

Desplegada en ORBILOQ-DEV (igfuafcekcpugpmsoqbe) el 23 de octubre de 2026 desde el editor de Supabase. No requiere migración SQL; requiere el catálogo de usuarios con `auth_id` y perfiles `roles`.

Desplegar en el proyecto correspondiente:

```sh
supabase functions deploy admin-restablecer-contrasena --project-ref igfuafcekcpugpmsoqbe
```

La función valida el JWT con Auth.getUser y verifica el administrador activo en la base. Resuelve el Auth ID desde el ID de catálogo seleccionado y cambia únicamente la contraseña mediante Auth Admin. La clave de servicio se usa solo en el servidor. No registra ni devuelve contraseñas. No activa cuentas ni altera perfiles. El formulario de edición abre una acción independiente para evitar guardados parciales de otros campos.

Probar localmente: `node --test tools/test_restablecer_contrasena.mjs`.

Verificación remota: POST sin credenciales y cuerpo vacío devuelve HTTP 401 con «Inicia sesión nuevamente.». No se modificaron contraseñas durante la verificación. Se configuró verify_jwt = false porque Auth.getUser valida el JWT dentro del handler.

El editor publicó el contenido de handler.mjs como file2.ts, con el import correspondiente en index.ts. Un próximo despliegue por CLI usará los nombres del repositorio.
