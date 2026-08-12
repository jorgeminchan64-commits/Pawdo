# FASE 25 — puerta Google Play

Fecha: 2026-08-12

## Resultado

Pawdo queda **preparada técnicamente** para completar la publicación, pero **no publicada ni publicable todavía**. El código y los recursos locales cumplen la base de Android/Play; la firma privada, Play Console, pruebas reales, dominio y declaraciones finales requieren intervención del propietario.

## Estado técnico cerrado

- Paquete: `com.pawdo.app`.
- Nombre: Pawdo.
- Versión: `1.0.0` (`versionCode` 1), heredada de `pubspec.yaml`.
- `compileSdk` 36, `targetSdk` 36 y `minSdk` 24.
- AAB release técnico: 100,674,591 bytes; compila pero está sin firma.
- APK universal técnico: 111,757,970 bytes; alineación ZIP 16 KB aprobada y sin firma.
- Las 12 bibliotecas ELF del AAB tienen alineación de 16 KB o 64 KB; ninguna queda por debajo de 16 KB.
- Android Lint: 0 errores y 5 advertencias no bloqueantes.
- Suite Flutter: 78 aprobadas. Puerta completa conservada: 57 Functions, 26 Firestore y 21 Storage; 182 automatizadas en total.
- Icono launcher renovado: capa adaptable transparente, icono legacy circular, capa monocromática e icono blanco específico de notificaciones.
- Recursos Play: icono 512 × 512 y feature graphic 1024 × 500.
- Firma Gradle preparada mediante `android/key.properties`, que está ignorado junto con `*.jks` y `*.keystore`; no hay contraseñas en Git.
- Borradores creados para ficha, Data Safety y custodia de firma.
- La política legal local fue actualizada para App Check, Crashlytics, notas de voz, ausencia de Analytics/publicidad y retenciones técnicas; sus 4 pruebas pasan.

## Requisitos oficiales verificados

- A partir del 31 de agosto de 2026, las nuevas apps y actualizaciones móviles deben apuntar a Android 16/API 36.
- Las apps dirigidas a Android 15/API 35 o posterior deben admitir páginas de 16 KB.
- Las cuentas personales creadas después del 13 de noviembre de 2023 deben completar, en general, una prueba cerrada con al menos 12 testers inscritos durante 14 días consecutivos antes de solicitar acceso a producción.
- Las apps con creación de cuenta necesitan borrado dentro de la app y un recurso web externo.
- Data Safety debe incluir datos propios y los recopilados por SDK/proveedores.
- Play App Signing usa una clave de firma de distribución y una upload key que conserva el desarrollador.

## Bloqueos externos antes de subir

1. Crear una upload key con contraseña elegida y custodiada por Jorge; generar el AAB firmado y verificarlo.
2. Crear/verificar la cuenta personal de Play Console e identidad del desarrollador.
3. Confirmar si aplica el requisito de 12 testers/14 días y completar la pista cerrada si corresponde.
4. Ejecutar la matriz de FASE 24 en dos teléfonos, incluido un entorno de páginas de 16 KB.
5. Tomar capturas reales con datos ficticios y revisar splash/iconos en dispositivos.
6. Completar clasificación de contenido, público objetivo, acceso de revisión y Data Safety en Play Console.
7. Comprar/configurar `pawdo.site`, validar DNS/HTTPS y sustituir las URLs legales; publicar la actualización legal solo con autorización.
8. Verificar recepción en `soporte.pawdo@gmail.com` y `borrado.pawdo@gmail.com`.
9. Desplegar backend/reglas coordinadamente a staging, probar borrado destructivo y después autorizar producción.
10. Registrar huellas de firma en Firebase, probar Play Integrity/App Check y un evento Crashlytics redactado antes de enforcement.

## Advertencias no bloqueantes

- Firebase BoM 34.17.0 está disponible frente a 34.13.0; se difiere para no introducir una actualización de SDK sin su propia matriz.
- `drawable-v21` es redundante con `minSdk` 24; retirada visual diferida.
- Tres sugerencias KTX son de estilo, no fallos funcionales.
- El AAB está por debajo de los límites, pero solo Play Console calcula el tamaño comprimido real por dispositivo.

## Decisión

FASE 25 queda **completada técnicamente con gates externos explícitos**. No se realizó ningún despliegue de producción, carga a Play Console, compra de dominio, activación de App Check enforcement ni creación insegura de secretos.

Fuentes oficiales: [Target API](https://support.google.com/googleplay/android-developer/answer/11926878), [16 KB](https://developer.android.com/guide/practices/page-sizes), [pruebas para cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465), [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469), [eliminación de cuenta](https://support.google.com/googleplay/android-developer/answer/13327111) y [firma de apps](https://developer.android.com/studio/publish/app-signing).
