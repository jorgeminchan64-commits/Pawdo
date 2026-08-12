# FASE 24 — puerta de pruebas completas

Fecha: 2026-08-12

## Resultado

La puerta automatizada y de artefacto queda aprobada. La matriz física no se declara ejecutada: requiere dos teléfonos Android reales, dos cuentas y acceso a Firebase Console. Pawdo todavía no es un release publicable porque el artefacto no tiene firma de producción y quedan los requisitos de FASE 25.

## Evidencia automatizada

| Comprobación | Resultado |
|---|---:|
| `dart analyze lib test` | 0 hallazgos |
| Flutter unit/widget/contract | 75 aprobadas |
| Cloud Functions con emuladores | 57 aprobadas |
| Firestore Rules | 26 aprobadas |
| Storage Rules | 21 aprobadas |
| Total automatizado | 179 aprobadas |
| Cobertura Flutter de líneas | 1,125 / 10,517 (10.7%) |
| Android Lint release | 0 errores, 13 advertencias |

La cobertura de 10.7% no demuestra por sí sola la calidad completa de la interfaz. Los recorridos con cámara, micrófono, notificaciones, widget, segundo plano, reinicio, cierre forzado y sincronización entre cuentas permanecen como pruebas físicas obligatorias.

## Revisión del APK

- APK release universal: 112,069,422 bytes.
- `compileSdk`: 36; `minSdk`: 24; `targetSdk`: 34.
- El APK está sin firma de publicación.
- `zipalign -c -P 16 4` terminó con código 0. Esto confirma la alineación ZIP a 16 KB, no sustituye una instalación en un entorno con páginas de memoria de 16 KB.
- Cámara y micrófono son capacidades opcionales; Pawdo no excluye dispositivos sin ese hardware.
- No se declara ubicación en segundo plano.
- Se retiró la dependencia directa de Firebase Analytics, que no tenía consumidor en Dart. Con ello desaparecieron del manifiesto fusionado `AD_ID`, permisos de AdServices e Install Referrer.
- Los permisos funcionales presentes son notificaciones, cámara, micrófono, Internet, ubicación aproximada/precisa, red y los permisos internos de Firebase necesarios para mensajería.

## Advertencias Android abiertas

Las 13 advertencias de Lint no bloquean la compilación, pero se trasladan a FASE 25:

- elevar el `targetSdk` tras verificar el requisito vigente de Google Play;
- actualizar de forma compatible el Firebase BoM;
- añadir icono monocromático y revisar el relleno del icono adaptable;
- retirar recursos legacy redundantes cuando se haya validado el resultado visual;
- revisar las sugerencias KTX sin mezclar una migración amplia antes del release.

## Matriz física obligatoria — dos teléfonos

Ejecutar con teléfono A y teléfono B, cuentas distintas y una pareja real de prueba:

1. Registro, inicio/cierre de sesión, vinculación, desvinculación y revinculación.
2. Perfil, foto, personaje, fecha de relación y sincronización en ambos sentidos.
3. Chat de texto, rápidos, imagen y audio; leído, borrado, paginación, pérdida y recuperación de red.
4. Notificaciones push, calendario, recordatorios, Te extraño y widget pequeño/mediano.
5. Mascota, Casa, Jardín, Álbum, Bienestar, Cine y todos los juegos.
6. Consentimiento, revocación y borrado de Bienestar; exportación y borrado completo de cuenta en staging.
7. Ubicación aproximada/precisa, detener, permiso rechazado/bloqueado, GPS apagado y segundo plano.
8. Reinicio, cierre forzado, modo avión, recuperación y conservación de estado.
9. Cámara/micrófono denegados y permitidos; indicadores de privacidad y liberación del hardware.
10. TalkBack, texto grande, pantalla pequeña, orientación, FPS, RAM, batería y calentamiento.
11. App Check en build interna y primer evento Crashlytics redactado en Firebase Console.
12. Instalación y arranque en un dispositivo o emulador Android con páginas de 16 KB.

Cada caso debe registrar dispositivo, versión Android, cuenta, hora, resultado, captura/log y defecto asociado. No activar enforcement de App Check ni desplegar reglas/Functions de producción hasta completar esta matriz.

## Decisión

FASE 24 queda **completada técnicamente** y **pendiente de validación física**. El trabajo local puede avanzar a FASE 25, pero Play Store permanece bloqueada por firma, target vigente, AAB final, ficha/Data Safety, dominio propio y pruebas reales.
