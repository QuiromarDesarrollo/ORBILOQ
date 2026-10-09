# Cierre de pendientes en ORBILOQ-DEV

Preparación del 9 de octubre de 2026. El usuario confirmó la aplicación de 089 en ORBILOQ-DEV; falta recibir el diagnóstico posterior y validar sesiones reales.

Diagnóstico compartido por el usuario el 9 de octubre: las dos firmas de `registrar_no_conforme` ya invocan la validación de 088. Existen las funciones base v87. Las cuatro funciones de Seguimiento todavía usan el permiso anterior y no aparece `seguimiento_acceso`: falta aplicar 089. No hace falta repetir 088 por este hallazgo. Posteriormente, el usuario confirmó haber aplicado 089.

1. Ejecutar `sql/diagnostico/verificar_pendientes_dev.sql` en el SQL Editor de ORBILOQ-DEV. Solo lee estructura y definiciones; no extrae datos de clientes.
2. Revisar los resultados antes de aplicar cambios. Si faltan funciones/columnas de 087, instalar `087_trazabilidad_op.sql`. Instalar `088_no_conforme_stock_disponible.sql` si falta su validación en cualquiera de las firmas de `registrar_no_conforme`.
3. Aplicar `089_permisos_seguimiento.sql` al final. Requiere 087; conserva las funciones base y limita las operaciones y evidencias a cuentas activas Admin/Seguimiento. Despacho conserva empaque e historial. No repetir migraciones anteriores después de 089 porque reemplazan sus permisos.
4. Repetir el diagnóstico. En las cuatro funciones de Seguimiento debe aparecer `permiso_seguimiento=true`; en las dos firmas de `registrar_no_conforme`, `valida_stock_nc=true`. La función `seguimiento_acceso` debe limitar los roles a admin/seguimiento.
5. Publicar la versión configurada para DEV y verificar con sesiones reales de Despacho y Seguimiento, incluyendo salida, PDF, archivos y recuperación de conexión.

No ejecutar `083_reiniciar_movimientos_y_empaques.sql`: es un reinicio destructivo de datos de prueba y no forma parte de esta entrega. Los ensayos locales sí lo utilizan exclusivamente dentro de su PostgreSQL desechable.

El ensayo `tools/ensayar_no_conforme_stock.ps1` valida la cadena de migraciones y repite 089 para comprobar idempotencia, además de probar permisos directos y el flujo de entregas. No conecta con Supabase. El saldo histórico -3 necesita una conciliación con cantidades confirmadas; estas migraciones previenen nuevos errores y no inventan movimientos de compensación.

Producción requiere un paquete propio sobre su estructura verificada: estos archivos llevan restricciones de DEV y no deben aplicarse allí.
