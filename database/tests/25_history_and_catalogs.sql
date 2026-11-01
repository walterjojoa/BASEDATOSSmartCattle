-- Historial, catalogos y vistas de reportes (migraciones 0025 a 0028).
--
-- Que existen, que los catalogos no se duplican al aplicar dos veces, y que
-- las tablas de historial rechazan lo que dicen rechazar.
DO $$
DECLARE
    missing text[];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY[
        'event_types', 'severity_levels', 'alert_statuses', 'camera_statuses',
        'lot_kinds', 'user_roles', 'animal_statuses', 'video_upload_statuses',
        'occupancy_samples', 'camera_status_changes', 'audit_log',
        -- Las tres vistas que no dependen de tablas del backend.
        'v_events_daily', 'v_occupancy_hourly', 'v_camera_status_periods'
    ]) AS name
    WHERE to_regclass(name) IS NULL;
    ASSERT missing IS NULL, format('faltan tablas o vistas: %s', missing);

    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY[
        'occupancy_samples_minute_idx', 'camera_status_changes_camera_id_changed_at_idx',
        'audit_log_created_at_idx', 'audit_log_actor_id_idx', 'audit_log_action_created_at_idx'
    ]) AS name
    WHERE to_regclass(name) IS NULL;
    ASSERT missing IS NULL, format('faltan indices del historial: %s', missing);
END $$;

-- Cada catalogo tiene sus filas una sola vez, aunque CI aplique todo dos veces.
DO $$
BEGIN
    ASSERT (SELECT count(*) FROM event_types)           = 1, 'event_types';
    ASSERT (SELECT count(*) FROM severity_levels)       = 3, 'severity_levels';
    ASSERT (SELECT count(*) FROM alert_statuses)        = 3, 'alert_statuses';
    ASSERT (SELECT count(*) FROM camera_statuses)       = 3, 'camera_statuses';
    ASSERT (SELECT count(*) FROM lot_kinds)             = 4, 'lot_kinds';
    ASSERT (SELECT count(*) FROM user_roles)            = 2, 'user_roles';
    ASSERT (SELECT count(*) FROM animal_statuses)       = 3, 'animal_statuses';
    ASSERT (SELECT count(*) FROM video_upload_statuses) = 5, 'video_upload_statuses';

    -- Los roles del catalogo son los que admite users.role.
    ASSERT (SELECT array_agg(code ORDER BY code) FROM user_roles) = ARRAY['owner', 'worker'],
           'user_roles no coincide con users.role';
    -- Las tildes llegaron enteras.
    ASSERT (SELECT label_es FROM user_roles WHERE code = 'owner') = 'Dueño',
           'la etiqueta en espanol se guardo con otra codificacion';
END $$;

DO $$
DECLARE
    test_camera bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-history') RETURNING id INTO test_camera;

    BEGIN
        INSERT INTO occupancy_samples (camera_id, minute, cattle_inside, cattle_outside, observed_at)
        VALUES (test_camera, now(), -1, 0, now());
        ASSERT false, 'occupancy_samples acepto un conteo negativo';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Un minuto por camara: el segundo reporte del mismo minuto no es otra fila.
    INSERT INTO occupancy_samples (camera_id, minute, cattle_inside, cattle_outside, observed_at)
    VALUES (test_camera, date_trunc('minute', now()), 3, 1, now());
    BEGIN
        INSERT INTO occupancy_samples (camera_id, minute, cattle_inside, cattle_outside, observed_at)
        VALUES (test_camera, date_trunc('minute', now()), 4, 0, now());
        ASSERT false, 'occupancy_samples acepto dos filas para el mismo minuto';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO camera_status_changes (camera_id, status, changed_at) VALUES (test_camera, 'dormida', now());
        ASSERT false, 'camera_status_changes acepto un estado inventado';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    INSERT INTO camera_status_changes (camera_id, status, changed_at) VALUES (test_camera, 'online', now());

    -- La vista de periodos ve el cambio, y el periodo actual queda abierto.
    ASSERT (SELECT ended_at FROM v_camera_status_periods WHERE camera = 'test-history') IS NULL,
           'v_camera_status_periods no deja abierto el periodo actual';

    -- CASCADE: borrar la camara se lleva su historial.
    DELETE FROM cameras WHERE id = test_camera;
    ASSERT NOT EXISTS (SELECT 1 FROM occupancy_samples WHERE camera_id = test_camera),
           'el historial de conteos sobrevivio a su camara';
    ASSERT NOT EXISTS (SELECT 1 FROM camera_status_changes WHERE camera_id = test_camera),
           'el historial de estados sobrevivio a su camara';
END $$;

-- Las medidas del lote, solo si el backend ya creo la tabla lots.
DO $$
BEGIN
    IF to_regclass('lots') IS NULL THEN
        RETURN;
    END IF;
    ASSERT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lots_dimensions_pair_check'),
           'falta lots_dimensions_pair_check';
END $$;
