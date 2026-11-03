# Confirmación de entrega a la comercial

Implementación para master / ORBILOQ-DEV. Producción no está habilitada.

## Uso

En Seguimiento, al seleccionar **Entregado**, aparece **Correo de la comercial (opcional)**. Con correo y fecha de recibido, Guardar cambios guarda la entrega y una notificación en una única transacción; después el cliente solicita el envío. Sin correo conserva el flujo anterior. No anuncia éxito para estados con novedad o devoluciones.

El mensaje contiene cliente, destinatario, OC, LE, OP distintas y fecha de recibido. Adjunta los archivos ya guardados en evidencia_le / evidencia_guia (PDF o imagen, hasta 10 MB cada uno). No genera documentos que no existan. Si no hay archivos, lo indica. El logo ORBILOQ va incrustado por CID; la plantilla tiene texto alternativo y HTML con tablas y estilos inline.

Los datos y adjuntos se congelan al confirmar. Una notificación por despacho y revisión: posteriores guardados no vuelven a enviar ni cambian el destinatario. Para correcciones posteriores se requiere revisión administrativa; no se ofrece un reenvío libre que pueda duplicar mensajes. El estado “aceptado por el servicio” no confirma recepción en el buzón ni lectura.

Si falla la red, el proveedor o la configuración, la entrega permanece guardada. La notificación queda visible al volver a abrir el seguimiento; **Reintentar correo** conserva la misma notificación. Gmail no ofrece una clave idempotente: si el envío comenzó y no se recibió una confirmación, pasa a revisión manual; hay que comprobar Enviados antes de repetirlo. Una reserva abandonada antes de enviar puede recuperarse a los 5 minutos. Los rechazos inequívocos y errores previos al envío permiten reintento. No hay un trabajador programado: el primer intento es automático al guardar; los pendientes requieren reintento desde Seguimiento.

## Configuración y despliegue DEV

1. Habilitar Gmail API en ORBILOQ Transporte. Usar exclusivamente `analistasdedatosing@gmail.com`, autorizada por el usuario. No requiere DNS.
2. Ejecutar `node tools/conectar_gmail_entregas.mjs` y autorizar `gmail.send`, `openid` y `email`. Se verifica la dirección y se guarda `.dart_tool/entrega-gmail-secrets.env` (ignorado por Git). Instalar los cuatro secretos `ENTREGA_GOOGLE_CLIENT_ID`, `ENTREGA_GOOGLE_CLIENT_SECRET`, `ENTREGA_GOOGLE_REFRESH_TOKEN`, `ENTREGA_GMAIL_FROM` en Supabase DEV. No reemplazar los secretos `CONDUCTOR_GOOGLE_*` de Drive. En modo Pruebas de Google el token puede expirar a los siete días; resolver la publicación/verificación apropiada antes de considerar la conexión permanente.
3. Aplicar `sql/pruebas/117_correo_entrega.sql` en DEV. Requiere la estructura existente y la RPC v87. Es repetible y conserva las funciones anteriores. El cliente detecta servidores sin 117 y mantiene el guardado sin notificación.
4. Desplegar `supabase/functions/entrega-correo` con todos sus módulos, incluyendo logo.mjs. La función verifica JWT con Auth y permiso activo de administrador/seguimiento antes de leer la cola. No acepta destinatarios, HTML ni rutas de archivo desde el navegador.
5. Publicar el cliente master en pruebas y realizar un envío a un buzón autorizado: LE+guía, LE sola, guía sola; comprobar adjuntos y logo en el cliente de correo real.

Estado verificado el 21 de octubre de 2026: Gmail API habilitada, consentimiento concedido y cuatro secretos instalados exclusivamente en Supabase DEV. SQL 117 aplicado y función entrega-correo desplegada. La función valida la sesión con Auth y los permisos con RPC; solicitudes sin sesión devuelven 401 y con token inválido 403. Compilación web completada y vista local disponible; no se publicó el cliente en un hosting remoto. No se modificó producción. Las credenciales permanecen fuera del código versionado; la dirección remitente autorizada sí figura en el código y esta documentación.

El remitente está fijado a la cuenta autorizada. El contenido MIME incluye texto y HTML UTF-8, archivos en base64 y logo inline. El Message-ID estable identifica el aviso, pero no se considera una garantía de deduplicación de Gmail.

## Validación local

- `node tools/test_entrega_correo.mjs`: envío simulado con cero/uno/dos documentos, permisos, fallos, escape HTML e idempotencia.
- `node tools/test_entrega_correo_sql.mjs`: PostgreSQL embebido con fixture mínimo; migración repetida, rollback, privacidad, OP, unicidad, bloqueo y recuperación de envío incierto. La RPC anterior se simula; no sustituye la prueba integrada en DEV.
- `flutter test test/seguimiento_entregas_test.dart`: formulario, validación y diseño móvil.

Documentación: https://developers.google.com/workspace/gmail/api/guides/sending y https://developers.google.com/workspace/gmail/api/auth/scopes.

