-- Exclusivo de pruebas. Inventario libre conserva OP, talla y estante de origen.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.facturacion_le_dato(uuid)') IS NULL OR to_regprocedure('public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere empaque 092 y facturación 097'; END IF;
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='usuarios' AND column_name='roles') THEN RAISE EXCEPTION 'Requiere roles 094'; END IF;
END $$;
DO $$ BEGIN IF to_regprocedure('public.inventario_disponible_op(uuid,uuid)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 101'; END IF; END $$;

-- Artículos de inventario sin OP: permanecen fuera del kardex de producción
-- (sus vistas enlazan con ordenes_produccion). Se conserva el ledger físico.
ALTER TABLE public.items_orden ADD COLUMN IF NOT EXISTS inventario_manual boolean NOT NULL DEFAULT false;
ALTER TABLE public.items_orden ALTER COLUMN orden_id DROP NOT NULL;
ALTER TABLE public.items_orden DROP CONSTRAINT IF EXISTS items_origen_inventario;
ALTER TABLE public.items_orden ADD CONSTRAINT items_origen_inventario CHECK
 ((inventario_manual AND orden_id IS NULL) OR (NOT inventario_manual AND orden_id IS NOT NULL));
CREATE TABLE IF NOT EXISTS public.inventario_importaciones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), huella text UNIQUE NOT NULL,
 solicitud text UNIQUE NOT NULL, archivo text NOT NULL, actor uuid NOT NULL REFERENCES public.usuarios(id),
 fecha timestamptz NOT NULL DEFAULT now(), filas jsonb NOT NULL, unidades bigint NOT NULL
);
ALTER TABLE public.inventario_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventario_importaciones FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.inventario_clave(p_texto text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT upper(regexp_replace(btrim(p_texto),'[[:space:]]+',' ','g'))
$$;
CREATE OR REPLACE FUNCTION public.inventario_importar_excel(p_solicitud text,p_archivo text,p_filas jsonb,p_confirmar boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $$
DECLARE a uuid; canon jsonb; h text; previo public.inventario_importaciones%rowtype;
 r record; uid uuid; iid uuid; carga uuid:=gen_random_uuid(); total bigint;
BEGIN
 PERFORM public.inventario_bloquear(); a:=public.inventario_actor(ARRAY['admin','logistica']);
 IF coalesce(length(p_solicitud),0) NOT BETWEEN 1 AND 128 OR coalesce(length(btrim(p_archivo)),0) NOT BETWEEN 1 AND 255 THEN RAISE EXCEPTION 'Indica archivo y solicitud'; END IF;
 IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Archivo inválido'; END IF;
 IF jsonb_array_length(p_filas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Máximo 1000 combinaciones de prenda y estante'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) f CROSS JOIN unnest(ARRAY['ficha','cliente','codigo','descripcion','talla','estante']) k
 WHERE jsonb_typeof(f->k) IS DISTINCT FROM 'string' OR coalesce(length(btrim(f->>k)),0) NOT BETWEEN 1 AND 500)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_filas) f WHERE coalesce(f->>'cantidad','') !~ '^[1-9][0-9]{0,5}$') THEN RAISE EXCEPTION 'Completa los campos y usa cantidades enteras de 1 a 999999'; END IF;
 SELECT jsonb_agg(to_jsonb(x) ORDER BY cliente,ficha,codigo,talla,estante,descripcion),sum(cantidad) INTO canon,total FROM (
 SELECT public.inventario_clave(f->>'ficha') ficha,public.inventario_clave(f->>'cliente') cliente,
 public.inventario_clave(f->>'codigo') codigo,public.inventario_clave(f->>'descripcion') descripcion,
 public.inventario_clave(f->>'talla') talla,public.inventario_clave(f->>'estante') estante,
 sum((f->>'cantidad')::integer) cantidad FROM jsonb_array_elements(p_filas) f GROUP BY 1,2,3,4,5,6) x;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(canon) f GROUP BY f->>'cliente',f->>'ficha',f->>'codigo',f->>'talla',f->>'estante' HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(canon) f WHERE (f->>'cantidad')::bigint>999999) THEN RAISE EXCEPTION 'Hay descripciones contradictorias o cantidades agrupadas superiores a 999999'; END IF;
 h:=md5(canon::text);
 SELECT * INTO previo FROM public.inventario_importaciones WHERE solicitud=p_solicitud;
 IF FOUND AND previo.huella<>h THEN RAISE EXCEPTION 'Solicitud utilizada con otro archivo'; END IF;
 SELECT * INTO previo FROM public.inventario_importaciones WHERE huella=h;
 IF FOUND THEN RETURN jsonb_build_object('repetido',true,'id',previo.id,'unidades',previo.unidades,'archivo',previo.archivo,'fecha',previo.fecha); END IF;
 FOR r IN SELECT DISTINCT f->>'estante' estante FROM jsonb_array_elements(canon) f LOOP
 IF (SELECT count(*) FROM public.ubicaciones WHERE activa AND public.inventario_clave(codigo)=r.estante)<>1 THEN RAISE EXCEPTION 'Estante inexistente, inactivo o ambiguo: %',r.estante; END IF;
 END LOOP;
 IF p_confirmar IS NOT TRUE THEN RETURN jsonb_build_object('filas',canon,'unidades',total,'repetido',false); END IF;
 INSERT INTO public.inventario_importaciones(id,huella,solicitud,archivo,actor,filas,unidades) VALUES(carga,h,p_solicitud,btrim(p_archivo),a,canon,total);
 FOR r IN SELECT * FROM jsonb_to_recordset(canon) AS x(ficha text,cliente text,codigo text,descripcion text,talla text,estante text,cantidad integer) LOOP
 SELECT id INTO STRICT uid FROM public.ubicaciones WHERE activa AND public.inventario_clave(codigo)=r.estante;
 INSERT INTO public.items_orden(orden_id,inventario_manual,codigo,descripcion,talla,cantidad_pedida,oc)
 VALUES(NULL,true,r.codigo,r.descripcion,r.talla,r.cantidad,NULL) RETURNING id INTO iid;
 INSERT INTO public.movimientos(tipo,item_orden_id,cantidad,ubicacion_id,usuario_id,nota)
 VALUES('recepcion',iid,r.cantidad,uid,a,'Entrada por Excel · '||p_archivo||' · '||carga);
 INSERT INTO public.inventario_transferencias(solicitud,item_id,ubicacion_id,cliente,ficha,cantidad,motivo,actor)
 VALUES('excel:'||carga||':'||iid,iid,uid,r.cliente,r.ficha,r.cantidad,'Entrada por Excel · '||p_archivo,a);
 END LOOP;
 UPDATE public.inventario_actualizacion SET version=version+1 WHERE id;
 RETURN jsonb_build_object('id',carga,'unidades',total,'filas',jsonb_array_length(canon),'repetido',false);
