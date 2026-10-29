-- ai_event_id es lo que hace idempotente la ingesta de eventos.
--
-- La IA genera el UUID una vez por deteccion y lo reutiliza en cada reintento.
-- El UNIQUE es el mecanismo: la base rechaza el segundo INSERT, asi que dos
-- reintentos simultaneos no pueden crear dos filas. Lo resuelve la base, no la
-- aplicacion.
DO $$
DECLARE
    camera bigint;
    token  uuid := gen_random_uuid();
BEGIN
    INSERT INTO cameras (name) VALUES ('test-idem')
    ON CONFLICT (name) DO NOTHING;
    SELECT id INTO camera FROM cameras WHERE name = 'test-idem';

    INSERT INTO events (type, camera_id, ai_event_id)
    VALUES ('cattle_out_of_zone', camera, token);

    BEGIN
        INSERT INTO events (type, camera_id, ai_event_id)
        VALUES ('cattle_out_of_zone', camera, token);
        ASSERT false, 'events acepto dos veces el mismo ai_event_id';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    -- Varios NULL si conviven bajo el UNIQUE, y en eso se apoya el esquema:
    -- los servicios que no generan el identificador no quedan obligados.
    INSERT INTO events (type, camera_id) VALUES ('cattle_out_of_zone', camera);
    INSERT INTO events (type, camera_id) VALUES ('cattle_out_of_zone', camera);

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