## Prueba real de Gmail

### Diagnóstico del 30 de octubre de 2026

La renovación de la credencial local instalada el 21 de octubre devuelve `invalid_grant` (vencida o revocada). Google Cloud muestra el proyecto `orbiloq-transporte` en Prueba y la publicación deshabilitada por información de marca incompleta. No se ha renovado la autorización ni enviado un correo durante este diagnóstico. No considerar el servicio restablecido.

La web corporativa enlaza «Política de Datos Personales» a un formulario de autorización: https://grupoquiromar.com/wp-content/uploads/2020/05/autorizacion_de_tratamiento_de_datos_personales_grupo_quiromar.pdf. Ese documento no describe las integraciones de ORBILOQ. Se preparó `output/privacidad-orbiloq-borrador.html` para revisión interna, sin publicación: faltan confirmar canal de atención, conservación/eliminación y compromisos organizacionales. No sustituye una política aprobada.

El código local distingue autorización vencida, configuración y fallos temporales; valida OAuth antes de descargar adjuntos o marcar el envío iniciado. Los pendientes siguen guardados y el aviso de entrega con correo pendiente se muestra como advertencia. Estos ajustes todavía no están desplegados en la función DEV. Requieren incluir el nuevo módulo `oauth.mjs` al desplegar. No se ha modificado producción.

Con autorización explícita del usuario se ejecutó `node tools/probar_gmail_entregas.mjs --enviar`. Gmail aceptó un mensaje a la misma cuenta autorizada con datos ficticios, LE_PRUEBA.pdf, GUIA_PRUEBA.pdf y logo incrustado. Esta prueba comprueba la conexión OAuth y el envío MIME, no el flujo completo de un despacho real ni la recepción/visualización en el buzón. Queda pendiente la comprobación visual por el usuario y una prueba integrada desde Seguimiento. El comando sin --enviar solo prepara el mensaje localmente.

### Publicación de la actualización 20261030 (3 de noviembre)

Se desplegó en producción `entrega-correo` con el módulo OAuth incorporado. El dashboard confirmó la actualización y una solicitud sin sesión devolvió HTTP 401. No se cambiaron secretos ni se envió un correo durante esta publicación. Esto verifica disponibilidad y rechazo anónimo, no restablece la autorización de Google ni acredita un envío real. El diagnóstico de credencial vencida anterior sigue siendo un pendiente separado.

### Corrección del 3 de noviembre de 2026

El usuario confirmó el contacto analistasdedatosing@gmail.com, conservación de un año y eliminación gestionada por administrador/TI. Aprobó expresamente `web/privacidad.html`, publicado en https://quiromardesarrollo.github.io/ORBILOQ/privacidad.html (HTTP 200) y registrado en Google Auth Platform. También confirmó cambiar OAuth de Prueba a Producción; el dashboard mostró «En producción». Esto no equivale a verificación de la aplicación por Google: durante la nueva autorización aparece el aviso de app no verificada.

Autorización nueva pendiente de completar por el titular en el navegador. Aún no se han reemplazado secretos de Supabase ni enviado la prueba de este turno. Usuario autorizó una prueba exclusivamente a su propia cuenta, con asunto [PRUEBA ORBILOQ], dos PDF ficticios y logo. No declarar correo restablecido hasta instalar la autorización y comprobar el envío.

El titular completó la autorización local el 3 de noviembre a las 07:55 (Bogotá). Se ejecutó la prueba ficticia aprobada y Gmail aceptó un mensaje con dos PDF y logo a analistasdedatosing@gmail.com; resultado privado en `.dart_tool/gmail-prueba-resultado.json`. Esto valida OAuth y el envío directo, no acredita todavía la configuración del servicio en producción. La instalación de los cuatro secretos ENTREGA_* en Supabase quedó detenida por revisión automática de permisos del navegador y se solicitó autorización delimitada al usuario. No se han tocado secretos de Drive ni datos operativos.

### Cierre de la reconexión (3 de noviembre, 12:57 UTC)

Con autorización específica del usuario se instalaron únicamente los cuatro secretos ENTREGA_* en producción cxrflhgnxvomcvxzugda. El dashboard mostró fecha 03 Nov 2026 12:57:39 UTC y las cuatro huellas SHA-256 coincidieron con la autorización local probada. Las tres huellas CONDUCTOR_* permanecieron iguales. Evidencia privada: `.dart_tool/gmail-produccion-instalado-20261103.json`.

Resultado: política pública aprobada, OAuth En producción, autorización renovada, configuración instalada y correo ficticio aceptado por Gmail. No se ejecutó un despacho real ni se comprobó visualmente la recepción en el buzón. La prueba fue directa contra Gmail con los mismos valores instalados, no un envío a clientes desde Seguimiento. Google puede revocar una autorización por otras causas; salir de Prueba elimina la caducidad de siete días propia de ese modo, no garantiza duración perpetua. El aviso de app no verificada no equivale a app verificada: no se completó una verificación formal de Google.
