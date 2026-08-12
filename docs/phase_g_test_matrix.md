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

## Casa — FASE 8

| Caso | Resultado esperado |
|---|---|
| Entrar desde Inicio | Abre la Casa directamente en horizontal y sin portal duplicado a Juegos/Álbum |
| Tocar cama, sofá, mesa, TV, planta, Pawdo o personajes | Ejecuta únicamente la acción coherente del objeto tocado |
| Agregar un mueble comprado | Se coloca en su zona sugerida y queda seleccionado para ajuste |
| Arrastrar muebles | Respeta límites y colisiones; aparece `Guardar *` al primer cambio |
| Intentar eliminar un mueble inicial | Informa que es esencial y conserva el objeto |
| Volver con cambios pendientes | Exige seguir editando o confirmar el descarte |
| Guardar desde dos teléfonos | La revisión evita sobrescribir silenciosamente el diseño más reciente |
| Salir de Casa | Restaura orientación vertical y mantiene Inicio disponible |
| Entrar sin pareja o sin inventario | No rompe el juego; explica el requisito en el inventario |
| Segundo plano y reanudación | No duplica recompensas ni deja controles bloqueados |

## Jardín — FASE 9

| Caso | Resultado esperado |
|---|---|
| Tocar suelo o camino vacío | Los personajes caminan; ninguno reproduce la animación de riego |
| Tocar planta, flor, maceta, arbusto o árbol | Se acercan al objeto real y riegan exactamente en esa posición |
| Tocar mesa | Ejecuta la escena de sentarse; no riega ni abre otro módulo |
| Regar por primera vez en el día | El servidor concede una sola recompensa y actualiza el conteo |
| Regar nuevamente el mismo día | Mantiene la animación local e informa que la recompensa ya fue reclamada |
| Alcanzar 3 y 6 riegos | HUD y sprite cambian a Creciendo y Floreció sin reabrir Jardín |
| Agregar, mover o eliminar decoración | Aparece `Guardar *` y se respetan casa, límites y colisiones |
| Cambiar de pestaña con cambios pendientes | Exige conservar la edición o confirmar el descarte |
| Conflicto entre dos teléfonos | No sobrescribe: solicita recargar la revisión más reciente |
| Salir de Jardín | Restaura orientación vertical y conserva Inicio |

## Personajes — FASE 10

| Caso | Resultado esperado |
|---|---|
| Abrir Personalizar personaje desde Perfil | Muestra la apariencia guardada y una vista previa completa |
| Cambiar cabello, piel, ropa, calzado y accesorio | Cada propiedad cambia de forma independiente sin reiniciar las demás |
| Cambiar expresión y pose | La vista previa se actualiza inmediatamente |
| Guardar y reabrir el editor | Todas las selecciones reaparecen sin pérdida de datos |
| Abrir Casa y Jardín después de guardar | El estilo base y la pose elegidos se aplican al personaje animado |
| Personalizar ambos integrantes desde sus teléfonos | Casa y Jardín muestran los dos perfiles compartidos en el orden de la pareja |
| Cuenta creada antes de FASE 10 | Mantiene los estilos clásicos sin error ni migración manual |
| Intentar guardar un valor fuera del catálogo | Firestore rechaza el documento y no comparte datos manipulados |
| Texto ampliado y pantalla pequeña | El editor permite desplazarse y todos los controles siguen accesibles |
| Perder red al guardar | Muestra el fallo sin cerrar el editor ni fingir que la apariencia se sincronizó |

## Mascota — FASE 11

| Caso | Resultado esperado |
|---|---|
| Tocar la imagen o Acariciar | Pawdo reacciona visualmente y ambos teléfonos reciben la felicidad actualizada |
| Alimentar | Sube hambre satisfecha, cambia la reacción y aumenta gradualmente la necesidad de baño |
| Jugar con energía suficiente | Sube felicidad y reduce energía, hambre e higiene dentro de 0–100 |
| Jugar con hambre o energía crítica | El servidor rechaza la acción y explica que debe comer o descansar |
| Dormir y luego intentar alimentar/jugar/bañar | Pawdo permanece dormido y pide despertarlo primero |
| Despertar | Cambia a despierto y habilita nuevamente los cuidados activos |
| Bañar | Sube higiene y presenta la reacción de burbujas |
| Ir al baño | Reduce la necesidad acumulada y mejora ligeramente la higiene |
| Dejar pasar varias horas | La siguiente acción aplica desgaste acotado sin valores fuera de 0–100 |
| Pulsar acciones rápidamente | Evita duplicados y el servidor aplica un enfriamiento corto |
| Escribir directamente `state/pet` desde cliente | Firestore deniega la manipulación aunque sea integrante de la pareja |
| Cuenta con documento legacy o sin documento | Usa valores seguros y crea el estado completo al primer cuidado |
| Pantalla pequeña y texto ampliado | Todo el contenido desplaza; emociones, barras y acciones siguen accesibles |
| Dos teléfonos ejecutan acciones | La transacción conserva un único estado compartido sin perder actualizaciones |

