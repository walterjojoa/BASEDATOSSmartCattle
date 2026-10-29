-- Ningun DEFAULT de fecha es naive.
--
-- `now()` devuelve timestamptz; `localtimestamp` y `current_timestamp::timestamp`
-- no. Un DEFAULT naive en una columna timestamptz se convierte usando la zona
-- de la sesion que inserto, asi que la misma fila escrita por el backend en
-- Render y por la IA en el predio quedaria con horas distintas.
DO $$
DECLARE
    suspicious text[];
BEGIN
    SELECT array_agg(format('%s.%s = %s', c.relname, a.attname, pg_get_expr(d.adbin, d.adrelid)))
    INTO suspicious
    FROM pg_attrdef d
    JOIN pg_class     c ON c.oid = d.adrelid
    JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    JOIN pg_type      t ON t.oid = a.atttypid
    WHERE c.relname IN ('alerts', 'animals', 'cameras', 'events', 'users', 'zones')
      AND t.typname = 'timestamptz'
      AND pg_get_expr(d.adbin, d.adrelid) ~* 'localtimestamp|localtime|current_timestamp *::|::timestamp[^t]';

    ASSERT suspicious IS NULL,
           format('DEFAULT de fecha sin zona horaria: %s', suspicious);
END $$;

-- Y toda columna timestamptz NOT NULL tiene DEFAULT, o un escritor sin ese
-- dato no puede insertar.
DO $$
DECLARE
    undefaulted text[];
BEGIN
    SELECT array_agg(format('%s.%s', c.relname, a.attname) ORDER BY c.relname, a.attname)
    INTO undefaulted
    FROM pg_class     c
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    JOIN pg_type      t ON t.oid = a.atttypid
    WHERE c.relname IN ('alerts', 'animals', 'cameras', 'events', 'users', 'zones')
      AND t.typname = 'timestamptz'
      AND a.attnotnull
      AND NOT a.atthasdef;

    ASSERT undefaulted IS NULL,
           format('timestamptz NOT NULL sin DEFAULT: %s', undefaulted);
END $$;
