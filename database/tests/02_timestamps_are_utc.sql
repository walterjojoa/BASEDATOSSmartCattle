-- Toda columna de fecha guarda zona horaria.
--
-- Un TIMESTAMP sin zona se interpreta con la del cliente: el servicio de IA
-- en el predio y el backend en Render escribirian la misma deteccion con
-- horas distintas, y la diferencia entre detected_at y received_at -- que es
-- justo lo que revela un reloj desfasado -- dejaria de significar nada.
DO $$
DECLARE
    naive text[];
BEGIN
    SELECT array_agg(format('%s.%s', table_name, column_name) ORDER BY table_name, column_name)
    INTO naive
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('alerts', 'animals', 'cameras', 'events', 'users', 'zones')
      AND data_type = 'timestamp without time zone';

    ASSERT naive IS NULL, format('columnas de fecha sin zona horaria: %s', naive);
END $$;
