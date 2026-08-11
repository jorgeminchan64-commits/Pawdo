# Pawdo — progreso hacia producción

Última actualización: 2026-08-11

## Estado por fase

| Fase | Estado | Pruebas/evidencia | Riesgo o bloqueo | Siguiente paso |
|---|---|---|---|---|
| 0. Auditoría inicial | Completada | Auditoría estática, arquitectura, Firebase, Android, assets y lifecycle | Falta profiling/dispositivos, reservado para fases posteriores | Priorizar hallazgos críticos |
| 1. Git, respaldo y baseline | Completada | Commits `6591847` y `217fb4c`; Flutter, Functions y rules probados; APK generado | Analyze con 78 hallazgos; APK unsigned; target 34 | Iniciar FASE 2 |
| 2. Errores críticos | Completada | Analyze limpio; 15 tests Flutter; bootstrap recuperable probado | Firma/target permanecen en FASE 25 | Iniciar FASE 3 |
| 3. Conectividad | Completada | 19 tests Flutter; recuperación por evento, lifecycle y backoff acotado | La carga de fotos no puede reconstruirse tras cerrar el proceso; el widget conserva su fase propia | Iniciar FASE 4 |
| 4. Juegos actuales | Completada | 24 tests Flutter; 43 Functions; 32 reglas; APK recompilado | FPS, memoria y batería requieren profiling físico en FASE 20/24 | Iniciar FASE 5 |
| 5. Perfil | Completada | 29 tests Flutter; 43 Functions; 32 reglas; APK recompilado | Fecha compartida canónica en FASE 15 | Iniciar FASE 6 |
| 6. Cuenta, privacidad y seguridad | Completada | Centro de cuenta; sitio legal público; 32 tests Flutter; 46 Functions; 33 reglas; APK recompilado | Data Safety, staging y despliegue quedan como gates de lanzamiento | Iniciar FASE 7 |
| 7. Navegación e Inicio | Completada | Rutas directas; saludo, reloj y relación; 37 tests Flutter; APK recompilado | Validación visual pendiente en dos teléfonos; fecha canónica compartida queda en FASE 15 | Iniciar FASE 8 |
| 8. Casa | Completada | Zonas coherentes, cambios protegidos, 40 tests Flutter; APK recompilado | Validación táctil/FPS pendiente en dos teléfonos | Iniciar FASE 9 |
| 9. Jardín | Completada | Riego por objetivo real, crecimiento sincronizado, 42 tests Flutter; APK recompilado | Validación táctil/FPS pendiente en dos teléfonos | Iniciar FASE 10 |
| 10–24 | Pendiente | — | Deben respetar el orden del roadmap | No iniciar aún |
| 25. Play Store | Bloqueada | APK unsigned de 105.98 MiB | Firma, target 36, dominio propio, AAB y dispositivos | Resolver fases anteriores |

## Completado

