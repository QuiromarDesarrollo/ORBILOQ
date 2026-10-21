-- Solo DEV. Unificar cliente únicamente para asignaciones autorizadas de inventario.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 111'; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.despacho_eventos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), despacho_id uuid NOT NULL,
 fecha timestamptz NOT NULL DEFAULT clock_timestamp(), actor text NOT NULL,
 accion text NOT NULL, detalle text NOT NULL DEFAULT '', fuente text NOT NULL,
 antes jsonb, despues jsonb, legado text UNIQUE
);
CREATE INDEX IF NOT EXISTS despacho_eventos_le_fecha ON public.despacho_eventos(despacho_id,fecha,id);
ALTER TABLE public.despacho_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.despacho_eventos FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.despacho_eventos_inmutable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$ BEGIN
 RAISE EXCEPTION 'El historial de despacho es inmutable';
END $$;
DROP TRIGGER IF EXISTS despacho_eventos_inmutable ON public.despacho_eventos;
CREATE TRIGGER despacho_eventos_inmutable BEFORE UPDATE OR DELETE ON public.despacho_eventos
 FOR EACH ROW EXECUTE FUNCTION public.despacho_eventos_inmutable();

CREATE OR REPLACE FUNCTION public.despacho_registrar_evento() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE n jsonb:=to_jsonb(NEW); o jsonb; did uuid; titulo text; texto text:=''; persona text;
BEGIN
 IF TG_OP='UPDATE' THEN o:=to_jsonb(OLD); IF n=o THEN RETURN NEW; END IF; END IF;
 did:=coalesce(n->>'despacho_id',n->>'id')::uuid;
 SELECT nombre INTO persona FROM public.usuarios WHERE auth_id=auth.uid();
 persona:=coalesce(persona,n->>'actor','Sin registrar');
 CASE TG_TABLE_NAME
 WHEN 'despachos_oc' THEN
   IF n->>'ediciones' IS DISTINCT FROM o->>'ediciones' THEN
     titulo:='Despacho corregido';
     SELECT motivo INTO texto FROM public.despacho_revisiones WHERE despacho_id=did ORDER BY edicion DESC LIMIT 1;
   ELSIF n->>'fase' IS DISTINCT FROM o->>'fase' THEN
     titulo:=CASE n->>'fase' WHEN 'empacado' THEN 'Empaque confirmado' WHEN 'cancelado' THEN 'Reserva cancelada' ELSE 'Salida confirmada' END;
     IF n->>'fase'='cancelado' THEN SELECT motivo_cancelacion INTO texto FROM public.inventario_despachos WHERE despacho_id=did AND cancelado LIMIT 1; END IF;
   ELSIF n->>'oc_documento' IS DISTINCT FROM o->>'oc_documento' OR n->>'oc' IS DISTINCT FROM o->>'oc' THEN
     titulo:='OC de despacho actualizada'; texto:=coalesce(n->>'oc_documento',n->>'oc');
   ELSIF n->'destinatario_empaque' IS DISTINCT FROM o->'destinatario_empaque' THEN
     titulo:='Destinatario de despacho actualizado';
   ELSIF n->'empaques' IS DISTINCT FROM o->'empaques' THEN
     titulo:='Contenido o peso de empaques actualizado';
   ELSE RETURN NEW;
   END IF;
 WHEN 'listas_empaque' THEN
   IF n->'datos'->>'pendiente'='true' THEN RETURN NEW; END IF;
   titulo:='Documento LE generado o actualizado'; texto:='LE '||coalesce(n->>'numero','');
 WHEN 'seguimiento_entregas' THEN
   titulo:='Seguimiento actualizado';
   texto:=concat_ws(' · ',n->>'estado',nullif(n->>'transportadora',''),nullif(n->>'placa_guia',''),nullif(n->>'observaciones',''));
 WHEN 'facturacion_le' THEN
   titulo:='Facturación actualizada'; texto:=concat_ws(' · ','Remisión: '||coalesce(n->>'remision',''),'ID OC: '||coalesce(n->>'id_oc',''));
 WHEN 'le_ajustes_admin' THEN
   titulo:='LE ajustada por administrador'; texto:=concat_ws(' · ','Número: '||(n->>'numero_solicitado'),'Fecha: '||(n->>'fecha_solicitada'));
 ELSE RETURN NEW;
 END CASE;
 INSERT INTO public.despacho_eventos(despacho_id,actor,accion,detalle,fuente,antes,despues)
 VALUES(did,persona,titulo,coalesce(texto,''),TG_TABLE_NAME,o,n);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.despacho_registrar_evento(),public.despacho_eventos_inmutable() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS despacho_evento ON public.despachos_oc;
