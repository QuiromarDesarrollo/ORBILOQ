-- Editar empaque de un kit reabierto, preservando stock, creditos e historial.
-- Aplicar sobre la funcion vigente (incluidas las restricciones administrativas).
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $patch$
DECLARE f text; patron text; nuevo text; coincidencias integer;
BEGIN
 f:=pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure);
 IF position('masiva148_editar_empaque' IN f)>0 THEN RETURN; END IF;
 IF position('masiva_admin_pantallas_20261125' IN f)=0 OR position('masiva136_catalogo_compartido' IN f)=0
 THEN RAISE EXCEPTION 'La funcion no tiene las protecciones/catalogo esperados. Revisar antes de aplicar 148'; END IF;
 patron:='v_catalogo_empaque jsonb;';
 SELECT count(*) INTO coincidencias FROM regexp_matches(f,patron,'g');
 IF coincidencias<>1 THEN RAISE EXCEPTION 'Declaracion inesperada: %',coincidencias; END IF;
 f:=replace(f,patron,'v_catalogo_empaque jsonb; v_caja_origen public.masiva_cajas; v_empaque_solicitado uuid; v_caja_exclusiva boolean;');
 patron:=$rx$ELSIF p_accion='embalar' THEN.*?ELSE\s+IF p_accion='validar' THEN$rx$;
 SELECT count(*) INTO coincidencias FROM regexp_matches(f,patron,'gs');
 IF coincidencias<>1 THEN RAISE EXCEPTION 'Bloque embalar inesperado: %',coincidencias; END IF;
 nuevo:=$body$ELSIF p_accion='embalar' THEN
 -- masiva148_editar_empaque: la operacion y el kit ya estan bloqueados FOR UPDATE.
 IF NOT EXISTS(SELECT 1 FROM public.masiva_articulos WHERE kit_id=k.id AND validado>0) THEN RAISE EXCEPTION 'Valida al menos una prenda antes de asignar el empaque'; END IF;
 n:=(p_datos->>'caja')::integer;
 IF n IS NULL OR n<1 THEN RAISE EXCEPTION 'Numero de contenedor invalido'; END IF;
 v_empaque_solicitado:=nullif(p_datos->>'empaque_id','')::uuid;
 IF v_empaque_solicitado IS NULL THEN RAISE EXCEPTION 'Selecciona el tipo de empaque'; END IF;
 SELECT * INTO v_caja_origen FROM public.masiva_cajas WHERE id=k.caja_id FOR UPDATE;
 anterior:=CASE WHEN v_caja_origen.id IS NULL THEN NULL ELSE to_jsonb(v_caja_origen) END;
 SELECT * INTO caja FROM public.masiva_cajas WHERE operacion_id=operacion AND lista=k.lista AND numero=n FOR UPDATE;
 IF v_caja_origen.id IS NOT NULL THEN
  IF NOT k.revision_abierta AND (v_caja_origen.id IS DISTINCT FROM caja.id OR coalesce(v_caja_origen.empaque_catalogo_id,v_caja_origen.empaque_id) IS DISTINCT FROM v_empaque_solicitado)
  THEN RAISE EXCEPTION 'Reabre el kit antes de modificar su empaque'; END IF;
  v_caja_exclusiva:=NOT EXISTS(SELECT 1 FROM public.masiva_kits WHERE caja_id=v_caja_origen.id AND id<>k.id);
  IF caja.id IS NOT NULL AND caja.id<>v_caja_origen.id AND v_caja_exclusiva
  THEN RAISE EXCEPTION 'Ese numero ya existe. Usa un numero libre para cambiar el contenedor de este kit sin dejar un empaque vacio'; END IF;
  -- Conservar el mismo registro al renumerar un contenedor exclusivo.
  IF caja.id IS NULL AND v_caja_exclusiva THEN
   UPDATE public.masiva_cajas SET numero=n WHERE id=v_caja_origen.id RETURNING * INTO caja;
  END IF;
 END IF;
 IF caja.id IS NOT NULL THEN
  IF coalesce(caja.empaque_catalogo_id,caja.empaque_id) IS DISTINCT FROM v_empaque_solicitado THEN
   IF caja.id IS DISTINCT FROM v_caja_origen.id OR EXISTS(SELECT 1 FROM public.masiva_kits WHERE caja_id=caja.id AND id<>k.id)
   THEN RAISE EXCEPTION 'Este contenedor utiliza otro tipo de empaque o contiene otros kits. Usa un numero libre para editar solo este kit'; END IF;
   SELECT to_jsonb(e) INTO v_catalogo_empaque FROM public.masiva_catalogo_empaques e WHERE e.id=v_empaque_solicitado AND e.activo FOR SHARE;
   IF v_catalogo_empaque IS NULL OR v_catalogo_empaque->>'peso_lleno' IS NULL THEN RAISE EXCEPTION 'Selecciona un empaque activo con peso promedio configurado'; END IF;
   UPDATE public.masiva_cajas SET empaque_id=NULL,empaque_catalogo_id=v_empaque_solicitado,empaque_snapshot=v_catalogo_empaque WHERE id=caja.id RETURNING * INTO caja;
  END IF;
 ELSE
  SELECT to_jsonb(e) INTO v_catalogo_empaque FROM public.masiva_catalogo_empaques e WHERE e.id=v_empaque_solicitado AND e.activo FOR SHARE;
  IF v_catalogo_empaque IS NULL OR v_catalogo_empaque->>'peso_lleno' IS NULL THEN RAISE EXCEPTION 'Selecciona un empaque activo con peso promedio configurado'; END IF;
  INSERT INTO public.masiva_cajas(operacion_id,lista,numero,empaque_catalogo_id,empaque_snapshot,creado_por)
  VALUES(operacion,k.lista,n,v_empaque_solicitado,v_catalogo_empaque,actor) RETURNING * INTO caja;
 END IF;
 UPDATE public.masiva_kits SET caja_id=caja.id,revision_abierta=false WHERE id=k.id;
 resultado:=jsonb_build_object('id',k.id,'caja',n,'estado',k.estado,'revision_abierta',false,
  'empaque_anterior',anterior,'empaque_actual',to_jsonb(caja),
  'requerido',(SELECT sum(a.cantidad) FROM public.masiva_articulos a WHERE a.kit_id=k.id),
  'validado',(SELECT sum(a.validado) FROM public.masiva_articulos a WHERE a.kit_id=k.id));
 ELSE
 IF p_accion='validar' THEN$body$;
 f:=regexp_replace(f,patron,nuevo,'s');
 patron:='revision_abierta=n<>0 WHERE id=k.id;';
 SELECT count(*) INTO coincidencias FROM regexp_matches(f,patron,'g');
 IF coincidencias<>1 THEN RAISE EXCEPTION 'Cierre validacion inesperado: %',coincidencias; END IF;
 f:=replace(f,patron,'revision_abierta=(n<>0 OR (k.caja_id IS NOT NULL AND k.revision_abierta)) WHERE id=k.id;');
 EXECUTE f;
END $patch$;
COMMIT;
SELECT position('masiva148_editar_empaque' IN pg_get_functiondef('public.masiva_ejecutar(text,jsonb)'::regprocedure))>0 AS aplicado;
