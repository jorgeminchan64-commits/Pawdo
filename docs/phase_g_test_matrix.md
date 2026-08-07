# Fase G: matriz de pruebas finales

Estas pruebas están preparadas, pero no se han ejecutado porque se acordó agrupar toda la validación al final.

## Navegación e Inicio — FASE 7

| Caso | Resultado esperado |
|---|---|
| Pulsar Mascota desde Inicio | Cambia directamente a la pestaña Mascota, sin pantalla intermedia |
| Pulsar Casa desde Inicio | Abre directamente el interior compartido en horizontal |
| Pulsar Jardín desde Inicio | Abre directamente el mundo exterior identificado como Jardín Pawdo |
| Volver desde Casa o Jardín | Restaura orientación vertical y conserva la pestaña Inicio |
| Cambiar tema en Perfil | El fondo de Inicio adopta rosa, lavanda o atardecer sin perder contraste |
| Cambiar nombre visible o foto | Inicio refleja el perfil actualizado y mantiene fallback seguro |
| Cambiar hora del dispositivo | Saludo y reloj se actualizan sin reabrir Pawdo |
| Fecha de relación configurada | Muestra duración de calendario y días para el próximo aniversario |
| Fecha ausente o futura | Muestra una invitación segura para corregirla en Perfil |
| Pantalla pequeña y texto ampliado | No hay overflow en cabecera, tarjeta de relación, métricas ni accesos |

## Dos teléfonos reales

| Caso | Teléfono A | Teléfono B | Resultado esperado |
|---|---|---|---|
| Punto aproximado | Comparte un punto | Observa y abre el mapa | Solo aparece el punto redondeado; A puede eliminarlo |
| Punto preciso | Comparte con máxima precisión | Observa exactitud y antigüedad | La exactitud refleja lo entregado por Android |
| 15 min, 1 h y 8 h | Inicia cada modo | Mantiene la pantalla abierta | Duración correcta y sin historial |
| Hasta detener | Inicia y permanece en primer plano | Observa cambios | Sigue activa con latido; nunca usa permiso de segundo plano |
| Indicador global | Cambia entre todas las pestañas | N/A | El indicador y el botón Detener siguen visibles |
| Detención inmediata | Pulsa Detener | Observa el stream | El documento desaparece y deja de verse |
| GPS apagado | Intenta iniciar | N/A | Explicación clara y acceso solo a ajustes de ubicación |
| Permiso rechazado | Rechaza una vez | N/A | No crea sesión y permite volver a intentar |
| Permiso bloqueado | Rechaza permanentemente | N/A | Abre solo los ajustes de Pawdo |
| Segundo plano | Envía Pawdo al fondo | Observa la antigüedad | No hay actualizaciones ocultas; vence por seguridad sin latidos |
| Reinicio | Cierra y abre Pawdo con sesión vigente | Observa | Recupera la sesión sin volver a pedir permiso |
| Sin red inicial | Inicia y pierde conexión | N/A | No deja documento vacío o intenta compensarlo |
| Red perdida durante uso | Pierde y recupera red | Observa | Reintenta con el siguiente movimiento/latido, sin bucle agresivo |
| Cierre de sesión | Cierra sesión | Observa | El punto se elimina antes de salir |
| Desvinculación | Desvincula la pareja | Observa | Se eliminan las ubicaciones de ambos integrantes |
| Inicio repetido | Pulsa iniciar repetidamente | N/A | El servidor aplica límite y no crea sesiones paralelas |

## Prueba técnica de audio y video

| Caso | Resultado esperado |
|---|---|
| Abrir pantalla por primera vez | No solicita permisos automáticamente |
| Rechazar cámara y micrófono | Muestra ambos permisos como no concedidos |
| Probar sin permiso | No activa hardware y explica qué permiso falta |
| Prueba de micrófono | Indicador Android visible aproximadamente un segundo; nivel local; ningún archivo creado |
| Prueba de cámara | Indicador Android visible brevemente; abre y cierra; ninguna foto o video creado |
| Probar en modo avión | Ambas pruebas locales funcionan sin Internet |
| Hardware ocupado | Muestra error controlado y permite reintentar |
| Rotar o salir durante la prueba | No deja el hardware activo |
| Revisar tráfico y almacenamiento | No hay subida de medios ni archivo nuevo |

## Rendimiento

- Medir memoria al abrir mundo, interior, Ludo, tienda y cambiar repetidamente entre pestañas.
- Verificar que las miniaturas y el tablero usan caché redimensionada sin perder nitidez visible.
- Medir consumo de batería con ubicación aproximada y precisa durante 15 minutos.
- Confirmar como máximo un envío cada 20 segundos en servidor y un latido cada 5 minutos en reposo.
- Revisar tamaño del APK y recursos duplicados antes de una migración a WebP.