CREATE TRIGGER despacho_evento AFTER UPDATE ON public.despachos_oc FOR EACH ROW EXECUTE FUNCTION public.despacho_registrar_evento();
DO $$ DECLARE tabla text; BEGIN
 FOREACH tabla IN ARRAY ARRAY['listas_empaque','seguimiento_entregas','facturacion_le','le_ajustes_admin'] LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS despacho_evento ON public.%I',tabla);
 EXECUTE format('CREATE TRIGGER despacho_evento AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.despacho_registrar_evento()',tabla);
 END LOOP;
END $$;
-- Los datos anteriores se identifican como tales: no se reconstruyen cambios inexistentes.
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT d.id,d.fecha,d.actor,'Registro previo de despacho',d.fase,'despachos_oc',to_jsonb(d),'despacho:'||d.id
FROM public.despachos_oc d WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=d.id)
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT s.despacho_id,s.actualizado_en,coalesce(u.nombre,'Sin registrar'),'Seguimiento previo disponible',
 concat_ws(' · ',s.estado,s.transportadora,s.placa_guia,s.observaciones),'seguimiento_entregas',to_jsonb(s),'seguimiento:'||s.despacho_id||':'||s.revision
FROM public.seguimiento_entregas s LEFT JOIN public.usuarios u ON u.auth_id=s.actualizado_por
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=s.despacho_id AND e.fuente='seguimiento_entregas')
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT f.despacho_id,f.actualizado_en,coalesce(u.nombre,'Sin registrar'),'Facturación previa disponible',
 concat_ws(' · ',f.remision,f.id_oc),'facturacion_le',to_jsonb(f),'facturacion:'||f.despacho_id||':'||f.revision
FROM public.facturacion_le f LEFT JOIN public.usuarios u ON u.auth_id=f.actualizado_por
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=f.despacho_id AND e.fuente='facturacion_le')
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,antes,legado)
SELECT r.despacho_id,r.fecha,coalesce(u.nombre,'Sin registrar'),'Despacho corregido',r.motivo,'despacho_revisiones',r.anterior,'revision:'||r.id
FROM public.despacho_revisiones r LEFT JOIN public.usuarios u ON u.id=r.actor
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=r.despacho_id AND e.accion='Despacho corregido' AND e.despues->>'ediciones'=r.edicion::text)
ON CONFLICT(legado) DO NOTHING;
INSERT INTO public.despacho_eventos(despacho_id,fecha,actor,accion,detalle,fuente,despues,legado)
SELECT a.despacho_id,a.fecha_registro,coalesce(u.nombre,'Sin registrar'),'LE ajustada por administrador',
 concat_ws(' · ','Número: '||a.numero_solicitado,'Fecha: '||a.fecha_solicitada),'le_ajustes_admin',to_jsonb(a),'admin:'||a.despacho_id||':'||a.revision
FROM public.le_ajustes_admin a LEFT JOIN public.usuarios u ON u.id=a.actor
WHERE NOT EXISTS(SELECT 1 FROM public.despacho_eventos e WHERE e.despacho_id=a.despacho_id AND e.fuente='le_ajustes_admin')
ON CONFLICT(legado) DO NOTHING;
DO $$ BEGIN
 IF to_regprocedure('public.historial_despachos_base_v113(text)') IS NULL THEN
 ALTER FUNCTION public.historial_despachos_empaques(text) RENAME TO historial_despachos_base_v113;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb; BEGIN
 filas:=public.historial_despachos_base_v113(p_despues);
 RETURN coalesce((SELECT jsonb_agg(f.value||jsonb_build_object('eventos',coalesce(e.eventos,'[]'::jsonb)) ORDER BY f.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY f
 LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('id',h.id,'fecha',h.fecha,'actor',h.actor,'accion',h.accion,'detalle',h.detalle) ORDER BY h.fecha DESC,h.id) eventos
 FROM public.despacho_eventos h WHERE h.despacho_id=(f.value->>'despacho_oc_id')::uuid) e ON true),'[]');
END $$;
REVOKE ALL ON FUNCTION public.historial_despachos_base_v113(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.historial_despachos_empaques(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.historial_despachos_empaques(text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
