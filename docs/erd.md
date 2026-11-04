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
    users   ||--o{ cameras : "SET NULL (account_id)"
    cameras ||--o{ detection_logs : "CASCADE"

    cameras {
        bigint id PK
        text   name UK
        text   source
        text   location
        bool   active
        bigint account_id FK
        text   display_name
    }
    detection_logs {
        bigint      camera_id PK
        timestamptz minute PK
        int         cattle_lying
        int         cattle_standing
        int         cattle_walking
        int         cattle_unknown
        int         people
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

De las tablas compartidas, a `users` solo la referencia `cameras`, por su cuenta
duena: los eventos y las detecciones llegan a la cuenta **a traves de su camara**.
Los eventos no registran quien los atendio y las alertas no registran a quien se
le mandaron; eso esta en las tablas del backend, en el diagrama siguiente.

## Las tablas del backend

Las crea y escribe solo SmartCattle-Backend (ver
[diccionario/tablas-del-backend.md](diccionario/tablas-del-backend.md)). Se
cuelgan de las compartidas, nunca al reves: ninguna tabla de `schema.sql`
apunta a una del backend.

```mermaid
erDiagram
    users           ||--o{ farms                 : "RESTRICT"
    farms           ||--o{ lots                  : "CASCADE"
    cameras         ||--o{ lots                  : "SET NULL"
    cameras         ||--o| camera_occupancy      : "CASCADE"
    events          ||--o{ security_alerts       : "SET NULL (ai_event_id)"
    cameras         ||--o{ security_alerts       : "SET NULL"
    users           ||--o{ security_alerts       : "SET NULL (atendio / resolvio)"
    video_analyses  ||--o{ video_analysis_alerts : "CASCADE"
    users           ||--o{ video_uploads         : "RESTRICT"
    lots            ||--o{ video_uploads         : "SET NULL"
    video_analyses  ||--o| video_uploads         : "SET NULL"

    farms {
        bigint id PK
        bigint owner_id FK
        text   name
        float8 latitude
        float8 longitude
    }
    lots {
        bigint id PK
        bigint farm_id FK
        bigint camera_id FK
        text   name
        text   kind
        jsonb  boundary
    }
    security_alerts {
        uuid        id PK
        uuid        event_id FK
        bigint      camera_id FK
        text        status
        bigint      acknowledged_by FK
        bigint      resolved_by FK
    }
    camera_occupancy {
        bigint      camera_id PK
        int         cattle_inside
        int         cattle_outside
        timestamptz received_at
    }
    video_uploads {
        uuid   id PK
        bigint lot_id FK
        bigint uploaded_by FK
        uuid   analysis_id FK
        text   status
        bigint size_bytes
    }
```

Los dos `RESTRICT` son a proposito: borrar una cuenta no puede llevarse fincas
ni videos por efecto colateral. Primero se reasignan, o la cuenta se desactiva
con `is_active`, que es como se retira el acceso.

## Lo que dice el diagrama de un vistazo

En este primer diagrama, tres relaciones borran en cascada: `zones` y
`detection_logs` con su camara, y `alerts` con su evento. Las demas hacen
`SET NULL`, y esa asimetria es la regla del esquema:
**el historico sobrevive a que se retire su origen**, salvo cuando la fila no
significa nada sin el.

`animals` a `events` es la unica que ademas lleva `ON UPDATE CASCADE`, porque
es la unica clave ajena que apunta a una clave primaria natural, y una clave
natural si cambia.