## Chat y mensajes de audio — FASE 12

| Caso | Resultado esperado |
|---|---|
| Pulsar micrófono por primera vez | Android/iOS pide permiso en contexto; no graba antes de la decisión |
| Rechazar permiso | No crea archivo ni mensaje y explica cómo habilitar el micrófono |
| Grabar entre 1 y 60 segundos | Muestra contador y permite cancelar o enviar |
| Alcanzar 60 segundos | Detiene y envía una sola vez; nunca graba en segundo plano indefinidamente |
| Cancelar grabación | Elimina el temporal y no crea objeto en Storage ni burbuja |
| Enviar audio válido | Sube AAC mono, valida servidor y aparece para ambos integrantes |
| Reproducir/pausar | Descarga con autenticación, usa caché temporal y muestra duración |
| Intentar MP3, ruta ajena, metadata falsa o más de 2 MB | Storage/Functions rechazan el archivo |
| Eliminar audio propio antes de 10 minutos | Desaparece para ambos y el servidor limpia el archivo |
| Abrir audio después de desvincular | Storage revoca acceso aunque el archivo estuviera en la ruta anterior |
| Perder red durante subida | No crea metadata huérfana; informa fallo y limpia el objeto si llegó a subirse |
| Texto, rápidos y fotos existentes | Conservan envío, reintento, paginación, leído y borrado sin regresiones |
| App en segundo plano durante grabación/reproducción | No mantiene una grabación oculta; al volver permite una acción controlada |
| Dos teléfonos físicos | Audio grabado en A se reproduce claramente en B y viceversa |

## Álbum de recuerdos — FASE 13

| Caso | Resultado esperado |
|---|---|
| Abrir Álbum desde Inicio | Muestra estado vacío o recuerdos compartidos sin mezclarlos con el chat |
| Crear con foto, descripción y fecha | Comprime, sube original/miniatura y aparece en ambos teléfonos |
| Agregar lugar y etiquetas repetidas | Lugar se conserva; etiquetas se normalizan, deduplican y limitan a 10 |
| Elegir cada categoría | Viajes, Citas, Aniversarios, Momentos especiales y Otros se muestran correctamente |
| Cambiar cuadrícula/línea de tiempo | Conserva datos y orden descendente por fecha sin nuevas descargas del original |
| Abrir detalle | Descarga original autenticado, permite zoom y muestra todos los metadatos |
| Marcar favorito en A y B | Cada integrante conserva su propio corazón sin borrar el del otro |
| Eliminar como creador | Documento desaparece y el trigger limpia original y miniatura |
| Intentar eliminar como pareja no creadora | El servidor lo rechaza sin pérdida de datos |
| Subir original >1 MB o miniatura >250 KB | Storage rechaza la variante fuera de límite |
| Alterar ruta, pareja, variante o propietario | Storage/Functions rechazan el intento |
| Desvincular pareja | Álbum e imágenes dejan de ser legibles desde ambos perfiles anteriores |
| Perder red entre original y metadata | No publica un recuerdo parcial y solicita reintento |
| Cargar 100 recuerdos | Cuadrícula usa miniaturas, desplazamiento fluido y caché acotada a la sesión |

## Calendario compartido — FASE 14

