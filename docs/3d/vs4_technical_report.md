# Pawdo 3D — informe técnico VS-4

Fecha de actualización: 2026-08-30  
Estado: **implementación técnica validada; no aprobada todavía como paquete final de Play Store**

## Resultado alcanzado

VS-4 incorpora la ruta local de voz, una reacción de voz en el Pawdo 3D y el
puente idempotente de interacciones con el backend. El audio de la repetición
no se sube, no usa Firebase Storage ni servicios de transcripción, y se elimina
del caché privado al completar, cancelar, fallar o dejar la aplicación en
segundo plano.

Unity recibe solamente señales efímeras y normalizadas (`active`, RMS y pico)
para animar mandíbula, cabeza y orejas. No recibe la grabación ni datos de voz.
Las recompensas, monedas e inventario siguen siendo exclusivamente del servidor.

## Entregado

- Grabación local PCM mono a 22.05 kHz, máximo diez segundos y detección VAD.
- Permiso de micrófono solicitado únicamente al mantener presionado el control.
- Reproducción local con ajuste ligero de velocidad y tono; no se declara
  conversión de voz, clonación ni reconocimiento de comandos.
- Borrado comprobable de WAV temporal, incluidos restos de sesiones anteriores.
- Cancelación segura al cambiar de pantalla, ir a segundo plano o destruir la
  actividad; ninguna devolución de llamada queda pendiente.
- `PawdoVoiceReactionController` para Pawdo 3D, con pruebas deterministas de
  apertura de mandíbula y retorno a reposo.
- Mensajes `voice.level` y `voice.playback` versionados, con límite de 64 KiB.
- Interacciones 3D con `operationId` único: el mismo ID devuelve el resultado
  original, un ID reutilizado para otra acción se rechaza y no puede acreditarse
  dos veces.

## Verificación ejecutada

| Área | Resultado |
|---|---:|
| Análisis Dart | sin incidencias |
| Flutter completo | 125/125 |
| Flutter específico de voz, bridge y economía | 15/15 |
| Unity EditMode | 21/21 |
| Unity PlayMode | 5/5 |
| Firebase Emulator (seguridad y economía) | 59/59 |
| Compilación Kotlin Android | correcta |
| Samsung SM-A315G, Flutter | abre y permanece activo |
| Samsung SM-A315G, jardín e interior Unity | ambas escenas cargan |

Las capturas físicas de esta validación están en `evidence/` con el prefijo
`pawdo_vs4_`.

## Privacidad y autoridad

- El audio temporal vive solo en `cacheDir`; no contiene URL, subida, HTTP,
  Cloud Storage ni Firebase.
- Después de la prueba local, `run-as com.pawdo.app ls cache` no mostró archivos
  `pawdo_voice_repeat_`.
- Unity no puede otorgar valores de recompensa: Flutter valida la petición y
  Cloud Functions escribe el estado canónico y el ledger.
- Las pruebas de servidor cubren replay exacto, ID vinculado a una acción y
  rechazo de IDs malformados.

## Límite explícito antes de la entrega final

El mundo Unity actual es un vertical slice 3D funcional de baja complejidad,
no el arte adulto final solicitado. La reacción de voz ya existe en Unity y el
contrato está preparado, pero la experiencia de voz expuesta al usuario sigue
en la pantalla Flutter de mascota mientras se completa el control nativo dentro
del mundo 3D.

La exportación de producción ARM64/IL2CPP está configurada y se restaura al
terminar cada QA. El equipo tiene una política de Control de aplicaciones que
bloquea `Bee.Toolchain.Android.dll` de Unity durante esa exportación. Por ello,
la validación física usó una exportación temporal ARMv7/Mono de depuración. No
es un artefacto apto para Play Store. La salida final requiere autorizar esa DLL
oficial de Unity o reinstalar Unity Android Build Support en una ubicación
permitida, y después generar un AAB ARM64 firmado.
