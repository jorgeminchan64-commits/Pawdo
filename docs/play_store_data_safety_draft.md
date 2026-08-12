# Borrador Data Safety — Pawdo 1.0

Fecha de inventario: 2026-08-12. Este documento prepara el formulario, pero no lo envía. Las respuestas deben contrastarse con el AAB firmado que finalmente llegue a Play Console y con la política legal publicada.

## Respuestas generales propuestas

- La app recopila datos: **sí**.
- Los datos se cifran en tránsito: **sí**, mediante HTTPS/TLS de Firebase.
- El usuario puede solicitar eliminación: **sí**, dentro de Pawdo y mediante la URL externa de eliminación.
- Venta de datos: **no**.
- Publicidad o personalización publicitaria: **no**.
- Google Analytics: **no está incluido**.
- Compartición con terceros: propuesta **no**, considerando a Firebase proveedor de servicio/subencargado. Confirmar en el formulario la excepción aplicable y cualquier cambio de SDK.
- Contenido compartido entre las dos personas: ocurre por acción del usuario dentro de la función principal de pareja; confirmar la excepción de transferencia iniciada por el usuario al completar el formulario.

## Datos que deben declararse

| Categoría de Play | Datos de Pawdo | Obligatorio u opcional | Finalidad principal |
|---|---|---|---|
| Información personal | correo, nombre visible, cumpleaños opcional | correo obligatorio; resto opcional | administración de cuenta y funcionalidad |
| Identificadores de usuario | UID Firebase, identificador de pareja | obligatorio | cuenta, seguridad y sincronización |
| Mensajes | chat privado, respuestas y reacciones | opcional | funcionalidad de pareja |
| Fotos | perfil, chat, álbum y calendario | opcional | funcionalidad solicitada |
| Audio | notas de voz | opcional | mensajería solicitada |
| Ubicación aproximada y precisa | coordenadas, precisión y vencimiento de sesión | opcional y temporal | compartir ubicación con la pareja |
| Salud y bienestar | ciclo, intensidad, síntomas, ánimo y notas | opcional; privado por defecto | funcionalidad de bienestar y resumen consentido |
| Otra actividad/contenido generado | calendario, recuerdos, fecha de relación, juegos, mascota, diseños y economía virtual | opcional o derivado del uso | funcionalidad y sincronización |
| Identificadores de dispositivo o instalación | FCM/Firebase Installation ID, Crashlytics UUID, token de integridad | automático | notificaciones, seguridad, prevención de abuso y estabilidad |
| Diagnóstico | trazas de fallos redactadas, versión, modelo, SO y estado técnico | automático solo en release | estabilidad y corrección de errores |
| Información de la app y rendimiento | estado técnico asociado a sesiones de fallo | automático solo en release | estabilidad |

## Datos que Pawdo no usa actualmente

- contactos o libreta de direcciones;
- historial de navegación o búsquedas web;
- SMS, MMS o registro de llamadas;
- números de teléfono;
- información financiera, pagos o compras con dinero real;
- publicidad, perfilado comercial o venta de datos;
- video cargado por Pawdo.

## Retención y borrado

- Datos funcionales: mientras la cuenta o el espacio de pareja estén activos, salvo datos temporales como ubicación.
- Ubicación: sesión temporal sin historial permanente; debe comprobarse físicamente su vencimiento y detención.
- Borrado de cuenta: elimina Auth, perfil, datos privados, archivos y el espacio compartido; requiere prueba destructiva en staging.
- Crashlytics: Firebase informa retención aproximada de 90 días para trazas e identificadores asociados.
- Authentication y respaldos del proveedor: la eliminación de sistemas activos y copias puede tardar hasta 180 días según Firebase.

## Verificación antes de enviar

1. Subir el AAB firmado a Prueba interna y revisar el análisis de permisos/SDK de Play Console.
2. Confirmar que la política pública menciona App Check, Crashlytics, notas de voz y retención.
3. Ejecutar borrado completo en staging y verificar Auth, Firestore y Storage.
4. Revisar el inventario de todos los SDK contra la guía vigente de Firebase.
5. Guardar una exportación del formulario enviado y versionarla con la release.

Fuentes oficiales: [formulario Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469), [eliminación de cuenta](https://support.google.com/googleplay/android-developer/answer/13327111), [divulgaciones Firebase para Android](https://firebase.google.com/docs/android/play-data-disclosure) y [privacidad/retención de Firebase](https://firebase.google.com/support/privacy/).