- Reparación e inicialización de Git.
- Refuerzo de `.gitignore` contra dependencias, artefactos y credenciales privadas.
- Punto de retorno del proyecto original.
- Formato automático aislado en commit propio.
- 42 tests Flutter, 46 de Functions, 19 de Firestore Rules y 14 de Storage Rules aprobados.
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
- Los diez juegos existentes fueron auditados; no se añadió ningún juego nuevo.
- Snapshots remotos parciales o legacy ya no pueden provocar `RangeError` en Memoria, Tres en raya ni listas de participantes.
- Atrapa a Pawdo pausa su cronómetro al entrar en background; Memoria offline suspende su temporizador de resolución.
- Ludo detiene audio/confeti fuera de primer plano, distingue fallo de red de cuenta no vinculada y recupera la sala automáticamente.
- Los seis minijuegos online compartidos reabren su sala tras recuperar red; las jugadas no se reenvían a ciegas.
- Cinco pruebas nuevas cubren snapshots malformados y pause/resume; suite Flutter aumentada de 19 a 24 tests.
- APK release de FASE 4: 110,549,753 bytes (105.43 MiB), todavía sin firma.
- Perfil comercial conectado a los datos reales, sin el texto “Pronto podrás editarlo”.
- Edición de nombre, nombre visible, foto comprimida, cumpleaños, fecha personal de relación y tres estilos visuales.
- Resumen de pareja limitado a nombre visible y ruta de foto validada; nombre privado no se replica al documento compartido.
- Foto cacheada por revisión para evitar descargas repetidas y refrescar al reemplazar el archivo en la misma ruta.
- Cinco pruebas nuevas cubren compatibilidad legacy, fechas, temas, guardado y validación; suite Flutter aumentada de 24 a 29 tests.
- APK release de FASE 5: 110,714,193 bytes (105.59 MiB), todavía sin firma.
- Centro de cuenta con cambio de correo verificado, descarga JSON, privacidad, términos, soporte configurable y borrado definitivo.
- Eliminación server-side probada de Auth, perfil/subcolecciones, fotos, parejas compartidas y estado privado de juegos; confirmación reciente y frase exacta obligatorias.
- Reglas del perfil endurecidas contra campos arbitrarios, tipos inválidos, temas no permitidos y rutas de foto ajenas.
- APK release de FASE 6: 111,058,781 bytes (105.91 MiB), todavía sin firma.
- Sitio público de Pawdo con privacidad, términos y borrado externo, identificado a nombre de Jorge Luis Minchan Huaman.
- Soporte configurado en `soporte.pawdo@gmail.com` y solicitudes externas de borrado en `borrado.pawdo@gmail.com`.
- Inicio renovado con saludo según la hora, reloj, nombre visible, pareja, relación, próximo aniversario, métricas y fondo asociado al tema de perfil.
- Navegación redundante eliminada: Casa abre directamente el interior, Jardín abre el mundo exterior y Mascota conserva su pestaña dedicada.
- Cinco pruebas nuevas cubren saludo, reloj, duración de relación, aniversario y ausencia de fecha; suite Flutter aumentada de 32 a 37 tests.
- APK release de FASE 7: 111,124,317 bytes (105.98 MiB), todavía sin firma.
- Casa conserva sus interacciones reales de cama, sofá, mesa, TV/cine, planta, Pawdo y personajes, sin añadir objetos decorativos falsos.
- El portal duplicado de Juegos fue retirado del flujo activo; Juegos permanece accesible desde Inicio y el asset no se elimina hasta la auditoría de FASE 20.
- Los muebles nuevos se colocan primero en zonas sugeridas de descanso, sala, mesa, Pawdo o decoración, conservando compatibilidad con diseños guardados.
- Arrastrar, agregar o eliminar marca el diseño como pendiente; volver exige guardar o confirmar el descarte y al salir se restaura la orientación vertical.
- Tres pruebas nuevas cubren asignación de zonas, límites del cuarto y etiquetas; suite Flutter aumentada de 37 a 40 tests.
- APK release de FASE 8: 111,124,317 bytes (105.98 MiB), todavía sin firma.
- Jardín clasifica explícitamente cada objeto: solo vegetación real activa riego, la mesa activa la escena de pareja y el suelo/objetos desconocidos únicamente permiten caminar.
- El personaje se acerca a la planta, árbol, flor, arbusto o maceta tocada; ya no existe una posición de riego implícita sobre espacios vacíos.
- Los estados persistidos de la planta principal se presentan como Brote, Creciendo y Floreció, y su sprite se sincroniza al cambiar desde cualquier teléfono.
- Edición del Jardín marca agregar, arrastrar o eliminar como pendiente; cambiar de pestaña o volver exige confirmar el descarte si no se guardó.
- Dos pruebas nuevas cubren objetivos válidos/inválidos y estados de crecimiento; suite Flutter aumentada de 40 a 42 tests.
- APK release de FASE 9: 111,140,701 bytes (105.99 MiB), todavía sin firma.

