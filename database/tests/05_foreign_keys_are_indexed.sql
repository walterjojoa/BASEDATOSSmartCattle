-- Toda clave ajena tiene un indice que la sirve.
--
-- PostgreSQL no los crea. Sin ellos se paga al consultar por la relacion y,
-- peor, al borrar el padre: recorre la tabla hija completa para aplicar el
-- CASCADE o el SET NULL, con la fila del padre bloqueada.
--
-- Vale cualquier indice cuya PRIMERA columna sea la clave ajena, asi que
-- zones (camera_id, name) sirve para zones.camera_id y no hace falta repetirlo.
DO $$
DECLARE
    unindexed text[];
BEGIN
    SELECT array_agg(format('%s.%s', rel, col) ORDER BY rel, col) INTO unindexed
    FROM (
        SELECT c.conrelid::regclass::text AS rel,
               a.attname                  AS col,
               c.conkey[1]                AS keycol,
               c.conrelid                 AS reloid
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
        WHERE c.contype = 'f' AND array_length(c.conkey, 1) = 1
    ) fk
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid = fk.reloid AND i.indkey[0] = fk.keycol
    );

    ASSERT unindexed IS NULL, format('claves ajenas sin indice: %s', unindexed);
END $$;
