-- Entorno mínimo desechable para probar 114 sin conectarse a Supabase.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE TABLE public.usuarios(auth_id uuid, numero_usuario text, nombre text, activo boolean,
rol text CONSTRAINT usuarios_rol_check CHECK(rol IN('admin','conductor')),roles text[]);
CREATE TABLE public.items_orden(id uuid,codigo text);
INSERT INTO public.items_orden VALUES('0701856a-7771-4536-9762-658a58af8803','DEMO-001');
CREATE FUNCTION public.admin_es_admin() RETURNS boolean LANGUAGE sql SECURITY DEFINER AS
$$ SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE auth_id=auth.uid() AND activo AND rol='admin') $$;
INSERT INTO auth.users VALUES('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),
('00000000-0000-0000-0000-000000000003');
INSERT INTO public.usuarios VALUES
('00000000-0000-0000-0000-000000000001','1','Admin',true,'admin',ARRAY['admin']),
('00000000-0000-0000-0000-000000000002','2','Conductor A',true,'conductor',ARRAY['conductor']),
('00000000-0000-0000-0000-000000000003','3','Conductor B',true,'conductor',ARRAY['conductor']);
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