| Caso | Resultado esperado |
|---|---|
| Abrir Calendario desde Inicio | Presenta el mes actual sin pedir permisos ni mezclar datos de otras parejas |
| Crear cada categoría | Aniversario, cita, salida, viaje, cumpleaños, día especial, recuerdo, situación y recordatorio se muestran con etiqueta correcta |
| Añadir descripción, emoji y fecha/hora | Los datos aparecen iguales en ambos teléfonos y sobreviven al reinicio |
| Añadir foto | Sube JPEG optimizado de hasta 750 KB y ambos integrantes pueden abrirlo con autenticación |
| Alterar ruta, propietario, pareja o tamaño | Storage/Functions rechazan el intento sin crear el evento |
| Elegir un recordatorio | El servidor calcula la hora, notifica una sola vez a ambos y marca el evento como procesado |
| Desactivar avisos de calendario | Ese integrante deja de recibirlos sin afectar a su pareja |
| Vista Próximos | Omite eventos pasados y ordena ascendentemente los futuros |
| Vista Recuerdos | Abre el álbum compartido sin anidar barras de navegación |
| Eliminar como creador | Solicita confirmación, elimina el documento y el servidor limpia la foto |
| Eliminar como pareja no creadora | El servidor rechaza el intento y conserva evento/foto |
| Desvincular pareja | Eventos y fotos dejan de ser legibles desde los perfiles anteriores |

## Contador de relación — FASE 15

| Caso | Resultado esperado |
|---|---|
| Tocar la tarjeta de relación en Inicio | Abre Nuestra historia con la misma fecha que observa la pareja |
| Configurar fecha desde una cuenta | La otra cuenta recibe el cambio por stream y muestra el mismo contador |
| Corregir desde la segunda cuenta | Solicita confirmación y actualiza una única fuente compartida |
| Fecha 29 de febrero | En años no bisiestos, el aniversario se normaliza al 28 de febrero |
| Fecha de hoy | Muestra 0 días y anuncia el aniversario del día |
| Fecha antigua | Calcula años, meses, días calendario y total de días sin negativos |
| Fecha futura, con hora o anterior a 1900 | Functions rechaza el cambio |
| Usuario externo o pareja desvinculada | Functions rechaza el cambio por membresía |
| Cuenta antigua sin fecha común | Inicio usa temporalmente su dato personal hasta guardar la fuente canónica |

## Bienestar y ciclo — FASE 16

| Caso | Resultado esperado |
|---|---|
| Abrir por primera vez | No crea datos ni comparte nada hasta pulsar Activar |
| Seleccionar ciclo regular | Muestra una próxima fecha orientativa basada en el promedio |
| Seleccionar ciclo irregular | Muestra un rango aproximado, nunca una fecha presentada como certeza |
| Registrar último periodo, fin, intensidad y síntomas | Guarda únicamente en el historial privado de quien registra |
| Escribir una nota | Solo su propietario puede leerla; nunca aparece en wellnessShared |
| Activar compartir sin elegir campos | No publica historial, fecha ni notas |
| Consentir solo estado de ánimo | La pareja ve únicamente ese campo y un mensaje de apoyo respetuoso |
| Cambiar estado de ánimo por síntomas | Borra inmediatamente el resumen anterior hasta el próximo registro |
| Revocar consentimiento | El resumen compartido desaparece sin borrar el historial privado |
| Eliminar todos los datos | Borra configuración, registros y cualquier resumen compartido |
| Intentar lectura como pareja o escritura directa | Firestore Rules rechaza historial y mutaciones cliente |
| Revisar textos médicos | No diagnostican fertilidad, embarazo, ovulación ni atribuyen emociones al ciclo |

## Widget Android — FASE 17

| Caso | Resultado esperado |
|---|---|
| Añadir en tamaño pequeño | Muestra foto cacheada y días juntos; oculta detalles si no hay consentimiento local |
| Ampliar a tamaño mediano | Añade duración, próximo evento y botón Te extraño sin recortar texto principal |
| Reducir nuevamente | Oculta detalles/botón que no caben y conserva la información principal |
| Pulsar el cuerpo | Abre Pawdo normalmente |
| Pulsar Te extraño | Abre Pawdo, autentica y envía una sola señal mediante el chat seguro |
| Pulsar sin red | Conserva la acción pendiente y la reintenta al abrir Pawdo con conectividad |
| Recibir un nuevo evento | Actualiza caché al siguiente snapshot sin polling continuo |
| Cerrar la app | Mantiene el último estado válido sin ejecutar un servicio permanente |
| Ocultar contenido | Reemplaza foto/datos por texto genérico de privacidad |
| Cerrar sesión o desvincular | Elimina foto cacheada, acción pendiente y todo contenido personal |
| Reiniciar teléfono | Android reconstruye el widget desde caché privada y abre Pawdo correctamente |

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
