# Pawdo — auditoría inicial de producción

Fecha: 2026-08-06  
Alcance actualizado hasta FASE 3. Este documento no declara la aplicación lista para producción.

## Resumen ejecutivo

Pawdo tiene una base funcional considerable: 100 archivos Dart en `lib`, separación por features, Riverpod parcial, Firebase Auth/Firestore/Storage/Functions, reglas con denegación general, paginación de chat y 94 pruebas automatizadas aprobadas entre Flutter, Functions y reglas. Android genera un APK release.

Los bloqueos de producción son concretos: release sin firma, `targetSdk` 34, falta de eliminación de cuenta y documentos legales, ausencia de App Check/Crashlytics, recuperación entre procesos todavía limitada para operaciones no persistentes y un APK de 105.43 MiB. No deben añadirse módulos grandes antes de resolver los elementos críticos por fase.

## Arquitectura observada

- UI Flutter organizada por `core`, `features` y `routes`.
- Estado híbrido: `flutter_riverpod` inyecta algunos servicios, pero numerosas pantallas acceden directamente a singletons Firebase.
- `MainScreen` conserva cinco pestañas mediante `IndexedStack`; esto evita recrearlas, pero retiene simultáneamente su memoria y streams.
- Cloud Functions centraliza pareja, chat, economía, layouts, bienestar, ubicación y juegos sensibles.
- Firestore y Storage aplican deny-by-default, con suites de reglas existentes.
- Chat carga 30 mensajes recientes y pagina hacia atrás; no descarga todo el historial.
- Los timers y listeners localizados tienen cancelación en los componentes principales. No existen `AnimationController` manuales.

## Registro de problemas

| Problema | Gravedad | Archivo/área | Causa | Impacto | Solución propuesta | Estado |
|---|---|---|---|---|---|---|
| Git inválido | Crítica | `.git`, `.gitignore` | Carpeta `.git` vacía; exclusiones incompletas para Node/credenciales | Sin rollback seguro | Inicializar, excluir artefactos y crear baseline | Resuelto en FASE 1 (`6591847`) |
| Release Android sin firma | Crítica | `android/app/build.gradle.kts` | No existe signing config de release | APK/AAB no publicable | Crear upload keystore seguro fuera del repo y configurar firma mediante propiedades locales/CI | Pendiente FASE 25 |
| Target SDK insuficiente | Crítica | `android/app/build.gradle.kts:16` | `targetSdk = 34` | Rechazo o limitación en Google Play | Migrar y probar `targetSdk = 36` | Pendiente FASE 25 |
| Eliminación de cuenta ausente | Crítica | Perfil, Functions, Firestore, Storage | No hay flujo in-app ni endpoint/web externo | Incumplimiento Play y retención de datos personales | Diseñar borrado server-side, desvinculación, limpieza y URL externa | Pendiente FASE 6 |
| Privacidad/Términos/soporte sin URLs reales | Alta | Auth y perfil | Solo hay texto de aceptación/accesos parciales | Riesgo legal y de revisión | Publicar recursos legales reales y enlazarlos dentro de la app/Play Console | Pendiente FASE 6/25 |
| Reconexión incompleta | Alta | Services, Functions, Storage, widget | Firestore persiste offline, pero callables y Storage no; además, una selección de foto no puede reconstruirse después de cerrar el proceso | Acciones no persistentes pueden requerir reintento explícito tras cierre forzado | Estado central por eventos, lifecycle, backoff acotado e idempotencia; cola durable sólo para operaciones serializables que lo justifiquen | Mitigado FASE 3 (`0224ea5`, `577bfda`); persistencia entre procesos y widget siguen en sus fases |
| Widget sin recuperación programada | Alta | `android_widget_service.dart`, `PawdoWidgetProvider.kt` | Actualización depende del canal/app y preferencias locales; no hay trabajo diferido/backoff | Datos congelados después de desconexión o cierre | Caché versionada y WorkManager solo cuando aporte valor, con restricciones de red | Pendiente FASE 17 |
| App Check ausente | Alta | Firebase cliente/Functions | Dependencia e inicialización inexistentes | Mayor exposición a clientes abusivos | Integrar sin enforcement, validar dos teléfonos y observar métricas | Pendiente FASE 21 |
| Crashlytics ausente | Alta | `main.dart`, dependencias | FASE 2 añadió captura global segura, pero todavía no existe telemetría Crashlytics | Crashes y fallos async no llegan a un panel de producción | Integrar Crashlytics con redacción estricta de PII | Pendiente FASE 22 |
| Inicialización crítica sin fallback | Alta | `lib/main.dart` | `Firebase.initializeApp()` bloqueaba antes de `runApp` y no tenía UI de recuperación | Fallo de configuración/red nativa podía impedir arrancar | Bootstrap observable con pantalla de error/reintento y reporte no sensible | Resuelto FASE 2 (`dd4c12a`) |
| Rutas Firestore con escritura amplia | Alta | `firestore.rules:205-214` | `state`, `cinemaReactions` y `cinemaMessages` permiten escritura de miembros sin esquema/campos/límites | Riesgo de datos inválidos, abuso y crecimiento | Inventariar consumidores y restringir esquemas, tamaños y frecuencia | Pendiente FASE 23 |
| Permisos sensibles declarados | Alta | `AndroidManifest.xml` | Cámara, audio y ubicación están en el manifiesto; llamadas reales están aplazadas | Mayor fricción y superficie de privacidad/políticas | Vincular cada permiso a función visible, solicitud contextual y retirar lo no necesario | Pendiente FASE 6/25 |
| APK grande | Alta | assets/build | 50.50 MB de assets PNG y dependencias nativas; APK universal de 105.43 MiB | Descarga, almacenamiento y retención peores | Medir AAB por ABI, optimizar assets con validación visual y eliminar solo referencias confirmadas | Pendiente FASE 20 |
| Dependencias atrasadas | Media | `pubspec.yaml`, `pubspec.lock` | 63 paquetes fuera de las restricciones; familia Firebase dos generaciones mayores disponible | Mantenimiento, API obsoleta y compatibilidad futura | Actualización escalonada con matriz de compatibilidad y tests | Pendiente FASE 20 |
| Functions usa release candidate | Alta | `functions/package.json` | `firebase-functions ^7.3.2-rc.0` | Riesgo de cambios/bugs pre-release en backend | Evaluar versión estable compatible antes de producción | Pendiente FASE 23 |
| Analizador no limpio | Media | Varios | 4 warnings y 74 infos en la línea base | La puerta de calidad fallaba y podía ocultar regresiones futuras | Corregir en commit mecánico, sin mezclar funciones | Resuelto FASE 2 (`f760274`); 0 hallazgos |
| Arquitectura de estado inconsistente | Media | `app_providers.dart` y pantallas | Servicios inyectados conviven con acceso directo a Firebase | Tests y reconexión transversal más difíciles | Migración incremental por feature; no reescritura global | Pendiente gradual |
| Código legacy/duplicado | Media | `login_screen_new.dart`, `uth_gate.dart`, `features/home/screens/chat_screen.dart`, `pet_screen.dart` | Implementaciones antiguas no importadas por flujo activo | Confusión, tamaño fuente y riesgo de editar archivo equivocado | Confirmar rutas y eliminar en commit separado con tests | Pendiente gradual |
| Functions monolítica | Media | `functions/index.js` (~115 KB) | Múltiples dominios y exports en un solo archivo | Revisión, ownership y pruebas selectivas difíciles | Modularizar sin cambiar contratos/export names | Pendiente gradual |
| Presencia escribe cada 75 s | Media | `presence_service.dart` | Heartbeat fijo mientras la app está activa | Coste Firestore/batería en sesiones largas | Medir necesidad, TTL y frecuencia; reducir escrituras redundantes | Pendiente FASE 20 |
| Cobertura UI y lifecycle insuficiente | Alta | `test`, `docs/phase_g_test_matrix.md` | 4 archivos de test Flutter; matriz manual no ejecutada | Navegación, permisos, background y reconexión sin garantía | Añadir widget/integration tests y repetir en dos teléfonos | Pendiente FASE 24 |
| Compatibilidad 16 KB no demostrada | Alta | dependencias Android/artefacto | No se inspeccionaron todas las librerías nativas en dispositivo 16 KB | Posible incumplimiento/crash en dispositivos modernos | Analizar AAB/APK y probar entorno 16 KB tras actualizar dependencias | Pendiente FASE 25 |