END $$;
REVOKE ALL ON FUNCTION public.inventario_importar_excel(text,text,jsonb,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inventario_importar_excel(text,text,jsonb,boolean) TO authenticated;
-- Mantener el control del cliente al despachar artículos sin OP.
DO $$ DECLARE ddl text; vieja text; BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 vieja:='SELECT cliente INTO cliente_actual FROM public.ordenes_produccion WHERE id=item.orden_id;';
 IF strpos(ddl,'INVENTARIO_EXCEL_105')=0 THEN
 IF strpos(ddl,vieja)=0 THEN RAISE EXCEPTION 'Base de despacho inesperada'; END IF;
 ddl:=replace(ddl,vieja,vieja||E'\n -- INVENTARIO_EXCEL_105\n IF item.inventario_manual THEN SELECT t.cliente INTO cliente_actual FROM public.inventario_transferencias t JOIN public.inventario_despachos d ON d.transferencia=t.id WHERE t.item_id=item.id AND d.solicitud=p_solicitud AND d.actor=actor.id AND NOT d.cancelado; END IF;');
 ddl:=replace(ddl,'(SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id)', 'coalesce((SELECT numero_op FROM public.ordenes_produccion WHERE id=item.orden_id),''INVENTARIO'')');
 EXECUTE ddl; END IF;
 ddl:=pg_get_functiondef('public.inventario_revertir(text,uuid,integer,text)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_EXCEL_105')=0 THEN
 ddl:=replace(ddl,'BEGIN',E'BEGIN\n -- INVENTARIO_EXCEL_105\n IF EXISTS(SELECT 1 FROM public.inventario_transferencias t JOIN public.items_orden i ON i.id=t.item_id WHERE t.id=p_transferencia AND i.inventario_manual) THEN RAISE EXCEPTION ''Una entrada Excel no tiene OP de origen para revertir''; END IF;');
 EXECUTE ddl; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inventario_detalle(p_cliente text,p_ficha text,p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') INTO resultado FROM (
 SELECT s.*,i.descripcion producto,i.codigo,i.talla,coalesce(o.numero_op,'INVENTARIO') numero_op,u.codigo ubicacion,i.inventario_manual entrada_excel,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.despacho_id,'le',l.numero,'cantidad',d.cantidad,'oc',x.oc,'fase',x.fase)),'[]') FROM public.inventario_despachos d JOIN public.despachos_oc x ON x.id=d.despacho_id LEFT JOIN public.listas_empaque l ON l.despacho_id=x.id WHERE d.transferencia=s.id) despachos,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('cantidad',r.cantidad,'motivo',r.motivo,'fecha',r.fecha)),'[]') FROM public.inventario_reversiones r WHERE r.transferencia=s.id) reversiones
 FROM public.inventario_saldos s JOIN public.items_orden i ON i.id=s.item_id LEFT JOIN public.ordenes_produccion o ON o.id=i.orden_id JOIN public.ubicaciones u ON u.id=s.ubicacion_id
 WHERE public.inventario_clave(s.cliente)=public.inventario_clave(p_cliente) AND public.inventario_clave(s.ficha)=public.inventario_clave(p_ficha) ORDER BY s.fecha DESC,s.id LIMIT 50 OFFSET greatest(p_pagina,0)*50) t;
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.inventario_listar(p_buscar text DEFAULT '',p_pagina integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE resultado jsonb; BEGIN
 PERFORM public.inventario_actor();
 IF p_pagina<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 WITH saldos AS MATERIALIZED (
 SELECT item_id,libre,reservado,despachado,ficha,cliente FROM public.inventario_saldos
 ), saldos_por_item AS (
 SELECT item_id,sum(libre) libre,sum(reservado) reservado FROM saldos GROUP BY item_id
 ), base AS (
 SELECT k.*,coalesce(nullif(trim(o.nombre_ficha_tecnica),''),'Sin ficha técnica') ficha,
 coalesce(s.libre,0) libre,coalesce(s.reservado,0) reservado,
 greatest(0,k.recibido-k.despachado-coalesce(s.libre,0)-coalesce(s.reservado,0)) bodega
 FROM public.vista_kardex k JOIN public.items_orden i ON i.id=k.item_orden_id JOIN public.ordenes_produccion o ON o.id=i.orden_id
 LEFT JOIN saldos_por_item s ON s.item_id=i.id
 WHERE i.admin_eliminado_en IS NULL
 ), componentes AS (
 SELECT ficha,cliente,descripcion,greatest(0,cantidad_pedida-producido) pendiente_producir,bodega,0::bigint libre,0::bigint reservado,0::bigint despachado FROM base
 UNION ALL
 SELECT s.ficha,s.cliente,i.descripcion,0,0,s.libre,s.reservado,s.despachado FROM saldos s JOIN public.items_orden i ON i.id=s.item_id
 ), agrupado AS (
 SELECT ficha,cliente,string_agg(DISTINCT descripcion,' · ') producto,sum(pendiente_producir) pendiente_producir,
 sum(bodega) bodega,sum(libre) libre,sum(reservado) reservado,sum(despachado) despachado
 FROM (SELECT public.inventario_clave(ficha) ficha,public.inventario_clave(cliente) cliente,descripcion,pendiente_producir,bodega,libre,reservado,despachado FROM componentes) c WHERE concat_ws(' ',ficha,cliente,descripcion) ILIKE '%'||coalesce(p_buscar,'')||'%' GROUP BY ficha,cliente
 ), pagina AS (SELECT * FROM agrupado ORDER BY cliente,ficha LIMIT 25 OFFSET p_pagina*25)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM agrupado),'filas',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pagina p),'[]')) INTO resultado;
 RETURN resultado;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
