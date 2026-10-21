-- Solo DEV. Unificar cliente únicamente para asignaciones autorizadas de inventario.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'igfuafcekcpugpmsoqbe' THEN RAISE EXCEPTION 'Solo ORBILOQ-DEV'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.items_orden WHERE id='0701856a-7771-4536-9762-658a58af8803' AND codigo='DEMO-001') THEN RAISE EXCEPTION 'No coincide la base de pruebas'; END IF;
 IF to_regprocedure('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere inventario 111'; END IF;
END $$;
DO $migration$
DECLARE ddl text; anterior text; nueva text;
BEGIN
 ddl:=pg_get_functiondef('public.despachar_oc(text,text,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_CLIENTE_112')>0 THEN RETURN; END IF;
 anterior:=$old$IF cliente_actual IS DISTINCT FROM p_cliente OR (item.oc IS DISTINCT FROM p_oc AND NOT EXISTS(SELECT 1 FROM public.inventario_despachos inv JOIN public.inventario_transferencias it ON it.id=inv.transferencia WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id AND it.item_id=item.id AND it.cliente=p_cliente AND NOT inv.cancelado)) /* INVENTARIO_V101 */ THEN RAISE EXCEPTION 'Las prendas deben pertenecer al cliente y OC seleccionados.'; END IF;$old$;
 nueva:=$new$
 -- INVENTARIO_CLIENTE_112: el origen mantiene su OC; la LE recibe la OC de destino.
 -- La excepción requiere asignaciones privadas de esta solicitud y de este actor.
 IF EXISTS(SELECT 1 FROM public.inventario_despachos inv
   JOIN public.inventario_transferencias it ON it.id=inv.transferencia
   WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id
     AND it.item_id=item.id AND NOT inv.cancelado) THEN
   IF nullif(public.inventario_clave(p_cliente),'') IS NULL
      OR public.inventario_clave(cliente_actual) IS DISTINCT FROM public.inventario_clave(p_cliente)
      OR EXISTS(SELECT 1 FROM public.inventario_despachos inv
        JOIN public.inventario_transferencias it ON it.id=inv.transferencia
        WHERE inv.solicitud=p_solicitud AND inv.actor=actor.id
          AND it.item_id=item.id AND NOT inv.cancelado
          AND public.inventario_clave(it.cliente) IS DISTINCT FROM public.inventario_clave(p_cliente))
   THEN RAISE EXCEPTION 'La prenda % (talla %) pertenece a un cliente diferente al seleccionado.',item.codigo,item.talla;
   END IF;
 ELSE
   IF item.inventario_manual THEN
     RAISE EXCEPTION 'La prenda % (talla %) no tiene una asignación de inventario válida para este despacho.',item.codigo,item.talla;
   END IF;
   IF cliente_actual IS DISTINCT FROM p_cliente THEN
     RAISE EXCEPTION 'La prenda % (talla %) pertenece a un cliente diferente al seleccionado.',item.codigo,item.talla;
   END IF;
   IF item.oc IS DISTINCT FROM p_oc THEN
     RAISE EXCEPTION 'La prenda % (talla %) pertenece a otra OC. Para despacharla con una nueva OC debe estar transferida y seleccionada desde inventario.',item.codigo,item.talla;
   END IF;
 END IF;
 $new$;
 IF strpos(ddl,anterior)=0 THEN RAISE EXCEPTION 'Validación de despacho inesperada; no se aplicó ningún cambio. Revisar migraciones 101 y 105.'; END IF;
 EXECUTE replace(ddl,anterior,nueva);
END $migration$;
DO $migration$
DECLARE ddl text; anterior text; nueva text;
BEGIN
 ddl:=pg_get_functiondef('public.inventario_empacar_multiple(text,jsonb,text,uuid,text,jsonb)'::regprocedure);
 IF strpos(ddl,'INVENTARIO_SALDO_112')>0 THEN RETURN; END IF;
 anterior:=$old$IF NOT FOUND OR x.cantidad>t.libre THEN RAISE EXCEPTION 'El stock cambió o el estante está inactivo. Actualiza la selección'; END IF;$old$;
 nueva:=$new$
 -- INVENTARIO_SALDO_112
 IF NOT FOUND THEN
   RAISE EXCEPTION 'La entrada de inventario % no está disponible o su estante está inactivo. Actualiza la selección.',x.transferencia;
 END IF;
 IF x.cantidad>t.libre THEN
   RAISE EXCEPTION 'Saldo insuficiente en la ficha % (entrada %): solicitadas %, disponibles %. Actualiza la selección.',t.ficha,x.transferencia,x.cantidad,t.libre;
 END IF;
 $new$;
 IF strpos(ddl,anterior)=0 THEN RAISE EXCEPTION 'Validación múltiple inesperada; revisar migración 111.'; END IF;
 EXECUTE replace(ddl,anterior,nueva);
END $migration$;
NOTIFY pgrst, 'reload schema';
COMMIT;
