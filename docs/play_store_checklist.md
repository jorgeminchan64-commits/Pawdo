# Pawdo — checklist Google Play

Verificado el 2026-08-12 contra documentación oficial vigente. Reconfirmar antes de subir el AAB firmado.

## Bloqueos actuales

- [x] `applicationId` definido: `com.pawdo.app`.
- [x] `targetSdk` 36.
- [x] `compileSdk` 36.
- [ ] Upload keystore creado y custodiado fuera del repositorio.
- [x] Firma release preparada para leer credenciales locales ignoradas por Git.
- [ ] Upload key real creada; AAB firmado y verificado.
- [x] AAB release técnico generado y estructuralmente inspeccionado.
- [x] `versionCode` y `versionName` gestionados desde `pubspec.yaml`.
- [x] Las 12 librerías ELF del AAB tienen alineación mínima de 16 KB.
- [ ] Arranque comprobado en dispositivo/emulador con páginas de 16 KB.
- [ ] Dos dispositivos físicos completan la matriz final.

## Identidad visual y ficha

- [x] Nombre Android: Pawdo.
- [x] Icono launcher adaptable con foreground transparente, legacy circular y capa monocromática.
- [x] Splash presente.
- [ ] Iconos, splash y recortes revisados visualmente en dispositivos.
- [x] Título, descripciones y categoría preparados como borrador.
- [ ] Capturas reales y feature graphic finales.
- [ ] Clasificación de contenido completada.
- [x] Email y URL de soporte configurados; falta confirmar recepción real antes del release.

## Privacidad, cuenta y datos

- [x] Política de privacidad pública y accesible dentro de la app.
- [x] Términos y condiciones públicos y accesibles.
- [x] Eliminación de cuenta iniciable dentro de Pawdo.
- [x] Recurso web externo para solicitar eliminación de cuenta/datos.
- [x] Borrado server-side de Auth, Firestore, Storage y datos de pareja probado en emuladores.
- [x] Exportación/descarga JSON definida y probada para el volumen actual.
- [x] Inventario/borrador Data Safety preparado para cuenta, medios, chat, ubicación, bienestar, notificaciones y diagnósticos.
- [ ] Formulario Data Safety enviado y aprobado en Play Console.
- [x] Retención técnica de Firebase/Crashlytics incorporada al código del sitio legal; despliegue pendiente.
- [x] Consentimiento explícito y reversible para bienestar compartido implementado y probado en reglas.

## Seguridad y estabilidad

- [x] Firestore Rules pasan 26 tests.
- [x] Storage Rules pasan 21 tests.
- [x] Functions pasan 57 tests.
- [x] Reglas de `state` y Cine endurecidas con esquemas cerrados.
- [x] App Check integrado; prueba Play Integrity/enforcement permanece externa.
- [x] Crashlytics integrado con excepción redactada y sin identificador de usuario.
- [x] Dependencia release-candidate de Functions sustituida por 7.3.2 estable.
- [ ] Pruebas de reconexión, background, cierre forzado y permisos rechazados.

## Permisos

- [x] Internet y notificaciones declarados.
- [x] Cámara, micrófono y ubicación vinculados a flujos visibles y solicitudes en contexto.
- [x] Sin `AD_ID`, AdServices, Install Referrer ni ubicación en segundo plano.
- [x] Cámara/micrófono declarados como hardware opcional.
- [ ] Data Safety enviada y política actualizada publicada reflejan el AAB final.

## Artefactos

- [x] APK release compila.
- [ ] APK/AAB firmado.
- [x] `flutter build appbundle --release` aprobado con API 36.
- [x] AAB técnico: 100,674,591 bytes; por debajo del límite, pero Play Console debe calcular descarga por dispositivo.
- [ ] Símbolos y mappings de release preservados si se habilita ofuscación.
- [ ] Play App Signing configurado y upload key respaldada.

## Referencias oficiales

- Target API: https://developer.android.com/google/play/requirements/target-sdk
- Compatibilidad 16 KB: https://developer.android.com/guide/practices/page-sizes
- Android App Bundles: https://support.google.com/googleplay/android-developer/answer/9844279
- Eliminación de cuenta: https://support.google.com/googleplay/android-developer/answer/13327111
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Políticas de privacidad y datos: https://support.google.com/googleplay/android-developer/answer/17190352
- Prueba obligatoria para cuentas personales nuevas: https://support.google.com/googleplay/android-developer/answer/14151465
- Firma/Play App Signing: https://developer.android.com/studio/publish/app-signing
