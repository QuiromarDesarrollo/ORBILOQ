-- Diagnóstico de solo lectura. Ejecutar en ORBILOQ-DEV y compartir resultados.
-- No modifica funciones, usuarios, permisos ni inventario.
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS firma,
       pg_get_functiondef(p.oid) AS definicion
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f'
  AND (
    p.proname='kardex_historico'
    OR (
      p.prosrc ~ $patron$\mrol\s+IN\s*\(('(?:admin|produccion|logistica|despacho|seguimiento|gerencia)'(?:\s*,\s*'(?:admin|produccion|logistica|despacho|seguimiento|gerencia)')*)\)$patron$
      AND p.proname NOT IN (
        'crear_lote','enviar_no_conforme_aliado','liberar_no_conforme','liberar_no_conforme_aliado',
        'recibir_lote_item','cerrar_lote_item_con_faltante','registrar_no_conforme',
        'registrar_sobrante','resolver_sobrante','validar_stock_no_conforme',
        'despachar_oc','despachar_oc_empaques','despachar_oc_prendas_empaques',
        'historial_despachos_oc','empaques_listar','le_acceso','seguimiento_acceso',
        'wms_cuenta_operativa','puede_ver_dashboards','kardex_historico'
      )
    )
  )
ORDER BY p.proname, firma;
