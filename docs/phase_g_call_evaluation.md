# Fase G: evaluación profesional de audio y video

## Decisión recomendada

Para el MVP de Pawdo se recomienda **LiveKit Cloud** como capa administrada de WebRTC. Reduce el riesgo operativo inicial porque el proveedor gestiona conectividad, TURN, despliegue global y escalado, mientras Pawdo conserva el control de identidad, autorización y experiencia de usuario.

Esta fase no activa llamadas reales. Integrar el proveedor requiere una decisión expresa del propietario del proyecto porque supone crear una cuenta externa, aceptar costos variables y custodiar credenciales.

## Comparación para el MVP

| Criterio | WebRTC operado por Pawdo | Proveedor administrado compatible |
|---|---|---|
| Complejidad | Muy alta: señalización, SFU, TURN, despliegue, escalado y observabilidad | Media: SDK cliente, autenticación segura y experiencia de llamada |
| Costo inicial | Infraestructura e ingeniería propias, incluso con poco uso | Menor operación inicial; consumo variable según minutos y transferencia |
| Privacidad | Control máximo, pero también toda la responsabilidad de configuración y registros | Requiere revisar contrato, región, retención y tratamiento del proveedor |
| TURN y redes móviles | Debe desplegarse, protegerse y dimensionarse | Administrado y distribuido por el proveedor |
| Calidad y reconexión | Requiere desarrollo, telemetría y ajuste continuos | Capacidades maduras disponibles en SDK e infraestructura |
| Consumo de datos | Totalmente configurable, con riesgo de una configuración deficiente | Capas y adaptación disponibles; Pawdo debe fijar un perfil conservador |
| Riesgo para el MVP | Alto | Moderado y controlable con topes de consumo |

La recomendación es administrado para el MVP y conservar una arquitectura portable para no acoplar la lógica de pareja al proveedor.

## Arquitectura propuesta

1. La persona inicia una llamada desde una pareja activa.
2. Una Cloud Function valida autenticación y pertenencia a la pareja.
3. La función crea un identificador de sala efímero y emite un token de acceso de corta duración solo para esa persona.
4. Cada integrante se conecta directamente a la infraestructura WebRTC del proveedor.
5. Firestore guarda como máximo estado efímero de invitación y finalización; nunca audio ni video.
6. No se habilita grabación, transcripción ni exportación por defecto.

## Controles obligatorios antes de integrar

- Sala privada y efímera por pareja y llamada; no usar nombres predecibles como único control de acceso.
- Tokens firmados exclusivamente en servidor, con identidad, sala y vencimiento limitados.
- Revalidar que ambos usuarios continúan vinculados al emitir cada token.
- Solicitar cámara y micrófono desde una acción clara del usuario.
- Mostrar indicadores permanentes de micrófono, cámara, conexión y finalización.
- Apagar la cámara al entrar en segundo plano y cerrar pistas al finalizar.
- No incluir secretos del proveedor en Flutter, repositorio, Remote Config ni Firestore.
- Aplicar límites por usuario y pareja para evitar abuso y costos inesperados.
- Definir alertas de consumo antes de habilitar producción.

## Perfil de ahorro de datos

- Video inicial de 360p y 15 FPS.
- Publicación por capas y suscripción adaptativa según tamaño visible.
- Pausar video remoto cuando no esté visible.
- Cambiar automáticamente a audio si la red se degrada.
- Permitir comenzar y continuar en modo solo audio.
- Evitar reconexiones agresivas; usar retroceso progresivo y estado visible.

## Costos y operación

LiveKit Cloud mide el uso principalmente por minutos de participante y transferencia. Los valores, cuotas y límites pueden cambiar, por lo que deben revisarse en el momento de contratar y antes de publicar. Para una etapa posterior sigue disponible la alternativa de desplegar el servidor LiveKit abierto, pero eso traslada al equipo la operación, TURN, observabilidad, actualizaciones y escalado.

## Evidencia oficial consultada

- LiveKit Cloud: https://docs.livekit.io/intro/cloud/
- Facturación y medición: https://docs.livekit.io/deploy/admin/billing/
- Cuotas y límites: https://docs.livekit.io/deploy/admin/quotas-and-limits/
- Dynacast en Flutter: https://docs.livekit.io/reference/client-sdk-flutter/livekit_client/RoomOptions/dynacast.html

## Estado de esta fase

La app incluye una pantalla local de preparación que comprueba disponibilidad de hardware y estado de permisos. Solo solicita permisos cuando la persona pulsa el botón correspondiente.

Además incluye dos pruebas aisladas y expresas:

- Micrófono: procesa aproximadamente un segundo de nivel sonoro en memoria, sin crear archivo ni enviar muestras.
- Cámara: abre y cierra el dispositivo para verificar acceso, sin tomar fotografía ni crear video.

Android mostrará sus indicadores de privacidad durante esas pruebas. No se establece ninguna llamada ni conexión con un proveedor externo.

## Condiciones para pasar a integración real

- Aprobación del proveedor, región y presupuesto mensual.
- Proyecto externo creado y secretos almacenados mediante Secret Manager.
- Límites de consumo y alertas configurados.
- Política de privacidad actualizada antes de producción.
- Prueba en dos teléfonos con Wi-Fi, datos móviles, red lenta, cambio de red y segundo plano.
- Verificación de llamada rechazada, no contestada, reconexión y cierre de pistas.
