# Fase G: optimización y privacidad

## Ubicación temporal

- Solo se mantiene el último punto de cada integrante; no existe historial de recorridos.
- Modos disponibles: punto único, 15 minutos, 1 hora, 8 horas y hasta detener.
- La ubicación aproximada reduce la precisión antes de guardarse en servidor.
- La app limita actualizaciones en cliente por tiempo y distancia.
- Un latido ligero renueva la sesión cuando el teléfono permanece quieto.
- El servidor aplica un segundo límite de frecuencia y valida sesión, pareja y coordenadas.
- El servidor bloquea inicios repetidos y aplica una caducidad de seguridad de 20 minutos sin actualizaciones.
- El seguimiento funciona solo en primer plano. Android no recibe permiso de ubicación en segundo plano.
- Detener, vencer o desvincular elimina el punto compartido.
- Una tarea programada limpia sesiones temporales vencidas.
- La interfaz oculta puntos vencidos y la limpieza programada elimina sus documentos; el cliente nunca puede escribirlos directamente.
- Un indicador persistente aparece sobre la navegación mientras la sesión está activa e incluye detención inmediata.
- Si el GPS falla antes del primer punto, no se crea una sesión vacía; si falla el envío inicial, se intenta una eliminación compensatoria.

## Llamadas futuras

- Perfil inicial de video moderado: 360p y 15 FPS.
- Adaptación automática a la red y degradación a solo audio.
- Cámara apagada en segundo plano.
- Sin grabación ni almacenamiento de medios por defecto.
- Tokens cortos emitidos desde servidor; ninguna credencial sensible en la aplicación.

## Criterio de cierre

Estas decisiones reducen batería, datos móviles, escrituras de Firestore y exposición de información sensible. La comprobación de compilación, análisis estático, reglas, emuladores y dispositivos se ejecutará en la etapa final de pruebas acordada con el propietario del proyecto.

## Auditoría de recursos y memoria

- Los recursos incluidos ocupan aproximadamente 48.23 MB antes del empaquetado final.
- Varias imágenes principales tienen cerca de 1.57 millones de píxeles y pueden consumir alrededor de 6 MB cada una al decodificarse en RGBA.
- Se añadieron dimensiones de caché al tablero y dados de Ludo y a miniaturas del mundo para evitar decodificar texturas mucho mayores que su tamaño visible.
- Las hojas de sprites que usa Flame conservan su resolución porque reducirlas sin recalcular cuadros, pivotes y colisiones rompería animaciones.
- La conversión masiva a WebP queda como optimización controlada posterior: las rutas también existen en catálogos de servidor y datos persistidos, por lo que requiere migración compatible y comparación visual.
- Los streams del indicador global de ubicación se conservan entre cambios de pestaña para evitar reconexiones y lecturas repetidas.

## Referencias oficiales

- Permisos de ubicación en Android: https://developer.android.com/develop/sensors-and-location/location/permissions
- Plugin Geolocator para Flutter: https://pub.dev/packages/geolocator
