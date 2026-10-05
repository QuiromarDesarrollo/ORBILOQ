-- SOLO LECTURA. Ejecutar después del 002 y antes de reabrir operaciones.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT 'conteos' AS comprobacion, jsonb_build_object(
 'ordenes',(SELECT count(*) FROM public.ordenes_produccion),
 'lineas',(SELECT count(*) FROM public.items_orden),
 'movimientos',(SELECT count(*) FROM public.movimientos),
 'lotes',(SELECT count(*) FROM public.lotes),
 'lineas_lote',(SELECT count(*) FROM public.lote_items),
 'usuarios',(SELECT count(*) FROM public.usuarios),
 'correcciones',(SELECT count(*) FROM public.admin_correcciones),
 'despachos_oc',(SELECT count(*) FROM public.despachos_oc)) AS resultado;
SELECT numero_op,codigo,talla,cantidad_pedida,producido,recibido,despachado,pendiente_reproceso
FROM public.vista_kardex WHERE numero_op='25438' AND codigo='2026556528' AND talla='30';
SELECT p.proname,pg_get_function_arguments(p.oid) AS argumentos,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS permite_autenticados,
 has_function_privilege('anon',p.oid,'EXECUTE') AS permite_anonimos
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('recibir_lote_item','admin_editar_kardex','admin_reporte_resumen','despachar_oc','admin_usuario_registrar')
ORDER BY p.proname,p.pronargs;
SELECT 'perfiles_historicos' AS comprobacion,count(*) AS conservados
FROM public.usuarios WHERE auth_id IS NULL AND nombre IN
 ('Operario Confección 1','Planta Corte Bogotá','Taller Externo');
SELECT conname,pg_get_constraintdef(oid) AS regla,convalidated
FROM pg_constraint WHERE conrelid='public.movimientos'::regclass AND contype='c';
COMMIT;
