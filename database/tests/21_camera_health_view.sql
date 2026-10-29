-- v_camera_health da por caida a una camara que dejo de reportar.
--
-- Es la regla que separa "la IA dijo online" de "la camara esta online". La
-- vista la crea la migracion 0012, que se salta si faltan las columnas del
-- backend, asi que la comprobacion tambien se salta en ese caso.
DO $$
DECLARE
    camera bigint;
BEGIN
    IF to_regclass('v_camera_health') IS NULL THEN
        RAISE NOTICE 'v_camera_health no existe (faltan las columnas del backend); se omite';
        RETURN;
    END IF;

    INSERT INTO cameras (name) VALUES ('test-health') RETURNING id INTO camera;

    -- Sin reporte: desconocida, no caida. Son estados distintos y confundirlos
    -- hace que una camara que nadie configuro parezca una averiada.
    ASSERT (SELECT effective_status FROM v_camera_health WHERE id = camera) = 'unknown',
           'una camara sin reporte deberia ser unknown';

    -- Reporte reciente diciendo online: online.
    UPDATE cameras SET reported_status = 'online', last_report_at = now() WHERE id = camera;
    ASSERT (SELECT effective_status FROM v_camera_health WHERE id = camera) = 'online',
           'un reporte reciente de online deberia quedar online';

    -- El mismo reporte, viejo: caida, aunque la columna siga diciendo online.
    UPDATE cameras SET last_report_at = now() - interval '10 minutes' WHERE id = camera;
    ASSERT (SELECT effective_status FROM v_camera_health WHERE id = camera) = 'offline',
           'un reporte vencido deberia dar offline';
    ASSERT (SELECT reported_status FROM v_camera_health WHERE id = camera) = 'online',
           'la vista no deberia modificar reported_status, solo interpretarlo';

    DELETE FROM cameras WHERE id = camera;
END $$;
