# Pawdo — línea base previa a modificaciones

Fecha: 2026-08-06  
Entorno: Windows, Flutter 3.41.9 estable, Dart 3.11.5, DevTools 2.54.2

## Estado preservado

- Git no reconocía la carpeta `.git` existente porque estaba vacía.
- Se inicializó la rama `main` y se preservó el proyecto original en el commit `6591847` (`chore: create stable baseline before production work`).
- Se reforzó `.gitignore` antes del commit para excluir `node_modules`, builds, cachés, logs, archivos `.env`, keystores y credenciales administrativas.
- `android/app/google-services.json` permanece versionado porque es configuración cliente necesaria para el build; no se encontraron claves privadas, cuentas de servicio ni keystores versionados.
- El formato automático posterior se aisló en `217fb4c` (`style: format baseline source`). El comando informó 102 archivos inspeccionados y 48 modificados; 47 archivos versionados formaron el commit.

## Comandos y resultados

| Comando | Resultado | Evidencia |
|---|---|---|
| `flutter clean` | Correcto | Eliminó un `build` previo de aproximadamente 2.98 GB y cachés generadas. |
| `flutter pub get` | Correcto | Dependencias resueltas; 63 paquetes tienen versiones nuevas incompatibles con las restricciones actuales. |
| `dart format .` | Correcto | 102 archivos procesados; 48 reportados como cambiados. |
| `flutter analyze` | No supera la puerta | 78 hallazgos: 4 warnings y 74 infos; 0 errores de compilación. |
| `flutter test` | Correcto | 13/13 tests pasaron. |
| Functions sin emulador | Invocación inválida | La suite exige `FIRESTORE_EMULATOR_HOST`; no fue un fallo de aserción. |
| Functions con Firestore Emulator | Correcto | 43/43 tests pasaron. |
| Firestore Rules | Correcto | 18/18 tests pasaron. |
| Storage Rules | Correcto | 14/14 tests pasaron. |
| `flutter build apk` | Compila, no publicable | APK release de 105.36 MiB; el artefacto está sin firma. |

## Hallazgos del analizador

- 4 warnings: tres funciones `_limit100` sin uso y un import innecesario de `interior_house_screen.dart`.
- 74 infos: 71 usos obsoletos de `Color.withOpacity`, dos casos de `curly_braces_in_flow_control_structures` y uno de `unnecessary_underscores`.
- No se corrigieron en FASE 0/1 para conservar una línea base fiel; se atenderán como deuda controlada en FASE 2.

## Estado Android

- `applicationId`: `com.pawdo.app`.
- `compileSdk`: 36.
- `targetSdk`: 34; no cumple el requisito actual/futuro inmediato de Google Play.
- `versionName`: 1.0; `versionCode`: 1.
- El APK se construyó en `build/app/outputs/flutter-apk/app-release.apk`.
- `jarsigner` confirmó `jar is unsigned`; no existe configuración release de keystore.
- Gradle mostró avisos de dependencias nativas que aún compilan con source/target Java 8.
- No se generó AAB en esta fase: hacerlo no resolvería firma, políticas ni calidad pendiente.

## Funciones operativas conocidas

El propietario informa que el estado previo fue probado en dos dispositivos físicos y que las funciones desarrolladas trabajan principalmente bien. En esta ejecución no se repitieron pruebas manuales de registro, pareja, chat, ubicación, widgets, juegos, background o reconexión. Por tanto, esos flujos siguen como “reportados”, no “verificados en 2026-08-06”.

## Problemas conocidos antes de correcciones

- La reconexión automática no está garantizada para operaciones vía Cloud Functions, Storage, widgets o uploads.
- APK sin firma, `targetSdk` insuficiente y ausencia de AAB validado.
- Falta eliminación de cuenta y recursos legales visibles.
- No hay App Check, Crashlytics ni captura global de errores.
- APK grande y recursos visuales por optimizar.
- Cobertura automatizada concentrada en lógica y seguridad; faltan widget/integration tests y dispositivos.