## Pendiente inmediato

1. Iniciar FASE 10: Personajes.
2. Conservar para lanzamiento el despliegue coordinado y la prueba destructiva de cuenta en staging.
3. Registrar `pawdo.site`, completar sus DNS pendientes y sustituir las URLs legales antes de Play Store.
4. Completar Data Safety y comprobar ambos correos antes de Play Store.

## Archivos modificados en FASE 0–7

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
- `lib/features/games/game_snapshot.dart` y seis consumidores para normalización defensiva.
- Ludo, Atrapa a Pawdo, Memoria offline, `mini_game_host.dart` y su servicio para lifecycle y reconexión.
- `test/game_snapshot_test.dart` y `test/game_lifecycle_test.dart` con cinco pruebas nuevas.
- Modelo, servicio, formulario y avatar cacheado bajo `lib/features/profile/`.
- `lib/features/home/screens/profile_screen.dart` rediseñado sobre streams existentes.
- `functions/index.js` conserva el contrato `memberProfiles.name`, pero prioriza `displayName`.
- `test/profile_data_test.dart`, `test/edit_profile_screen_test.dart` y casos Firebase ampliados.
- `docs/pre_modification_baseline.md`.
- `docs/final_production_audit.md`.
- `docs/production_progress.md`.
- `docs/play_store_checklist.md`.
- `docs/optimization_report.md`.
- Modelo de presentación, reloj y resumen temporal bajo `lib/features/home/models/`.
- `home_dashboard_screen.dart`, `main_screen.dart` y `world_screen.dart` para Inicio y destinos directos.
- `test/home_dashboard_summary_test.dart` con cinco pruebas de presentación temporal.
- Política de zonas bajo `lib/features/interior/models/`, juego y pantalla activa de Casa.
- `test/interior_layout_policy_test.dart` con tres pruebas de distribución coherente.
- Política de interacción bajo `lib/features/world/models/`, juego y pantalla activa de Jardín.
- `test/garden_interaction_policy_test.dart` con dos pruebas de riego y crecimiento.

## Riesgos de seguimiento

- Los flujos manuales siguen basados en pruebas físicas previas reportadas por el propietario.
- No se debe interpretar “APK compila” como “release publicable”.
- No actualizar dependencias Firebase en bloque: requiere migración y pruebas por familia.
- No eliminar los 21 assets candidatos hasta comprobar catálogos y rutas dinámicas.
- Firebase CLI tuvo un cierre transitorio de hub después de que las aserciones pasaran; una repetición aislada cerró con código 0.
- `connectivity_plus` sólo representa disponibilidad de transporte; no se interpreta por sí solo como garantía de acceso a Internet.
- Firestore mantiene su persistencia offline nativa; los callables y cargas de Storage requieren la recuperación explícita implementada o una nueva acción del usuario.
- El APK universal sigue excediendo 100 MiB y no está firmado; ambos puntos permanecen reservados para FASE 20/25.
- No se ejecutó profiling de FPS/RAM/GPU en dispositivo durante FASE 4; queda como gate físico de FASE 20/24.
- PIN/biometría no se añadió: la reautenticación de Firebase protege las acciones sensibles sin guardar otro secreto local. Puede evaluarse más adelante como bloqueo opcional de interfaz.
- Identidad personal, URLs legales públicas y correos de soporte/borrado quedaron configurados y enlazados en la aplicación.
- El resumen de relación de Inicio utiliza la fecha personal compatible existente; la fuente compartida canónica y el contador completo se resolverán en FASE 15.
- `pawdo.site` está vinculado en Sites pero pendiente de compra y DNS. No se debe sustituir la URL operativa hasta validar HTTPS.
- El asset `interior/games_portal.png` quedó sin consumidor activo; se conserva como candidato hasta la auditoría integral de assets en FASE 20.
