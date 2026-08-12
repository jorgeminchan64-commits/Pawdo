# Pawdo — validación controlada de Crashlytics

Estado técnico: SDK y complemento Android integrados. Primer evento en Firebase Console: pendiente de build interna.

## Privacidad aplicada

- Recolección desactivada en debug y activada en release.
- Errores globales Flutter, async y Zone se reportan como fatales.
- El reporte sustituye la excepción original por `PawdoUnhandledError<tipo>`.
- No se adjuntan mensaje original, nombre, correo, UID, pareja, texto de chat, URL, ruta de Storage ni ubicación.
- No se establecen identificadores de usuario ni claves personalizadas con datos personales.

La traza técnica se conserva para ubicar el origen del fallo. Crashlytics no sustituye registros funcionales, soporte ni consentimiento descrito en la política de privacidad.

## Validación operativa pendiente

1. Instalar una build release interna en un teléfono de prueba.
2. Provocar una excepción de prueba únicamente en una rama/build temporal; no dejar botón de crash en producción.
3. Reabrir Pawdo para permitir el envío del reporte.
4. Confirmar el evento en Firebase Console y verificar que no contiene el mensaje privado usado en la prueba.
5. Confirmar ANR/crash mapping y vincular el track interno de Google Play cuando exista.
6. Si en el futuro se usa `--split-debug-info`/`--obfuscate`, subir los símbolos con Firebase CLI usando el App ID Android y el mismo directorio de símbolos.

Fuente de configuración: documentación oficial de Firebase para Flutter y complemento Android Crashlytics 3.0.7.
