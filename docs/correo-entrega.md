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

Con autorización explícita del usuario se ejecutó `node tools/probar_gmail_entregas.mjs --enviar`. Gmail aceptó un mensaje a la misma cuenta autorizada con datos ficticios, LE_PRUEBA.pdf, GUIA_PRUEBA.pdf y logo incrustado. Esta prueba comprueba la conexión OAuth y el envío MIME, no el flujo completo de un despacho real ni la recepción/visualización en el buzón. Queda pendiente la comprobación visual por el usuario y una prueba integrada desde Seguimiento. El comando sin --enviar solo prepara el mensaje localmente.
