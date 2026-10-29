-- Las tablas y las columnas con trampa estan comentadas.
--
-- No se exige comentario en todo: "id = identificador" es ruido. Se exige en
-- las columnas cuyo nombre y tipo NO alcanzan para usarlas bien, que son las
-- que el equipo ya documento en docs/diccionario/.
DO $$
DECLARE
    missing text[];
    required text[] := ARRAY[
        'cameras.name', 'cameras.source',
        'zones.x_min', 'zones.camera_id',
        'users.email', 'users.password_hash', 'users.role',
        'animals.tag', 'animals.status',
        'events.type', 'events.box', 'events.detected_at',
        'events.received_at', 'events.ai_event_id',
        'alerts.event_id', 'alerts.status'
    ];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(required) AS name
    WHERE col_description(
              split_part(name, '.', 1)::regclass,
              (SELECT attnum FROM pg_attribute
               WHERE attrelid = split_part(name, '.', 1)::regclass
                 AND attname = split_part(name, '.', 2))
          ) IS NULL;

    ASSERT missing IS NULL, format('columnas con trampa sin comentar: %s', missing);
END $$;

DO $$
DECLARE
    missing text[];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['cameras', 'zones', 'users', 'animals', 'events', 'alerts']) AS name
    WHERE obj_description(name::regclass, 'pg_class') IS NULL;

    ASSERT missing IS NULL, format('tablas sin comentar: %s', missing);
END $$;
