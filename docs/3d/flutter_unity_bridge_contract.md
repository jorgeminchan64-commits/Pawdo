# Pawdo 3D — contrato Flutter–Unity v1

Estado: contrato v1 implementado en Flutter, Android y Unity

## Regla de autoridad

Unity presenta el mundo y solicita acciones. Flutter autentica, obtiene datos,
solicita permisos y llama al backend. Cloud Functions conserva la autoridad
sobre economía, mascota, inventario y layouts.

Unity no recibe refresh tokens, credenciales administrativas ni capacidad para
escribir monedas. El identificador `uid` se usa solo como contexto visual y no
como prueba de autenticación.

## Envelope

Todo mensaje usa JSON UTF-8 con límite de tamaño y esquema versionado:

```json
{
  "schemaVersion": 1,
  "messageId": "uuid",
  "correlationId": "uuid-or-null",
  "type": "scene.load",
  "sentAtEpochMs": 0,
  "payload": {}
}
```

Requisitos:

- `messageId` único para deduplicación.
- `correlationId` obligatorio en respuestas.
- Rechazar versiones y tipos desconocidos con error tipado.
- Máximo inicial: 64 KiB por mensaje; los binarios nunca viajan como Base64.
- Timeouts explícitos y una sola respuesta final por solicitud.
- Ningún mensaje se interpreta dinámicamente como nombre de método.

## Flutter → Unity

| Tipo | Contenido |
|---|---|
| `runtime.initialize` | versión app, locale, safe area, calidad objetivo |
| `session.context` | uid, coupleId, miembros y capacidades no sensibles |
| `scene.load` | `pet`, `garden` o `interior`; revisión de layout |
| `scene.pause` | razón y timestamp |
| `scene.resume` | estado de app y revisión canónica |
| `scene.unload` | cierre solicitado |
| `avatar.appearance` | configuración validada de ambos avatares |
| `pet.snapshot` | hambre, felicidad, energía, higiene, baño y revisión |
| `inventory.snapshot` | IDs poseídos/equipados y revisión |
| `layout.snapshot` | layout canónico ya validado por backend |
| `interaction.result` | resultado autorizado o error de Cloud Function |
| `voice.permission` | concedido, denegado o restringido |
| `voice.level` | señal RMS/pico normalizada para animación local; nunca contiene audio |
| `voice.playback` | inicio/fin de reproducción local para movimiento labial |

## Unity → Flutter

| Tipo | Contenido |
|---|---|
| `runtime.ready` | versión Unity, escena y capacidades |
| `runtime.error` | código, severidad y contexto no sensible |
| `scene.ready` | revisión renderizada y métricas de arranque |
| `interaction.request` | acción, target, precondición y `clientActionId` |
| `layout.save.request` | revisión base y transforms válidos |
| `voice.start.request` | gesto explícito del usuario |
| `voice.stop.request` | finalización explícita/VAD |
| `navigation.exit` | regreso solicitado por el usuario |
| `telemetry.sample` | FPS, memoria, temperatura y escena; sin PII |

## Flujo económico

```text
Toque válido en Unity
  → interaction.request(clientActionId, targetId, action)
  → Flutter valida sesión y llama Cloud Function
  → servidor comprueba pareja, estado, límite e idempotencia
  → interaction.result(correlationId, canonicalState, reward)
  → Unity anima el resultado confirmado
```

No se muestra una recompensa definitiva antes de recibir la respuesta. Si el
backend rechaza o expira, Unity revierte el estado visual y presenta un mensaje
localizable.

## Layout

El formato 3D usará metros y rotaciones normalizadas:

```json
{
  "layoutSchemaVersion": 1,
  "scene": "garden",
  "baseRevision": 12,
  "items": [
    {
      "instanceId": "plant-1",
      "catalogItemId": "plant_lavender_01",
      "position": {"x": 1.2, "y": 0.0, "z": -2.1},
      "rotationYDegrees": 90,
      "variantId": "default"
    }
  ]
}
```

Unity valida colliders y zonas antes de emitir. Flutter/servidor vuelve a
validar propiedad, catálogo, límites, solapamiento, revisión y tamaño. Un layout
legacy se migra en copia y no reemplaza al canónico hasta pasar validación.

## Voz y privacidad

- Flutter solicita `RECORD_AUDIO` justo después de una pulsación visible.
- Repetición: buffer temporal local, sin Storage ni Firebase.
- Unity recibe niveles de amplitud o frames procesados necesarios para lip-sync,
  nunca credenciales.
- El archivo temporal se elimina tras reproducción, cancelación, background,
  cierre de sesión o error.
- Reconocimiento de comandos es una capacidad separada. Se prioriza el servicio
  on-device y se informa antes de cualquier fallback remoto.
- No hay escucha continua ni servicio de micrófono en segundo plano.

## Fallos y rollback

Si Unity no emite `runtime.ready` dentro del timeout, repite un `messageId`,
devuelve un esquema inválido o pierde el canal, Flutter descarga/pausa el
runtime y abre el fallback legacy. Las solicitudes sin respuesta no generan
recompensas ni cambios persistidos.

## Pruebas obligatorias

- Serialización Dart y C# con los mismos fixtures.
- Versiones desconocidas y campos faltantes.
- Duplicados y respuestas fuera de orden.
- Timeout, background y destrucción de Activity.
- Acción económica idempotente.
- Layout obsoleto/conflictivo.
- Audio cancelado y limpieza de archivo.
- Cero tokens o secretos en logs y mensajes.
