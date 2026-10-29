-- Las filas semilla existen a lo sumo una vez.
--
-- CI aplica schema.sql dos veces; esto es lo que detecta que el
-- ON CONFLICT DO NOTHING de la semilla dejo de funcionar. El de zones depende
-- de UNIQUE (camera_id, name): si ese UNIQUE desaparece, el ON CONFLICT ya no
-- tiene a que agarrarse y la segunda pasada duplica en silencio.
DO $$
BEGIN
    ASSERT (SELECT count(*) FROM cameras WHERE name = 'Main camera') <= 1,
           'la camara semilla esta duplicada';
    ASSERT (SELECT count(*) FROM zones WHERE name = 'Safe zone') <= 1,
           'la zona semilla esta duplicada';
END $$;

-- Y los indices que agregan las migraciones siguen ahi.
DO $$
DECLARE
    missing  text[];
    required text[] := ARRAY[
        'events_camera_id_idx', 'events_zone_id_idx', 'events_received_at_idx',
        'animals_camera_id_idx', 'animals_zone_id_idx', 'alerts_event_id_idx'
    ];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(required) AS name
    WHERE to_regclass(name) IS NULL;

    ASSERT missing IS NULL, format('faltan indices de las migraciones: %s', missing);
END $$;
