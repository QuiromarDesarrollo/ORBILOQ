-- Acceso a Resumen/Indicadores exclusivo de administradores.
-- Sin operacion, resumen solo devuelve el selector de operaciones compartido.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $patch$
DECLARE original text; nuevo text;
BEGIN
 original:=pg_get_functiondef('public.masiva_consultar(uuid,text,text,integer,text)'::regprocedure);
 IF position('masiva_admin_resumen_indicadores_20261125' IN original)>0 THEN RETURN; END IF;
 IF position('masiva_admin_pantallas_20261125' IN original)=0 THEN RAISE EXCEPTION 'Falta proteccion previa; revisar definicion'; END IF;
 nuevo:=regexp_replace(original,'\mBEGIN\M',$guard$BEGIN
 -- masiva_admin_resumen_indicadores_20261125
 IF (p_vista='indicadores' OR (p_vista='resumen' AND p_operacion IS NOT NULL)) AND NOT EXISTS (SELECT 1 FROM public.usuarios u WHERE u.auth_id=auth.uid() AND u.activo AND 'admin'=ANY(coalesce(u.roles,ARRAY[u.rol]))) THEN
 RAISE EXCEPTION 'Esta pantalla de Masiva requiere rol Administrador' USING ERRCODE='42501'; END IF;
$guard$,'i');
 IF nuevo=original THEN RAISE EXCEPTION 'No se encontro bloque principal'; END IF;
 EXECUTE nuevo;
END $patch$;
COMMIT;
SELECT position('masiva_admin_resumen_indicadores_20261125' IN pg_get_functiondef('public.masiva_consultar(uuid,text,text,integer,text)'::regprocedure))>0 AS protegido;
