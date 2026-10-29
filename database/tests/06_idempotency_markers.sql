-- Las filas semilla existen a lo sumo una vez.
--
-- CI aplica schema.sql dos veces; esto es lo que detecta que el
-- ON CONFLICT DO NOTHING de la semilla dejo de funcionar.
--
-- La zona se cuenta **por camara**, no por nombre. El UNIQUE es
-- (camera_id, name), asi que cada camara puede tener su propia "Safe zone" y
-- contar el nombre global crece de forma legitima en cuanto hay mas de una
-- camara -- que es justo lo que pasa al sembrar datos de desarrollo.
DO $$
BEGIN
    ASSERT (SELECT count(*) FROM cameras WHERE name = 'Main camera') <= 1,
           'la camara semilla esta duplicada';

    ASSERT (
        SELECT count(*) FROM zones z
        JOIN cameras c ON c.id = z.camera_id
        WHERE c.name = 'Main camera' AND z.name = 'Safe zone'
    ) <= 1, 'la zona semilla esta duplicada';
END $$;

-- Y en general: ninguna camara tiene dos zonas con el mismo nombre. Esto es
-- lo que el UNIQUE promete, y la comprobacion anterior se apoya en el.
DO $$
DECLARE
    clashing text[];
BEGIN
    SELECT array_agg(format('%s/%s', camera_id, name)) INTO clashing
    FROM zones GROUP BY camera_id, name HAVING count(*) > 1;

    ASSERT clashing IS NULL, format('zonas repetidas en la misma camara: %s', clashing);
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
