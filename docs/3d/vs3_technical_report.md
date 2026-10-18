# Pawdo 3D — informe técnico VS-3

Fecha de cierre técnico: 2026-08-29  
Estado: **aprobado técnicamente en Android físico; arte 3D de producción aún pendiente**

## Resultado

El interior funciona como una única escena 3D con escala coherente, navegación,
una cama doble con exactamente dos `SleepSocket`, entradas y salidas
independientes, y una cama exclusiva para Pawdo. Los avatares caminan hasta la
cama, estabilizan la pose, se acuestan sobre el colchón, permanecen, se levantan
y abandonan el mueble sin crear objetos nuevos.

La validación no se limita a la reserva lógica: cada ciclo comprueba que los
límites renderizados de ambos cuerpos permanezcan dentro de la superficie útil
de la cama y por encima del colchón.

## Correcciones realizadas durante QA físico

- Se corrigió el origen local de los contenedores visuales de los dos avatares
  y de Pawdo. Antes conservaban el origen global y desplazaban el cuerpo lejos
  del anclaje lógico.
- Las dos plazas se centraron y elevaron sobre el edredón.
- Brazos y piernas se estabilizan en una pose neutra al terminar la caminata;
  ya no heredan un fotograma aleatorio de locomoción.
- Se añadió el contador independiente `support`, además de teletransporte,
  colisión y duplicados.
- La velocidad del ensayo físico se fijó en 2×. A 5× y 3× el dispositivo podía
  perder cuadros y producir saltos reales; no se relajó el detector para
  ocultarlos.
- El `Intent` inicial de Unity se reenvía también en `onCreate`, por lo que una
  apertura nueva carga la escena solicitada y no depende de `onNewIntent`.
- El acceso ADB de QA está condicionado a que la aplicación sea depurable; no
  se habilita en una compilación release.

## Verificación automatizada

| Suite | Resultado |
|---|---:|
| Unity EditMode | 18/18 |
| Unity PlayMode | 5/5 |
| Ciclos PlayMode | 25/25 limpios |
| Flutter | 110/110 |
| Análisis Dart | sin incidencias |

Resultado final PlayMode:

```text
PAWDO_VS3_QA_COMPLETE cycles=25 teleports=0 collisions=0 duplicates=0 support=0
```

## Verificación en dispositivo

- Dispositivo: Samsung `SM-A315G`, Android 12/API 31, ARM64.
- Escena: `InteriorSlice`, Unity as a Library, orientación horizontal.
- Resultado: 25/25 ciclos físicos limpios.
- Cama de pareja: dos ocupantes distintos y soporte geométrico válido.
- Cama de Pawdo: socket tipado exclusivo para mascota.
- Errores fatales, abortos de pareja y fallos de soporte: 0.
- APK debug integrado: 407,180,475 bytes.
- SHA-256 local e instalado:
  `50CDF35C1AD8B98A9FCED59479BE86685F714AFDF430D6631555F5EE15BB25F4`.
- Coincidencia del APK instalado: sí.
- Memoria al final del ensayo: PSS 498,439 KB; RSS 267,166 KB. El dato es una
  línea base de debug, no un presupuesto de release.

## Evidencia

- `evidence/vs3_pair_sleeping_sm_a315g.png`
- `evidence/vs3_pawdo_own_bed_sm_a315g.png`
- `evidence/vs3_qa25_final_sm_a315g.png`
- `evidence/vs3_final_logcat_sm_a315g.txt`
- `evidence/vs3_final_meminfo_sm_a315g.txt`
- `evidence/vs3_unity_playmode.log`
- `evidence/vs3_unity_editmode.log`
- `evidence/vs3_unity_android_export.log`
- `evidence/vs3_apk_integrity_sm_a315g.txt`

## Límite explícito

VS-3 demuestra comportamiento, arquitectura y estabilidad. La escena actual es
un bloque 3D procedural de baja complejidad y **no representa todavía el acabado
visual profesional final**. Tampoco se declara rendimiento final: falta build
release, perfilado de la superficie Unity y un segundo Android de gama baja.

