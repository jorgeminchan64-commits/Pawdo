# Pawdo — progreso hacia producción

Última actualización: 2026-08-22

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
| 10. Personajes | Completada | Editor extensible, perfil compartido seguro, 45 tests Flutter y APK recompilado | Nuevos sprites por capas requieren catálogo visual futuro; validación física pendiente | Iniciar FASE 11 |
| 11. Mascota | Completada | Cuidado server-side, 7 emociones, 49 Flutter/48 Functions/35 reglas; APK recompilado | Validación táctil en dos teléfonos; voz/sonido descartados por permisos y consumo | Iniciar FASE 12 |
| 12. Chat y audio | Completada | Audio privado AAC, 52 Flutter/49 Functions/38 reglas; APK recompilado | Grabación/reproducción física pendiente en dos teléfonos | Iniciar FASE 13 |
| 13. Álbum | Completada | Cuadrícula/línea de tiempo, detalle, originales+miniaturas; 55 Flutter/50 Functions/41 reglas | Flujo visual y cámara física pendientes en dos teléfonos | Iniciar FASE 14 |
| 14. Calendario | Completada | Mes/próximos/recuerdos, eventos, foto y avisos; 58 Flutter/53 Functions/44 reglas | Aviso push y zona horaria requieren prueba en dos teléfonos | Iniciar FASE 15 |
| 15. Contador de relación | Completada | Fecha canónica, duración, días y aniversario; 58 Flutter/55 Functions/44 reglas | Sincronización visual requiere prueba en dos teléfonos | Iniciar FASE 16 |
| 16. Bienestar | Completada | Regular/irregular, historial privado y consentimiento; 61 Flutter/57 Functions/45 reglas | Recordatorios son internos; experiencia requiere prueba física | Iniciar FASE 17 |
| 17. Widgets | Completada | Adaptable, caché privada, relación/evento y Te extraño; 63 Flutter/57 Functions/45 reglas | Foto, redimensionado y acción requieren prueba física | Iniciar FASE 18 |
| 18. Nuevos juegos | Completada | 3 juegos locales ligeros; 65 Flutter/57 Functions/45 reglas | Conversación/maquetación requieren prueba física | Iniciar FASE 19 |
| 19. Tienda y personalización | Completada | 10 categorías y estados explícitos; 67 Flutter/57 Functions/45 reglas | Revisión visual pendiente; dinero real permanece desactivado | Iniciar FASE 20 |
| 20. Optimización global | Completada técnica | Carga diferida, -37.5% latidos, assets limpiados, 69 Flutter y APK/AAB medidos | FPS/RAM/visual requieren dos teléfonos | Iniciar FASE 21 |
| 21. App Check | Completada técnica | Debug/Play Integrity, renovación automática, 72 Flutter y APK | Enforcement exige consola, certificados y dos teléfonos | Iniciar FASE 22 |
| 22. Crashlytics | Completada técnica | Captura global redactada, plugin Android, 73 Flutter y APK | Primer evento requiere build interna y Firebase Console | Iniciar FASE 23 |
| 23. Seguridad final | Completada técnica | Esquemas cerrados, Functions estable y 177 pruebas | Audit transitivo y gates externos requieren seguimiento | Iniciar FASE 24 |
| 24. Pruebas completas | Completada técnica | 179 pruebas; analyze limpio; Lint 0 errores; permisos y APK inspeccionados | Cobertura 10.7% y matriz en dos teléfonos pendientes | Iniciar FASE 25 sin publicar |
| 25. Play Store | Completada técnica | API 36; 182 pruebas; AAB 100,674,591 bytes; ELF 16 KB; recursos/ficha/Data Safety preparados | Firma, consola, dominio, staging y dos teléfonos | Completar gates externos sin publicar prematuramente |
| 26. Experiencia 2.5D y release firmado | Completada local | Avatares modulares, jardín/exterior/interior 2.5D; 199 pruebas; APK/AAB firmados | Un binding IAM, dominio y matriz física siguen externos | Autorizar IAM exacto y continuar gates de Play |

