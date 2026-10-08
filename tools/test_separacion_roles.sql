-- Solo ensayo local; no ejecutar en Supabase.
BEGIN;
DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO auth.users(id,email) SELECT ('00000000-0000-0000-0000-00000000000'||n)::uuid,n||'@orbiloq.local' FROM generate_series(1,5)n;
INSERT INTO public.usuarios(nombre,rol,auth_id,numero_usuario,email)
 SELECT 'TEST '||n,r,('00000000-0000-0000-0000-00000000000'||n)::uuid,n::text,n||'@orbiloq.local'
 FROM (VALUES(1,'admin'),(2,'produccion'),(3,'logistica'),(4,'despacho'))x(n,r);
INSERT INTO public.ubicaciones(id,codigo) VALUES('40000000-0000-0000-0000-000000000001','TEST-A');
GRANT USAGE ON SCHEMA auth TO authenticated;
CREATE FUNCTION pg_temp.denegado(q text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 BEGIN EXECUTE q;
 EXCEPTION WHEN insufficient_privilege THEN RETURN;
 WHEN raise_exception THEN
   IF SQLERRM='Acceso exclusivo del administrador.' THEN RETURN; END IF;
   RAISE;
 END;
 RAISE EXCEPTION 'Se permitio una operacion prohibida: %',q;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE n int; q text; li uuid; e jsonb; lineas jsonb; envases jsonb; respuesta jsonb;
BEGIN
 -- Todos leen el kardex. Solo Despacho y Admin pueden despachar por cualquier RPC.
 FOR n IN 1..4 LOOP
   PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-00000000000'||n,true);
   IF NOT public.wms_cuenta_activa() THEN RAISE EXCEPTION 'Cuenta no reconocida'; END IF;
   PERFORM * FROM public.vista_kardex;
   IF n IN (2,3) THEN
     FOREACH q IN ARRAY ARRAY[
       $q$SELECT public.despachar(NULL,1,NULL)$q$,
       $q$SELECT public.despachar_oc('prohibido','TEST','TEST-OC','[]')$q$,
       $q$SELECT public.despachar_oc_empaques('prohibido','TEST','TEST-OC','[]','[]')$q$,
       $q$SELECT public.despachar_oc_prendas_empaques('prohibido','TEST','TEST-OC','[]','[]')$q$,
       $q$SELECT public.historial_despachos_empaques()$q$
     ] LOOP PERFORM pg_temp.denegado(q); END LOOP;
   END IF;
   IF n IN (2,4) THEN
     PERFORM pg_temp.denegado('SELECT public.recibir_lote_item(NULL,1,NULL,'''')');
     PERFORM pg_temp.denegado('SELECT public.recibir_lote_item(NULL,1,NULL,'''',''TEST'')');
     PERFORM pg_temp.denegado('SELECT public.cerrar_lote_item_con_faltante(NULL,'''')');
     -- Usar la firma completa que invoca la app; la antigua comparte defaults.
     PERFORM pg_temp.denegado('SELECT public.registrar_no_conforme(NULL,1,NULL,''TEST'','''',''TEST'')');
     PERFORM pg_temp.denegado('SELECT public.registrar_sobrante(NULL,NULL,1,''TEST'','''')');
     PERFORM pg_temp.denegado('SELECT public.resolver_sobrante(NULL,''TEST'')');
   END IF;
   IF n IN (3,4) THEN
     PERFORM pg_temp.denegado('SELECT public.crear_lote(''[]'',''TEST'')');
     PERFORM pg_temp.denegado('SELECT public.liberar_no_conforme(NULL,1,''TEST'','''',''TEST'')');
     PERFORM pg_temp.denegado('SELECT public.enviar_no_conforme_aliado(NULL,1,NULL,''TEST'',''TEST'','''')');
     PERFORM pg_temp.denegado('SELECT public.liberar_no_conforme_aliado(NULL,1,''TEST'',''TEST'','''')');
   END IF;
   IF n<>1 THEN
     PERFORM pg_temp.denegado('SELECT public.importar_fechas_esperadas(''[]'')');
     PERFORM pg_temp.denegado('SELECT public.importar_ordenes_produccion(''[]'',''[]'',''TEST'',''TEST'',''TEST'')');
   END IF;
   -- Tampoco se admite escribir inventario directamente, ni como administrador.
   PERFORM pg_temp.denegado('UPDATE public.movimientos SET cantidad=1 WHERE false');
   PERFORM pg_temp.denegado('DELETE FROM public.lote_items WHERE false');
 END LOOP;
 -- Flujo real: Produccion entrega, Bodega recibe y Despacho despacha.
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 PERFORM public.crear_lote('[{"item_orden_id":"0701856a-7771-4536-9762-658a58af8803","cantidad":10}]','TEST','ROLES-070');
 SELECT id INTO li FROM public.lote_items WHERE item_orden_id='0701856a-7771-4536-9762-658a58af8803';
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
 PERFORM public.recibir_lote_item(li,10,'40000000-0000-0000-0000-000000000001','','Bodega');
 IF NOT EXISTS(SELECT 1 FROM public.vista_kardex WHERE fecha_ultima_recepcion IS NOT NULL) THEN RAISE EXCEPTION 'No actualizo fecha de recibido'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 e:=public.admin_empaque_guardar(NULL,NULL,'{"nombre":"Caja roles","categoria":"CAJA","largo_cm":30,"ancho_cm":20,"alto_cm":10,"peso_neto_kg":0.1,"peso_bruto_kg":2,"activo":true}');
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
 PERFORM public.empaques_listar();
 lineas:='[{"item_id":"0701856a-7771-4536-9762-658a58af8803","ubicacion":"TEST-A","cantidad":5}]';
 envases:=jsonb_build_array(jsonb_build_object('item_id','0701856a-7771-4536-9762-658a58af8803','empaque_id',e->>'id','cantidad',5,'version',md5(e::text)));
 respuesta:=public.despachar_oc_prendas_empaques('roles-070','TEST','TEST-OC',lineas,envases);
 IF jsonb_array_length(public.historial_despachos_empaques())<>1 THEN RAISE EXCEPTION 'No despacho'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM pg_temp.denegado('SELECT public.despachar_oc(''inactivo'',''TEST'',''TEST-OC'',''[]'')');
END $$;
RESET ROLE;
-- El alta del rol nuevo mantiene la validacion del administrador.
SELECT public.admin_usuario_registrar('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005','5','Nuevo despacho','despacho');
UPDATE public.usuarios SET activo=false WHERE numero_usuario='4';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
SELECT pg_temp.denegado('SELECT public.despachar_oc(''inactivo'',''TEST'',''TEST-OC'',''[]'')');
ROLLBACK;
