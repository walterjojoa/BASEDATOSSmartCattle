-- zones.outline acepta un poligono valido y rechaza lo demas.
--
-- JSONB acepta cualquier forma, asi que sin el CHECK esta columna se traga una
-- cadena, un numero o un vertice fuera del cuadro, y quien la consume se
-- entera al dibujar.
DO $$
DECLARE
    camera bigint;
    zone   bigint;
BEGIN
    INSERT INTO cameras (name) VALUES ('test-outline') RETURNING id INTO camera;
    INSERT INTO zones (camera_id, name, x_min, y_min, x_max, y_max)
    VALUES (camera, 'Poligono', 0.1, 0.1, 0.9, 0.9) RETURNING id INTO zone;

    -- Un poligono valido entra.
    UPDATE zones SET outline = '[{"x":0.1,"y":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9},{"x":0.1,"y":0.8}]'::jsonb
    WHERE id = zone;

    -- Y NULL sigue valiendo: manda el rectangulo.
    UPDATE zones SET outline = NULL WHERE id = zone;

    -- No es un arreglo.
    BEGIN
        UPDATE zones SET outline = '{"x":0.1,"y":0.1}'::jsonb WHERE id = zone;
        ASSERT false, 'outline acepto un objeto en vez de un arreglo';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Dos vertices no encierran area.
    BEGIN
        UPDATE zones SET outline = '[{"x":0.1,"y":0.1},{"x":0.9,"y":0.9}]'::jsonb WHERE id = zone;
        ASSERT false, 'outline acepto un poligono de dos vertices';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Coordenada fuera del cuadro.
    BEGIN
        UPDATE zones SET outline = '[{"x":0.1,"y":0.1},{"x":1.5,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb WHERE id = zone;
        ASSERT false, 'outline acepto una coordenada mayor que 1';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Vertice sin y.
    BEGIN
        UPDATE zones SET outline = '[{"x":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb WHERE id = zone;
        ASSERT false, 'outline acepto un vertice sin y';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Coordenada como cadena en vez de numero.
    BEGIN
        UPDATE zones SET outline = '[{"x":"0.1","y":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb WHERE id = zone;
        ASSERT false, 'outline acepto una coordenada en texto';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    DELETE FROM zones WHERE camera_id = camera;
    DELETE FROM cameras WHERE id = camera;
END $$;
