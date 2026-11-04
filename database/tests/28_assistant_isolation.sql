-- El asistente ve solo la cuenta de la sesion, y nada sensible.
--
-- Es la prueba mas importante de este bloque: un fallo aqui muestra la finca de
-- un cliente a otro, y el texto del asistente no permite notarlo.
--
-- Un usuario sin CREATEROLE instala sin el rol (ver 0033), y entonces no hay nada
-- que probar. CI siempre lo tiene.
SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'smartcattle_assistant') AS has_assistant_role \gset
\if :has_assistant_role
BEGIN;

DO $$
DECLARE
    ana   bigint;
    luis  bigint;
    cam_a bigint;
    cam_l bigint;
BEGIN
    INSERT INTO users (email, password_hash, full_name) VALUES ('t28-ana@x.co', 'h', 'Ana') RETURNING id INTO ana;
    INSERT INTO users (email, password_hash, full_name) VALUES ('t28-luis@x.co', 'h', 'Luis') RETURNING id INTO luis;
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t28-a', ana, 'Corral') RETURNING id INTO cam_a;
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t28-l', luis, 'Potrero') RETURNING id INTO cam_l;

    INSERT INTO detection_logs (camera_id, minute, cattle_lying, cattle_standing, cattle_walking,
                                cattle_unknown, people, observed_at) VALUES
        (cam_a, '2026-03-01 15:00+00', 1, 0, 0, 0, 0, now()),
        (cam_l, '2026-03-01 15:00+00', 0, 0, 0, 0, 2, now()),
        (cam_l, '2026-03-01 15:01+00', 0, 0, 0, 0, 3, now());
    INSERT INTO events (type, camera_id, detected_at) VALUES ('cattle_out_of_zone', cam_l, '2026-03-01 15:00+00');

    -- Los ids pasan como variables de sesion porque el rol no puede leer users.
    PERFORM set_config('t28.ana', ana::text, true);
    PERFORM set_config('t28.luis', luis::text, true);
END $$;

SET LOCAL ROLE smartcattle_assistant;

DO $$
BEGIN
    -- Sin cuenta en la sesion: nada, ni siquiera un error.
    PERFORM set_config('app.current_account_id', '', true);
    ASSERT (SELECT count(*) FROM v_assistant_detections) = 0, 'sin cuenta no deberia ver detecciones';
    ASSERT (SELECT count(*) FROM v_assistant_events) = 0, 'sin cuenta no deberia ver eventos';
    ASSERT (SELECT count(*) FROM assistant_daily_reports('2026-03-01', '2026-03-01')) = 0,
           'sin cuenta no deberia ver informes';

    PERFORM set_config('app.current_account_id', current_setting('t28.ana'), true);
    ASSERT (SELECT count(*) FROM v_assistant_detections) = 1, 'ana deberia ver solo su fila';
    ASSERT (SELECT camera FROM v_assistant_detections) = 'Corral', 'ana deberia ver su camara';
    ASSERT (SELECT count(*) FROM v_assistant_events) = 0, 'ana no deberia ver eventos de luis';
    ASSERT (SELECT camera FROM assistant_daily_reports('2026-03-01', '2026-03-01')) = 'Corral',
           'ana deberia recibir solo su informe';

    PERFORM set_config('app.current_account_id', current_setting('t28.luis'), true);
    ASSERT (SELECT count(*) FROM v_assistant_detections) = 2, 'luis deberia ver sus dos filas';
    ASSERT (SELECT count(*) FROM v_assistant_events) = 1, 'luis deberia ver su evento';
    ASSERT (SELECT max_people FROM assistant_daily_reports('2026-03-01', '2026-03-01')) = 3,
           'luis deberia recibir su informe';

    -- Pedir la camara de otro por nombre tampoco la trae.
    ASSERT NOT EXISTS (SELECT 1 FROM v_assistant_detections WHERE camera = 'Corral'),
           'luis no deberia alcanzar la camara de ana por su nombre';
END $$;

-- El rol no alcanza ninguna tabla, y no escribe.
DO $$
DECLARE
    target text;
BEGIN
    FOREACH target IN ARRAY ARRAY['users', 'cameras', 'detection_logs', 'detections', 'events', 'audit_log'] LOOP
        BEGIN
            EXECUTE format('SELECT 1 FROM %I LIMIT 1', target);
            ASSERT false, format('el asistente no deberia leer %s', target);
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
    END LOOP;

    ASSERT NOT has_table_privilege('smartcattle_assistant', 'v_assistant_detections', 'INSERT, UPDATE, DELETE'),
           'el asistente no deberia poder escribir por las vistas';

    -- daily_reports() acepta cualquier cuenta, y por eso no le sirve a este rol:
    -- corre con sus permisos y no alcanza las tablas.
    BEGIN
        PERFORM * FROM daily_reports(current_setting('t28.ana')::bigint, '2026-03-01', '2026-03-01');
        ASSERT false, 'el asistente no deberia pedir el informe de una cuenta a su eleccion';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
        PERFORM prune_detection_logs(interval '1 second');
        ASSERT false, 'el asistente no deberia podar';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END $$;

RESET ROLE;

-- La funcion con SECURITY DEFINER no queda abierta a cualquiera.
DO $$
BEGIN
    ASSERT NOT has_function_privilege('public', 'assistant_daily_reports(date, date, text)', 'EXECUTE'),
           'assistant_daily_reports no deberia estar abierta a PUBLIC';
END $$;

-- Ninguna vista del asistente saca columnas sensibles, ni las que lleguen luego.
DO $$
DECLARE
    leaked text[];
BEGIN
    SELECT array_agg(format('%s.%s', table_name, column_name)) INTO leaked
      FROM information_schema.columns
     WHERE table_name LIKE 'v\_assistant\_%'
       AND column_name IN ('password_hash', 'email', 'full_name', 'source', 'stream_url',
                           'last_error', 'ip_address', 'preferences', 'storage_key');
    ASSERT leaked IS NULL, format('el asistente expone columnas sensibles: %s', leaked);

    -- Todas llevan security_barrier, tambien las que se crean condicionalmente.
    SELECT array_agg(c.relname) INTO leaked
      FROM pg_class c
     WHERE c.relkind = 'v' AND c.relname LIKE 'v\_assistant\_%'
       AND NOT coalesce(c.reloptions @> ARRAY['security_barrier=true'], false);
    ASSERT leaked IS NULL, format('vistas sin security_barrier: %s', leaked);
END $$;

ROLLBACK;
\else
\echo 'smartcattle_assistant no existe; se omite'
\endif