## Completado

- Reparación e inicialización de Git.
- Refuerzo de `.gitignore` contra dependencias, artefactos y credenciales privadas.
- Punto de retorno del proyecto original.
- Formato automático aislado en commit propio.
- 65 tests Flutter, 57 de Functions, 24 de Firestore Rules y 21 de Storage Rules aprobados.
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
- Personajes incorpora un editor vectorial real con estilo base, cabello, color, piel, ropa, calzado, accesorios, expresión y pose como propiedades independientes.
- La apariencia se guarda en el perfil personal, se replica a la pareja mediante un resumen validado y refleja estilo animado/pose en Casa y Jardín sin romper cuentas antiguas.
- Firestore exige un esquema completo y cerrado; Functions descarta apariencias parciales o manipuladas antes de compartirlas.
- Tres pruebas nuevas cubren serialización, compatibilidad defensiva y edición/guardado; suite Flutter aumentada de 42 a 45 tests.
- APK release de FASE 10: 111,304,657 bytes (106.15 MiB), todavía sin firma.
- Mascota ahora permite tocar/acariciar, alimentar, jugar, dormir, despertar, bañar e ir al baño desde una pantalla desplazable y accesible.
- Pawdo expresa estados feliz, triste, cansado, hambriento, emocionado, dormido o con necesidad de aseo, con reacciones y animaciones 2D ligeras.
- Hambre, felicidad, energía, higiene y necesidad de baño se degradan de forma acotada según tiempo transcurrido y se actualizan autoritativamente en Functions.
- Las escrituras cliente en `couples/{code}/state` quedaron cerradas; ambos integrantes solo observan y las acciones validadas pasan por el servidor.
- Cuatro pruebas Flutter, dos de Functions y una de Firestore nuevas elevan la suite a 132 pruebas automatizadas.
- APK release de FASE 11: 111,305,117 bytes (106.15 MiB), todavía sin firma.
- Chat conserva texto, accesos rápidos, fotos, paginación, leído, presencia, borrado de 10 minutos y reintento idempotente; no se reescribieron contratos ya seguros.
- Mensajes de voz AAC-LC mono de hasta 60 segundos/2 MB, con permiso solicitado únicamente al tocar micrófono, grabación visible, cancelar/enviar y reproducción autenticada.
- Storage limita ruta, membresía, formato, propietario, pareja, tamaño y metadatos; Functions verifica nuevamente el objeto antes de crear el mensaje.
- Audios nunca guardan URLs con token; se descargan a caché temporal y el trigger de borrado limpia foto o audio al eliminar el mensaje.
- `record 6.0.0` quedó fijado por compatibilidad con Dart 3.11 y la familia Firebase actual; 6.2.x genera conflicto web y 7.x exige Dart 3.12.
- Tres pruebas Flutter, una de Functions y tres de Storage elevan la suite a 139 pruebas automatizadas.
- APK release de FASE 12: 111,444,371 bytes (106.28 MiB), todavía sin firma.
- Álbum compartido separado del chat, accesible desde Inicio, con cuadrícula, línea de tiempo cronológica y detalle ampliable.
- Cada recuerdo admite foto, descripción, fecha, lugar opcional, hasta 10 etiquetas, favorito individual y categoría Viajes/Citas/Aniversarios/Momentos especiales/Otros.
- Cada subida genera original JPEG comprimido ≤1 MB y miniatura ≤250 KB; la cuadrícula nunca descarga el original y la caché evita repetir lecturas durante la sesión.
- Documentos y favoritos son server-only; Storage valida membresía, ruta, variante, tamaño y metadatos. Solo quien creó un recuerdo puede eliminarlo.
- Tres pruebas Flutter, una de Functions, una de Firestore y dos de Storage elevan la suite a 146 pruebas automatizadas.
- APK release de FASE 13: 111,674,279 bytes (106.50 MiB), todavía sin firma.
- Calendario compartido accesible desde Inicio con vistas de mes, próximos eventos y enlace directo al Álbum de recuerdos.
- Eventos con título, descripción, fecha/hora, nueve categorías, emoji, foto JPEG opcional optimizada a 750 KB y eliminación confirmada solo por su creador.
- Recordatorios procesados cada 15 minutos en el servidor, entrega a ambos integrantes, preferencia individual para desactivarlos y marca idempotente contra avisos repetidos.
- Documentos de calendario server-only y fotos privadas con ruta, membresía, propietario, tipo, metadatos y tamaño validados por Storage y Functions.
- Tres pruebas Flutter, tres de Functions, una de Firestore y dos de Storage elevan la suite a 155 pruebas automatizadas.
- APK release de FASE 14: 112,526,631 bytes (107.31 MiB), todavía sin firma de publicación.
- La fecha de relación tiene ahora una fuente canónica en el documento de pareja; Inicio deja de depender de dos valores personales potencialmente distintos.
- La tarjeta de Inicio abre “Nuestra historia”, con duración calendario, días totales, fecha inicial y próximo aniversario, incluida la normalización de años bisiestos.
- Cualquiera de los dos integrantes puede corregir la fecha con confirmación; Functions valida membresía, día UTC normalizado, límite 1900 y rechazo del futuro.
- Dos pruebas de Functions amplían permisos y fechas manipuladas; la suite total queda en 157 pruebas automatizadas.
- APK release de FASE 15: 112,527,019 bytes (107.31 MiB), todavía sin firma de publicación.
- Bienestar conserva activación voluntaria, historial/notas privados, borrado total y consentimiento explícito por campo; el perfil de la pareja nunca puede leer el historial personal.
- Ciclos regulares muestran una fecha orientativa; ciclos irregulares muestran un rango calculado con intervalos observados o un margen inicial prudente.
- Los textos de apoyo evitan atribuir emociones a la menstruación, invitan a preguntar cómo se siente la persona y reiteran que Pawdo no diagnostica fertilidad, embarazo u ovulación.
- Cambiar o retirar campos compartidos elimina inmediatamente el resumen anterior; las notas y fechas exactas nunca entran al documento compartido.
- Tres pruebas Flutter, dos de Functions y una de Firestore elevan la suite a 163 pruebas automatizadas.
- APK release de FASE 16: 112,527,019 bytes (107.31 MiB), todavía sin firma de publicación.
- Widget Android adaptable: pequeño muestra foto/días; mediano añade tiempo, próximo evento y botón “Te extraño ❤️”.
- La foto se descarga autenticada y se guarda únicamente en archivos privados de la app; contenido detallado permanece oculto de forma predeterminada.
- “Te extraño” abre Pawdo y usa el callable autenticado/idempotente del chat; si falla conserva la acción para reintentar, sin credenciales dentro del receptor Android.
- Sin polling, servicio permanente ni WorkManager: actualiza por snapshots reales, conserva el último estado válido sin red y limpia foto/datos al cerrar sesión o desvincular.
- Dos pruebas Flutter elevan la suite a 165 pruebas automatizadas; la integración Kotlin/XML quedó comprobada por la compilación release.
- APK release de FASE 17: 112,543,651 bytes (107.33 MiB), todavía sin firma de publicación.
- Tres minijuegos nuevos y distintos: ¿Quién conoce mejor?, Verdadero o falso y Elige uno, con 18 tarjetas iniciales y dos opciones por ronda.
- Se ejecutan juntos en un teléfono, sin red, temporizadores, audio, partículas, escrituras Firebase ni recompensas; abandonar la pantalla no deja trabajo activo.
- El mazo evita repetir inmediatamente la misma tarjeta y las transiciones usan solo un AnimatedSwitcher corto.
- Dos pruebas Flutter elevan la suite a 167 pruebas automatizadas; backend/reglas no cambiaron y conservan sus compuertas aprobadas.
- APK release de FASE 18: 112,560,211 bytes (107.35 MiB), todavía sin firma de publicación.
- Tienda reorganizada en las diez categorías previstas: ropa, cabello, accesorios, zapatos, decoración, muebles, jardín, mascota, fondos y temas.
- Cada categoría declara un estado visible —Gratis, Monedas, Bloqueado o Premium futuro— y las opciones no disponibles no exponen rutas de compra.
- Ropa, cabello, accesorios y zapatos reutilizan el editor real del personaje; fondos y temas abren la edición de perfil; decoración, muebles y jardín conservan sus tiendas con compra atómica e inventario compartido.
- No se activó dinero real. El contenido premium permanece bloqueado hasta una futura integración y validación de Google Play Billing.
- Dos pruebas Flutter elevan la suite a 169 pruebas automatizadas; las 57 de Functions, 24 de Firestore y 21 de Storage también fueron repetidas y aprobadas.
- APK release de FASE 19: 112,560,583 bytes (107.35 MiB), todavía sin firma de publicación.
- Las pestañas secundarias ahora se construyen únicamente al primer uso y conservan su estado; se evitan streams, pantallas y trabajo de arranque innecesarios.
- La presencia mantiene sincronización inmediata en eventos importantes y amplía su latido de 75 a 120 segundos, reduciendo 37.5% las escrituras periódicas.
- Un PNG huérfano de 220,777 bytes, una pantalla de acceso duplicada y tres archivos vacíos fueron eliminados tras confirmar que no tenían consumidores.
- Assets: 50,351,206 bytes. APK universal: 112,339,592 bytes, 220,991 menos que FASE 19. AAB técnico arm64: 72,544,764 bytes; APK por ABI entre 71,481,306 y 75,261,986 bytes.
- Dos pruebas Flutter elevan la suite a 171 pruebas automatizadas; analyze quedó limpio. Backend y reglas no cambiaron y conservan la compuerta completa repetida en FASE 19.
- App Check se activa antes de usar servicios Firebase: Debug solo en compilaciones debug y Play Integrity en Android release, con renovación automática del token.
- Plataformas no preparadas no fingen attestation; Auth, reglas y validaciones server-side permanecen obligatorias.
- Tres pruebas Flutter elevan la suite a 174 pruebas automatizadas; analyze quedó limpio y el APK release con App Check compiló en 112,356,448 bytes.
- Enforcement remoto no fue activado: requiere registrar certificados, probar dos teléfonos y observar métricas antes de habilitarlo gradualmente.
- Crashlytics se activa solo en release y recibe fallos globales Flutter, async y Zone; debug conserva diagnóstico local sin enviar telemetría.
- La excepción original se reemplaza por su tipo técnico antes de reportar, evitando adjuntar correos, mensajes, URLs, rutas u otros datos personales.
- El complemento Android 3.0.7 quedó integrado; una prueba nueva eleva la suite a 175 automatizadas y el APK release compila en 112,505,685 bytes.
- El primer evento visible y la revisión de su contenido requieren una build interna controlada; no se añadió ningún botón de crash al producto.
- Cine dejó de aceptar documentos arbitrarios: reacciones, mensajes, fuente y reproducción tienen esquemas cerrados, autor autenticado, timestamps del servidor y límites de tamaño.
- El documento de pareja rechaza cualquier campo cliente fuera de los cuatro campos explícitos de Cine; los demás dominios permanecen server-only.
- Functions usa ahora `firebase-functions` 7.3.2 estable en lugar del release candidate, con sus 57 pruebas aprobadas sin cambios de contrato.
- La compuerta queda en 73 Flutter, 57 Functions, 26 Firestore y 21 Storage: 177 pruebas automatizadas aprobadas; APK release de 112,505,685 bytes.
- `npm audit` conserva 12 avisos transitivos (3 altos) documentados; no se ejecutó una corrección forzada que propone degradar Firebase y el runner de pruebas.
- FASE 24 repite la batería completa con 75 Flutter, 57 Functions, 26 Firestore y 21 Storage: 179 pruebas aprobadas.
- La cobertura Flutter medida es 10.7% (1,125 de 10,517 líneas); no reemplaza la matriz física.
- Android Lint release queda en 0 errores y 13 advertencias; el APK de 112,069,422 bytes pasa la alineación ZIP de 16 KB, pero continúa sin firma.
- Se retiró Firebase Analytics sin uso; el APK dejó de declarar `AD_ID`, AdServices e Install Referrer. Cámara y micrófono quedaron como hardware opcional y no existe ubicación en segundo plano.
- FASE 25 eleva `targetSdk` a 36, unifica la versión con `pubspec.yaml` y prepara firma release mediante secretos locales ignorados.
- La suite Flutter sube a 78 y la compuerta total a 182 pruebas. Android Lint termina con 0 errores y 5 avisos no bloqueantes.
- AAB técnico final: 100,674,591 bytes, sin firma; sus 12 ELF cumplen alineación mínima de 16 KB. APK técnico: 111,757,970 bytes, alineado y sin firma.
- Icono adaptable/monocromático, icono de notificación, app icon 512 × 512 y feature graphic 1024 × 500 quedan preparados.
- Ficha, Data Safety, firma y reporte final quedan documentados. La política legal local incorpora Crashlytics/App Check y supera 4 pruebas; no fue desplegada sin autorización.
- FASE 26 integra un renderer 2.5D compartido para avatares modulares en el editor, jardín e interior, con cabello, piel, ropa, calzado, accesorios, expresión y pose persistentes.
- Casa, muebles, plantas, Pawdo y personajes usan profundidad por la base, sombras de contacto, iluminación cálida, atmósfera determinista y microanimación sin alterar posiciones guardadas ni funciones existentes.
- La compuerta final queda en 95 Flutter, 57 Functions, 26 Firestore y 21 Storage: 199 pruebas aprobadas; `dart analyze` termina sin hallazgos.
- La upload key de Jorge Luis Minchan Huaman fue creada y protegida fuera de Git. APK universal, tres APK por ABI y AAB tienen firma release verificada; el AAB final mide 97.16 MiB.
- Las huellas SHA-1/SHA-256 de la upload key están registradas en Firebase y `google-services.json` incluye el cliente OAuth Android resultante para `com.pawdo.app`.
- Firestore Rules, Storage Rules y las Functions nuevas fueron desplegadas. Solo `savecalendarevent` requiere un binding Cloud Run IAM explícito para que el transporte llegue a su validación Firebase Auth.

