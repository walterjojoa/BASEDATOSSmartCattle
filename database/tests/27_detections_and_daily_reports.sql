-- detection_logs rechaza lo invalido, y el informe diario cuadra.
BEGIN;

DO $$
DECLARE
    cam bigint;
    col text;
BEGIN
    INSERT INTO cameras (name) VALUES ('t27-limites') RETURNING id INTO cam;
    INSERT INTO detection_logs (camera_id, minute, cattle_lying, cattle_standing, cattle_walking,
                                cattle_unknown, people, avg_confidence, observed_at)
    VALUES (cam, '2026-03-01 12:00+00', 0, 0, 0, 0, 0, NULL, now());

    FOREACH col IN ARRAY ARRAY['cattle_lying', 'cattle_standing', 'cattle_walking', 'cattle_unknown', 'people'] LOOP
        BEGIN
            EXECUTE format('UPDATE detection_logs SET %I = -1 WHERE camera_id = $1', col) USING cam;
            ASSERT false, format('%s no deberia aceptar negativos', col);
        EXCEPTION WHEN check_violation THEN NULL;
        END;
    END LOOP;

    BEGIN
        UPDATE detection_logs SET avg_confidence = 1.01 WHERE camera_id = cam;
        ASSERT false, 'avg_confidence no deberia aceptar mas de 1';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    UPDATE detection_logs SET avg_confidence = 1 WHERE camera_id = cam;
    UPDATE detection_logs SET avg_confidence = 0 WHERE camera_id = cam;

    -- Un minuto por camara: el segundo reporte reescribe, no agrega.
    BEGIN
        INSERT INTO detection_logs (camera_id, minute, cattle_lying, cattle_standing, cattle_walking,
                                    cattle_unknown, people, observed_at)
        VALUES (cam, '2026-03-01 12:00+00', 1, 0, 0, 0, 0, now());
        ASSERT false, 'no deberia haber dos filas por camara y minuto';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
END $$;

-- La vista detections da una fila por objeto y postura vistos, sin ceros.
DO $$
DECLARE
    cam bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('t27-vista') RETURNING id INTO cam;
    INSERT INTO detection_logs (camera_id, minute, cattle_lying, cattle_standing, cattle_walking,
                                cattle_unknown, people, observed_at)
    VALUES (cam, '2026-03-01 12:00+00', 2, 0, 1, 4, 3, now());

    ASSERT (SELECT count(*) FROM detections WHERE camera_id = cam) = 4, 'deberia omitir el conteo en cero';
    ASSERT (SELECT detected_count FROM detections
             WHERE camera_id = cam AND object_type = 'cattle' AND posture = 'lying') = 2, 'reses echadas';
    ASSERT (SELECT detected_count FROM detections
             WHERE camera_id = cam AND object_type = 'cattle' AND posture IS NULL) = 4, 'postura desconocida';
    ASSERT (SELECT detected_count FROM detections WHERE camera_id = cam AND object_type = 'person') = 3, 'personas';
    ASSERT NOT EXISTS (SELECT 1 FROM detections WHERE camera_id = cam AND posture = 'standing'),
           'de pie estaba en cero';
    ASSERT (SELECT DISTINCT "timestamp" FROM detections WHERE camera_id = cam) = '2026-03-01 12:00+00',
           'timestamp deberia ser el minuto';
END $$;

-- El dia se corta en la zona pedida y cada cuenta recibe lo suyo.
DO $$
DECLARE
    ana  bigint;
    luis bigint;
    cam  bigint;
    r    record;
