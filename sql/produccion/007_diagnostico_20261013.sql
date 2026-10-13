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
 'nuevas_instaladas',jsonb_build_object('v90',to_regprocedure('public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NOT NULL,
 'v92',to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NOT NULL,
 'v93',to_regprocedure('public.le_importar_clientes_internacionales(jsonb)') IS NOT NULL,
 'v94',to_regprocedure('public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)') IS NOT NULL)
);
COMMIT;