## Pendiente inmediato

1. Autorizar y aplicar `allUsers → roles/run.invoker` únicamente al servicio Cloud Run `savecalendarevent`; `requireAuth()` conserva la protección de datos.
2. Respaldar juntos `android/app/pawdo-release.jks` y `android/key.properties` en dos ubicaciones privadas.
3. Ejecutar la matriz de FASE 24 en dos teléfonos y un entorno de páginas de 16 KB; validar App Check, Crashlytics y notificaciones con la build firmada.
4. Registrar `pawdo.site`, completar DNS/HTTPS y publicar la política legal actualizada.
5. Activar Play App Signing, registrar las huellas de su certificado de distribución en Firebase y completar Play Console, Data Safety, clasificación, capturas y prueba cerrada si aplica.

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
- El APK universal final excede 100 MiB, pero ya está firmado. El AAB firmado mide 97.16 MiB y la validación en Play Console continúa como gate externo posterior a FASE 26.
- No se ejecutó profiling de FPS/RAM/GPU en dispositivo; queda como gate físico de FASE 24.
- PIN/biometría no se añadió: la reautenticación de Firebase protege las acciones sensibles sin guardar otro secreto local. Puede evaluarse más adelante como bloqueo opcional de interfaz.
- Identidad personal, URLs legales públicas y correos de soporte/borrado quedaron configurados y enlazados en la aplicación.
- El resumen de relación de Inicio utiliza la fecha personal compatible existente; la fuente compartida canónica y el contador completo se resolverán en FASE 15.
- `pawdo.site` está vinculado en Sites pero pendiente de compra y DNS. No se debe sustituir la URL operativa hasta validar HTTPS.
- El asset `interior/games_portal.png` fue eliminado en FASE 20 tras confirmar que no tenía consumidores.
