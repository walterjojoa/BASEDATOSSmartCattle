-- events rechaza una resolucion de cuadro no positiva, y sigue aceptando NULL.
DO $$
DECLARE
    camera bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-frame') RETURNING id INTO camera;

    -- Si viene, tiene que ser positiva.
    BEGIN
        INSERT INTO events (type, camera_id, width, height)
        VALUES ('cattle_out_of_zone', camera, 0, 480);
        ASSERT false, 'events acepto width = 0';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO events (type, camera_id, width, height)
        VALUES ('cattle_out_of_zone', camera, 640, -1);
        ASSERT false, 'events acepto height negativo';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Pero no es obligatoria: hay servicios que no la reportan.
    INSERT INTO events (type, camera_id) VALUES ('cattle_out_of_zone', camera);
    INSERT INTO events (type, camera_id, width, height)
    VALUES ('cattle_out_of_zone', camera, 640, 480);

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
