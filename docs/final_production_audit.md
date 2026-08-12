# Pawdo — auditoría inicial de producción

Fecha de actualización: 2026-08-11
Alcance actualizado hasta el cierre de FASE 13. Este documento no declara la aplicación lista para producción.

## Resumen ejecutivo

Pawdo tiene una base funcional considerable: separación por features, Riverpod parcial, Firebase Auth/Firestore/Storage/Functions, reglas con denegación general, chat privado, álbum compartido optimizado y 146 pruebas automatizadas aprobadas entre Flutter, Functions y reglas. Android genera un APK release.

Los bloqueos de producción son concretos: release sin firma, `targetSdk` 34, dominio propio/Data Safety y prueba staging pendientes, enforcement/validación operativa de App Check y Crashlytics pendientes, recuperación entre procesos todavía limitada para operaciones no persistentes y un APK superior a 100 MiB. No deben añadirse módulos grandes fuera del orden de fases.

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
| Eliminación de cuenta ausente | Crítica | Perfil, Functions, Firestore, Storage | No existía flujo in-app ni limpieza integral | Incumplimiento Play y retención de datos personales | Borrado server-side, reautenticación, confirmación escrita y limpieza integral | Resuelto en código FASE 6; despliegue/staging pendiente |
| Privacidad/Términos/soporte sin URLs reales | Alta | Cuenta y Play Console | Faltaban identidad, correos y recursos públicos | Riesgo legal y de revisión | Sitio público con tres rutas, identidad personal y contactos separados | Resuelto FASE 6 |
| Reconexión incompleta | Alta | Services, Functions, Storage, widget | Firestore persiste offline, pero callables y Storage no; además, una selección de foto no puede reconstruirse después de cerrar el proceso | Acciones no persistentes pueden requerir reintento explícito tras cierre forzado | Estado central por eventos, lifecycle, backoff acotado e idempotencia; cola durable sólo para operaciones serializables que lo justifiquen | Mitigado FASE 3 (`0224ea5`, `577bfda`); persistencia entre procesos y widget siguen en sus fases |
| Widget sin recuperación programada | Alta | `android_widget_service.dart`, `PawdoWidgetProvider.kt` | Actualización depende del canal/app y preferencias locales; no hay trabajo diferido/backoff | Datos congelados después de desconexión o cierre | Caché versionada y WorkManager solo cuando aporte valor, con restricciones de red | Pendiente FASE 17 |
| App Check sin enforcement | Media | Firebase cliente/Console | Debug y Play Integrity integrados; consola aún no fuerza tokens | Clientes no verificados todavía no se bloquean | Registrar certificados, validar dos teléfonos y activar por servicio | Integración resuelta FASE 21; gate remoto pendiente |
| Crashlytics sin primer evento | Media | `main.dart`, Android, Firebase Console | Captura release y plugin integrados con excepción original redactada | No se ha demostrado todavía recepción en el panel | Provocar crash solo en build interna y revisar contenido | Integración resuelta FASE 22; gate operativo pendiente |
| Inicialización crítica sin fallback | Alta | `lib/main.dart` | `Firebase.initializeApp()` bloqueaba antes de `runApp` y no tenía UI de recuperación | Fallo de configuración/red nativa podía impedir arrancar | Bootstrap observable con pantalla de error/reintento y reporte no sensible | Resuelto FASE 2 (`dd4c12a`) |
| Rutas Firestore con escritura amplia | Alta | `firestore.rules:205-214` | `state`, `cinemaReactions` y `cinemaMessages` permiten escritura de miembros sin esquema/campos/límites | Riesgo de datos inválidos, abuso y crecimiento | Inventariar consumidores y restringir esquemas, tamaños y frecuencia | Pendiente FASE 23 |
| Permisos sensibles declarados | Alta | `AndroidManifest.xml` | Cámara, audio y ubicación están en el manifiesto; llamadas reales están aplazadas | Mayor fricción y superficie de privacidad/políticas | Vincular cada permiso a función visible, solicitud contextual y retirar lo no necesario | Pendiente FASE 6/25 |
| APK grande | Alta | assets/build | 50,351,206 bytes de assets; APK universal de 112,339,592 bytes | Descarga y almacenamiento mayores | AAB/ABI medidos; optimización visual adicional exige QA en dos teléfonos | Mitigado FASE 20; seguimiento físico FASE 24/25 |
| Lifecycle y snapshots de juegos frágiles | Alta | Ludo, Atrapa a Pawdo, Memoria y host online | Temporizadores continuaban en background; Ludo mantenía efectos; algunas listas remotas se indexaban sin validar longitud/tipo | Trabajo innecesario, sala que parecía congelada o cierre por `RangeError` ante estado parcial | Pausar recursos, recuperar salas idempotentemente y normalizar snapshots antes de renderizar | Mitigado FASE 4 (`fe6e841`, `09f80ed`); profiling físico pendiente FASE 20/24 |
| Perfil final no editable | Alta | `profile_screen.dart`, ProfileService, Storage | La pantalla ignoraba los datos guardados y mostraba “Pronto podrás editarlo”; una tarjeta de Casa no ejecutaba ninguna acción | Perfil incompleto, poco comercial y datos desactualizados para la pareja | Formulario compatible, foto privada, temas, fechas, resumen seguro y accesos reales | Resuelto FASE 5 (`ec4d809`, `f91efad`) |
| Dependencias atrasadas | Media | `pubspec.yaml`, `pubspec.lock` | Familia Firebase antigua pero internamente compatible; actualización mayor disponible | Mantenimiento y compatibilidad futura | Actualización escalonada después del lanzamiento; no mezclar con App Check/Crashlytics | Diferido para evitar migración mayor previa al release |
| Functions usa release candidate | Alta | `functions/package.json` | `firebase-functions ^7.3.2-rc.0` | Riesgo de cambios/bugs pre-release en backend | Evaluar versión estable compatible antes de producción | Pendiente FASE 23 |
| Analizador no limpio | Media | Varios | 4 warnings y 74 infos en la línea base | La puerta de calidad fallaba y podía ocultar regresiones futuras | Corregir en commit mecánico, sin mezclar funciones | Resuelto FASE 2 (`f760274`); 0 hallazgos |
| Arquitectura de estado inconsistente | Media | `app_providers.dart` y pantallas | Servicios inyectados conviven con acceso directo a Firebase | Tests y reconexión transversal más difíciles | Migración incremental por feature; no reescritura global | Pendiente gradual |
| Código legacy/duplicado | Media | `login_screen_new.dart`, `uth_gate.dart`, `features/home/screens/chat_screen.dart`, `pet_screen.dart` | Implementaciones antiguas no importadas por flujo activo | Confusión, tamaño fuente y riesgo de editar archivo equivocado | Confirmar rutas y eliminar en commit separado con tests | Pendiente gradual |
| Functions monolítica | Media | `functions/index.js` (~115 KB) | Múltiples dominios y exports en un solo archivo | Revisión, ownership y pruebas selectivas difíciles | Modularizar sin cambiar contratos/export names | Pendiente gradual |
| Presencia periódica | Baja | `presence_service.dart` | Latido cada 120 s, dentro de una frescura visual de 3 min | Coste Firestore/batería en sesiones largas | Sincronización inmediata en eventos y medición física | Mitigado FASE 20; 37.5% menos escrituras periódicas |
| Cobertura UI y lifecycle insuficiente | Alta | `test`, `docs/phase_g_test_matrix.md` | 10 archivos de test Flutter; matriz manual todavía no ejecutada completamente | Navegación, permisos y recorridos físicos siguen sin garantía total | Añadir integration tests y repetir en dos teléfonos | Pendiente FASE 24 |
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
- 50 tests de Functions, 22 de Firestore Rules y 19 de Storage Rules pasan en emuladores.

