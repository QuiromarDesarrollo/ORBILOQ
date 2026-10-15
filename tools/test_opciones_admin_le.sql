-- Solo servidor local del ensayo; no ejecutar en Supabase.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE e jsonb; destino jsonb; packs jsonb; lineas jsonb; r jsonb; doc jsonb; ctx jsonb;
 historico jsonb; falla boolean; opcion text; bruto numeric; BEGIN
 historico:=public.le_documento('destino-test');
 destino:=public.destinatarios_para_empaque()->0;
 e:=public.admin_empaque_guardar_v92(NULL,NULL,'{"nombre":"Paquete pesado","categoria":"BOLSA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.5,"activo":true}');
 IF e->>'peso_bruto_kg' IS NOT NULL THEN RAISE EXCEPTION 'Catálogo exige bruto'; END IF;
 packs:=jsonb_build_array(
  jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',2,'version',md5(e::text),'peso_bruto_kg',10),
  jsonb_build_object('numero',1,'item_id','0701856a-7771-4536-9762-658a58af8804','empaque_id',e->>'id','cantidad',1,'version',md5(e::text),'peso_bruto_kg',10));
 lineas:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":2},{"item_id":"0701856a-7771-4536-9762-658a58af8804","ubicacion":"TEST-A","cantidad":1}]';
 FOREACH opcion IN ARRAY ARRAY['null','0','-1','0.4','100001'] LOOP
  falla:=false;
  BEGIN PERFORM public.guardar_empaque_destinatario_v92('peso-invalido','TEST','TEST-OC',lineas,jsonb_set(packs,'{0,peso_bruto_kg}',opcion::jsonb),(destino->>'id')::uuid,destino->>'version'); EXCEPTION WHEN raise_exception THEN falla:=true; END;
  IF NOT falla THEN RAISE EXCEPTION 'Aceptó peso inválido %',opcion; END IF;
 END LOOP;
 falla:=false;
 BEGIN PERFORM public.guardar_empaque_destinatario_v92('peso-distinto','TEST','TEST-OC',lineas,jsonb_set(packs,'{0,peso_bruto_kg}','11'),(destino->>'id')::uuid,destino->>'version'); EXCEPTION WHEN raise_exception THEN falla:=true; END;
 IF NOT falla THEN RAISE EXCEPTION 'Aceptó dos pesos para una pieza'; END IF;
 r:=public.guardar_empaque_destinatario_v92('peso-real','TEST','TEST-OC',lineas,packs,(destino->>'id')::uuid,destino->>'version');
 IF public.guardar_empaque_destinatario_v92('peso-real','TEST','TEST-OC',lineas,packs,(destino->>'id')::uuid,destino->>'version') IS DISTINCT FROM r THEN RAISE EXCEPTION 'Peso no idempotente'; END IF;
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(ctx->'empaques') x WHERE (x->>'peso_bruto_kg')::numeric<>10 OR (x->>'peso_tara_kg')::numeric<>0.5 OR (x->>'peso_neto_kg')::numeric<>9.5) THEN RAISE EXCEPTION 'Pesos incorrectos %',ctx; END IF;
 falla:=false;
 BEGIN PERFORM public.admin_confirmar_le((r->>'id')::uuid,0,(destino->>'id')::uuid,'{}',(historico->>'numero')::bigint,'2025-01-15'); EXCEPTION WHEN raise_exception THEN falla:=true; END;
 IF NOT falla THEN RAISE EXCEPTION 'Acepto numero duplicado'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 falla:=false;
 BEGIN PERFORM public.admin_confirmar_le((r->>'id')::uuid,0,(destino->>'id')::uuid,'{}',99999,'2025-01-15'); EXCEPTION WHEN insufficient_privilege THEN falla:=true; END;
 IF NOT falla THEN RAISE EXCEPTION 'Acepto usuario sin admin'; END IF;
 falla:=false;
 BEGIN PERFORM public.guardar_empaque_destinatario_v92('no-admin-masivo','TEST','TEST-OC',lineas,jsonb_set(packs,'{0,admin_masivo}','true'),(destino->>'id')::uuid,destino->>'version'); EXCEPTION WHEN insufficient_privilege THEN falla:=true; END;
 IF NOT falla THEN RAISE EXCEPTION 'Acepto masivo sin admin'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 doc:=public.admin_confirmar_le((r->>'id')::uuid,0,(destino->>'id')::uuid,'{}',99999,'2025-01-15');
 IF doc->>'numero'<>'99999' OR (doc->>'fecha')::timestamptz AT TIME ZONE 'America/Bogota' <> timestamp '2025-01-15 12:00' THEN RAISE EXCEPTION 'No ajusto numero/fecha %',doc; END IF;
 IF public.admin_confirmar_le((r->>'id')::uuid,0,(destino->>'id')::uuid,'{}',99999,'2025-01-15') IS DISTINCT FROM doc THEN RAISE EXCEPTION 'Reintento diferente'; END IF;
 IF public.le_documento('peso-real') IS DISTINCT FROM doc THEN RAISE EXCEPTION 'PDF no conserva fecha/numero'; END IF;
 SELECT sum(peso) INTO bruto FROM (SELECT (x->>'numero')::integer,max((x->>'peso_bruto_kg')::numeric) peso FROM jsonb_array_elements(doc->'empaques') x GROUP BY 1) por_pieza;
 IF bruto<>10 THEN RAISE EXCEPTION 'Duplicó peso por talla'; END IF;
 -- Corrección de una LE liberada: nuevo peso y misma pieza compartida.
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 packs:=jsonb_set(jsonb_set(packs,'{0,peso_bruto_kg}','12'),'{1,peso_bruto_kg}','12');
 r:=public.guardar_empaque_destinatario_v92('peso-corregido','TEST','TEST-OC',lineas,packs,(destino->>'id')::uuid,destino->>'version',(r->>'id')::uuid,ctx->>'version','Ajuste del peso real');
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(ctx->'empaques') x WHERE (x->>'peso_bruto_kg')::numeric<>12 OR (x->>'peso_neto_kg')::numeric<>11.5) THEN RAISE EXCEPTION 'Corrección perdió pesos %',ctx; END IF;
 doc:=public.seguimiento_confirmar((r->>'id')::uuid,1,(destino->>'id')::uuid);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'empaques') x WHERE (x->>'peso_neto_kg')::numeric<>11.5) THEN RAISE EXCEPTION 'LE corregida perdió pesos'; END IF;
 -- El catálogo se modifica sin reescribir el documento emitido.
 PERFORM public.admin_empaque_guardar_v92((e->>'id')::uuid,md5(e::text),e||'{"peso_neto_kg":1}');
 IF public.le_documento('peso-real') IS DISTINCT FROM doc THEN RAISE EXCEPTION 'Catálogo alteró LE histórica'; END IF;
 IF public.le_documento('destino-test') IS DISTINCT FROM historico THEN RAISE EXCEPTION 'Alteró documento previo'; END IF;
 IF has_function_privilege('authenticated','public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)','EXECUTE') THEN RAISE EXCEPTION 'Permite omitir pesos usando cliente antiguo'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT siguiente FROM public.lista_empaque_config WHERE id=true)>99999 THEN RAISE EXCEPTION 'Modifico consecutivo general'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.le_ajustes_admin WHERE numero_solicitado=99999 AND fecha_solicitada='2025-01-15') THEN RAISE EXCEPTION 'No audito cambio'; END IF;
END $$;
ROLLBACK;