BEGIN
    INSERT INTO users (email, password_hash, full_name) VALUES ('t27-ana@x.co', 'h', 'Ana') RETURNING id INTO ana;
    INSERT INTO users (email, password_hash, full_name) VALUES ('t27-luis@x.co', 'h', 'Luis') RETURNING id INTO luis;
    INSERT INTO cameras (name, account_id, display_name) VALUES ('t27-dia', ana, 'Corral') RETURNING id INTO cam;

    INSERT INTO detection_logs (camera_id, minute, cattle_lying, cattle_standing, cattle_walking,
                                cattle_unknown, people, avg_confidence, observed_at) VALUES
        -- 23:30 del 1 en Bogota, ya el 2 en UTC: cuenta para el 1.
        (cam, '2026-03-02 04:30+00', 4, 2, 0, 0, 0, 0.8, now()),
        (cam, '2026-03-01 12:00+00', 2, 2, 0, 0, 1, 0.6, now()),
        -- 00:30 del 2 en Bogota: no cuenta para el 1.
        (cam, '2026-03-02 05:30+00', 9, 9, 9, 9, 9, 0.9, now());

    INSERT INTO events (type, camera_id, detected_at) VALUES
        ('cattle_out_of_zone', cam, '2026-03-01 15:00+00'),
        ('otro_tipo',          cam, '2026-03-01 15:00+00');
    INSERT INTO occupancy_samples (camera_id, minute, cattle_inside, cattle_outside, observed_at) VALUES
        (cam, '2026-03-01 15:01+00', 6, 2, now());

    SELECT * INTO STRICT r FROM daily_reports(ana, '2026-03-01', '2026-03-01', 'America/Bogota');
    ASSERT r.report_date = '2026-03-01' AND r.camera = 'Corral', 'dia o nombre incorrecto';
    ASSERT r.minutes_observed = 2, format('minutos esperados 2, hay %s', r.minutes_observed);
    -- Conteos de lo que se veia: 6 y 4 reses dan promedio 5, no 10.
    ASSERT r.avg_cattle = 5.0 AND r.max_cattle = 6, format('ganado: %s y %s', r.avg_cattle, r.max_cattle);
    ASSERT r.avg_cattle_lying = 3.0 AND r.avg_cattle_standing = 2.0 AND r.avg_cattle_walking = 0.0, 'posturas';
    ASSERT r.max_people = 1 AND r.minutes_with_people = 1, 'personas';
    ASSERT r.avg_confidence = 0.700, format('confianza esperada 0.700, hay %s', r.avg_confidence);
    ASSERT r.first_seen_at = '2026-03-01 12:00+00' AND r.last_seen_at = '2026-03-02 04:30+00', 'primera y ultima vez';
    ASSERT r.out_of_zone_events = 1, 'solo deberia contar cattle_out_of_zone';
    ASSERT r.max_cattle_outside = 2, 'ganado afuera';

    -- En UTC el mismo dia corta distinto: la fila de las 04:30 pasa al dia 2.
    ASSERT (SELECT minutes_observed FROM daily_reports(ana, '2026-03-01', '2026-03-01', 'UTC')) = 1,
           'la zona horaria deberia cambiar el corte del dia';

    ASSERT (SELECT count(*) FROM daily_reports(ana, '2026-03-01', '2026-03-02', 'America/Bogota')) = 2,
           'un rango de dos dias con datos deberia dar dos filas';
    ASSERT (SELECT count(*) FROM daily_reports(ana, '2026-03-20', '2026-03-20', 'America/Bogota')) = 0,
           'un dia sin datos no deberia tener fila';
    ASSERT (SELECT count(*) FROM daily_reports(luis, '2026-03-01', '2026-03-02', 'America/Bogota')) = 0,
           'otra cuenta no deberia recibir este informe';
    ASSERT (SELECT count(*) FROM daily_reports(NULL, '2026-03-01', '2026-03-02', 'America/Bogota')) = 0,
           'sin cuenta no deberia haber informe';

    BEGIN
        PERFORM * FROM daily_reports(ana, '2026-03-01', '2026-03-01', 'Marte/Olympus');
        ASSERT false, 'una zona horaria invalida deberia fallar';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    -- La poda no toca los eventos, y lo podado deja de aparecer en el informe.
    ASSERT prune_detection_logs(interval '1 second') >= 3, 'la poda deberia borrar las filas viejas';
    ASSERT NOT EXISTS (SELECT 1 FROM detection_logs WHERE camera_id = cam), 'quedaron filas sin podar';
    ASSERT (SELECT minutes_observed FROM daily_reports(ana, '2026-03-01', '2026-03-01', 'America/Bogota')) = 0,
           'lo podado no deberia contar';
    BEGIN
        PERFORM prune_detection_logs(interval '0');
        ASSERT false, 'prune_detection_logs no deberia aceptar un intervalo cero';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
END $$;

ROLLBACK;
