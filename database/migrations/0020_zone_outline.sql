-- 0020: zones.outline, la zona segura como poligono.
--
-- `zones` guarda un rectangulo: cuatro numeros. El frontend ya sabe dibujar y
-- editar un poligono (`SafeZone.outline`), y un potrero real no es rectangular
-- -- sigue una cerca, un camino o un arroyo. Con solo el rectangulo, encerrar
-- el potrero obliga a dejar fuera terreno valido o a meter terreno que no lo es,
-- y cada metro mal clasificado es una alerta falsa o una fuga sin avisar.
--
-- JSONB y no una geometria de PostGIS: Neon no trae PostGIS en el plan
-- gratuito, y para un poligono de cuatro a una docena de vertices
-- normalizados, el indice espacial no aporta nada.
--
-- Formato: [{"x": 0.1, "y": 0.1}, ...], el mismo que ya usa el frontend, con
-- coordenadas de 0 a 1 como el rectangulo.
--
-- Admite NULL, y mientras lo sea manda el rectangulo. Las dos representaciones
-- conviven a proposito: `x_min..y_max` sigue siendo la caja envolvente, que es
-- lo que permite descartar rapido un punto antes de la prueba del poligono.

ALTER TABLE zones ADD COLUMN IF NOT EXISTS outline JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'zones_outline_check'
    ) THEN
        ALTER TABLE zones ADD CONSTRAINT zones_outline_check CHECK (
            outline IS NULL OR (
                jsonb_typeof(outline) = 'array'
                -- Menos de tres vertices no encierra area.
                AND jsonb_array_length(outline) >= 3
                AND jsonb_array_length(outline) <= 64
                -- Todo vertice es un objeto con x e y numericos de 0 a 1.
                AND NOT EXISTS (
                    SELECT 1 FROM jsonb_array_elements(outline) AS v
                    WHERE jsonb_typeof(v) <> 'object'
                       OR jsonb_typeof(v -> 'x') <> 'number'
                       OR jsonb_typeof(v -> 'y') <> 'number'
                       OR (v ->> 'x')::numeric NOT BETWEEN 0 AND 1
                       OR (v ->> 'y')::numeric NOT BETWEEN 0 AND 1
                )
            )
        );
    END IF;
END $$;

COMMENT ON COLUMN zones.outline IS
    'Poligono opcional [{"x":0..1,"y":0..1}, ...]. Cuando esta, manda sobre el rectangulo, y x_min..y_max queda como caja envolvente.';
