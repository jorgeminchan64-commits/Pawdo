# Pawdo — progreso hacia producción

Última actualización: 2026-08-06

## Estado por fase

| Fase | Estado | Pruebas/evidencia | Riesgo o bloqueo | Siguiente paso |
|---|---|---|---|---|
| 0. Auditoría inicial | Completada | Auditoría estática, arquitectura, Firebase, Android, assets y lifecycle | Falta profiling/dispositivos, reservado para fases posteriores | Priorizar hallazgos críticos |
| 1. Git, respaldo y baseline | Completada | Commits `6591847` y `217fb4c`; Flutter, Functions y rules probados; APK generado | Analyze con 78 hallazgos; APK unsigned; target 34 | Iniciar FASE 2 |
| 2. Errores críticos | Pendiente | — | Bootstrap, analyzer y bloqueos Play | Corregir en commits pequeños |
| 3. Conectividad | Pendiente | — | No hay cola/reconexión transversal | Diseñar antes de implementar |
| 4–24 | Pendiente | — | Deben respetar el orden del roadmap | No iniciar aún |
| 25. Play Store | Bloqueada | APK unsigned de 105.36 MiB | Firma, target 36, privacidad, AAB y dispositivos | Resolver fases anteriores |

## Completado

- Reparación e inicialización de Git.
- Refuerzo de `.gitignore` contra dependencias, artefactos y credenciales privadas.
- Punto de retorno del proyecto original.
- Formato automático aislado en commit propio.
- 13 tests Flutter, 43 de Functions, 18 de Firestore Rules y 14 de Storage Rules aprobados.
- APK release compilado y verificado como no firmado.
- Inventario inicial de assets y checklist Play Store.

## Pendiente inmediato

1. Limpiar los 78 hallazgos de analyzer sin cambios funcionales.
2. Diseñar recuperación del bootstrap y captura segura de errores.
3. Revisar reglas abiertas de `state` y cinema con sus consumidores.
4. Preparar, sin activar enforcement, la estrategia de App Check.
5. No abordar aún perfil, casa, jardín, mascota, voz o widgets.

## Archivos modificados en FASE 0/1

- `.gitignore`.
- 47 archivos Dart, únicamente por `dart format .`.
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

