-- Lo que install.sql tiene que dejar montado.
--
-- Es la comprobacion que detecta la omision mas probable de este repositorio:
-- agregar una migracion y olvidar la linea en install.sql. Entonces CI pasa
-- (aplica el directorio completo con un bucle) y una base nueva instalada por
-- el camino documentado queda incompleta.
DO $$
DECLARE
    missing text[];
BEGIN
    -- Vistas
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['v_api_events', 'v_active_herd']) AS name
    WHERE to_regclass(name) IS NULL;
    ASSERT missing IS NULL, format('faltan vistas: %s', missing);

    -- Indices de las migraciones
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY[
        'events_camera_id_idx', 'events_zone_id_idx', 'events_received_at_idx',
        'animals_camera_id_idx', 'animals_zone_id_idx', 'alerts_event_id_idx',
        'alerts_pending_queue_idx', 'animals_active_by_camera_idx',
        'events_api_listable_idx', 'animals_last_detection_idx',
        'cameras_active_idx', 'events_high_level_idx', 'alerts_sent_at_idx'
    ]) AS name
    WHERE to_regclass(name) IS NULL;
    ASSERT missing IS NULL, format('faltan indices: %s', missing);

    -- Columnas de las migraciones
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['users.last_login_at', 'alerts.user_id', 'zones.outline']) AS name
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name  = split_part(name, '.', 1)
          AND column_name = split_part(name, '.', 2)
    );
    ASSERT missing IS NULL, format('faltan columnas: %s', missing);

    -- Funciones
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['prune_events', 'is_valid_zone_outline', 'set_updated_at']) AS name
    WHERE NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = name);
    ASSERT missing IS NULL, format('faltan funciones: %s', missing);

    -- Constraints agregadas por migraciones
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['events_frame_size_check', 'zones_outline_check']) AS name
    WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = name);
    ASSERT missing IS NULL, format('faltan constraints: %s', missing);

    -- events.confidence se amplio a float8
    ASSERT (
        SELECT data_type FROM information_schema.columns
        WHERE table_name = 'events' AND column_name = 'confidence'
    ) = 'double precision', 'events.confidence no se amplio a double precision';
END $$;
