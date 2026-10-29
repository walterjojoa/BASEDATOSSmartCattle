-- Una direccion no puede registrarse dos veces.
--
-- El UNIQUE solo sirve porque el CHECK obliga a minusculas: sin el,
-- Ana@finca.com y ana@finca.com son dos cadenas distintas para el UNIQUE y la
-- misma persona entra dos veces.
DO $$
BEGIN
    INSERT INTO users (email, password_hash, full_name) VALUES ('dup@finca.com', 'x', 'Ana');
    BEGIN
        INSERT INTO users (email, password_hash, full_name) VALUES ('dup@finca.com', 'y', 'Otra Ana');
        ASSERT false, 'users acepto el mismo correo dos veces';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    DELETE FROM users WHERE email = 'dup@finca.com';
END $$;
