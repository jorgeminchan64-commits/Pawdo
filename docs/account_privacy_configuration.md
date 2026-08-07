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

## Identidad y recursos públicos configurados

Responsable: **Jorge Luis Minchan Huaman**, desarrollador independiente en Perú.

| Variable | Valor predeterminado publicado |
|---|---|
| `PAWDO_PRIVACY_URL` | `https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/privacidad` |
| `PAWDO_TERMS_URL` | `https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/terminos` |
| `PAWDO_DELETION_URL` | `https://pawdo-privacidad.leonardomartin03961j.chatgpt.site/eliminar-cuenta` |
| `PAWDO_SUPPORT_EMAIL` | `soporte.pawdo@gmail.com` |
| `PAWDO_DELETION_EMAIL` | `borrado.pawdo@gmail.com` |

Los valores pueden sustituirse por `--dart-define` sin cambiar el código. El sitio identifica al responsable, describe las prácticas reales, proveedores, conservación, derechos ARCO y efectos del borrado. Conviene una revisión legal independiente antes del lanzamiento comercial.

## Operación y despliegue

Antes de probar contra producción se deben desplegar las nuevas Functions `exportAccountData` y `deleteAccount`, junto con `firestore.rules`. No se ejecutó ningún despliegue desde este trabajo.

El exportador tiene límites preventivos de 2.000 documentos y 5 MiB serializados, y está pensado para el volumen actual. Antes de escalar el producto debe migrarse a un trabajo asíncrono con archivo privado, vencimiento corto y limpieza automática; nunca a una URL pública permanente.

Para el cambio de correo hay que revisar en Firebase Authentication los dominios autorizados, la plantilla de verificación y el dominio de enlaces de acción. La aplicación no modifica el correo hasta que la persona abre el enlace recibido.

## Verificaciones de lanzamiento restantes

1. Confirmar que ambos correos reciben y responden mensajes antes de publicar.
2. Revisión de Data Safety coherente con Auth, perfil, fotos, chat, ubicación temporal, bienestar, notificaciones y permisos.
3. Prueba destructiva controlada en un proyecto de staging con dos cuentas y dos teléfonos.
4. Desplegar Functions y reglas durante la preparación coordinada del release.

La identidad, el soporte y los tres recursos web requeridos ya no bloquean FASE 6. Las verificaciones anteriores permanecen como puertas de lanzamiento y no justifican declarar toda la aplicación lista para producción.
