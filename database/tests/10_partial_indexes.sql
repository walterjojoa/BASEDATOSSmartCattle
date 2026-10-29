-- Los indices parciales de las migraciones 0007 a 0009 existen y son parciales.
--
-- Que exista un indice con ese nombre no basta: lo que los justifica es el
-- WHERE. Un indice completo con el mismo nombre pasaria una comprobacion que
-- solo mire `to_regclass`, y habria perdido justo la propiedad por la que se
-- creo.
DO $$
DECLARE
    full_indexes text[];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO full_indexes
    FROM unnest(ARRAY[
        'alerts_pending_queue_idx',
        'animals_active_by_camera_idx',
        'events_api_listable_idx'
    ]) AS name
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indexrelid = to_regclass(name)
          AND i.indpred IS NOT NULL
    );

    ASSERT full_indexes IS NULL,
           format('estos indices faltan o dejaron de ser parciales: %s', full_indexes);
END $$;
