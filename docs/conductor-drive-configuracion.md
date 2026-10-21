# Activar evidencias del conductor en pruebas

Estado al 21/10/2026: conexión Google Drive configurada y función desplegada en DEV.
No aplicar a producción. Proyecto Supabase permitido: `igfuafcekcpugpmsoqbe`.
No hace falta cambiar tablas ni almacenar imágenes en la base de datos.

## Configuración realizada y límites de la validación

- Google Cloud: `orbiloq-transporte`; Drive API y Google Picker API habilitadas.
- OAuth externo en modo Pruebas; cuenta de prueba `analistasdedatosing@gmail.com`.
- Cliente web `ORBILOQ Transporte DEV`, retorno `http://localhost:8765/oauth/callback`
  y origen `http://localhost:8765`. Único alcance: `drive.file`.
- Clave `ORBILOQ Picker DEV`: solo Google Picker API, referencias
  `http://localhost:8765/*` y `https://docs.google.com/*`.
- TRANSPORTE seleccionada en Google Picker y permiso `canAddChildren` verificado.
- Los tres secretos indicados más abajo están guardados en Supabase DEV.
- `conductor-evidencia` desplegada mediante el editor de Supabase. Para ese
  despliegue se unieron `handler.mjs` e `index.ts` en un solo `index.ts`, omitiendo
  únicamente la importación local de `crearHandler`; la lógica es la misma.
- Desactivada la comprobación JWT heredada del gateway, conservando la
  autenticación `Auth.getUser` y la lectura del vehículo con RLS en la función.
- Comprobados: 401 sin sesión en la función real, renovación del token Google,
  escritura en TRANSPORTE y subida reanudable de una imagen técnica de 67 bytes.
  Esa subida comprobó Drive directamente; no suplanta una sesión de conductor
  ni demuestra todavía el recorrido completo Flutter → función → Drive.

Pendiente: validar con una sesión real del conductor la captura móvil, subida,
guardado del registro y apertura del enlace por los usuarios correspondientes.
Google mantiene la app en modo Pruebas: el refresh token de este permiso caduca
a los siete días. No usar esta autorización temporal como configuración definitiva
de operación continua; resolver la publicación/configuración OAuth antes de eso.

## Herramientas locales de conexión y renovación

`node tools/conectar_drive_conductor.mjs` inicia un asistente administrativo
solo en loopback (`127.0.0.1:8765`) durante 30 minutos. Usa estado OAuth, PKCE,
cookie HttpOnly y comprobación CSRF. Solo admite la carpeta TRANSPORTE fijada.
Abrir el enlace que imprime en la misma máquina; no compartirlo. Tras verificar
Google Picker y permisos, guarda el archivo de secretos para DEV, sin desplegarlo
automáticamente ni imprimir credenciales.

Archivos locales ignorados por Git, dentro de `.dart_tool/`:

- `conductor-oauth-client.json`: credenciales del cliente web.
- `conductor-picker-key.txt`: clave restringida de Picker.
- `conductor-drive-secrets.env`: secretos destinados exclusivamente a Supabase DEV.

No incluirlos en copias compartidas ni adjuntarlos en chats. El navegador solo
recibe un token de acceso temporal para Picker; el secreto OAuth y el refresh
token permanecen en el servidor local y, tras su configuración, en Supabase.

`node tools/verificar_drive_conductor.mjs` comprueba el rechazo sin sesión,
la renovación de Google y el permiso de carpeta. Agregar `--subir-prueba` crea
una pequeña imagen de prueba, identificada por nombre, en TRANSPORTE. El informe
sin secretos queda en `.dart_tool/conductor-drive-prueba.json`.

## 1. Google Cloud y cuenta empresarial

