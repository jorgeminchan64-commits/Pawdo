# Pawdo — checklist Google Play

Verificado el 2026-08-06. Los requisitos pueden cambiar y deben reconfirmarse antes de subir el AAB.

## Bloqueos actuales

- [x] `applicationId` definido: `com.pawdo.app`.
- [ ] `targetSdk` 36. Actualmente es 34.
- [x] `compileSdk` 36.
- [ ] Upload keystore creado y custodiado fuera del repositorio.
- [ ] Firma release configurada. El APK actual está sin firma.
- [ ] AAB release generado, firmado y verificado.
- [ ] `versionCode` y `versionName` gestionados desde una única fuente y aumentados por release.
- [ ] Compatibilidad de páginas de memoria de 16 KB comprobada en librerías nativas y dispositivo/emulador.
- [ ] Dos dispositivos físicos completan la matriz final.

## Identidad visual y ficha

- [x] Nombre Android: Pawdo.
- [x] Icono launcher/adaptive icon presente.
- [x] Splash presente.
- [ ] Iconos, splash y recortes revisados en todas las densidades.
- [ ] Título, descripciones, capturas, feature graphic y categoría finales.
- [ ] Clasificación de contenido completada.
- [ ] Email y URL de soporte reales.

## Privacidad, cuenta y datos

- [ ] Política de privacidad pública, estable y accesible dentro de la app.
- [ ] Términos y condiciones públicos y accesibles.
- [x] Eliminación de cuenta iniciable dentro de Pawdo.
- [ ] Recurso web externo para solicitar eliminación de cuenta/datos.
- [x] Borrado server-side de Auth, Firestore, Storage y datos de pareja probado en emuladores.
- [x] Exportación/descarga JSON definida y probada para el volumen actual.
- [ ] Formulario Data Safety completado para autenticación, fotos, chat, ubicación, bienestar, notificaciones y diagnósticos.
- [ ] Retención y excepciones legales documentadas.
- [ ] Consentimiento explícito y reversible para bienestar compartido.

## Seguridad y estabilidad

- [x] Firestore Rules pasan 19 tests.
- [x] Storage Rules pasan 14 tests.
- [x] Functions pasan 46 tests.
- [ ] Reglas amplias de `state` y cinema endurecidas.
- [ ] App Check integrado, probado sin enforcement y luego evaluado.
- [ ] Crashlytics integrado sin PII ni contenido íntimo.
- [ ] Dependencia release-candidate de Functions sustituida o justificada.
- [ ] Pruebas de reconexión, background, cierre forzado y permisos rechazados.

## Permisos

- [x] Internet y notificaciones declarados.
- [ ] Cámara, micrófono y ubicación justificados por flujos visibles y solicitados en contexto.
- [ ] Permisos no necesarios retirados antes del release.
- [ ] Data Safety y política reflejan exactamente los permisos y usos efectivos.

## Artefactos

- [x] APK release compila.
- [ ] APK/AAB firmado.
- [ ] `flutter build appbundle --release` aprobado.
- [ ] Tamaño de descarga por dispositivo medido desde AAB; APK universal actual: 105.91 MiB.
- [ ] Símbolos y mappings de release preservados si se habilita ofuscación.
- [ ] Play App Signing configurado y upload key respaldada.

## Referencias oficiales

- Target API: https://developer.android.com/google/play/requirements/target-sdk
- Compatibilidad 16 KB: https://developer.android.com/guide/practices/page-sizes
- Android App Bundles: https://support.google.com/googleplay/android-developer/answer/9844279
- Eliminación de cuenta: https://support.google.com/googleplay/android-developer/answer/13327111
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Políticas de privacidad y datos: https://support.google.com/googleplay/android-developer/answer/17190352
