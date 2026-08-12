# Pawdo — despliegue seguro de Firebase App Check

Estado técnico: integrado en la app. Enforcement remoto: **desactivado** hasta completar validación física.

## Proveedores

- Android debug: proveedor Debug; registrar únicamente tokens de dispositivos de desarrollo en Firebase Console.
- Android release: Play Integrity.
- Apple release: DeviceCheck, preparado por compatibilidad; Pawdo se publica primero en Android.
- Windows y web: no se presentan como clientes verificados.

App Check se activa inmediatamente después de `Firebase.initializeApp()` y antes de usar Messaging, Firestore, Storage o Functions. La renovación automática de tokens está habilitada.

## Orden en Firebase Console

1. Registrar `com.pawdo.app` en App Check con Play Integrity.
2. Confirmar SHA-256 de la clave de subida y, cuando exista, de App Signing de Google Play.
3. Para debug local, copiar el token mostrado por Android y registrarlo como token Debug; nunca incluirlo en Git ni en el APK.
4. Distribuir una compilación de prueba en dos teléfonos y recorrer autenticación, pareja, chat, fotos/audio, álbum, calendario, tienda, mascota, juegos y notificaciones.
5. Observar métricas de solicitudes verificadas/no verificadas durante al menos 24–48 horas de prueba interna.
6. Activar enforcement de forma gradual: primero Functions, luego Firestore y Storage. Verificar cada servicio antes de continuar.
7. Mantener rollback inmediato: desactivar enforcement si aparecen usuarios legítimos bloqueados.

## Criterio de cierre remoto

- Dos teléfonos release reciben tokens válidos de Play Integrity.
- No existen errores `app-check` en los recorridos críticos.
- Emuladores y desarrollo local siguen operativos mediante Debug.
- Métricas no muestran clientes legítimos sin verificar.

App Check complementa Auth, reglas y validaciones server-side; no las reemplaza.
