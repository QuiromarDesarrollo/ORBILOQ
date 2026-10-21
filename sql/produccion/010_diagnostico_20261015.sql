-- PRODUCCION confirmada: cxrflhgnxvomcvxzugda. SOLO LECTURA.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='60s';
SELECT jsonb_build_object(
 'fecha_utc',now(), 'proyecto_configurado',current_setting('app.settings.project_ref',true),
 'base',current_database(),
 'funciones',(SELECT jsonb_agg(jsonb_build_object('firma',format('%I.%I(%s)',n.nspname,p.proname,oidvectortypes(p.proargtypes)),
   'md5',md5(replace(pg_get_functiondef(p.oid),E'\r\n',E'\n')))) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind IN ('f','p')),
 'conteos',jsonb_build_object('op',(SELECT count(*) FROM public.ordenes_produccion),'items',(SELECT count(*) FROM public.items_orden),
 'movimientos',(SELECT count(*) FROM public.movimientos),'lotes',(SELECT count(*) FROM public.lotes),'usuarios',(SELECT count(*) FROM public.usuarios),
 'auth_usuarios',(SELECT count(*) FROM auth.users),'despachos',(SELECT count(*) FROM public.despachos_oc),
 'destinatarios',(SELECT count(*) FROM public.destinatarios_empaque),'empaques',(SELECT count(*) FROM public.empaques)),
 'secuencias',(SELECT jsonb_agg(to_jsonb(s)) FROM pg_sequences s WHERE schemaname='public'),
 'storage',(SELECT jsonb_agg(x) FROM (SELECT b.id,b.public,count(o.id) objetos,sum(CASE WHEN o.metadata->>'size' ~ '^[0-9]+$' THEN (o.metadata->>'size')::bigint ELSE 0 END) bytes FROM storage.buckets b LEFT JOIN storage.objects o ON o.bucket_id=b.id GROUP BY b.id,b.public) x),
 'nuevas_instaladas',jsonb_build_object(
 'v95',to_regprocedure('public.admin_destinatario_editar(uuid,jsonb,jsonb)') IS NOT NULL,
 'v96',to_regprocedure('public.dashboard_despachos_mensuales(date,date,text,timestamptz)') IS NOT NULL,
 'v97',to_regclass('public.facturacion_le') IS NOT NULL,
 'v98',to_regprocedure('public.dashboard_facturacion_semanal(date,date,text,timestamptz)') IS NOT NULL,
 'v99',to_regprocedure('public.admin_confirmar_le(uuid,integer,uuid,jsonb,bigint,date)') IS NOT NULL,
 'v100',to_regprocedure('public.dashboard_puntualidad_mensual(date,date,text,timestamptz)') IS NOT NULL)
);
COMMIT;
