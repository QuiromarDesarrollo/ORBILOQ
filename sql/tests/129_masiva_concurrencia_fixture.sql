-- SOLO base PostgreSQL LOCAL DESECHABLE. Deja dos kits ficticios y una unidad recibida
-- para lanzar cinco solicitudes concurrentes; NO ejecutar en DEV ni producción.
BEGIN;
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000004');
INSERT INTO public.usuarios(auth_id,numero_usuario,nombre,rol,roles,activo) VALUES
 ('00000000-0000-0000-0000-000000000004','TEST-CONCURRENCIA','Concurrencia ficticia','admin',ARRAY['admin'],true);
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
DO $$ DECLARE op uuid; imp uuid; p uuid; inv uuid; asig uuid;
BEGIN
 op:=(public.masiva_ejecutar('crear_operacion','{"nombre":"Concurrencia ficticia","cliente":"Ficticio"}')->>'id')::uuid;
 p:=(public.masiva_ejecutar('guardar_personal','{"nombre":"Armador sin cuenta"}')->>'id')::uuid;
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','recepcion','archivo','Recepción ficticia.xlsx','total_filas',1,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas','[{"proveedor":"Proveedor","pedido":"P1","sku":"001","descripcion":"Prenda","cantidad":1,"unidad":"UNIDAD"}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 SELECT id INTO inv FROM public.masiva_inventario WHERE operacion_id=op;
 PERFORM public.masiva_ejecutar('recibir',jsonb_build_object('operacion_id',op,'inventario_id',inv,'cantidad',1,'soporte','REM-CONCURRENCIA','request_id',gen_random_uuid()));
 imp:=(public.masiva_ejecutar('iniciar_importacion',jsonb_build_object('operacion_id',op,'tipo','personal','archivo','Base ficticia.xlsx','total_filas',2,'total_lotes',1))->>'importacion_id')::uuid;
 PERFORM public.masiva_ejecutar('cargar_lote',jsonb_build_object('importacion_id',imp,'indice',0,'filas',
 '[{"lista":"1","numero_persona":1,"cedula":"1","nombre":"Uno","sku":"001","descripcion":"Prenda","cantidad":1},
 {"lista":"1","numero_persona":2,"cedula":"2","nombre":"Dos","sku":"001","descripcion":"Prenda","cantidad":1}]'::jsonb));
 PERFORM public.masiva_ejecutar('confirmar_importacion',jsonb_build_object('importacion_id',imp));
 asig:=(public.masiva_ejecutar('asignar',jsonb_build_object('operacion_id',op,'lista','1','empacador_id',p))->>'id')::uuid;
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','iniciar'));
 PERFORM public.masiva_ejecutar('tiempo',jsonb_build_object('operacion_id',op,'asignacion_id',asig,'accion','finalizar'));
END $$;
COMMIT;
