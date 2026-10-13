-- CANDIDATO incremental 2026-10-13. Ensayar sobre respaldo antes de aplicar.
-- SOLO producción cxrflhgnxvomcvxzugda. No copia datos DEV ni reinicia consecutivos.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database() NOT IN ('ensayo','postgres') THEN RAISE EXCEPTION 'Base inesperada'; END IF;
 IF nullif(current_setting('app.settings.project_ref',true),'') IS NOT NULL AND current_setting('app.settings.project_ref',true)<>'cxrflhgnxvomcvxzugda' THEN RAISE EXCEPTION 'Proyecto incorrecto'; END IF;
 IF to_regprocedure('public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text)') IS NOT NULL OR to_regprocedure('public.le_importar_clientes_internacionales(jsonb)') IS NOT NULL OR to_regprocedure('public.admin_empaque_guardar_v92(uuid,text,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'Actualización ya iniciada/instalada'; END IF;
 IF to_regprocedure('public.seguimiento_acceso()') IS NULL THEN RAISE EXCEPTION 'Falta despliegue del 09'; END IF;
END $$;
DO $baseline$ BEGIN
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_guardar(text, uuid, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '28d15223e73f3b181d881e592f7b1cda' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_guardar(text, uuid, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_catalogos_listar(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '15ca446753397c8af4df941f3a90ab8b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_catalogos_listar(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_contexto_edicion(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM '92eed44998dfea36a342ff6f55f06d71' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_contexto_edicion(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_editar_kardex(uuid, text, jsonb, text, text, uuid, uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '296b65ec649fbcc2d4d07a0f1b25e9d8' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_editar_kardex(uuid, text, jsonb, text, text, uuid, uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_editar_recepciones(uuid, text, jsonb, text, text, jsonb, uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'da6652aac9b24a517c19da8a64bb895c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_editar_recepciones(uuid, text, jsonb, text, text, jsonb, uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_eliminar_linea(uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '058c432424ea51fda0232a875cdec68d' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_eliminar_linea(uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_empaque_guardar(uuid, text, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '94f3b7d549cbbc426ae543be67aa7450' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_empaque_guardar(uuid, text, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_es_admin()')), E'\r\n', E'\n')) IS DISTINCT FROM '5ce1b98b713dde03a81a64f4dfa459a9' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_es_admin()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_exportar_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '28dda8245e0bba92af1167368d9f9f8a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_exportar_kardex()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_importar_kardex(text, text, jsonb, text, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e39d438c21344efac59b39473d5872f7' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_importar_kardex(text, text, jsonb, text, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_pagina(text, text, timestamp with time zone)')), E'\r\n', E'\n')) IS DISTINCT FROM '5d3c83e1c43b8f8ed161eddce8284131' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_reporte_pagina(text, text, timestamp with time zone)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_reporte_resumen()')), E'\r\n', E'\n')) IS DISTINCT FROM 'caab38bd9c4433368a82fa02d33c8c35' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_reporte_resumen()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_sincronizar_envios_corregidos()')), E'\r\n', E'\n')) IS DISTINCT FROM '852847fd778020175d6fc04f9da74efa' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_sincronizar_envios_corregidos()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_trazabilidad_op(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f1f299c1b1fec71ab6e96ebda3e60799' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_trazabilidad_op(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_alta_pendiente(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '58cd4920a2523e673613349dc15d0be1' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_alta_pendiente(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_guardar(uuid, text, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fa00c82cba322de47eb896f68aea258b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_guardar(uuid, text, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_usuario_registrar(uuid, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a43577d177c2e1853931ffa184c624f2' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_usuario_registrar(uuid, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.admin_version_kardex()')), E'\r\n', E'\n')) IS DISTINCT FROM '15c1d98c07bf0877b8b91023c7e90a84' THEN RAISE EXCEPTION 'Cambió función: %', 'public.admin_version_kardex()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_aliado(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '291208d88384db9e9cfd1a841c1a1e14' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_aliado(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_logistica(text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'decb7a3991e2da1f9bfa42aeb4f5b5fc' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_logistica(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.agregar_personal_produccion(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '33cee1f3bdbca4529b60594d3b555f0a' THEN RAISE EXCEPTION 'Cambió función: %', 'public.agregar_personal_produccion(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.cerrar_lote_item_con_faltante(uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'dabcbe376510ffbc6d9529b3dbc17e7f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.cerrar_lote_item_con_faltante(uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_configurar(text, date, integer, integer, integer, text, integer)')), E'\r\n', E'\n')) IS DISTINCT FROM '1eed144861f60867a3748ad449c7de57' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_configurar(text, date, integer, integer, integer, text, integer)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_estado()')), E'\r\n', E'\n')) IS DISTINCT FROM 'ff6f158f4252b9b6d19a47a3892bb5b1' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_estado()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_importar(jsonb, text, boolean, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f05027656568da3e694825c717155f0f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_importar(jsonb, text, boolean, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_pagina(text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'dd068044c4d70cb1412e583bda6d5a00' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_pagina(text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.ciclos_versiones(date, jsonb, ciclos_ordenes)')), E'\r\n', E'\n')) IS DISTINCT FROM '4c3100b89b0094a44903d623d9d6a5fa' THEN RAISE EXCEPTION 'Cambió función: %', 'public.ciclos_versiones(date, jsonb, ciclos_ordenes)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.corregir_despacho_le(uuid, text, text, text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a5a8ac028ba2110b385cd337f40bb35f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.corregir_despacho_le(uuid, text, text, text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.corregir_despacho_le_base_v81(uuid, text, text, text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '9e06779128fc8ffb38729e5d56eebe6d' THEN RAISE EXCEPTION 'Cambió función: %', 'public.corregir_despacho_le_base_v81(uuid, text, text, text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.crear_lote(jsonb, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '958a95fb6bd7083418daa2a2c1fcfe51' THEN RAISE EXCEPTION 'Cambió función: %', 'public.crear_lote(jsonb, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar(uuid, integer, uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fdf4c441ccc75070926e9f92b41b6180' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar(uuid, integer, uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc(text, text, text, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '11f6e608e17ff198c22ca6f944fe8af7' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc(text, text, text, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_bultos(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '1dcf533fdc7288d1bd3790fbc8ab18bb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_bultos(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_bultos_base_v81(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '1188e33f1d1fe1aa41d4a4aecbd73132' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_bultos_base_v81(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_empaques(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '2aaca2c98c60511ba83a12e2b487a004' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_empaques(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despachar_oc_prendas_empaques(text, text, text, jsonb, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a89564bcfdc5672b527a5209e2f8d6c2' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despachar_oc_prendas_empaques(text, text, text, jsonb, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.despacho_para_corregir(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'fbbf1cac0ae1415ec1ed986cffb2c4a9' THEN RAISE EXCEPTION 'Cambió función: %', 'public.despacho_para_corregir(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.destinatarios_para_empaque()')), E'\r\n', E'\n')) IS DISTINCT FROM '2c01bf620442878d0a8e6f5fa232d347' THEN RAISE EXCEPTION 'Cambió función: %', 'public.destinatarios_para_empaque()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.empaques_listar(boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM '4ef028505dad31deeb984e5bdd084d15' THEN RAISE EXCEPTION 'Cambió función: %', 'public.empaques_listar(boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '84f44e47e938679c1fe7ee17b0687399' THEN RAISE EXCEPTION 'Cambió función: %', 'public.enviar_no_conforme_aliado(uuid, integer, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5e763479636c23d70bbb78c66d513d06' THEN RAISE EXCEPTION 'Cambió función: %', 'public.guardar_empaque_destinatario(text, text, text, jsonb, jsonb, uuid, text, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_empaques(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '4fd91f9fce06a5d2846ff0862c46e12e' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_empaques(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.historial_despachos_oc(text)')), E'\r\n', E'\n')) IS DISTINCT FROM '887a24c107abc9016f17a2122bf5d271' THEN RAISE EXCEPTION 'Cambió función: %', 'public.historial_despachos_oc(text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_fechas_esperadas(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '8d27b01ae790c9238d56e6c2fd6c6e6c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_fechas_esperadas(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '5478b89211abbd38a98970277c06ba72' THEN RAISE EXCEPTION 'Cambió función: %', 'public.importar_ordenes_produccion(jsonb, jsonb, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_acceso()')), E'\r\n', E'\n')) IS DISTINCT FROM '3b6be1bd857815f17923461e4cb6cea5' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_acceso()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_clientes()')), E'\r\n', E'\n')) IS DISTINCT FROM '99f4492d129d70280068540c1831e2db' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_clientes()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_configurar(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b346b4b8680c6ad7ea430b8314ea4ff3' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_configurar(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_documento(text, uuid, jsonb, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'f6654a90f2157dbffea7fd479ad2590c' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_documento(text, uuid, jsonb, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.le_importar_clientes(jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '2f3f6274a9c33af3a35c173e3fa75b2e' THEN RAISE EXCEPTION 'Cambió función: %', 'public.le_importar_clientes(jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '8654662d2cfdd6f52663ab4154bd47e7' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme(uuid, integer, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme(uuid, integer, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd08fc638f2c8152815d74d4c9515477e' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme(uuid, integer, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.liberar_no_conforme_aliado(uuid, integer, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '8d604c3c8ed8affddec8e016275f7f34' THEN RAISE EXCEPTION 'Cambió función: %', 'public.liberar_no_conforme_aliado(uuid, integer, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.proteger_reservas()')), E'\r\n', E'\n')) IS DISTINCT FROM '991d83e8ff92205f9ddd46df0f84f880' THEN RAISE EXCEPTION 'Cambió función: %', 'public.proteger_reservas()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.puede_ver_dashboards()')), E'\r\n', E'\n')) IS DISTINCT FROM '33f8766b217450572eb68dca168e3210' THEN RAISE EXCEPTION 'Cambió función: %', 'public.puede_ver_dashboards()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid, integer, uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e4edb6902bc880117519be989b86df0f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.recibir_lote_item(uuid, integer, uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.recibir_lote_item(uuid, integer, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'e1ab5280cccc698801ed17962bf0cd22' THEN RAISE EXCEPTION 'Cambió función: %', 'public.recibir_lote_item(uuid, integer, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM 'b3bc2cd5b91e2b0ef587fd38064d0639' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_no_conforme(uuid, integer, uuid, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_no_conforme(uuid, integer, uuid, text, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '549863a484b45cf672bed3e14acedeee' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_no_conforme(uuid, integer, uuid, text, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.registrar_sobrante(uuid, uuid, integer, text, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '863cf51794a9ee7e36f7a8e5456f26dd' THEN RAISE EXCEPTION 'Cambió función: %', 'public.registrar_sobrante(uuid, uuid, integer, text, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.reservar_empaque_interno(uuid, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'd162072cc031fb5f3f5b28f8ec6cb800' THEN RAISE EXCEPTION 'Cambió función: %', 'public.reservar_empaque_interno(uuid, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.resolver_sobrante(uuid, text)')), E'\r\n', E'\n')) IS DISTINCT FROM '69e5fcc669a0a85694959cc424b869ca' THEN RAISE EXCEPTION 'Cambió función: %', 'public.resolver_sobrante(uuid, text)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_acceso()')), E'\r\n', E'\n')) IS DISTINCT FROM 'dd0d06a489a8aac150ba0d181380703b' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_acceso()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_archivo_permitido(text, boolean)')), E'\r\n', E'\n')) IS DISTINCT FROM 'daa8d6f9758801965b440f30907d5402' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_archivo_permitido(text, boolean)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_confirmar(uuid, integer, uuid, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '40deb7aec7619fd4ca03d88cc82dc411' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_confirmar(uuid, integer, uuid, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_guardar(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '88494fcd3e3a86c1700ef3ea4c0686bb' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_guardar(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_guardar_v87(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '73edae96e2c62b78c711b51ccfb18511' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_guardar_v87(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_entregas_listar(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM '68d3416ae5da6167153ce33deeb0a648' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_entregas_listar(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_guardar_base_v87(uuid, integer, integer, jsonb)')), E'\r\n', E'\n')) IS DISTINCT FROM '27657401808462d263d99ed5fa07c114' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_guardar_base_v87(uuid, integer, integer, jsonb)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.seguimiento_listar_base_v87(bigint)')), E'\r\n', E'\n')) IS DISTINCT FROM 'a16ef2c28a5713c9f323c51c3ccc0b90' THEN RAISE EXCEPTION 'Cambió función: %', 'public.seguimiento_listar_base_v87(bigint)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.traza_fecha_empaque()')), E'\r\n', E'\n')) IS DISTINCT FROM '666ca5e76493588aef91855e1e032e34' THEN RAISE EXCEPTION 'Cambió función: %', 'public.traza_fecha_empaque()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.validar_reservas_item(uuid)')), E'\r\n', E'\n')) IS DISTINCT FROM 'ced288b1bd8dbf7a53c0a7062fab06c6' THEN RAISE EXCEPTION 'Cambió función: %', 'public.validar_reservas_item(uuid)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.validar_stock_no_conforme(uuid, integer)')), E'\r\n', E'\n')) IS DISTINCT FROM 'cfbf91df51c17f657b80acd9edc142ac' THEN RAISE EXCEPTION 'Cambió función: %', 'public.validar_stock_no_conforme(uuid, integer)'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_cuenta_activa()')), E'\r\n', E'\n')) IS DISTINCT FROM '22ed4e3986b546d43054c2014765043f' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_cuenta_activa()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_cuenta_operativa()')), E'\r\n', E'\n')) IS DISTINCT FROM '53bf06665272f81d2479162f62a32c8e' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_cuenta_operativa()'; END IF;
IF md5(replace(pg_get_functiondef(to_regprocedure('public.wms_nombre_actor()')), E'\r\n', E'\n')) IS DISTINCT FROM 'dafe4b70701bdf326cdf2bf0edc80652' THEN RAISE EXCEPTION 'Cambió función: %', 'public.wms_nombre_actor()'; END IF;
END $baseline$;
CREATE TEMP TABLE previo_tablas(nombre text PRIMARY KEY,columnas text) ON COMMIT DROP;
CREATE TEMP TABLE previo_filas(nombre text,fila jsonb) ON COMMIT DROP;
CREATE TEMP TABLE previo_secuencias ON COMMIT DROP AS SELECT to_jsonb(s) fila FROM pg_sequences s WHERE schemaname='public';
DO $$ DECLARE t record; cols text; BEGIN
 FOR t IN SELECT c.oid,n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','respaldo_mantenimiento','auth','storage') AND c.relkind='r' ORDER BY n.nspname,c.relname LOOP
  IF t.nspname IN ('public','respaldo_mantenimiento') THEN EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',t.nspname,t.relname); END IF;
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols FROM pg_attribute WHERE attrelid=t.oid AND attnum>0 AND NOT attisdropped;
  INSERT INTO previo_tablas VALUES(format('%I.%I',t.nspname,t.relname),cols);
  EXECUTE format('INSERT INTO previo_filas SELECT %L,to_jsonb(x) FROM (SELECT %s FROM %I.%I) x',format('%I.%I',t.nspname,t.relname),cols,t.nspname,t.relname);
 END LOOP;
END $$;

-- 090_oc_documento_despacho.sql

-- Probar primero con tools/ensayar_trazabilidad_op.ps1. No ejecutar en producción.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.seguimiento_acceso()') IS NULL THEN RAISE EXCEPTION 'Requiere migración 089'; END IF;
END $$;
ALTER TABLE public.despachos_oc ADD COLUMN IF NOT EXISTS oc_documento text
 CHECK(oc_documento IS NULL OR (length(oc_documento) BETWEEN 1 AND 150 AND oc_documento=btrim(oc_documento)));
CREATE OR REPLACE FUNCTION public.guardar_empaque_destinatario_v90(
 p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb,p_destinatario uuid,p_destinatario_version text,
 p_id uuid DEFAULT NULL,p_version text DEFAULT NULL,p_motivo text DEFAULT NULL,p_oc_documento text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE a public.usuarios%rowtype; previo public.empaque_solicitudes%rowtype; destino jsonb; r jsonb;
 pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques,
 'destinatario',p_destinatario,'destinatario_version',p_destinatario_version,'id',p_id,'version',p_version,'motivo',p_motivo,'oc_documento',nullif(btrim(p_oc_documento),''));
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 IF length(btrim(p_oc_documento))>150 THEN RAISE EXCEPTION 'La OC del despacho permite máximo 150 caracteres'; END IF;
 SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.empaque_solicitudes WHERE solicitud=p_solicitud;
 IF FOUND THEN
  IF previo.actor<>a.id OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada para otro empaque'; END IF;
  RETURN previo.resultado;
 END IF;
 SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario FOR SHARE;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona el destinatario antes de empacar'; END IF;
 IF p_destinatario_version IS DISTINCT FROM md5(destino::text) THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo y vuelve a generar los rótulos'; END IF;
 IF p_id IS NULL THEN
  IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud ya registrada. Abre su LE para corregir'; END IF;
  r:=public.despachar_oc_bultos(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 ELSE
  IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud de corrección ya registrada'; END IF;
  r:=public.corregir_despacho_le(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 UPDATE public.despachos_oc SET oc_documento=nullif(btrim(p_oc_documento),''),destinatario_id=p_destinatario,destinatario_empaque=destino,empacado_por=a.nombre WHERE id=(r->>'id')::uuid;
 INSERT INTO public.empaque_solicitudes(solicitud,actor,pedido,resultado) VALUES(p_solicitud,a.id,pedido,r);
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) TO authenticated;
-- Solo cambia la OC a imprimir. Las LE emitidas se devuelven intactas;
-- una corrección invalida la LE y conserva su versión anterior en auditoría.
DO $$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('public.le_documento(text,uuid,jsonb,boolean)'::regprocedure) INTO f;
 IF position('coalesce(d.oc_documento,d.oc)' in f)=0 THEN
  IF position('''oc'',d.oc' in f)=0 THEN RAISE EXCEPTION 'Revisar generador de LE'; END IF;
  EXECUTE replace(f,'''oc'',d.oc','''oc'',coalesce(d.oc_documento,d.oc)');
 END IF;
END $$;
-- Conserva la OC original para cálculos y añade la OC visible del despacho.
DO $$ BEGIN
 IF to_regprocedure('public.historial_despachos_base_v90(text)') IS NULL THEN
  ALTER FUNCTION public.historial_despachos_empaques(text) RENAME TO historial_despachos_base_v90;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.historial_despachos_empaques(p_despues text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.historial_despachos_base_v90(p_despues);
 RETURN coalesce((SELECT jsonb_agg(x.value||jsonb_build_object('oc_documento',coalesce(d.oc_documento,d.oc,x.value->>'oc')) ORDER BY x.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY x
 LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_oc_id')::uuid),'[]');
END $$;
REVOKE ALL ON FUNCTION public.historial_despachos_base_v90(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.historial_despachos_empaques(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.historial_despachos_empaques(text) TO authenticated;
-- Excel conserva la OC del kardex y añade la del despacho en otra columna.
DO $$ BEGIN
 IF to_regprocedure('public.admin_trazabilidad_base_v90(text)') IS NULL THEN
  ALTER FUNCTION public.admin_trazabilidad_op(text) RENAME TO admin_trazabilidad_base_v90;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.admin_trazabilidad_op(p_op text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE filas jsonb;
BEGIN
 filas:=public.admin_trazabilidad_base_v90(p_op);
 RETURN coalesce((SELECT jsonb_agg(x.value||jsonb_build_object('oc_documento',coalesce(d.oc_documento,d.oc)) ORDER BY x.ordinality)
 FROM jsonb_array_elements(filas) WITH ORDINALITY x
 LEFT JOIN public.despachos_oc d ON d.id=(x.value->>'despacho_id')::uuid),'[]');
END $$;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_base_v90(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.admin_trazabilidad_op(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_trazabilidad_op(text) TO authenticated;
NOTIFY pgrst,'reload schema';


-- 091_fecha_recibido_libre.sql


SET LOCAL lock_timeout='5s';
DO $$ DECLARE f text;
 regla text := $regla$IF f IS NOT NULL AND (f<(d.fecha AT TIME ZONE 'America/Bogota')::date OR f>(now() AT TIME ZONE 'America/Bogota')::date) THEN RAISE EXCEPTION 'La recepción debe estar entre el despacho y hoy'; END IF;$regla$;
BEGIN
 
 
 SELECT pg_get_functiondef('public.seguimiento_guardar_base_v87(uuid,integer,integer,jsonb)'::regprocedure) INTO f;
 IF position('public.seguimiento_acceso()' in f)=0 THEN RAISE EXCEPTION 'Requiere permisos de 089'; END IF;
 IF position('FECHA_LIBRE_V91' in f)>0 THEN RETURN; END IF;
 IF position(regla in f)=0 THEN RAISE EXCEPTION 'Validación de fecha inesperada; revisar antes de aplicar'; END IF;
 -- Conserva conversión a date, control de versiones, estados, archivos y permisos.
 EXECUTE replace(f,regla,'-- FECHA_LIBRE_V91: la fecha válida la elige el usuario, sin límites relativos al despacho o a hoy.');
END $$;
NOTIFY pgrst,'reload schema';


-- 092_peso_por_empaque.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Requiere 090'; END IF;
END $$;
-- peso_neto_kg del catálogo conserva el significado de tara por compatibilidad.
-- En cada despacho se guardan explícitamente tara, bruto real y neto (bruto - tara).
ALTER TABLE public.empaques ALTER COLUMN peso_bruto_kg DROP NOT NULL;
CREATE OR REPLACE FUNCTION public.admin_empaque_guardar_v92(p_id uuid,p_version text,p_datos jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb;
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.empaques IN SHARE ROW EXCLUSIVE MODE;
 IF jsonb_typeof(p_datos) IS DISTINCT FROM 'object'
 OR p_datos->>'categoria' IS NULL OR p_datos->>'categoria' NOT IN ('CAJA','BOLSA')
 OR coalesce(length(trim(p_datos->>'nombre')),0) NOT BETWEEN 1 AND 150
 OR jsonb_typeof(p_datos->'activo') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Datos del empaque invalidos.'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['largo_cm','ancho_cm','alto_cm','peso_neto_kg']) k
   WHERE jsonb_typeof(p_datos->k) IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Medidas y pesos deben ser numeros.'; END IF;
 IF p_id IS NOT NULL THEN
   SELECT to_jsonb(e) INTO anterior FROM public.empaques e WHERE id=p_id;
   IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'El empaque cambio. Actualiza la lista.'; END IF;
   UPDATE public.empaques SET nombre=trim(p_datos->>'nombre'),categoria=p_datos->>'categoria',
     largo_cm=(p_datos->>'largo_cm')::numeric,ancho_cm=(p_datos->>'ancho_cm')::numeric,alto_cm=(p_datos->>'alto_cm')::numeric,
     peso_neto_kg=(p_datos->>'peso_neto_kg')::numeric,peso_bruto_kg=NULL,activo=(p_datos->>'activo')::boolean
   WHERE id=p_id RETURNING to_jsonb(empaques.*) INTO nuevo;
 ELSE
   INSERT INTO public.empaques(nombre,categoria,largo_cm,ancho_cm,alto_cm,peso_neto_kg,peso_bruto_kg,activo)
   VALUES(trim(p_datos->>'nombre'),p_datos->>'categoria',(p_datos->>'largo_cm')::numeric,(p_datos->>'ancho_cm')::numeric,
     (p_datos->>'alto_cm')::numeric,(p_datos->>'peso_neto_kg')::numeric,NULL,(p_datos->>'activo')::boolean)
   RETURNING to_jsonb(empaques.*) INTO nuevo;
 END IF;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues)
 VALUES(auth.uid(),'empaques',(nuevo->>'id')::uuid,anterior,nuevo);
 RETURN nuevo;
END $$;

CREATE OR REPLACE FUNCTION public.guardar_empaque_destinatario_v92(
 p_solicitud text,p_cliente text,p_oc text,p_lineas jsonb,p_empaques jsonb,p_destinatario uuid,p_destinatario_version text,
 p_id uuid DEFAULT NULL,p_version text DEFAULT NULL,p_motivo text DEFAULT NULL,p_oc_documento text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE a public.usuarios%rowtype; previo public.empaque_solicitudes%rowtype; destino jsonb; r jsonb; copia jsonb;
 pedido jsonb:=jsonb_build_object('cliente',p_cliente,'oc',p_oc,'lineas',p_lineas,'empaques',p_empaques,
 'destinatario',p_destinatario,'destinatario_version',p_destinatario_version,'id',p_id,'version',p_version,'motivo',p_motivo,'oc_documento',nullif(btrim(p_oc_documento),''));
BEGIN
 LOCK TABLE public.usuarios IN SHARE MODE;
 IF NOT public.le_acceso() THEN RAISE EXCEPTION 'Se requiere Despacho o Seguimiento' USING ERRCODE='42501'; END IF;
 IF length(btrim(p_oc_documento))>150 THEN RAISE EXCEPTION 'La OC del despacho permite máximo 150 caracteres'; END IF;
 SELECT * INTO a FROM public.usuarios WHERE auth_id=auth.uid() AND activo;
 LOCK TABLE public.ordenes_produccion,public.items_orden,public.movimientos,public.ubicaciones,public.despachos_oc IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO previo FROM public.empaque_solicitudes WHERE solicitud=p_solicitud;
 IF FOUND THEN
  IF previo.actor<>a.id OR previo.pedido IS DISTINCT FROM pedido THEN RAISE EXCEPTION 'Solicitud utilizada para otro empaque'; END IF;
  RETURN previo.resultado;
 END IF;
 -- Cada número es una pieza física; sus OP/tallas comparten un único peso.
 IF jsonb_typeof(p_empaques) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Empaques inválidos'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e
   WHERE jsonb_typeof(e->'peso_bruto_kg') IS DISTINCT FROM 'number') THEN RAISE EXCEPTION 'Indica el peso bruto de cada caja o paquete'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e
   WHERE (e->>'peso_bruto_kg')::numeric<=0 OR (e->>'peso_bruto_kg')::numeric>100000) THEN RAISE EXCEPTION 'Peso bruto fuera de rango'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) e GROUP BY e->>'numero'
   HAVING count(DISTINCT (e->>'peso_bruto_kg')::numeric)>1) THEN RAISE EXCEPTION 'Todas las prendas del mismo empaque deben compartir su peso bruto'; END IF;
 LOCK TABLE public.empaques IN SHARE MODE;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_empaques) x JOIN public.empaques e ON e.id=(x->>'empaque_id')::uuid
   WHERE (x->>'peso_bruto_kg')::numeric<e.peso_neto_kg) THEN RAISE EXCEPTION 'El peso bruto no puede ser menor que la tara'; END IF;
 SELECT datos INTO destino FROM public.destinatarios_empaque WHERE id=p_destinatario FOR SHARE;
 IF destino IS NULL THEN RAISE EXCEPTION 'Selecciona el destinatario antes de empacar'; END IF;
 IF p_destinatario_version IS DISTINCT FROM md5(destino::text) THEN RAISE EXCEPTION 'El destinatario cambió. Actualiza el catálogo y vuelve a generar los rótulos'; END IF;
 IF p_id IS NULL THEN
  IF EXISTS(SELECT 1 FROM public.despachos_oc WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud ya registrada. Abre su LE para corregir'; END IF;
  r:=public.despachar_oc_bultos(p_solicitud,p_cliente,p_oc,p_lineas,p_empaques);
 ELSE
  IF EXISTS(SELECT 1 FROM public.despacho_revisiones WHERE solicitud=p_solicitud) THEN RAISE EXCEPTION 'Solicitud de corrección ya registrada'; END IF;
  r:=public.corregir_despacho_le(p_id,p_version,p_solicitud,p_motivo,p_cliente,p_oc,p_lineas,p_empaques);
 END IF;
 UPDATE public.despachos_oc SET oc_documento=nullif(btrim(p_oc_documento),''),destinatario_id=p_destinatario,destinatario_empaque=destino,empacado_por=a.nombre WHERE id=(r->>'id')::uuid;
 SELECT jsonb_agg(e.value||jsonb_build_object(
   'peso_tara_kg',(e.value->>'peso_neto_kg')::numeric,
   'peso_bruto_kg',(p_empaques->(e.ordinality::integer-1)->>'peso_bruto_kg')::numeric,
   'peso_neto_kg',(p_empaques->(e.ordinality::integer-1)->>'peso_bruto_kg')::numeric-(e.value->>'peso_neto_kg')::numeric
 ) ORDER BY e.ordinality) INTO copia
 FROM public.despachos_oc d CROSS JOIN LATERAL jsonb_array_elements(d.empaques) WITH ORDINALITY e WHERE d.id=(r->>'id')::uuid;
 UPDATE public.despachos_oc SET empaques=copia WHERE id=(r->>'id')::uuid;
 r:=r||jsonb_build_object('empaques',copia);
 INSERT INTO public.empaque_solicitudes(solicitud,actor,pedido,resultado) VALUES(p_solicitud,a.id,pedido,r);
 RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb),public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_empaque_guardar_v92(uuid,text,jsonb),public.guardar_empaque_destinatario_v92(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) TO authenticated;
-- Impide que un cliente antiguo omita el peso obligatorio.
REVOKE ALL ON FUNCTION public.admin_empaque_guardar(uuid,text,jsonb),public.guardar_empaque_destinatario(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text),public.guardar_empaque_destinatario_v90(text,text,text,jsonb,jsonb,uuid,text,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';


-- 093_destinatarios_internacionales.sql


SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
END $$;
CREATE OR REPLACE FUNCTION public.le_importar_clientes_internacionales(p_filas jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r jsonb; n integer:=0; k text; campo text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Solo Administrador' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Archivo de clientes invalido'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
  IF jsonb_typeof(r) IS DISTINCT FROM 'object' OR r->>'tipo_destinatario' IS DISTINCT FROM 'internacional' OR length(r::text)>10000 THEN RAISE EXCEPTION 'Destinatario internacional invalido'; END IF;
  FOREACH campo IN ARRAY ARRAY['nombre','email','via','tipo_carga','embalaje','puerto_embarque','pais_origen','puerto_destino','pais_destino','termino_negociacion'] LOOP
   IF jsonb_typeof(r->campo) IS DISTINCT FROM 'string' OR coalesce(length(btrim(r->>campo)),0) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Completa el campo internacional: %',campo; END IF;
  END LOOP;
  -- Espacio de claves independiente: jamás sustituye un destinatario nacional.
  k:=md5(jsonb_build_array('internacional',r->>'nombre',r->>'nit',r->>'direccion',r->>'ciudad',r->>'contacto',r->>'telefono',r->>'celular',coalesce(nullif(btrim(r->>'sede'),''),''))::text);
  INSERT INTO public.destinatarios_empaque(clave,datos) VALUES(k,r)
   ON CONFLICT(clave) DO UPDATE SET datos=excluded.datos;
  n:=n+1;
 END LOOP;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.le_importar_clientes_internacionales(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.le_importar_clientes_internacionales(jsonb) TO authenticated;


-- 094_usuarios_multiperfil.sql

-- Después actualizar admin-crear-usuario (index.ts y handler.mjs) en DEV.

SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 
 
 IF to_regprocedure('public.le_importar_clientes_internacionales(jsonb)') IS NULL THEN RAISE EXCEPTION 'Requiere migracion 093'; END IF;
END $$;
-- NULL conserva exactamente el rol anterior, sin reescribir cuentas históricas.
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS roles text[];
CREATE TEMP TABLE perfiles_usuarios_previos ON COMMIT DROP AS SELECT to_jsonb(u) fila FROM public.usuarios u;
CREATE OR REPLACE FUNCTION public.usuario_roles_normalizar(p_roles text[]) RETURNS text[]
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,public AS $$
DECLARE resultado text[];
BEGIN
 IF p_roles IS NULL OR cardinality(p_roles) NOT BETWEEN 1 AND 6 OR array_ndims(p_roles)<>1
    OR array_position(p_roles,NULL) IS NOT NULL
    OR NOT p_roles <@ ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia']::text[] THEN
  RAISE EXCEPTION 'Selecciona al menos un perfil valido.';
 END IF;
 SELECT array_agg(r ORDER BY n) INTO resultado FROM unnest(ARRAY['admin','seguimiento','produccion','logistica','despacho','gerencia']) WITH ORDINALITY AS t(r,n) WHERE r=ANY(p_roles);
 RETURN resultado;
END $$;
REVOKE ALL ON FUNCTION public.usuario_roles_normalizar(text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.usuario_roles_normalizar(text[]) TO authenticated,service_role;
ALTER TABLE public.usuarios DROP CONSTRAINT IF EXISTS usuarios_roles_check;
-- Admin siempre es principal. Gerencia es principal únicamente si no hay perfiles operativos.
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_roles_check CHECK (
 roles IS NULL OR (roles=public.usuario_roles_normalizar(roles) AND rol=roles[1])
);

-- Actualiza solamente predicados de autorización de las RPC instaladas.
-- Se conservan sus firmas, grants y el resto de validaciones de cada operación.
DO $$ DECLARE r record; d text; nuevo text;
 patron text := $p$\mrol\s+IN\s*\(('(?:admin|produccion|logistica|despacho|seguimiento|gerencia)'(?:\s*,\s*'(?:admin|produccion|logistica|despacho|seguimiento|gerencia)')*)\)$p$;
BEGIN
 FOR r IN SELECT p.oid,p.proname,p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc ~ patron LOOP
  IF r.proname NOT IN (
   'crear_lote','enviar_no_conforme_aliado','liberar_no_conforme','liberar_no_conforme_aliado',
   'recibir_lote_item','cerrar_lote_item_con_faltante','registrar_no_conforme','registrar_sobrante','resolver_sobrante','validar_stock_no_conforme',
   'despachar_oc','despachar_oc_empaques','despachar_oc_prendas_empaques','historial_despachos_oc','empaques_listar',
   'le_acceso','seguimiento_acceso','wms_cuenta_operativa','puede_ver_dashboards','kardex_historico'
  ) THEN RAISE EXCEPTION 'Revisar predicado de perfiles en % antes de migrar',r.proname; END IF;
  d:=pg_get_functiondef(r.oid);
  nuevo:=regexp_replace(d,patron,'(coalesce(roles,ARRAY[rol]) && ARRAY[\1]::text[])','g');
  EXECUTE nuevo;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_guardar_roles(p_id uuid,p_nombre text,p_roles text[],p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE anterior jsonb; nuevo jsonb; perfiles text[];
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 perfiles:=public.usuario_roles_normalizar(p_roles);
 SELECT to_jsonb(u) INTO anterior FROM public.usuarios u WHERE id=p_id;
 IF anterior IS NULL OR p_version IS DISTINCT FROM md5(anterior::text) THEN RAISE EXCEPTION 'La cuenta cambio. Actualiza la lista antes de guardar.'; END IF;
 IF p_activo IS NULL OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Nombre o estado invalido.'; END IF;
 IF (anterior->>'auth_id')::uuid=auth.uid() AND NOT p_activo THEN RAISE EXCEPTION 'No puedes desactivar tu propia cuenta.'; END IF;
 IF (anterior->>'activo')::boolean AND anterior->>'rol'='admin' AND (NOT p_activo OR NOT 'admin'=ANY(perfiles))
    AND NOT EXISTS(SELECT 1 FROM public.usuarios WHERE id<>p_id AND rol='admin' AND activo AND auth_id IS NOT NULL) THEN RAISE EXCEPTION 'Debe permanecer al menos un administrador activo con acceso.'; END IF;
 UPDATE public.usuarios SET nombre=trim(p_nombre),rol=perfiles[1],roles=perfiles,activo=p_activo WHERE id=p_id RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(auth.uid(),'usuarios',p_id,anterior,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_usuario_guardar_roles(uuid,text,text[],boolean,text) TO authenticated;

-- Clientes antiguos pueden cambiar nombre/estado, pero nunca descartar perfiles extra sin verlo.
CREATE OR REPLACE FUNCTION public.admin_usuario_guardar(p_id uuid,p_nombre text,p_rol text,p_activo boolean,p_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE perfiles text[]; principal text;
BEGIN
 IF NOT public.admin_es_admin() THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 SELECT roles,rol INTO perfiles,principal FROM public.usuarios WHERE id=p_id;
 IF cardinality(perfiles)>1 AND p_rol IS DISTINCT FROM principal THEN RAISE EXCEPTION 'Actualiza la aplicación para editar varios perfiles.'; END IF;
 RETURN public.admin_usuario_guardar_roles(p_id,p_nombre,CASE WHEN p_rol=principal THEN coalesce(perfiles,ARRAY[p_rol]) ELSE ARRAY[p_rol] END,p_activo,p_version);
END $$;

CREATE OR REPLACE FUNCTION public.admin_usuario_registrar_roles(p_actor uuid,p_auth_id uuid,p_numero text,p_nombre text,p_roles text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET lock_timeout='5s' AS $$
DECLARE nuevo jsonb; perfiles text[];
BEGIN
 LOCK TABLE public.usuarios IN SHARE ROW EXCLUSIVE MODE;
 IF NOT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_actor AND rol='admin' AND activo) THEN RAISE EXCEPTION 'Acceso exclusivo del administrador.' USING ERRCODE='42501'; END IF;
 perfiles:=public.usuario_roles_normalizar(p_roles);
 IF p_auth_id IS NULL OR p_numero IS NULL OR p_numero !~ '^[0-9]{1,30}$' OR coalesce(length(trim(p_nombre)),0) NOT BETWEEN 1 AND 150 THEN RAISE EXCEPTION 'Datos del usuario invalidos.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_auth_id AND email=p_numero||'@orbiloq.local') THEN RAISE EXCEPTION 'La cuenta de acceso no corresponde al numero de usuario.'; END IF;
 SELECT to_jsonb(u) INTO nuevo FROM public.usuarios u WHERE auth_id=p_auth_id AND numero_usuario=p_numero;
 IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=p_auth_id OR numero_usuario=p_numero) THEN RAISE EXCEPTION 'La cuenta o numero de usuario ya existe.'; END IF;
 INSERT INTO public.usuarios(numero_usuario,nombre,rol,roles,auth_id,email,activo) VALUES(p_numero,trim(p_nombre),perfiles[1],perfiles,p_auth_id,p_numero||'@orbiloq.local',true) RETURNING to_jsonb(usuarios.*) INTO nuevo;
 INSERT INTO public.admin_catalogos_historial(actor_id,catalogo,registro_id,antes,despues) VALUES(p_actor,'usuarios',(nuevo->>'id')::uuid,NULL,nuevo);
 RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION public.admin_usuario_registrar_roles(uuid,uuid,text,text,text[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_usuario_registrar_roles(uuid,uuid,text,text,text[]) TO service_role;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.usuarios FROM authenticated,anon;
DO $$ BEGIN
 IF EXISTS(SELECT fila FROM perfiles_usuarios_previos EXCEPT ALL SELECT to_jsonb(u) FROM public.usuarios u)
 OR EXISTS(SELECT to_jsonb(u) FROM public.usuarios u EXCEPT ALL SELECT fila FROM perfiles_usuarios_previos) THEN
  RAISE EXCEPTION 'La migración no debe modificar cuentas existentes';
 END IF;
END $$;
NOTIFY pgrst,'reload schema';


-- Ninguna fila ni columna original puede cambiar; incluye documentos emitidos y Auth.
DO $$ DECLARE t record; diferencia boolean; BEGIN
 FOR t IN SELECT * FROM previo_tablas LOOP
  EXECUTE format('SELECT EXISTS((SELECT fila FROM previo_filas WHERE nombre=%L EXCEPT ALL SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x) UNION ALL (SELECT to_jsonb(x) FROM (SELECT %s FROM %s) x EXCEPT ALL SELECT fila FROM previo_filas WHERE nombre=%L))',t.nombre,t.columnas,t.nombre,t.columnas,t.nombre,t.nombre) INTO diferencia;
  IF diferencia THEN RAISE EXCEPTION 'Cambió contenido original de %: rollback',t.nombre; END IF;
 END LOOP;
 IF EXISTS((SELECT fila FROM previo_secuencias EXCEPT ALL SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public') UNION ALL (SELECT to_jsonb(s) FROM pg_sequences s WHERE schemaname='public' EXCEPT ALL SELECT fila FROM previo_secuencias)) THEN RAISE EXCEPTION 'Cambió un consecutivo: rollback'; END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
