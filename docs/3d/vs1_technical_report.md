# VS-1 — informe técnico verificable

Estado: evidencia técnica y física completa; aprobación visual explícita
pendiente antes de iniciar VS-2.

Fecha de evidencia: 2026-08-23 (America/Lima).

## Resultado implementado

- Proyecto fijado en Unity `6000.3.20f1` con licencia Unity Personal activa.
- Android Build Support, SDK/NDK Tools y OpenJDK 17 instalados y marcados como
  `Instalado` por Unity Hub.
- URP móvil, Input System, AI Navigation, Addressables y Test Framework fijados
  por versión.
- Escena gris `Bootstrap`, pipeline URP y exportador reproducible Unity as a
  Library para Android ARM64, IL2CPP, API mínima 26 y target/compile SDK 36.
- Contrato JSON v1 estricto: límite 64 KiB, lista blanca, dirección, UUID,
  deduplicación y ciclo de vida.
- Flutter inicia la actividad interna `PawdoUnityActivity` con el envelope
  `runtime.initialize` dentro del `Intent`; Unity lo valida antes de aceptar la
  sesión.
- `PawdoUnityActivity` captura Atrás clásico y predictivo, comparte la misma
  tarea Android que Flutter y reutiliza una sola instancia del runtime. Así se
  puede entrar y regresar repetidamente sin duplicar Unity ni terminar el
  proceso Flutter.
- Cada nueva entrada reordena la actividad Unity existente al frente y reenvía
  `runtime.initialize`; al regresar, la pestaña Mascota puede crear una nueva
  visita controlada sin perder el fallback.
- `scene.pause`, `scene.resume` y `scene.unload` cruzan la frontera nativa; el
  último solicita `Application.Unload()`.
- Un solo launcher Android. `MainActivity` queda exportada y la actividad Unity
  queda interna (`exported=false`) sin otro `MAIN/LAUNCHER`.
- Feature flag maestro apagado por defecto y fallback 2.5D conservado.
- El enlace Gradle es opcional: si el export no existe o se usa
  `-PpawdoUnityEnabled=false`, la app clásica continúa compilando.

## Evidencia automática

| Control | Resultado |
|---|---|
| `dart analyze lib test` | sin hallazgos |
| Suite Flutter | 110/110 pruebas |
| Unity EditMode | 6/6 pruebas, 0 fallos |
| Export Unity Library sincronizado | éxito; BuildReport 734,795,575 bytes; 9.60 s con caché |
| APK Flutter + Unity | éxito; 327,196,510 bytes |
| SHA-256 APK 3D | `F2396A35E3B27CC48E721FC9C02C49525D63BC92AC425228E542439F10F10C1E` |
| Hash del APK final instalado vs. local | coincidencia byte por byte |
| Binarios del APK 3D | `libunity.so`, `libil2cpp.so`, `libmain.so`, `lib_burst_generated.so` para ARM64 |
| Manifiesto fusionado | 1 launcher; host Unity `exported=false`, `singleTop`, misma task affinity |
| Compilación fallback | `BUILD SUCCESSFUL` en 53 s |
| Binarios Unity en APK fallback | 0 |

APK 3D generado en:

`build/app/outputs/flutter-apk/app-debug.apk`

El export Android es derivado y no se versiona. Se regenera desde
`Pawdo.Editor.PawdoAndroidLibraryExporter.Export`; el código fuente canónico
permanece en `unity/Pawdo3D`.

## Activación y rollback

El runtime 3D solo se abre en una compilación interna que incluya:

```text
--dart-define=PAWDO_UNITY_3D=true
```

Cada destino puede apagarse por separado con `PAWDO_UNITY_PET_3D`,
`PAWDO_UNITY_GARDEN_3D` o `PAWDO_UNITY_INTERIOR_3D` en `false`.

Para compilar el fallback sin enlazar el export Unity:

```text
gradlew --no-daemon -PpawdoUnityEnabled=false :app:assembleDebug
```

