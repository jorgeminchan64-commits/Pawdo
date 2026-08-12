# Firma de publicación Android

Estado: configuración preparada; upload key real pendiente del propietario.

Pawdo nunca guarda contraseñas ni claves de firma en Git. `android/key.properties`, `*.jks` y `*.keystore` están ignorados. Gradle firma el tipo `release` solamente cuando existe `android/key.properties`; sin ese archivo permite generar un AAB técnico, pero el resultado queda sin firma y no debe subirse a Play Console.

## Crear la upload key

Crear una carpeta privada fuera del repositorio, por ejemplo `C:/secure/pawdo`, y ejecutar de forma interactiva:

```powershell
keytool -genkeypair -v -keystore C:/secure/pawdo/pawdo-upload.jks -alias pawdo-upload -keyalg RSA -keysize 4096 -validity 10000
```

Usar una contraseña fuerte y única. No escribirla en chats, tickets, commits ni capturas. Guardar dos copias cifradas en ubicaciones separadas y conservar también el alias.

Después:

1. Copiar `android/key.properties.example` como `android/key.properties`.
2. Cambiar `storeFile`, `storePassword`, `keyAlias` y `keyPassword` por los valores reales.
3. Ejecutar `flutter build appbundle --release`.
4. Confirmar con `jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab` que el bundle está verificado.
5. Subir primero a Prueba interna, no a Producción.

## Play App Signing y Firebase

Activar Play App Signing. Google custodiará la clave de firma de distribución y la clave local será la upload key. Registrar en Firebase las huellas SHA-256 necesarias de la upload key y, cuando Play Console la muestre, de la app signing key. Validar App Check/Play Integrity en la pista interna antes de activar enforcement.

Para cada nueva subida, aumentar `version:` en `pubspec.yaml`; Android hereda de allí `versionName` y `versionCode`. Nunca reutilizar un `versionCode` ya enviado a Play.

Referencia: [firma de aplicaciones Android](https://developer.android.com/studio/publish/app-signing).
