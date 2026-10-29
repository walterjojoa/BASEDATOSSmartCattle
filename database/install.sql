-- Instalacion completa, en orden, para una base vacia.
--
-- Por que existe: `schema.sql` describe el estado final de las TABLAS, pero
-- los indices, las vistas, los comentarios y la funcion de retencion llegaron
-- despues, en migraciones. Una base nueva creada solo con `schema.sql` queda
-- con las tablas correctas y sin nada de eso, y la diferencia no se nota hasta
-- que una consulta va lenta o una vista no existe.
--
-- Este archivo aplica las dos cosas en el orden correcto:
--
--   psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f database/install.sql
--
-- `\i` necesita las rutas relativas al directorio desde el que se invoca
-- psql, asi que se corre desde la raiz del repositorio.
--
-- Es idempotente, como todo aqui: volver a correrlo no falla ni duplica.

\echo '== esquema =='
\i database/schema.sql

\echo '== migraciones =='
\i database/migrations/0001_widen_event_confidence.sql
\i database/migrations/0002_index_event_foreign_keys.sql
\i database/migrations/0003_index_remaining_foreign_keys.sql
\i database/migrations/0004_index_event_received_at.sql
\i database/migrations/0005_user_last_login.sql
\i database/migrations/0006_alerts_recipient.sql
\i database/migrations/0007_pending_alert_queue.sql
\i database/migrations/0008_active_herd_index.sql
\i database/migrations/0009_api_event_index.sql
\i database/migrations/0010_event_frame_bounds.sql
\i database/migrations/0011_view_api_events.sql
\i database/migrations/0012_view_camera_health.sql
\i database/migrations/0013_view_active_herd.sql
\i database/migrations/0014_event_retention.sql
\i database/migrations/0015_comment_cameras.sql
\i database/migrations/0016_comment_users.sql
\i database/migrations/0017_comment_animals.sql
\i database/migrations/0018_comment_events.sql
\i database/migrations/0019_comment_alerts.sql
\i database/migrations/0020_zone_outline.sql

\echo '== listo =='