Crear un proyecto de Google Cloud de la empresa y habilitar **Google Drive API**.
Configurar Google Auth Platform (marca, audiencia y acceso a datos).
Usar una cuenta empresarial que tenga permiso de agregar archivos en
[TRANSPORTE](https://drive.google.com/drive/folders/1KCgLHDHkiek82eyTwpdjfPACmRGC1l7W).
El conector de Drive de Codex no sustituye estas credenciales de la aplicación.

La cuenta debe conservar espacio disponible en Drive. Una cuenta de servicio
no sustituye sin más a la cuenta propietaria de una carpeta de Mi unidad.
Si se utiliza Google Workspace, consultar con el administrador la audiencia
interna y las políticas OAuth. No hacer pública la carpeta para resolver permisos.

## 2. Autorizar la aplicación una vez

Crear un cliente OAuth de tipo «Aplicación web». Configurar una URI de retorno
local exacta para el proceso administrativo de autorización, por ejemplo
`http://localhost:8765/oauth/callback` (no es una URL del portal del conductor).
Usar autorización de servidor con `access_type=offline` y consentimiento para
obtener un refresh token. La contraseña de Google nunca se introduce en ORBILOQ.

Preferir el permiso `https://www.googleapis.com/auth/drive.file` junto con Google
Picker para seleccionar explícitamente la carpeta TRANSPORTE desde **la misma
aplicación OAuth**. Para este procedimiento se habilita también Google Picker API.
Con `drive.file`, compartir la carpeta con la cuenta o copiar su URL no basta:
la aplicación debe recibir acceso a ella mediante el selector de Google.
No usar el permiso de acceso a todo Drive como solución automática.

Este paso de autorización debe completarse con el administrador. El asistente
local anterior permite realizarlo; no es una pantalla pública de ORBILOQ. Verificar
con el token obtenido que `files.get` puede leer la carpeta y que
`capabilities.canAddChildren` es verdadero. Si Google mantiene la aplicación
externa en estado Testing, revisar la vigencia limitada de sus refresh tokens;
no depender de un token temporal para operación continua.

## 3. Secretos del servidor de pruebas

En Supabase DEV → Edge Functions → Secrets, registrar:

- `CONDUCTOR_GOOGLE_CLIENT_ID`
- `CONDUCTOR_GOOGLE_CLIENT_SECRET`
- `CONDUCTOR_GOOGLE_REFRESH_TOKEN`

No pegarlos en chats, código Flutter, archivos versionados ni parámetros de
compilación. El ID de carpeta es fijo en el servidor; el cliente no puede elegir
otro destino. Las variables estándar SUPABASE_URL y SUPABASE_ANON_KEY las aporta
Supabase. No se necesita service_role para esta función.

Desplegar explícitamente en pruebas con la CLI autenticada:

```powershell
supabase functions deploy conductor-evidencia --project-ref igfuafcekcpugpmsoqbe
```

`supabase/config.toml` desactiva la verificación heredada del gateway para esta
función; la propia función verifica JWT con Auth.getUser y consulta el vehículo
con RLS. Rechaza producción incluso si se despliega allí por equivocación.

## 4. Prueba real antes de habilitar uso diario

1. Abrir la app DEV por HTTPS en Android/Chrome e iPhone/Safari; permitir cámara.
2. Capturar, revisar, descartar y repetir. Comprobar que se apaga al cerrar.
3. Seleccionar una foto no sensible y pulsar Guardar registro: confirmar la subida
   automática a TRANSPORTE y el enlace en el historial. No hay carga manual por
   archivo ni campo para pegar enlaces.
4. Repetir con una factura PDF y con las cuatro fotos del seguimiento diario.
5. Guardar el registro, abrir historial y verificar sus enlaces con el conductor
   y el coordinador. Los archivos heredan los permisos de la carpeta: tener rol
   Conductor en ORBILOQ no concede automáticamente permisos en Google Drive.
6. Interrumpir la red durante un lote y volver a pulsar Guardar registro;
   comprobar que los archivos completados no se repiten y la recuperación de
   la subida. La URL de sesión es temporal y no debe registrarse en logs.
7. Probar usuario desactivado/vehículo ajeno: no se debe iniciar la carga.
8. Revisar en Network que las imágenes van a `www.googleapis.com`, mientras
   Supabase recibe solo metadatos de autorización y enlaces de los registros.

No prometer consumo cero: Supabase sigue atendiendo autenticación, metadatos y
registros. Este flujo evita transferir los bytes de fotos/archivos por Supabase.
Google Drive consume su propia cuota de almacenamiento/API. Los archivos son
evidencias privadas y no se cambian sus permisos desde la app.

## Referencias

- [Subida reanudable de Drive](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
- [OAuth de servidor y acceso sin conexión](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Permisos y alcance drive.file](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Google Picker](https://developers.google.com/workspace/drive/picker/guides/overview)
