# Modelo de datos

```mermaid
erDiagram
    cameras ||--o{ zones   : "CASCADE"
    cameras ||--o{ animals : "SET NULL"
    cameras ||--o{ events  : "SET NULL"
    zones   ||--o{ animals : "SET NULL"
    zones   ||--o{ events  : "SET NULL"
    animals ||--o{ events  : "SET NULL + UPDATE CASCADE"
    events  ||--o{ alerts  : "CASCADE"

    cameras {
        bigint id PK
        text   name UK
        text   source
        text   location
        bool   active
    }
    zones {
        bigint id PK
        bigint camera_id FK
        text   name
        real   x_min
        real   y_min
        real   x_max
        real   y_max
        bool   active
    }
    users {
        bigint id PK
        text   email UK
        text   password_hash
        text   full_name
        text   role
        bool   is_active
    }
    animals {
        text        tag PK
        text        status
        bigint      camera_id FK
        bigint      zone_id FK
        text        name
        timestamptz last_detection
    }
    events {
        bigint      id PK
        text        type
        text        level
        text        source
        bigint      camera_id FK
        bigint      zone_id FK
        text        animal_tag FK
        text        detected_object
        float8      confidence
        jsonb       box
        timestamptz detected_at
        timestamptz received_at
        uuid        ai_event_id UK
    }
    alerts {
        bigint      id PK
        bigint      event_id FK
        text        channel
        text        status
        timestamptz sent_at
    }
```

`users` no aparece conectada porque **nada la referencia todavia**. Los eventos
no registran quien los atendio y las alertas no registran a quien se le
mandaron. Cuando exista la autenticacion, `alerts` es la que gana una clave
ajena a `users`.

## Lo que dice el diagrama de un vistazo

Solo dos relaciones borran en cascada: `zones` con su camara y `alerts` con su
evento. Las demas hacen `SET NULL`, y esa asimetria es la regla del esquema:
**el historico sobrevive a que se retire su origen**, salvo cuando la fila no
significa nada sin el.

`animals` a `events` es la unica que ademas lleva `ON UPDATE CASCADE`, porque
es la unica clave ajena que apunta a una clave primaria natural, y una clave
natural si cambia.
