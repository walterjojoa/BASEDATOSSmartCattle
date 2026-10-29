-- La funcion validadora es IMMUTABLE y clasifica bien cada forma.
--
-- Se prueba la funcion aparte del CHECK porque es reutilizable: el backend
-- puede llamarla para validar antes de escribir, y entonces su contrato
-- importa por si mismo.
DO $$
BEGIN
    -- Un CHECK solo admite funciones IMMUTABLE. Si alguien la redefine como
    -- STABLE o VOLATILE, la constraint deja de poder recrearse.
    ASSERT (
        SELECT provolatile FROM pg_proc WHERE proname = 'is_valid_zone_outline'
    ) = 'i', 'is_valid_zone_outline dejo de ser IMMUTABLE';
END $$;

DO $$
BEGIN
    -- Acepta
    ASSERT is_valid_zone_outline(NULL), 'deberia aceptar NULL';
    ASSERT is_valid_zone_outline('[{"x":0,"y":0},{"x":1,"y":0},{"x":1,"y":1}]'::jsonb),
           'deberia aceptar un triangulo en los limites';
    ASSERT is_valid_zone_outline('[{"x":0.1,"y":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9},{"x":0.1,"y":0.8}]'::jsonb),
           'deberia aceptar un cuadrilatero';

    -- Rechaza
    ASSERT NOT is_valid_zone_outline('{"x":0.1,"y":0.1}'::jsonb),
           'no deberia aceptar un objeto suelto';
    ASSERT NOT is_valid_zone_outline('[{"x":0.1,"y":0.1},{"x":0.9,"y":0.9}]'::jsonb),
           'no deberia aceptar dos vertices';
    ASSERT NOT is_valid_zone_outline('[{"x":0.1,"y":0.1},{"x":1.5,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb),
           'no deberia aceptar una coordenada mayor que 1';
    ASSERT NOT is_valid_zone_outline('[{"x":-0.1,"y":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb),
           'no deberia aceptar una coordenada negativa';
    ASSERT NOT is_valid_zone_outline('[{"x":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb),
           'no deberia aceptar un vertice sin y';
    ASSERT NOT is_valid_zone_outline('[{"x":"0.1","y":0.1},{"x":0.9,"y":0.2},{"x":0.8,"y":0.9}]'::jsonb),
           'no deberia aceptar una coordenada en texto';
    ASSERT NOT is_valid_zone_outline('"[]"'::jsonb),
           'no deberia aceptar una cadena';
    ASSERT NOT is_valid_zone_outline('3'::jsonb),
           'no deberia aceptar un numero';
END $$;
