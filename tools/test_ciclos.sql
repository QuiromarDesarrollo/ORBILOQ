-- Ensayo local, nunca producción.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
-- El servidor local no incluye safeupdate: verificar también las cláusulas
-- que requiere Supabase, además de los casos funcionales de abajo.
DO $$ DECLARE firma text; d text; BEGIN
 FOREACH firma IN ARRAY ARRAY[
  'public.ciclos_configurar(text,date,integer,integer,integer,text,integer)',
  'public.ciclos_importar(jsonb,text,boolean,text)'
 ] LOOP
  d:=pg_get_functiondef(to_regprocedure(firma));
  IF position('UPDATE public.ciclos_revision SET revision=revision+1 WHERE id = true;' IN d)=0
  THEN RAISE EXCEPTION 'Revision sin WHERE en %',firma; END IF;
  IF firma LIKE '%ciclos_configurar%' AND position('WHERE o.versiones IS DISTINCT FROM public.ciclos_versiones(o.inicio,o.fines,o);' IN d)=0
  THEN RAISE EXCEPTION 'Asignacion de versiones sin filtro'; END IF;
 END LOOP;
END $$;
INSERT INTO auth.users(id,email) SELECT ('00000000-0000-0000-0000-00000000000'||n)::uuid,n||'@orbiloq.local' FROM generate_series(1,5)n;
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email)
 SELECT 'TEST '||n,r,('00000000-0000-0000-0000-00000000000'||n)::uuid,n::text,n||'@orbiloq.local'
 FROM (VALUES(1,'admin'),(2,'produccion'),(3,'logistica'),(4,'despacho'),(5,'gerencia'))x(n,r);
GRANT USAGE ON SCHEMA auth TO authenticated;
CREATE FUNCTION pg_temp.denegado(q text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE q;
 EXCEPTION WHEN insufficient_privilege THEN RETURN;
 WHEN raise_exception THEN IF SQLERRM='Acceso exclusivo del administrador.' THEN RETURN; END IF; RAISE;
 END;
 RAISE EXCEPTION 'Operacion prohibida permitida: %',q;
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
DO $$ DECLARE p text; r text; filas jsonb; j jsonb; antigua text; BEGIN
 FOREACH p IN ARRAY ARRAY['compras','trazo','corte','separado','aliados','terminado','logistica'] LOOP
   r:=public.ciclos_estado()->>'revision';
   PERFORM public.ciclos_configurar(p,'2026-01-01',3,10,CASE p WHEN 'corte' THEN 7000 WHEN 'separado' THEN 7000 WHEN 'aliados' THEN 17000 ELSE NULL END,r);
 END LOOP;
 r:=public.ciclos_estado()->>'revision';
 filas:='[{"op":"OS421","cliente":"PRUEBA","cantidad":20,"inicio":"2026-09-01","fines":{"compras":"2026-09-03","trazo":"2026-09-04","corte":null,"separado":null,"aliados":null,"terminado":null,"logistica":null}},
 {"op":"OTRA","cliente":"PRUEBA","cantidad":30,"inicio":null,"fines":{"compras":null,"trazo":null,"corte":null,"separado":null,"aliados":null,"terminado":null,"logistica":null}}]';
 j:=public.ciclos_importar(filas,r,false,'historico.xlsx');
 IF (j->>'nuevas')::int<>2 OR jsonb_array_length(public.ciclos_pagina('',r))<>0 THEN RAISE EXCEPTION 'Preview muta o falla'; END IF;
 PERFORM public.ciclos_importar(filas,r,true,'historico.xlsx');
 r:=public.ciclos_estado()->>'revision';
 j:=public.ciclos_pagina('',r);
 IF jsonb_array_length(j)<>2 THEN RAISE EXCEPTION 'Faltan OP'; END IF;
 SELECT x->'versiones'->>'compras' INTO antigua FROM jsonb_array_elements(j)x WHERE x->>'op'='OS421';
 IF antigua IS NULL THEN RAISE EXCEPTION 'No asigno version'; END IF;
 -- Configuración retroactiva no reescribe una versión ya asociada.
 PERFORM public.ciclos_configurar('compras','2026-08-01',1,15,70,r);
 r:=public.ciclos_estado()->>'revision';
 SELECT x INTO j FROM jsonb_array_elements(public.ciclos_pagina('',r))x WHERE x->>'op'='OS421';
 IF j->'versiones'->>'compras'<>antigua THEN RAISE EXCEPTION 'Reescribio historia'; END IF;
 -- Corrección de inicio vuelve a elegir versión; vacío borra fecha y versión dependiente.
 filas:=jsonb_build_array(jsonb_set(jsonb_set(filas->0,'{inicio}','"2026-09-02"'),'{fines,compras}','null'));
 j:=public.ciclos_importar(filas,r,false,'actualizado.xlsx');
 IF (j->>'fechas_borradas')::int<>1 THEN RAISE EXCEPTION 'No detecto borrado'; END IF;
 PERFORM public.ciclos_importar(filas,r,true,'actualizado.xlsx');
 r:=public.ciclos_estado()->>'revision';
 SELECT x INTO j FROM jsonb_array_elements(public.ciclos_pagina('',r))x WHERE x->>'op'='OS421';
 IF j->'versiones'->>'compras'=antigua OR j->'versiones'->>'trazo' IS NOT NULL OR j->'fines'->>'compras' IS NOT NULL THEN RAISE EXCEPTION 'Correccion no aplicada'; END IF;
 IF jsonb_array_length(public.ciclos_pagina('',r))<>2 THEN RAISE EXCEPTION 'Borro OP no importada'; END IF;
 IF (SELECT count(*) FROM public.ciclos_importaciones)<>2 THEN RAISE EXCEPTION 'Falta auditoria'; END IF;
 -- Revision obsoleta bloquea escritura; fechas incoherentes revierten todo.
 BEGIN PERFORM public.ciclos_importar(filas,'0',true,'stale.xlsx'); RAISE EXCEPTION 'Acepto revision obsoleta';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'Los datos cambiaron%' THEN RAISE; END IF; END;
 BEGIN PERFORM public.ciclos_importar(jsonb_build_array(jsonb_set(filas->0,'{fines,trazo}','"2020-01-01"')),r,true,'invalido.xlsx'); RAISE EXCEPTION 'Acepto fecha incoherente';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM NOT LIKE 'Fechas contradictorias%' THEN RAISE; END IF; END;
 IF public.ciclos_estado()->>'revision'<>r THEN RAISE EXCEPTION 'Fallo atomico'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000005',true);
