# Pawdo — configuración de cuenta, privacidad y borrado

Fecha técnica: 2026-08-07

## Implementado en la app

- Cambio de correo mediante reautenticación con contraseña y enlace de verificación de Firebase Auth.
- Exportación local en JSON de la cuenta, perfil, subcolecciones privadas y espacio compartido. El archivo enumera rutas de multimedia, pero no incrusta sus binarios.
- Borrado permanente con contraseña reciente y frase exacta `ELIMINAR`.
- Limpieza de Firebase Authentication, `users/{uid}` y subcolecciones, foto de perfil, espacios `couples` relacionados, multimedia compartida y `privateGameState` asociado.
- Desvinculación del perfil de la otra persona antes de borrar el espacio compartido.
- Política y términos informativos dentro de la app, más soporte y URLs externas configurables.
- Reglas de perfil limitadas a campos editables, tipos, fechas, temas y ruta de foto propios.

El borrado del espacio compartido afecta a ambas personas. La interfaz lo informa antes de solicitar contraseña y confirmación escrita. No existe recuperación automática.

## Variables obligatorias para publicación

La aplicación no incorpora URLs ni identidades inventadas. El responsable debe proporcionar valores públicos reales mediante `--dart-define`:

| Variable | Contenido requerido |
|---|---|
| `PAWDO_PRIVACY_URL` | HTTPS público, estable, no geobloqueado y no PDF |
| `PAWDO_TERMS_URL` | HTTPS público de términos vigentes |
| `PAWDO_DELETION_URL` | Recurso web que permite solicitar el borrado sin reinstalar Pawdo |
| `PAWDO_SUPPORT_EMAIL` | Correo real atendido por el responsable |

La política publicada debe identificar exactamente a la entidad o persona que figure en Google Play, incluir el contacto, prácticas reales, proveedores, conservación y excepciones legales. Los textos incluidos en el repositorio son una base informativa y no sustituyen revisión legal.

## Operación y despliegue

Antes de probar contra producción se deben desplegar las nuevas Functions `exportAccountData` y `deleteAccount`, junto con `firestore.rules`. No se ejecutó ningún despliegue desde este trabajo.

El exportador tiene límites preventivos de 2.000 documentos y 5 MiB serializados, y está pensado para el volumen actual. Antes de escalar el producto debe migrarse a un trabajo asíncrono con archivo privado, vencimiento corto y limpieza automática; nunca a una URL pública permanente.

Para el cambio de correo hay que revisar en Firebase Authentication los dominios autorizados, la plantilla de verificación y el dominio de enlaces de acción. La aplicación no modifica el correo hasta que la persona abre el enlace recibido.

## Bloqueos externos restantes

1. Identidad legal del responsable.
2. Correo de soporte atendido.
3. Publicación de privacidad, términos y solicitud web de borrado.
4. Revisión de Data Safety coherente con Auth, perfil, fotos, chat, ubicación temporal, bienestar, notificaciones y permisos.
5. Prueba destructiva controlada en un proyecto de staging con dos cuentas y dos teléfonos.

Mientras falte cualquiera de estos puntos, FASE 6 está cerrada técnicamente pero bloqueada para publicación y no autoriza avanzar a FASE 7 bajo el roadmap secuencial.
