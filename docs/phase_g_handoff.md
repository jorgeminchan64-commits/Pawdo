# Fase G: entrega y operación

## Resultado implementado

- Ubicación puntual y temporal con consentimiento doble, aproximación en servidor, límites de frecuencia y sin historial.
- Seguimiento solo en primer plano, recuperación segura, latido en reposo y caducidad por falta de actualizaciones.
- Indicador global con detención inmediata.
- Limpieza al detener, cerrar sesión, desvincular o vencer.
- Pruebas locales reales de cámara y micrófono, sin archivos ni transferencia.
- Evaluación comparativa para una integración futura con proveedor administrado.
- Reducción de memoria de decodificación en miniaturas y Ludo.

## Verificación pendiente por acuerdo

No se han ejecutado formato, análisis, pruebas, emuladores, compilación, instalación en teléfonos ni despliegue. Hasta completar esa etapa, la fase está **implementada pero no verificada**.

## Riesgos restantes

- `geolocator` requiere resolver dependencias mediante `flutter pub get`.
- Las nuevas Cloud Functions y reglas aún no están publicadas.
- La prueba nativa debe compilarse y ejecutarse en las versiones Android de los dos teléfonos.
- La tarea programada de limpieza puede requerir confirmar índices y permisos del proyecto.
- Las llamadas reales siguen intencionalmente sin integrar hasta aprobar proveedor, costos, región y secretos.
- El directorio actual no está reconocido como repositorio Git; no existe una reversión automática confiable de los cambios actuales.

## Comandos de validación final

```powershell
flutter pub get
dart format lib
flutter analyze
flutter test
node --check functions/index.js
npm --prefix functions test
firebase emulators:exec --project pawdo-aeda8 --only firestore,storage "npm --prefix firebase-tests test"
firebase emulators:exec --project pawdo-aeda8 --only firestore "npm --prefix functions test"
flutter build apk --debug
```

Si el puerto 8080 sigue ocupado, primero se debe identificar el proceso existente o configurar otro puerto de Firestore en `firebase.json`; no deben iniciarse dos emuladores sobre el mismo puerto.

## Comando de despliegue, no ejecutado

Solo después de que las pruebas sean correctas:

```powershell
firebase deploy --project pawdo-aeda8 --only functions:startLocationSharing,functions:updateSharedLocation,functions:stopLocationSharing,functions:cleanupExpiredLocationShares,firestore:rules
```

## Reversión

Antes del despliegue se debe crear un punto de versión en Git. Si la validación falla, revertir juntos los archivos de ubicación, llamadas, `functions/index.js`, `firestore.rules`, `pubspec.yaml`, `MainActivity.kt`, `AndroidManifest.xml`, `main.dart`, `main_screen.dart` y `profile_screen.dart`. No se debe revertir solamente el cliente o solamente el servidor porque sus contratos dependen entre sí.

Si ya hubo despliegue, publicar la versión anterior de Functions y reglas antes de distribuir el APK anterior. La limpieza de `locationShares` es segura porque esos documentos son temporales y no representan historial.
