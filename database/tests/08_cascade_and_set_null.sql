-- Borrar el origen conserva el historico, salvo donde la fila no significa
-- nada sin el.
--
-- Esta es la asimetria central del esquema y no se lee en una sola tabla:
-- events hace SET NULL con su camara, alerts hace CASCADE con su evento.
DO $$
DECLARE
    camera bigint;
    event  bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-cascade') RETURNING id INTO camera;
    INSERT INTO events (type, camera_id) VALUES ('cattle_out_of_zone', camera)
    RETURNING id INTO event;
    INSERT INTO alerts (event_id) VALUES (event);

    -- Retirar la camara conserva el evento, con la referencia en NULL.
    DELETE FROM cameras WHERE id = camera;
    ASSERT (SELECT count(*) FROM events WHERE id = event) = 1,
           'borrar la camara se llevo el evento';
    ASSERT (SELECT camera_id FROM events WHERE id = event) IS NULL,
           'events.camera_id deberia quedar en NULL';

    -- Borrar el evento si se lleva su alerta: una alerta sin evento no se
    -- puede auditar ni reenviar.
    DELETE FROM events WHERE id = event;
    ASSERT (SELECT count(*) FROM alerts WHERE event_id = event) = 0,
           'la alerta sobrevivio a su evento';
END $$;
