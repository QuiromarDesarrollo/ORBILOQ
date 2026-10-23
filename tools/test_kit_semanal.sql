RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT id AS vid FROM public.conductor_vehiculos WHERE placa='TEST01' \gset
SELECT set_config('test.vehiculo',:'vid',false);
SELECT set_config('test.kit',jsonb_build_object('inspector','Inspector','fecha',to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD'),'respuestas',$json${"Gato para elevar el vehículo": {"estado": "Buen estado"}, "Manivela o mecanismo de accionamiento": {"estado": "Buen estado"}, "Cruceta para las tuercas de las ruedas": {"estado": "Buen estado"}, "Triángulo reflectivo N.º 1": {"estado": "Buen estado"}, "Triángulo reflectivo N.º 2": {"estado": "Buen estado"}, "Soportes de los triángulos": {"estado": "Buen estado"}, "Lámparas amarillas intermitentes": {"estado": "Buen estado"}, "Guantes desechables de nitrilo": {"estado": "Buen estado"}, "Mascarilla de barrera para RCP": {"estado": "Buen estado"}, "Gasas estériles": {"estado": "Buen estado"}, "Apósitos estériles": {"estado": "Buen estado"}, "Vendas de gasa": {"estado": "Buen estado"}, "Venda elástica": {"estado": "Buen estado"}, "Esparadrapo o cinta médica": {"estado": "Buen estado"}, "Apósitos adhesivos": {"estado": "Buen estado"}, "Solución salina estéril": {"estado": "Buen estado"}, "Toallitas antisépticas": {"estado": "Buen estado"}, "Compresa estéril para quemaduras": {"estado": "Buen estado"}, "Tijeras de punta roma": {"estado": "Buen estado"}, "Pinzas de punta roma": {"estado": "Buen estado"}, "Manta térmica de emergencia": {"estado": "Buen estado"}, "Bolsas para material contaminado": {"estado": "Buen estado"}, "Estuche del botiquín": {"estado": "Buen estado"}, "Extintor adecuado para el vehículo": {"estado": "Buen estado"}, "Carga y mantenimiento del extintor": {"estado": "Buen estado"}, "Manómetro, seguro y sello": {"estado": "Buen estado"}, "Soporte de fijación del extintor": {"estado": "Buen estado"}, "Taco de bloqueo N.º 1": {"estado": "Buen estado"}, "Taco de bloqueo N.º 2": {"estado": "Buen estado"}, "Alicate": {"estado": "Buen estado"}, "Destornillador de pala": {"estado": "Buen estado"}, "Destornillador de estrella": {"estado": "Buen estado"}, "Llave de expansión": {"estado": "Buen estado"}, "Juego de llaves fijas": {"estado": "Buen estado"}, "Caja o bolso de herramientas": {"estado": "Buen estado"}, "Llanta de repuesto compatible": {"estado": "Buen estado"}, "Presión y estado de la llanta": {"estado": "Buen estado"}, "Fijación de la llanta": {"estado": "Buen estado"}, "Linterna funcional": {"estado": "Buen estado"}, "Pilas o batería con carga": {"estado": "Buen estado"}, "Chaleco reflectivo": {"estado": "Buen estado"}, "Cables de arranque o arrancador portátil": {"estado": "Buen estado"}, "Compresor o medidor de presión": {"estado": "Buen estado"}, "Sellador de pinchazos": {"estado": "Buen estado"}, "Guantes de trabajo": {"estado": "Buen estado"}, "Agua potable": {"estado": "Buen estado"}, "Impermeable": {"estado": "Buen estado"}, "Cargador portátil para celular": {"estado": "Buen estado"}, "Cuerda de remolque compatible": {"estado": "Buen estado"}, "Contactos de emergencia": {"estado": "Buen estado"}}$json$::jsonb)::text,false);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT public.conductor_registrar_kit(:'vid',current_setting('test.kit')::jsonb);
DO $$ DECLARE vid uuid:=current_setting('test.vehiculo')::uuid; datos jsonb:=current_setting('test.kit')::jsonb; resumen jsonb; BEGIN
 resumen:=public.conductor_resumen_kit(ARRAY[vid]);
 IF resumen->vid::text->>'fecha' IS DISTINCT FROM datos->>'fecha' THEN RAISE EXCEPTION 'Resumen incorrecto'; END IF;
 IF resumen::text LIKE '%Inspector%' OR resumen::text LIKE '%respuestas%' THEN RAISE EXCEPTION 'Filtración de detalle'; END IF;
 IF EXISTS(SELECT 1 FROM public.conductor_registros) THEN RAISE EXCEPTION 'Detalle visible al conductor'; END IF;
 IF EXISTS(SELECT 1 FROM public.conductor_historial(vid) r WHERE r->'datos' ? 'respuestas') THEN RAISE EXCEPTION 'Historial no privado'; END IF;
 BEGIN
 PERFORM public.conductor_registrar_kit(vid,jsonb_set(datos,'{respuestas,Gato para elevar el vehículo}', '{"estado":"No aplica"}'));
 RAISE EXCEPTION 'ERROR: permitió omitir gato';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN
 PERFORM public.conductor_registrar_kit(vid,jsonb_set(datos,'{respuestas,Gasas estériles}',jsonb_build_object('estado','Buen estado','vencimiento','2000-01-01')));
 RAISE EXCEPTION 'ERROR: permitió vencido';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN
 PERFORM public.conductor_registrar_kit(vid,jsonb_set(datos,'{respuestas,Gasas estériles}', '{"estado":"Con novedad"}'));
 RAISE EXCEPTION 'ERROR: permitió novedad sin detalle';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 BEGIN
 PERFORM public.conductor_registrar_kit(vid,jsonb_set(datos,'{fecha}','"2000-01-01"'));
 RAISE EXCEPTION 'ERROR: permitió semana anterior';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'ERROR:%' THEN RAISE; END IF; END;
 datos:=jsonb_set(datos,'{respuestas,Gasas estériles}',jsonb_build_object('estado','Con novedad','detalle','Reemplazar','vencimiento','2000-01-01'));
 PERFORM public.conductor_registrar_kit(vid,datos);
 resumen:=public.conductor_resumen_kit(ARRAY[vid]);
 IF (resumen->vid::text->>'novedades')::integer<>1 OR resumen->vid::text->'vencimientos'->>'Gasas estériles'<>'2000-01-01' THEN RAISE EXCEPTION 'Alerta incorrecta'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
DO $$ BEGIN
 BEGIN PERFORM public.conductor_resumen_kit(ARRAY[current_setting('test.vehiculo')::uuid]); RAISE EXCEPTION 'Leyó vehículo ajeno'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.conductor_registrar_kit(current_setting('test.vehiculo')::uuid,current_setting('test.kit')::jsonb); RAISE EXCEPTION 'Escribió vehículo ajeno'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.conductor_historial(current_setting('test.vehiculo')::uuid) r WHERE r->>'tipo'='Checklist semanal de carretera' AND r->'datos' ? 'respuestas')<>2 THEN RAISE EXCEPTION 'Admin no ve detalle'; END IF;
END $$;
RESET ROLE;