## Evidencia física ARM64

Dispositivo: Samsung `SM-A315G`, Android 12 / API 31, ARM64, 3,667 MB de RAM
informados por Unity y pantalla física 1080 × 2400. El APK se instaló con
`adb install -r -t`, conservando la sesión y los datos existentes.

| Control físico | Resultado |
|---|---|
| Serie limpia abrir Unity → Atrás → Flutter | 20/20 |
| `runtime.initialize` aceptados en el log preservado | 20/20 |
| Fallos `FATAL EXCEPTION` / `Fatal signal` | 0 |
| Proceso durante toda la serie | PID 9022 estable |
| Pantalla negra o salida al launcher | 0 después de la corrección |
| Smoke test del artefacto final exacto | 1 handshake, 0 fatal, regreso correcto a Flutter |
| FPS estabilizados en escena gris | 59.45–59.51 FPS; transitorios de reanudación 50–57 FPS |
| Memoria Flutter antes de la serie | PSS 583,687 KiB; RSS 385,123 KiB |
| Memoria con Unity visible tras la serie | PSS 638,348 KiB; RSS 396,890 KiB |
| Memoria Flutter tras volver y reposar 25 s | PSS 671,299 KiB; RSS 388,639 KiB |
| Variación RSS comparable tras reposo | +3,516 KiB, aproximadamente +0.9 % |
| Temperatura | 26.6 °C → 26.7 °C |
| Batería durante prueba conectada | 61 % → 63 % |
| Arranque frío de `MainActivity` | 7.174 s, incluyendo Firebase y dashboard |
| Actividad Unity visible | +0.885 s |
| Bridge `Ready` desde actividad Unity visible | +4.736 s |

No se observó OOM, cierre fatal ni crecimiento continuo de RSS. El aumento
transitorio de superficies se liberó al volver a Flutter y reposar. PSS incluye
páginas compartidas/intercambiadas y se seguirá perfilando por escena en VS-2 y
VS-5; esta prueba no sustituye una sesión larga de profiler.

Evidencia preservada:

- [`evidence/vs1_20cycles_logcat_sm_a315g.txt`](evidence/vs1_20cycles_logcat_sm_a315g.txt):
  logcat exacto de la serie, con 20 handshakes y 0 fallos fatales.
- [`evidence/vs1_after_20_flutter_sm_a315g.png`](evidence/vs1_after_20_flutter_sm_a315g.png):
  regreso correcto al dashboard después de la serie.
- [`evidence/vs1_unity_after_20_cycles_sm_a315g.png`](evidence/vs1_unity_after_20_cycles_sm_a315g.png):
  escena técnica `Ready` capturada en el dispositivo.

La puerta física de VS-1 está cumplida. La bandera 3D continúa apagada por
defecto y VS-2 no comienza hasta recibir aprobación visual explícita.

## Incidencias conocidas y resueltas

- Input System `1.12.0` referenciaba una API eliminada en Unity 6000.3. Se
  actualizó a `1.17.0`; proyecto y tests compilan.
- Windows Application Control bloquea la DLL JIT temporal de Burst dentro de
  `Library/BurstCache` (Policy ID
  `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`). No se ocultó el aviso. El build
  Android Burst AOT sí terminó, produjo `lib_burst_generated.so` y el APK
  compiló correctamente.
- `UnityPlayerGameActivity` consumía Atrás y dejaba al usuario dentro de la
  escena. Se añadió un host propio que atiende `KEYCODE_BACK` y Android 13+.
- Cerrar o descargar directamente la actividad Unity terminaba también el
  proceso Flutter compartido. Se corrigió manteniendo una sola instancia,
  `REORDER_TO_FRONT`, la misma tarea Android y retorno explícito a
  `MainActivity`.
- La primera automatización tocaba durante la rotación y produjo estados
  alternados; esos intentos no se contabilizaron. La serie oficial se reinició
  desde cero con sincronización de orientación y obtuvo 20/20.
