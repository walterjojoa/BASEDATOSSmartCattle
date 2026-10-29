-- Las vistas existen y aplican la regla que dicen aplicar.
DO $$
DECLARE
    missing text[];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(ARRAY['v_api_events', 'v_active_herd']) AS name
    WHERE to_regclass(name) IS NULL;

    ASSERT missing IS NULL, format('faltan vistas: %s', missing);
END $$;

-- v_api_events excluye las filas que el esquema Event no puede representar.
DO $$
DECLARE
    camera bigint;
    before_count bigint;
BEGIN
    SELECT count(*) INTO before_count FROM v_api_events;
    INSERT INTO cameras (name) VALUES ('test-view') RETURNING id INTO camera;

    -- Fila de otro servicio: sin ai_event_id ni received_at.
    INSERT INTO events (type, camera_id, detected_object, confidence)
    VALUES ('cattle_out_of_zone', camera, 'cow', 0.9);
    -- Fila completa salvo confidence.
    INSERT INTO events (type, camera_id, detected_object, ai_event_id, received_at)
    VALUES ('cattle_out_of_zone', camera, 'cow', gen_random_uuid(), now());
    -- Fila que si cumple.
    INSERT INTO events (type, camera_id, detected_object, confidence, ai_event_id, received_at)
    VALUES ('cattle_out_of_zone', camera, 'cow', 0.9, gen_random_uuid(), now());

    ASSERT (SELECT count(*) FROM v_api_events) = before_count + 1,
           'v_api_events deberia listar solo la fila completa';
    ASSERT (SELECT camera_name FROM v_api_events WHERE camera_id = camera) = 'test-view',
           'v_api_events no resolvio el nombre de la camara';

    DELETE FROM events WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;

-- v_active_herd no esconde a un animal sin ubicacion.
DO $$
BEGIN
    INSERT INTO animals (tag, name) VALUES ('test-herd', 'Sin ubicar');
    ASSERT (SELECT count(*) FROM v_active_herd WHERE tag = 'test-herd') = 1,
           'v_active_herd perdio un animal sin camara ni zona (LEFT JOIN roto)';

    UPDATE animals SET status = 'inactive' WHERE tag = 'test-herd';
    ASSERT (SELECT count(*) FROM v_active_herd WHERE tag = 'test-herd') = 0,
           'v_active_herd listo un animal inactivo';

    DELETE FROM animals WHERE tag = 'test-herd';
END $$;
