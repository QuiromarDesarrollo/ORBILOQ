DO $$ BEGIN IF current_database()<>'ensayo' THEN RAISE EXCEPTION 'Solo ensayo'; END IF; END $$;
INSERT INTO public.ordenes_produccion(numero_op,cliente,fecha_esperada_produccion,fecha_esperada_logistica) VALUES
('25812','TEST','2026-08-01','2026-09-01'),
('25813','TEST','2026-07-31','2026-08-31'),
('25814','TEST','2026-08-15','2026-08-20'),
('25815','TEST','2025-08-15',NULL);

INSERT INTO public.ordenes_produccion(numero_op,cliente,fecha_esperada_produccion,fecha_esperada_logistica) VALUES
('25811','FUERA','2026-08-10','2026-08-20'),
('25824','FUERA','2026-08-10','2026-08-20'),
('25831','FUERA','2026-08-10','2026-08-20'),
('25853','FUERA','2026-08-10','2026-08-20'),
('25854','FUERA','2026-08-10','2026-08-20'),
('25855','FUERA','2026-08-10','2026-08-20'),
('25856','FUERA','2026-08-10','2026-08-20'),
('25991','FUERA','2026-08-10','2026-08-20'),
('25997','FUERA','2026-08-10','2026-08-20'),
('26070','FUERA','2026-08-10','2026-08-20');
