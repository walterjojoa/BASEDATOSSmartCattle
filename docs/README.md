# Documentacion

| Documento | Para que |
| --- | --- |
| [diccionario/](diccionario/) | Ficha por tabla: cada columna, su tipo, y **por que es asi**. |
| [diccionario/vistas.md](diccionario/vistas.md) | Las vistas y funciones, que no estan en `schema.sql`. |
| [erd.md](erd.md) | Diagrama del modelo. |
| [consultas.md](consultas.md) | Recetario, con la trampa de cada consulta anotada. |
| [convenciones.md](convenciones.md) | Reglas que ya sigue el esquema. |
| [decisiones.md](decisiones.md) | Lo que se decidio, **lo que se descarto** y que cuesta. |
| [integraciones.md](integraciones.md) | Quien escribe que tabla. Explica la nulabilidad. |
| [seguridad.md](seguridad.md) | Que guarda y que pasa si se filtra. |
| [rendimiento.md](rendimiento.md) | Los indices y como comprobar que sirven. |
| [runbooks/](runbooks/) | Respaldo, restauracion, migraciones, Neon, crecimiento, incidentes. |

## Por donde empezar

- **Vas a consultar la base:** [consultas.md](consultas.md), y usa
  `v_api_events` en vez de `events`.
- **Vas a cambiar el esquema:** [convenciones.md](convenciones.md) y
  [../CONTRIBUTING.md](../CONTRIBUTING.md).
- **Algo no funciona:** [runbooks/incidentes.md](runbooks/incidentes.md).
- **No entiendes por que una columna es asi:**
  [diccionario/](diccionario/), y si no esta ahi,
  [decisiones.md](decisiones.md).