## Recursos y rendimiento

- Assets: 68 archivos, 50,571,983 bytes; 65 PNG (50,495,995 bytes) y 3 MP3 (75,988 bytes).
- No se encontraron archivos binariamente duplicados por SHA-256.
- Los mayores recursos son `garden_basic.png` (2.75 MB), `room_basic.png` (2.17 MB), `tree_big_love.png` (2.09 MB) y spritesheets de personajes de aproximadamente 1.86–1.89 MB.
- Un análisis estático detectó 21 assets sin referencia literal, por 11,658,717 bytes. Son candidatos, no basura confirmada: Ludo, catálogos y Flame pueden construir rutas dinámicamente.
- `IndexedStack` mantiene vivas cinco pantallas; se debe perfilar RAM/streams antes de cambiarlo.
- El build hizo tree-shaking de Material Icons de 1,645,184 a 17,464 bytes.

## Seguridad y privacidad

Fortalezas confirmadas:

- Firestore y Storage terminan en reglas deny-by-default.
- Escrituras sensibles de chat, economía, pareja, juegos y bienestar pasan por Functions.
- Shared photos limitadas a imágenes válidas de hasta 1 MB y miembros activos.
- 43 tests de Functions, 18 de Firestore Rules y 14 de Storage Rules pasan en emuladores.

Pendiente de validar:

- App Check, eliminación/exportación de cuenta, retención, logs productivos y secretos de CI.
- Consentimiento y borrado completo de bienestar/ubicación en producción.
- Inventario Data Safety real y URLs legales públicas.
- Reglas amplias de `state` y cinema.

## Estado de FASE 0–3

- Auditoría estática y documental: completada.
- Git y respaldo: completados.
- Baseline Flutter/Android/Firebase: completado con hallazgos registrados.
- FASE 2: analizador limpio; bootstrap con carga, error, reintento y captura global segura; dos widget tests añadidos.
- Puerta final de FASE 2: 15 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK recompilado.
- FASE 3: recuperación central por conectividad/lifecycle, estados accesibles, backoff acotado y reintento idempotente de chat con el mismo ID.
- Puerta de FASE 3: 19 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK de 110,549,629 bytes recompilado y verificado como no firmado.
- Firestore conserva su sincronización offline nativa. El indicador de transporte no se trata como prueba absoluta de Internet; los fallos transitorios reales de Firebase mantienen activa la recuperación.
- Pruebas físicas y profiling: no ejecutados en esta fase.
- Siguiente paso autorizado por el roadmap: FASE 4, estabilización de juegos.
