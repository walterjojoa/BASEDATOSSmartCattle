-- Los CHECK de rango rechazan de verdad lo que dicen rechazar.
--
-- 03_check_constraints.sql comprueba que existen por nombre. Esto comprueba
-- que funcionan: una constraint se puede redefinir conservando el nombre y
-- dejar de rechazar nada, y entonces la otra comprobacion sigue pasando.
DO $$
DECLARE
    camera bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-ranges') RETURNING id INTO camera;

    -- confidence fuera de 0..1
    BEGIN
        INSERT INTO events (type, camera_id, confidence)
        VALUES ('cattle_out_of_zone', camera, 1.5);
        ASSERT false, 'events acepto confidence mayor que 1';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO events (type, camera_id, confidence)
        VALUES ('cattle_out_of_zone', camera, -0.1);
        ASSERT false, 'events acepto confidence negativa';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Los limites si entran: 0 y 1 son validos.
    INSERT INTO events (type, camera_id, confidence) VALUES ('cattle_out_of_zone', camera, 0);
    INSERT INTO events (type, camera_id, confidence) VALUES ('cattle_out_of_zone', camera, 1);

    -- Zona con las esquinas invertidas: deja todo el cuadro "fuera" y dispara
    -- una alerta por cada animal visible.
    BEGIN
        INSERT INTO zones (camera_id, name, x_min, y_min, x_max, y_max)
        VALUES (camera, 'Invertida', 0.9, 0.9, 0.1, 0.1);
        ASSERT false, 'zones acepto un rectangulo invertido';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Zona de area cero.
    BEGIN
        INSERT INTO zones (camera_id, name, x_min, y_min, x_max, y_max)
        VALUES (camera, 'Plana', 0.5, 0.5, 0.5, 0.5);
        ASSERT false, 'zones acepto un rectangulo de area cero';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Coordenada fuera del cuadro.
    BEGIN
        INSERT INTO zones (camera_id, name, x_min, y_min, x_max, y_max)
        VALUES (camera, 'Fuera', 0.1, 0.1, 1.4, 0.9);
        ASSERT false, 'zones acepto una coordenada mayor que 1';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Canal y estado de alerta fuera de la lista.
    BEGIN
        INSERT INTO alerts (event_id, channel)
        SELECT id, 'paloma' FROM events WHERE camera_id = camera LIMIT 1;
        ASSERT false, 'alerts acepto un canal fuera de la lista';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM zones  WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
