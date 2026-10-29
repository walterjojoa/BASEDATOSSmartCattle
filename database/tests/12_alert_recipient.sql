-- Retirar una cuenta conserva el registro de las alertas que se le mandaron.
--
-- alerts.user_id es SET NULL y no CASCADE a proposito: la fila de alerts es la
-- prueba de que se aviso, y esa prueba vale aunque la persona ya no este en el
-- predio.
DO $$
DECLARE
    camera    bigint;
    event     bigint;
    recipient bigint;
    alert     bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-recipient') RETURNING id INTO camera;
    INSERT INTO events (type, camera_id) VALUES ('cattle_out_of_zone', camera)
    RETURNING id INTO event;
    INSERT INTO users (email, password_hash, full_name)
    VALUES ('aviso@finca.com', 'x', 'Quien recibe') RETURNING id INTO recipient;
    INSERT INTO alerts (event_id, user_id, channel, status)
    VALUES (event, recipient, 'whatsapp', 'sent') RETURNING id INTO alert;

    DELETE FROM users WHERE id = recipient;

    ASSERT (SELECT count(*) FROM alerts WHERE id = alert) = 1,
           'borrar la cuenta se llevo la alerta';
    ASSERT (SELECT user_id FROM alerts WHERE id = alert) IS NULL,
           'alerts.user_id deberia quedar en NULL';
    ASSERT (SELECT status FROM alerts WHERE id = alert) = 'sent',
           'el estado de envio se perdio';

    DELETE FROM events WHERE id = event;
    DELETE FROM cameras WHERE id = camera;
END $$;
