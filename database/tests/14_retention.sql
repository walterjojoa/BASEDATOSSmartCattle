-- prune_events borra por antiguedad, se lleva las alertas y rechaza un
-- intervalo invalido.
DO $$
DECLARE
    camera bigint;
    old_event bigint;
    new_event bigint;
    removed bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-prune') RETURNING id INTO camera;
    INSERT INTO events (type, camera_id, detected_at)
    VALUES ('cattle_out_of_zone', camera, now() - interval '200 days')
    RETURNING id INTO old_event;
    INSERT INTO events (type, camera_id, detected_at)
    VALUES ('cattle_out_of_zone', camera, now() - interval '1 day')
    RETURNING id INTO new_event;
    INSERT INTO alerts (event_id) VALUES (old_event);

    SELECT prune_events(interval '90 days') INTO removed;

    ASSERT removed >= 1, 'prune_events no informo las filas borradas';
    ASSERT (SELECT count(*) FROM events WHERE id = old_event) = 0,
           'prune_events dejo el evento viejo';
    ASSERT (SELECT count(*) FROM events WHERE id = new_event) = 1,
           'prune_events se llevo un evento dentro del plazo';
    ASSERT (SELECT count(*) FROM alerts WHERE event_id = old_event) = 0,
           'la alerta sobrevivio al borrado en cascada';

    -- Un intervalo invalido aborta en vez de borrarlo todo.
    BEGIN
        PERFORM prune_events(interval '0');
        ASSERT false, 'prune_events acepto un intervalo de cero';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
