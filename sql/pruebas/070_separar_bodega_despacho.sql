-- SOLO ORBILOQ-DEV, despues de 065, 066, 067 y 068. Ejecutar completo.
-- Conserva cuentas, cantidades e historial. logistica sigue siendo Bodega.
-- No volver a ejecutar migraciones anteriores despues de esta.
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $migracion$
DECLARE r record; definicion text; vieja text; nueva text; veces integer;
BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL
    AND current_setting('app.settings.project_ref',true) <> 'igfuafcekcpugpmsoqbe' THEN
   RAISE EXCEPTION 'Solo ORBILOQ-DEV';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN
   RAISE EXCEPTION 'No coincide el inventario de pruebas. Revisar el proyecto.';
 END IF;
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 ALTER TABLE public.usuarios DROP CONSTRAINT usuarios_rol_check;
 ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
   CHECK (rol IN ('admin','produccion','logistica','despacho'));

 -- Cambia solo los controles de rol, conservando las validaciones y auditoria.
 FOR r IN SELECT * FROM (VALUES
   ('public.despachar_oc(text,text,text,jsonb)',2,false),
   ('public.despachar_oc_empaques(text,text,text,jsonb,jsonb)',1,false),
   ('public.despachar_oc_prendas_empaques(text,text,text,jsonb,jsonb)',1,false),
   ('public.historial_despachos_oc(text)',1,false),
   ('public.empaques_listar(boolean)',1,false),
   ('public.admin_usuario_guardar(uuid,text,text,boolean,text)',1,true),
   ('public.admin_usuario_registrar(uuid,uuid,text,text,text)',1,true)
 ) AS funciones(firma,esperadas,administracion) LOOP
   SELECT pg_get_functiondef(to_regprocedure(r.firma)) INTO definicion;
   IF definicion IS NULL THEN RAISE EXCEPTION 'Falta la funcion %. Detener y revisar.',r.firma; END IF;
   vieja:=CASE WHEN r.administracion THEN '(''admin'',''produccion'',''logistica'')' ELSE '(''admin'',''logistica'')' END;
   nueva:=CASE WHEN r.administracion THEN '(''admin'',''produccion'',''logistica'',''despacho'')' ELSE '(''admin'',''despacho'')' END;
   veces:=(length(definicion)-length(replace(definicion,vieja,'')))/length(vieja);
   IF veces=0 AND (length(definicion)-length(replace(definicion,nueva,'')))/length(nueva)=r.esperadas THEN
     CONTINUE; -- ya aplicado
   END IF;
   IF veces<>r.esperadas THEN RAISE EXCEPTION 'La funcion % cambio; revisar sus permisos.',r.firma; END IF;
   definicion:=replace(definicion,vieja,nueva);
   IF NOT r.administracion THEN
     definicion:=replace(replace(definicion,'Logística o Administrador','Despacho o Administrador'),'Logistica o Administrador','Despacho o Administrador');
   END IF;
   EXECUTE definicion;
 END LOOP;
END $migracion$;

-- Los RPC antiguos eran SECURITY INVOKER. Convertir solo el inventario
-- verificado con controles explicitos de cuenta activa y rol, y fijar ruta.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
DO $$ DECLARE r record; d text; BEGIN
 FOR r IN SELECT * FROM (VALUES
   ('public.crear_lote(jsonb,text,text)','produccion'),
   ('public.enviar_no_conforme_aliado(uuid,integer,uuid,text,text,text)','produccion'),
   ('public.liberar_no_conforme(uuid,integer,text,text)','produccion'),
   ('public.liberar_no_conforme(uuid,integer,text,text,text)','produccion'),
   ('public.liberar_no_conforme_aliado(uuid,integer,text,text,text)','produccion'),
   ('public.recibir_lote_item(uuid,integer,uuid,text)','logistica'),
   ('public.recibir_lote_item(uuid,integer,uuid,text,text)','logistica'),
   ('public.cerrar_lote_item_con_faltante(uuid,text)','logistica'),
   ('public.registrar_no_conforme(uuid,integer,uuid,text,text)','logistica'),
   ('public.registrar_no_conforme(uuid,integer,uuid,text,text,text)','logistica'),
   ('public.registrar_sobrante(uuid,uuid,integer,text,text)','logistica'),
   ('public.resolver_sobrante(uuid,text)','logistica'),
   ('public.importar_fechas_esperadas(jsonb)','admin'),
   ('public.importar_ordenes_produccion(jsonb,jsonb,text,text,text)','admin')
 ) AS f(firma,rol) LOOP
   SELECT pg_get_functiondef(to_regprocedure(r.firma)) INTO d;
   IF d IS NULL OR position('public.wms_cuenta_activa()' in d)=0
      OR (r.rol='admin' AND position('public.admin_es_admin()' in d)=0)
      OR (r.rol<>'admin' AND position('rol IN (''admin'','''||r.rol||''')' in d)=0) THEN
     RAISE EXCEPTION 'No se verificaron los controles de acceso de %',r.firma;
   END IF;
   EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER',r.firma);
   EXECUTE format('ALTER FUNCTION %s SET search_path=pg_catalog,public,pg_temp',r.firma);
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',r.firma);
 END LOOP;
END $$;

-- Las operaciones usan RPC SECURITY DEFINER con comprobacion de rol.
-- Impide saltarse dichos controles escribiendo directamente tablas/vistas.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
 public.ordenes_produccion, public.items_orden, public.movimientos,
 public.lotes, public.lote_items, public.devoluciones_produccion,
 public.liberaciones_no_conforme, public.no_conformes_aliados,
 public.liberaciones_aliados, public.sobrantes_bodega, public.despachos_oc
 FROM anon, authenticated;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relkind='v'
 LOOP
   EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON public.%I FROM anon, authenticated',r.relname);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
SELECT 'OK: Bodega y Despacho separados; datos conservados' AS resultado;