DO $$ DECLARE q text; n int; BEGIN
 IF NOT public.puede_ver_dashboards() THEN RAISE EXCEPTION 'Gerencia sin acceso'; END IF;
 PERFORM public.ciclos_estado(); PERFORM public.ciclos_pagina('',public.ciclos_estado()->>'revision');
 PERFORM public.admin_reporte_resumen(); PERFORM public.admin_reporte_pagina('movimientos','',now());
 FOREACH q IN ARRAY ARRAY[
  $q$INSERT INTO storage.objects VALUES('prohibido')$q$,
  $q$SELECT public.ciclos_configurar('compras','2026-01-01',3,10,20,'0')$q$,
  $q$SELECT public.ciclos_importar('[]','0',true,'x')$q$,
  $q$SELECT public.admin_reporte_pagina('auditoria','',now())$q$,
  $q$SELECT public.crear_lote('[]','TEST')$q$,
  $q$SELECT public.recibir_lote_item(NULL,1,NULL,'')$q$,
  $q$SELECT public.despachar_oc('x','x','x','[]')$q$,
  $q$SELECT public.agregar_personal_logistica('PROHIBIDO')$q$,
  $q$SELECT public.agregar_personal_produccion('PROHIBIDO')$q$,
  $q$SELECT public.agregar_personal_aliado('PROHIBIDO')$q$,
  $q$INSERT INTO public.ciclos_ordenes(op,cliente,cantidad,fines)VALUES('PROHIBIDO','x',1,'{}')$q$
 ] LOOP PERFORM pg_temp.denegado(q); END LOOP;
 IF (SELECT count(*) FROM public.ciclos_importaciones)<>0 THEN RAISE EXCEPTION 'Auditoria visible a gerencia'; END IF;
 FOR n IN 2..4 LOOP
   PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000'||n,true);
   PERFORM pg_temp.denegado('SELECT public.ciclos_estado()');
 END LOOP;
END $$;
RESET ROLE;
UPDATE public.usuarios SET activo=false WHERE rol='gerencia';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000005',true);
SELECT pg_temp.denegado('SELECT public.ciclos_estado()');
ROLLBACK;
