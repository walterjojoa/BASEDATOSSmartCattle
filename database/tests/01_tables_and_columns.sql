-- Las seis tablas existen y llevan las columnas que la API espera.
DO $$
DECLARE
    expected text[] := ARRAY['alerts', 'animals', 'cameras', 'events', 'users', 'zones'];
    missing  text[];
BEGIN
    SELECT array_agg(name ORDER BY name) INTO missing
    FROM unnest(expected) AS name
    WHERE to_regclass(name) IS NULL;

    ASSERT missing IS NULL, format('faltan tablas: %s', missing);
END $$;

DO $$
BEGIN
    -- animals.tag es la clave primaria natural, no un id numérico.
    ASSERT (
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
        WHERE i.indrelid = 'animals'::regclass AND i.indisprimary
    ) = 'tag', 'la clave primaria de animals deberia ser tag';

    -- events.animal_tag la referencia, asi que tiene que ser TEXT.
    ASSERT (
        SELECT data_type FROM information_schema.columns
        WHERE table_name = 'events' AND column_name = 'animal_tag'
    ) = 'text', 'events.animal_tag deberia ser text, como animals.tag';
END $$;
