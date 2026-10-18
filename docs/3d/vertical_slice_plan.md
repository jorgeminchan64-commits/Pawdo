# Pawdo 3D — plan del vertical slice

Estado al 2026-08-30: VS-1 a VS-3 aprobados técnicamente. VS-4 está
implementado y validado en pruebas de Flutter, Unity, Firebase y Android físico.
La dirección visual de producción, la voz directamente dentro del mundo 3D y la
exportación ARM64/IL2CPP para Play Store siguen pendientes; VS-5 queda activo.

## Propósito

Demostrar en un Android físico que la arquitectura híbrida puede ofrecer una
experiencia adulta, estable y verificable antes de ampliar catálogo o retirar
el fallback 2D.

## Prerrequisitos

1. Aprobar el Hito 0.
2. Instalar Android Build Support para Unity `6000.3.20f1`.
3. Conectar un Android físico de gama media y otro de gama baja.
4. Crear el manifiesto de activos y aprobar sus licencias.
5. Definir una cuenta Firebase exclusiva de pruebas sin datos personales.

## Alcance cerrado

- Proyecto Unity URP móvil versionado en `unity/Pawdo3D/`.
- Una escena `Bootstrap`, una `GardenSlice` y una `InteriorSlice`.
- Dos avatares adultos sobre humanoid rig.
- Pawdo 3D con locomoción, idle, sentado y reacción de voz.
- Un peinado o una prenda intercambiable por avatar.
- Jardín pequeño: terreno, camino, cantero, planta y regadera.
- Interior: habitación, cama doble con dos sockets y cama de Pawdo.
- NavMesh, colliders, sockets e interacción por raycast.
- Repetición local de voz mediante mantener presionado.
- Contrato Flutter–Unity v1 y feature flag con fallback.
- Lectura y actualización autorizada de estado con una cuenta de prueba.

No incluye catálogo completo, clima, multihabitación, reconocimiento remoto,
mercado de activos ni retiro del motor 2D.

## Secuencia

### VS-1 — esqueleto técnico

- Crear proyecto Unity con versión fijada y paquetes bloqueados.
- Configurar URP, Input System, AI Navigation, Addressables y Test Framework.
- Integrar runtime Android a pantalla completa.
- Implementar handshake, pausa, reanudación, salida y fallback.

Salida: escena gris abre y cierra veinte veces sin perder navegación Flutter.

### VS-2 — locomoción y jardín

- Importar avatares y Pawdo con manifiesto/licencia.
- Construir NavMesh, obstáculos, raycast y zonas semánticas.
- Colocar una planta con collider y `WateringSocket`.
- Implementar preview verde/rojo, guardado válido y rechazo de vacío.

Salida: 100 toques vacíos generan cero riegos; 100 desplazamientos horizontales
mantienen rotación correcta.

Resultado al 2026-08-23: salida técnica cumplida en Samsung `SM-A315G` con el
APK final verificado por SHA-256. La escena actual es un vertical slice 3D
original y funcional, construido con geometría procedural y materiales URP;
sirve para validar interacción, navegación, semántica y persistencia. No se
declara arte final fotorrealista ni modelo de producción de alta definición.
Ver `vs2_technical_report.md`.

### VS-3 — interior y sockets

- Construir habitación coherente y cama doble.
- Reservar dos `SleepSocket`, puntos de entrada y socket de salida.
- Implementar caminar, girar, acostarse, permanecer y levantarse.
- Pawdo usa únicamente su cama.

Salida: 25 ciclos completos sin teletransporte visible, colisiones ni props
duplicados.

Resultado al 2026-08-29: salida técnica cumplida en Samsung `SM-A315G`.
Resultado físico final: `cycles=25 teleports=0 collisions=0 duplicates=0
support=0`. Se corrigieron el origen visual local, la estabilización de la pose,
la colocación sobre el colchón y la apertura inicial de Unity. Ver
`vs3_technical_report.md`. El bloque procedural no se declara arte final.

### VS-4 — voz y backend

- Implementar pulsar-para-hablar y permiso justo a tiempo.
- Grabar en caché, VAD/RMS, pitch/formante y lip-sync.
- Borrar buffer en éxito, error, cancelación y background.
- Conectar interacciones al backend mediante Flutter con idempotencia.

Salida: red bloqueada no sube audio ni concede recompensa; el estado canónico
se recupera tras reiniciar.

Resultado al 2026-08-30: grabación y repetición local con limpieza de caché,
señal de voz para Pawdo 3D, contrato v1 y operaciones 3D idempotentes
implementados. Ver `vs4_technical_report.md`. No se aprueba aún como entrega
Play Store por el bloqueo local de la exportación ARM64/IL2CPP y porque el arte
procedural actual no es el acabado adulto final.

### VS-5 — perfil y aprobación

- Perfilar CPU, GPU, memoria, temperatura, batería y arranque.
- Ejecutar matriz física y grabar todos los criterios.
- Corregir fallos y producir APK/AAB interno.
- Presentar comparación visual con la biblia 3D.

## Presupuestos iniciales

| Métrica | Objetivo | Piso/puerta |
|---|---:|---:|
| FPS gama media | 60 sostenidos | nunca <30 sostenido |
| Frame CPU/GPU a 60 Hz | p95 ≤16.7 ms | sin picos repetitivos visibles |
| Entrada a escena caliente | ≤2 s | medir p50/p95 |
| Entrada fría | ≤5 s | fallback si timeout |
| Memoria | fijar tras escena gris | cero OOM en 20 ciclos |
| GC durante locomoción | 0 B/frame estable | sin pausas recurrentes |
| Repetición tras soltar | ≤500 ms objetivo | medir en dispositivo |

La memoria se baselinará antes de fijar un techo porque Unity as a Library
retiene parte del runtime aun después de descargar escenas.

## Matriz mínima de QA

- Android gama baja, 4 GB RAM, OpenGL ES 3.
- Android gama media, ARM64, Vulkan y OpenGL ES.
- Relación 16:9, 20:9 y dispositivo con notch.
- Wi-Fi estable, red lenta, offline y cambio de red.
- Micrófono concedido, denegado, denegado permanentemente y revocado.
- Background/foreground, llamada entrante, rotación bloqueada y low-memory.
- Sesión válida, expirada, pareja desvinculada y revisión de layout obsoleta.

## Evidencia exigida

- Tests Unity EditMode y PlayMode.
- Fixtures del puente aprobados en Dart y C#.
- Tests Flutter completos y emuladores Firebase.
- Videos sin cortes de locomoción, 100 toques, cama y voz.
- Captura del Profiler y Android GPU Inspector o equivalente.
- Log de memoria de veinte entradas/salidas.
- APK/AAB firmado de pista interna y hash SHA-256.
- Checklist de permisos y privacidad actualizado.

## Rollback

- Feature flag desactiva cada escena 3D por separado.
- Flutter conserva las rutas legacy y no migra destructivamente layouts.
- Cada layout 3D tiene `schemaVersion` y `baseRevision` independiente.
- Un fallo del runtime no modifica economía ni elimina inventario.
- El contenido Addressable conserva catálogo anterior hasta confirmar la nueva
  versión.
- Flame solo se retira después de paridad, pista interna y aprobación explícita.

## Criterio de aprobación

El vertical slice se aprueba únicamente si funciona en dispositivos reales,
cumple la dirección adulta, no activa acciones en vacío, alinea correctamente
la cama, elimina el audio temporal y mantiene la autoridad de Firebase. Una
captura bonita o un test dorado no son suficientes.
