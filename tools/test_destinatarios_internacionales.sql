BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-000000000093','internacional@local');
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email,activo)
 VALUES('ADMIN INTERNACIONAL','admin','00000000-0000-0000-0000-000000000093','993','internacional@local',true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000093',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb := '{"nombre":"DESTINO INTERNACIONAL TEST","direccion":"CALLE 1","tipo_destinatario":"internacional","email":"test@example.com","via":"AÉREA","tipo_carga":"SUELTA","embalaje":"CAJAS DE CARTÓN","puerto_embarque":"EL DORADO","pais_origen":"COLOMBIA","puerto_destino":"REINA BEATRIX","pais_destino":"ARUBA","termino_negociacion":"CIP"}'; filas jsonb;
BEGIN
 PERFORM public.le_importar_clientes('[{"nombre":"DESTINO INTERNACIONAL TEST","direccion":"CALLE 1"}]');
 PERFORM public.le_importar_clientes_internacionales(jsonb_build_array(r));
 PERFORM public.le_importar_clientes_internacionales(jsonb_build_array(r));
 SELECT jsonb_agg(value) INTO filas FROM jsonb_array_elements(public.le_clientes()) WHERE value->'datos'->>'nombre'='DESTINO INTERNACIONAL TEST';
 IF jsonb_array_length(filas)<>2 THEN RAISE EXCEPTION 'Sobrescritura nacional o duplicación internacional'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(filas) WHERE value->'datos'->>'puerto_destino'='REINA BEATRIX') THEN RAISE EXCEPTION 'Perdida de datos'; END IF;
 BEGIN
  PERFORM public.le_importar_clientes_internacionales(jsonb_build_array(r-'pais_destino'));
  RAISE EXCEPTION 'Aceptó incompleto' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL; END;
END $$;
DO $$ DECLARE destino jsonb; e jsonb; packs jsonb; lineas jsonb; r jsonb; doc jsonb;
BEGIN
 SELECT value INTO destino FROM jsonb_array_elements(public.destinatarios_para_empaque()) WHERE value->'datos'->>'tipo_destinatario'='internacional';
 e:=public.admin_empaque_guardar_v92(NULL,NULL,'{"nombre":"Caja internacional","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.5,"activo":true}');
 packs:=jsonb_build_array(jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',1,'version',md5(e::text),'peso_bruto_kg',10));
 lineas:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":1}]';
 r:=public.guardar_empaque_destinatario_v92('intl-snapshot','TEST','TEST-OC',lineas,packs,(destino->>'id')::uuid,destino->>'version');
 PERFORM public.le_importar_clientes_internacionales(jsonb_build_array(destino->'datos'||'{"pais_destino":"OTRO PAIS"}'));
 doc:=public.seguimiento_confirmar((r->>'id')::uuid,0,(destino->>'id')::uuid);
 IF doc->'destinatario' IS DISTINCT FROM destino->'datos' THEN RAISE EXCEPTION 'LE perdió instantánea internacional %',doc; END IF;
 IF public.le_documento('intl-snapshot') IS DISTINCT FROM doc THEN RAISE EXCEPTION 'Reimpresión diferente'; END IF;
END $$;
RESET ROLE;
UPDATE public.usuarios SET rol='despacho' WHERE auth_id='00000000-0000-0000-0000-000000000093';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN
  PERFORM public.le_importar_clientes_internacionales('[]');
  RAISE EXCEPTION 'Aceptó sin permisos';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
