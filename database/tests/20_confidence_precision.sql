-- events.confidence guarda 0.95 como 0.95.
--
-- Es la comprobacion de la migracion 0001, y es la que mas facil se pierde:
-- si alguien recrea la columna como REAL, nada falla. Simplemente los valores
-- vuelven a leerse sucios, y el backend tendria que volver a redondear al leer
-- -- que es justo el parche que la migracion elimino.
DO $$
DECLARE
    camera bigint;
    stored double precision;
BEGIN
    ASSERT (
        SELECT data_type FROM information_schema.columns
        WHERE table_name = 'events' AND column_name = 'confidence'
    ) = 'double precision',
    'events.confidence volvio a ser REAL: 0.95 se leera como 0.949999988';

    INSERT INTO cameras (name) VALUES ('test-precision') RETURNING id INTO camera;
    INSERT INTO events (type, camera_id, confidence)
    VALUES ('cattle_out_of_zone', camera, 0.95);

    SELECT confidence INTO stored FROM events WHERE camera_id = camera;

    -- En float4 esto devolveria 0.949999988079071 y la igualdad fallaria.
    ASSERT stored = 0.95,
           format('0.95 se guardo como %s', stored);

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
