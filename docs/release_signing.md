# Firma de publicación Android

Estado: upload key release creada y artefactos firmados verificados el 22 de
agosto de 2026.

Pawdo nunca guarda contraseñas ni claves de firma en Git.
`android/key.properties`, `*.jks` y `*.keystore` están ignorados. Gradle firma
el tipo `release` solamente cuando existe `android/key.properties`; sin ese
archivo permite generar un artefacto técnico, pero no debe distribuirse.

Archivos locales actuales:

```text
android/app/pawdo-release.jks
android/key.properties
```

El certificado pertenece a `Jorge Luis Minchan Huaman`, alias `pawdo`, y vence
el 7 de enero de 2054. Huellas:

```text
SHA-1   AC:6B:BD:A1:74:2D:DB:19:38:F6:50:BB:9B:94:EE:01:D8:D0:67:F8
SHA-256 CF:FC:2E:D7:AD:09:63:AE:95:85:F6:84:11:BD:9F:E2:
        70:9E:DD:59:7A:B7:9E:90:BB:D6:0D:09:89:27:02:8C
```

Respaldar ambos archivos juntos en dos ubicaciones privadas. El archivo
`key.properties` contiene la contraseña necesaria y no debe compartirse ni
subirse a Git.

## Recrear solo para una aplicación nueva

No ejecutar el generador otra vez para esta misma ficha de Play. El script
`tool/create_release_signing.ps1` se niega a sobrescribir la llave existente.
Solo para una aplicación nueva y sin upload key se puede ejecutar:

```powershell
.\tool\create_release_signing.ps1
```

El script genera una contraseña aleatoria de 40 caracteres y no la imprime.
Después se compila con `flutter build appbundle --release`, se verifica con
`jarsigner -verify` y se sube primero a Prueba interna, no a Producción.

## Play App Signing y Firebase

Activar Play App Signing. Google custodiará la clave de firma de distribución y la clave local será la upload key. Registrar en Firebase las huellas SHA-256 necesarias de la upload key y, cuando Play Console la muestre, de la app signing key. Validar App Check/Play Integrity en la pista interna antes de activar enforcement.

Para cada nueva subida, aumentar `version:` en `pubspec.yaml`; Android hereda de allí `versionName` y `versionCode`. Nunca reutilizar un `versionCode` ya enviado a Play.

Referencia: [firma de aplicaciones Android](https://developer.android.com/studio/publish/app-signing).
