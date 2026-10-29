-- users: el rol y la baja de acceso se comportan como dice el esquema.
DO $$
DECLARE
    person bigint;
BEGIN
    -- El rol por defecto es el menos privilegiado. Si alguien invierte el
    -- DEFAULT, cada cuenta creada sin rol explicito nace como dueña.
    INSERT INTO users (email, password_hash, full_name)
    VALUES ('rol@finca.test', 'x', 'Sin rol explicito') RETURNING id INTO person;
    ASSERT (SELECT role FROM users WHERE id = person) = 'worker',
           'el rol por defecto deberia ser worker, el menos privilegiado';

    -- Y se crea activa.
    ASSERT (SELECT is_active FROM users WHERE id = person),
           'una cuenta nueva deberia nacer activa';

    -- Un rol fuera de la lista se rechaza.
    BEGIN
        UPDATE users SET role = 'admin' WHERE id = person;
        ASSERT false, 'users acepto un rol fuera de la lista';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- Retirar el acceso conserva la fila: una cuenta borrada no se distingue
    -- de una que nunca existio, y eso destruye el registro de quien tuvo
    -- acceso.
    UPDATE users SET is_active = false WHERE id = person;
    ASSERT (SELECT count(*) FROM users WHERE id = person) = 1,
           'la fila deberia quedarse al retirar el acceso';

    DELETE FROM users WHERE id = person;
END $$;
