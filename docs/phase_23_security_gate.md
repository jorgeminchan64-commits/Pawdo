# Pawdo — compuerta de seguridad final (FASE 23)

Estado técnico: aprobada. Despliegue productivo: pendiente de las compuertas externas y de publicación.

## Endurecimiento aplicado

- El documento principal de pareja dejó de aceptar campos cliente desconocidos. Solo Cine puede escribir directamente `cinema`, `cinemaPlayback`, `lastAction` y `updatedAt`, con esquema, autor, tamaños, plataforma, posición y timestamp validados.
- Reacciones de Cine admiten únicamente los seis emojis visibles, identidad autenticada, nombre de 1–80 caracteres y timestamp del servidor.
- Mensajes de Cine admiten solo creación, identidad autenticada, esquema cerrado, texto de 1–500 caracteres y timestamp del servidor. No pueden editarse ni borrarse desde el cliente.
- Estado, economía, inventarios, diseños, mascota, juegos, álbum, calendario, bienestar, ubicación y chat principal continúan server-only o con contratos específicos.
- `firebase-functions` pasó de `7.3.2-rc.0` a `7.3.2` estable sin cambiar APIs ni exports.

## Evidencia automatizada

| Suite | Resultado |
|---|---:|
| Flutter | 73 aprobadas |
| Functions | 57 aprobadas |
| Firestore Rules | 26 aprobadas |
| Storage Rules | 21 aprobadas |
| Total | 177 aprobadas |

`dart analyze lib test` quedó limpio y el APK release recompiló en 112,505,685 bytes.

## Cadena de suministro

`npm audit` reporta 12 avisos transitivos: 1 bajo, 8 moderados y 3 altos. Los altos corresponden a `brace-expansion`, `js-yaml` y `serialize-javascript`; parte de ellos entra por Mocha (solo pruebas). Los avisos de Storage llegan por Firebase Admin.

No se aplicó `npm audit fix --force`: npm propone degradaciones mayores e incompatibles de Firebase Admin/Functions y una versión anterior de Mocha, lo que puede introducir más riesgo que el que elimina. Seguimiento requerido:

1. actualizar cuando Firebase publique una cadena compatible que resuelva sus transitivas;
2. no procesar YAML, patrones glob o objetos serializables controlados por usuarios dentro de Functions;
3. repetir `npm audit` antes de cada release backend;
4. conservar pruebas en emuladores después de cada cambio de lockfile.

## Compuertas externas aún pendientes

- Enforcement de App Check después de certificados, métricas y dos teléfonos.
- Primer reporte Crashlytics en build interna y revisión de PII.
- Despliegue coordinado de Functions/reglas y prueba destructiva de cuenta en staging.
- Firma, Play App Signing, dominio propio, Data Safety y Play Console.
