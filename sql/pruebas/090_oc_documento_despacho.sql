-- SOLO ORBILOQ-DEV. Requiere 089. Conserva las OC originales y documentos emitidos.
-- Probar primero con tools/ensayar_trazabilidad_op.ps1. No ejecutar en producción.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.seguimiento_acceso()') IS NULL THEN RAISE EXCEPTION 'Requiere migración 089'; END IF;
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS oc_documento text
 CHECK(oc_documento IS NULL OR (length(oc_documento) BETWEEN 1 AND 150 AND oc_documento=btrim(oc_documento)));
CREATE OR REPLACE FUNCTION public.guardar_empaque_destinatario_v90(
 p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb,p_destinatario uuid,p_destinatario_version text,
 p_id uuid DEFAULT NULL,p_version text DEFAULT NULL,p_motivo text DEFAULT NULL,p_oc_documento text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE a public.usuarios%rowtype; previo public.empaque_solicitudes%rowtype; destino jsonb; r jsonb;
 pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques,
 'destinatario',p_destinatario,'destinatario_version',p_destinatario_version,'id',p_id,'version',p_version,'motivo',p_motivo,'oc_documento',nullif(btrim(p_oc_documento),''));
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 IF length(btrim(p_oc_documento))>150 THEN RAISE EXCEPTION 'La OC del despacho permite máximo 150 caracteres'; END IF;
 SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.empaque_solicitudes WHERE solicitud=p_solicitud;
 IF FOUND THEN
  IF previo.actor<>a.id OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada para otro empaque'; END IF;
  RETURN previo.resultado;
 END IF;
 SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario FOR SHARE;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona el destinatario antes de empacar'; END IF;
 IF p_destinatario_version IS DISTINCT FROM md5(destino::text) THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo y vuelve a generar los rótulos'; END IF;
 IF p_id IS NULL THEN
  IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud ya registrada. Abre su LE para corregir'; END IF;
  r:=public.despachar_oc_bultos(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 ELSE
  IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud de corrección ya registrada'; END IF;
  r:=public.corregir_despacho_le(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 UPDATE public.despachos_oc SET oc_documento=nullif(btrim(p_oc_documento),''),destinatario_id=p_destinatario,destinatario_empaque=destino,empacado_por=a.nombre WHERE id=(r->>'id')::uuid;
 INSERT INTO public.empaque_solicitudes(solicitud,actor,pedido,resultado) VALUES(p_solicitud,a.id,pedido,r);
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) TO authenticated;
-- Solo cambia la OC a imprimir. Las LE emitidas se devuelven intactas;
-- una corrección invalida la LE y conserva su versión anterior en auditoría.
DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('coalesce(d.oc_documento,d.oc)' in f)=0 THEN
  IF position('''oc'',d.oc' in f)=0 THEN RAISE EXCEPTION 'Revisar generador de LE'; END IF;
  EXECUTE replace(f,'''oc'',d.oc','''oc'',coalesce(d.oc_documento,d.oc)');
 END IF;
END $$;
-- Conserva la OC original para cálculos y añade la OC visible del despacho.
DO $$ BEGIN
 IF to_regprocedure('public.historial_despachos_base_v90(text)') IS NULL THEN
  ALTER FUNCTION public.historial_despachos_empaques(text) RENAME TO historial_despachos_base_v90;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.historial_despachos_base_v90(p_despues);
 RETURN coalesce((SELECT jsonb_agg(x.value||jsonb_build_object('oc_documento',coalesce(d.oc_documento,d.oc,x.value->>'oc')) ORDER BY x.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY x
 LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_oc_id')::uuid),'[]');
END $$;
REVOKE ALL ON FUNCTION public.historial_despachos_base_v90(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.historial_despachos_empaques(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.historial_despachos_empaques(text) TO authenticated;
-- Excel conserva la OC del kardex y añade la del despacho en otra columna.
DO $$ BEGIN
 IF to_regprocedure('public.admin_trazabilidad_base_v90(text)') IS NULL THEN
  ALTER FUNCTION public.admin_trazabilidad_op(text) RENAME TO admin_trazabilidad_base_v90;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.admin_trazabilidad_op(p_op text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.admin_trazabilidad_base_v90(p_op);
 RETURN coalesce((SELECT jsonb_agg(x.value||jsonb_build_object('oc_documento',coalesce(d.oc_documento,d.oc)) ORDER BY x.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY x
 LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_id')::uuid),'[]');
END $$;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_base_v90(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_op(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_trazabilidad_op(text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
