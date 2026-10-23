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

 -- El automático reservado debe quedar disponible; un reintento no lo libera dos veces.
 PERFORM set_config('test.anterior',ctx->>'le_numero',true);
 r:=public.guardar_empaque_destinatario_v92('auto-despues-manual','TEST','TEST-OC',lineas,packs,(destino->>'id')::uuid,destino->>'version');
 ctx:=public.despacho_para_corregir((r->>'id')::uuid);
 IF ctx->>'le_numero' IS DISTINCT FROM current_setting('test.anterior') THEN RAISE EXCEPTION 'Saltó el automático liberado: %',ctx; END IF;
 -- Confirmar el mismo número no debe liberarlo ni duplicarlo.
 doc:=public.admin_confirmar_le((r->>'id')::uuid,0,(destino->>'id')::uuid,'{}',(ctx->>'le_numero')::bigint);
 PERFORM set_config('test.confirmado',doc->>'numero',true);
END $$;
RESET ROLE;
DO $$ DECLARE n bigint; v bigint; BEGIN
 IF EXISTS(SELECT 1 FROM public.le_numeros_disponibles WHERE numero=current_setting('test.confirmado')::bigint) THEN RAISE EXCEPTION 'Liberó el número confirmado'; END IF;
 -- Dos reservas simultáneamente abiertas: recuperar la primera sin retroceder el contador.
 SELECT siguiente INTO n FROM public.lista_empaque_config WHERE id=true FOR UPDATE;
 INSERT INTO public.le_numeros_disponibles(numero,despacho_origen)
 SELECT n-1,id FROM public.despachos_oc LIMIT 1;
 -- Si un número está ocupado, nunca se entrega de nuevo.
 UPDATE public.le_numeros_disponibles SET numero=current_setting('test.confirmado')::bigint;
 v:=public.le_tomar_numero_disponible(n);
 IF v<>n THEN RAISE EXCEPTION 'Reutilizó un ocupado'; END IF;
 INSERT INTO public.le_numeros_disponibles(numero,despacho_origen) SELECT 1054,id FROM public.despachos_oc LIMIT 1;
 BEGIN
  PERFORM public.le_tomar_numero_disponible(n);
  RAISE EXCEPTION 'Simular fallo';
 EXCEPTION WHEN raise_exception THEN NULL;
 END;
 IF NOT EXISTS(SELECT 1 FROM public.le_numeros_disponibles WHERE numero=1054) THEN RAISE EXCEPTION 'El fallo consumió la reserva'; END IF;
 IF has_function_privilege('authenticated','public.le_tomar_numero_disponible(bigint)','EXECUTE') THEN RAISE EXCEPTION 'Asignador expuesto'; END IF;
END $$;
ROLLBACK;