Pendiente de validar:

- App Check, revisión legal/Data Safety final, despliegue y prueba destructiva en staging, logs productivos y secretos de CI.
- Consentimiento y borrado completo de bienestar/ubicación en producción.
- Inventario Data Safety real y verificación operativa de los correos publicados.
- Reglas amplias de `state` y cinema.

## Estado de FASE 0–13

- Auditoría estática y documental: completada.
- Git y respaldo: completados.
- Baseline Flutter/Android/Firebase: completado con hallazgos registrados.
- FASE 2: analizador limpio; bootstrap con carga, error, reintento y captura global segura; dos widget tests añadidos.
- Puerta final de FASE 2: 15 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK recompilado.
- FASE 3: recuperación central por conectividad/lifecycle, estados accesibles, backoff acotado y reintento idempotente de chat con el mismo ID.
- Puerta de FASE 3: 19 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK de 110,549,629 bytes recompilado y verificado como no firmado.
- Firestore conserva su sincronización offline nativa. El indicador de transporte no se trata como prueba absoluta de Internet; los fallos transitorios reales de Firebase mantienen activa la recuperación.
- FASE 4: diez juegos auditados; snapshots defensivos, timers y efectos conscientes del lifecycle, y recuperación automática de salas sin repetir jugadas.
- Puerta de FASE 4: 24 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK de 110,549,753 bytes recompilado y verificado como no firmado.
- FASE 5: perfil editable y comercial, foto privada cacheada, nombre visible seguro, fechas, pareja, accesos útiles y tres estilos compatibles con documentos legacy.
- Puerta de FASE 5: 29 tests Flutter, 43 Functions, 18 Firestore Rules y 14 Storage Rules aprobados; APK de 110,714,193 bytes recompilado y verificado como no firmado.
- FASE 6 técnica: cambio de correo con verificación, exportación JSON, centro de privacidad/soporte configurable, borrado completo con autenticación reciente y reglas de perfil restringidas.
- Puerta final de FASE 6: analyze limpio; sitio público validado; 32 tests Flutter, 46 Functions, 19 Firestore Rules y 14 Storage Rules aprobados; APK de 111,058,781 bytes recompilado y verificado como no firmado.
- FASE 6 cerrada con identidad personal, correos diferenciados y sitio legal público enlazado dentro de Pawdo. La prueba destructiva de staging permanece como gate de lanzamiento.
- FASE 7: Inicio contextual con hora, nombre visible, relación, próximo aniversario, tema visual y accesos rápidos; Casa y Jardín ya no comparten el mismo destino.
- Puerta final de FASE 7: analyze limpio; 37 tests Flutter aprobados; APK de 111,124,317 bytes recompilado y verificado como no firmado. Backend y reglas no cambiaron, por lo que conservan sus puertas aprobadas de FASE 6.
- FASE 8: Casa activa sin portal duplicado, muebles nuevos guiados por zonas, cambios no guardados protegidos y orientación vertical restaurada al salir; diseños existentes permanecen compatibles.
- Puerta final de FASE 8: analyze limpio; 40 tests Flutter aprobados; APK de 111,124,317 bytes recompilado y verificado como no firmado. Backend y reglas no cambiaron.
- FASE 9: Jardín con riego ligado exclusivamente a vegetación tocada, etapas comprensibles y sincronización visual; edición protegida contra salida sin guardar.
- Puerta final de FASE 9: analyze limpio; 42 tests Flutter aprobados; APK de 111,140,701 bytes recompilado y verificado como no firmado. Backend y reglas no cambiaron.
- FASE 10: editor de personaje extensible con propiedades independientes, resumen compartido validado y estilo/pose animados en Casa y Jardín; cuentas legacy conservan los estilos clásicos.
- Puerta final de FASE 10: analyze limpio; 45 tests Flutter, 46 Functions, 20 Firestore Rules y 14 Storage Rules aprobados; APK de 111,304,657 bytes recompilado y verificado como no firmado.
- FASE 11: Mascota compartida con siete cuidados, cinco necesidades, siete emociones, reacciones y movimiento 2D ligero; desgaste temporal y precondiciones se calculan en el servidor.
- Puerta final de FASE 11: analyze limpio; 49 tests Flutter, 48 Functions, 21 Firestore Rules y 14 Storage Rules aprobados; APK de 111,305,117 bytes recompilado y verificado como no firmado.
- FASE 12: chat existente preservado y ampliado con grabación contextual, subida privada, validación server-side, reproducción autenticada y limpieza de notas de voz AAC de hasta 60 segundos.
- Puerta final de FASE 12: analyze limpio; 52 tests Flutter, 49 Functions, 21 Firestore Rules y 17 Storage Rules aprobados; APK de 111,444,371 bytes recompilado y verificado como no firmado.
- FASE 13: Álbum compartido con cuadrícula, línea de tiempo, detalle, categorías, fecha, lugar, etiquetas y favoritos individuales; originales/miniaturas optimizados y privados.
- FASE 14: Calendario compartido con mes, próximos, recuerdos, nueve categorías, fotos privadas y recordatorios periódicos idempotentes para ambos integrantes.
- Puerta final de FASE 14: analyze limpio; 58 tests Flutter, 53 Functions, 23 Firestore Rules y 21 Storage Rules aprobados; APK de 112,526,631 bytes recompilado y verificado como no firmado de publicación.
- FASE 15: Contador basado en una fecha canónica de pareja, con duración calendario, días totales, próximo aniversario y edición confirmada por cualquier integrante activo.
- Puerta final de FASE 15: analyze limpio; 58 tests Flutter, 55 Functions, 23 Firestore Rules y 21 Storage Rules aprobados; APK de 112,527,019 bytes recompilado y verificado como no firmado de publicación.
- FASE 16: Bienestar voluntario y privado con ciclos regulares/irregulares, fecha o rango orientativos, historial propietario, lenguaje respetuoso y consentimiento revocable por campo.
- Puerta final de FASE 16: analyze limpio; 61 tests Flutter, 57 Functions, 24 Firestore Rules y 21 Storage Rules aprobados; APK de 112,527,019 bytes recompilado y verificado como no firmado de publicación.
- FASE 17: Widget Android adaptable con foto privada cacheada, días/tiempo juntos, próximo evento y Te extraño autenticado; sin sondeo ni servicio persistente.
- Puerta final de FASE 17: analyze limpio; 63 tests Flutter, 57 Functions, 24 Firestore Rules y 21 Storage Rules aprobados; Kotlin/XML compilados dentro del APK de 112,543,651 bytes, todavía sin firma de publicación.
- FASE 18: Tres juegos locales de tarjetas —Quién conoce mejor, Verdadero o falso y Elige uno— sin red, recompensas, temporizadores ni recursos pesados.
- Puerta final de FASE 18: analyze limpio; 65 tests Flutter, 57 Functions, 24 Firestore Rules y 21 Storage Rules aprobados; APK de 112,560,211 bytes recompilado y todavía sin firma de publicación.
- FASE 19: Tienda unificada en diez categorías, con estados Gratis/Monedas/Bloqueado/Premium futuro, rutas a los editores existentes y dinero real completamente desactivado.
- Puerta final de FASE 19: analyze limpio; 67 tests Flutter, 57 Functions, 24 Firestore Rules y 21 Storage Rules aprobados; APK de 112,560,583 bytes recompilado y todavía sin firma de publicación.
- FASE 20: carga diferida de pestañas, presencia a 120 segundos, código/asset huérfano retirado y medición APK/AAB por arquitectura sin degradar recursos visuales.
- Puerta técnica de FASE 20: analyze limpio; 69 tests Flutter aprobados; APK universal de 112,339,592 bytes y AAB arm64 de 72,544,764 bytes. Backend/reglas no cambiaron desde la compuerta completa de FASE 19.
- FASE 21: Firebase App Check integrado antes de los servicios Firebase, con Debug en desarrollo, Play Integrity en Android release y renovación automática; enforcement remoto deliberadamente pendiente.
- Puerta técnica de FASE 21: analyze limpio; 72 tests Flutter aprobados y APK de 112,356,448 bytes recompilado.
- FASE 22: Crashlytics release recibe fallos globales con el mensaje original eliminado; debug permanece local y el plugin Android prepara reportes legibles.
- Puerta técnica de FASE 22: analyze limpio; 73 tests Flutter aprobados y APK de 112,505,685 bytes recompilado. Primer evento en consola pendiente de build interna.
- Pruebas físicas y profiling: no ejecutados en esta fase.
- Siguiente paso autorizado por el roadmap: FASE 23, seguridad final.
