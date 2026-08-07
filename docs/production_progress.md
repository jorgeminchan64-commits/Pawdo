# Pawdo — progreso hacia producción

Última actualización: 2026-08-06

## Estado por fase

| Fase | Estado | Pruebas/evidencia | Riesgo o bloqueo | Siguiente paso |
|---|---|---|---|---|
| 0. Auditoría inicial | Completada | Auditoría estática, arquitectura, Firebase, Android, assets y lifecycle | Falta profiling/dispositivos, reservado para fases posteriores | Priorizar hallazgos críticos |
| 1. Git, respaldo y baseline | Completada | Commits `6591847` y `217fb4c`; Flutter, Functions y rules probados; APK generado | Analyze con 78 hallazgos; APK unsigned; target 34 | Iniciar FASE 2 |
| 2. Errores críticos | Completada | Analyze limpio; 15 tests Flutter; bootstrap recuperable probado | Firma/target permanecen en FASE 25 | Iniciar FASE 3 |
| 3. Conectividad | Completada | 19 tests Flutter; recuperación por evento, lifecycle y backoff acotado | La carga de fotos no puede reconstruirse tras cerrar el proceso; el widget conserva su fase propia | Iniciar FASE 4 |
| 4–24 | Pendiente | — | Deben respetar el orden del roadmap | No iniciar aún |
| 25. Play Store | Bloqueada | APK unsigned de 105.43 MiB | Firma, target 36, privacidad, AAB y dispositivos | Resolver fases anteriores |

## Completado

- Reparación e inicialización de Git.
- Refuerzo de `.gitignore` contra dependencias, artefactos y credenciales privadas.
- Punto de retorno del proyecto original.
- Formato automático aislado en commit propio.
- 19 tests Flutter, 43 de Functions, 18 de Firestore Rules y 14 de Storage Rules aprobados.
- APK release compilado y verificado como no firmado.
- Inventario inicial de assets y checklist Play Store.
- 78 hallazgos estáticos corregidos; `flutter analyze` queda limpio.
- Bootstrap recuperable con UI de carga, error y reintento.
- Captura global de errores que evita contenido detallado en logs release.
- Dos widget tests de arranque; suite Flutter aumentada de 13 a 15 tests.
- Servicio central de recuperación dirigido por eventos de transporte y lifecycle, sin polling continuo.
- Estados accesibles `Sin conexión`, `Reconectando…` y `Actualizado`, con backoff acotado a cinco intentos.
- Chat conserva el identificador del mensaje y reintenta envíos pendientes de forma idempotente al recuperar red.
- Presencia, notificaciones, ubicación y marcador de lectura registran tareas de recuperación.
- Cuatro pruebas nuevas de pérdida/retorno de transporte, backoff, reanudación y estado visual; suite Flutter aumentada de 15 a 19 tests.
- APK release recompilado: 110,549,629 bytes (105.43 MiB), todavía sin firma.

## Pendiente inmediato

1. Iniciar FASE 4: estabilización de Ludo, tres en raya y Connect Four.
2. Mantener intactos los contratos Firebase y la lógica sensible del servidor.
3. Añadir pruebas deterministas de salida, reconexión y finalización antes de ampliar UX.
4. No abordar aún perfil, casa, jardín, mascota, voz o widgets.

## Archivos modificados en FASE 0–3

- `.gitignore`.
- 47 archivos Dart, únicamente por `dart format .`.
- 9 archivos Dart para limpiar los hallazgos estáticos.
- `lib/main.dart` para el bootstrap recuperable y captura global.
- `test/pawdo_bootstrap_test.dart` con dos pruebas de estado y reintento.
- `lib/core/services/network_recovery_service.dart` con estado, lifecycle, registro de tareas y backoff.
- `lib/core/widgets/network_status_banner.dart` con estados visibles y semánticos.
- Servicios de presencia, notificaciones y ubicación, `lib/main.dart`, `main_screen.dart` y chat para recuperación coordinada.
- `test/network_recovery_service_test.dart` con cuatro pruebas de conectividad.
- `pubspec.yaml`, lockfiles y registrantes nativos por `connectivity_plus` 7.3.1.
- `docs/pre_modification_baseline.md`.
- `docs/final_production_audit.md`.
- `docs/production_progress.md`.
- `docs/play_store_checklist.md`.
- `docs/optimization_report.md`.

## Riesgos de seguimiento

- Los flujos manuales siguen basados en pruebas físicas previas reportadas por el propietario.
- No se debe interpretar “APK compila” como “release publicable”.
- No actualizar dependencias Firebase en bloque: requiere migración y pruebas por familia.
- No eliminar los 21 assets candidatos hasta comprobar catálogos y rutas dinámicas.
- Firebase CLI tuvo un cierre transitorio de hub después de que las aserciones pasaran; una repetición aislada cerró con código 0.
- `connectivity_plus` sólo representa disponibilidad de transporte; no se interpreta por sí solo como garantía de acceso a Internet.
- Firestore mantiene su persistencia offline nativa; los callables y cargas de Storage requieren la recuperación explícita implementada o una nueva acción del usuario.
- El APK universal sigue excediendo 100 MiB y no está firmado; ambos puntos permanecen reservados para FASE 20/25.
