-- El trigger set_updated_at() refresca updated_at en animals y users.
--
-- La columna la mantiene la base a proposito: varios servicios escriben en
-- estas tablas (el de IA actualiza last_detection), y un timestamp que solo un
-- escritor refresca empieza a mentir en cuanto otro toca la fila.
DO $$
DECLARE
    before_update timestamptz;
BEGIN
    INSERT INTO animals (tag, name) VALUES ('test-trigger', 'Prueba');
    SELECT updated_at INTO before_update FROM animals WHERE tag = 'test-trigger';

    UPDATE animals SET status = 'lost' WHERE tag = 'test-trigger';

    ASSERT (SELECT updated_at FROM animals WHERE tag = 'test-trigger') >= before_update,
           'el trigger no refresco animals.updated_at';
    ASSERT (SELECT status FROM animals WHERE tag = 'test-trigger') = 'lost',
           'el trigger interfirio con el UPDATE';

    DELETE FROM animals WHERE tag = 'test-trigger';
END $$;

-- El mismo trigger esta montado en users.
DO $$
DECLARE
    found integer;
BEGIN
    SELECT count(*) INTO found
    FROM pg_trigger
    WHERE NOT tgisinternal
      AND tgrelid IN ('animals'::regclass, 'users'::regclass);

    ASSERT found = 2, format('se esperaban 2 triggers updated_at, hay %s', found);
END $$;
