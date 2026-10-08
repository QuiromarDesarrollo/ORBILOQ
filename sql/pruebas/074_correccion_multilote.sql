-- SOLO ORBILOQ-DEV. No cambia cantidades existentes.
BEGIN;
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true) <> 'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'Revisar el proyecto de pruebas.'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.admin_editar_recepciones(p_item_id uuid,p_campo text,p_valor jsonb,p_motivo text,p_version text,p_recepciones jsonb,p_ubicacion_id uuid,p_confirmar boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE ctx jsonb; antes jsonb; e jsonb; li public.lote_items%rowtype; delta integer; total integer; suma integer:=0; resultado jsonb; paso jsonb;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 IF p_campo IS DISTINCT FROM 'recibido' OR p_confirmar IS NULL OR coalesce(trim(p_motivo),'')='' THEN RAISE EXCEPTION 'Corrección inválida.'; END IF;
 IF jsonb_typeof(p_recepciones) IS DISTINCT FROM 'array' OR jsonb_array_length(p_recepciones)=0 THEN RAISE EXCEPTION 'Selecciona cantidades por lote.'; END IF;
 IF jsonb_typeof(p_valor) IS DISTINCT FROM 'number' OR (p_valor #>> '{}') !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Total inválido.'; END IF;
 LOCK TABLE public.usuarios IN SHARE MODE;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.lotes,public.lote_items,public.movimientos,public.admin_correcciones,public.ubicaciones IN SHARE ROW EXCLUSIVE MODE;
 ctx:=public.admin_contexto_edicion(p_item_id); antes:=ctx->'valores';
 IF p_version IS DISTINCT FROM ctx->>'version' THEN RAISE EXCEPTION 'La fila cambió. Cierra y vuelve a abrir la edición.'; END IF;
 IF (SELECT count(*) <> count(DISTINCT (x->>'id')::uuid) FROM jsonb_array_elements(p_recepciones) x) THEN RAISE EXCEPTION 'Lote repetido.'; END IF;
 FOR e IN SELECT * FROM jsonb_array_elements(p_recepciones) LOOP
   IF jsonb_typeof(e->'cantidad') IS DISTINCT FROM 'number' OR (e->>'cantidad') !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Cantidad por lote inválida.'; END IF;
   SELECT * INTO li FROM public.lote_items WHERE id=(e->>'id')::uuid AND item_orden_id=p_item_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Lote ajeno a la fila.'; END IF;
   IF (e->>'cantidad')::integer > li.cantidad_enviada THEN RAISE EXCEPTION 'La recepción corregida supera lo enviado en el lote.'; END IF;
   suma:=suma+(e->>'cantidad')::integer-coalesce(li.cantidad_recibida,0);
 END LOOP;
 IF suma=0 OR (antes->>'recibido')::integer+suma<>(p_valor #>> '{}')::integer THEN RAISE EXCEPTION 'La suma por lote no coincide con el total deseado.'; END IF;
 -- La revisión ejecuta las mismas validaciones que guardar y revierte todas sus escrituras.
 BEGIN
   total:=(antes->>'recibido')::integer;
   -- Reducciones primero: evita exceder temporalmente lo producido al redistribuir.
   FOR e IN SELECT x FROM jsonb_array_elements(p_recepciones) x JOIN public.lote_items l ON l.id=(x->>'id')::uuid ORDER BY (x->>'cantidad')::integer-coalesce(l.cantidad_recibida,0) LOOP
     SELECT * INTO li FROM public.lote_items WHERE id=(e->>'id')::uuid;
     delta:=(e->>'cantidad')::integer-coalesce(li.cantidad_recibida,0);
     IF delta=0 THEN CONTINUE; END IF;
     total:=total+delta;
     ctx:=public.admin_contexto_edicion(p_item_id);
     paso:=public.admin_editar_kardex(p_item_id,'recibido',to_jsonb(total),p_motivo,ctx->>'version',li.id,p_ubicacion_id,true);
   END LOOP;
   resultado:=jsonb_build_object('antes',antes,'despues',paso->'despues','guardado',p_confirmar);
   IF NOT p_confirmar THEN RAISE EXCEPTION USING ERRCODE='Z0740',MESSAGE='Revisión sin guardar'; END IF;
 EXCEPTION WHEN SQLSTATE 'Z0740' THEN NULL;
 END;
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_editar_recepciones(uuid,text,jsonb,text,text,jsonb,uuid,boolean) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
