# VS-2 — informe técnico verificable

Estado: salida técnica cumplida; aprobación visual explícita pendiente. VS-3
no iniciado.

Fecha de evidencia: 2026-08-23 (America/Lima).

## Resultado implementado

- Escena Unity `GardenSlice` verdaderamente 3D, sin sprites ni fondos PNG.
- Casa modular, terreno, camino, bordes florales contenidos, olivo, muebles y
  cantero editable construidos como geometría runtime con materiales URP.
- Dos avatares de proporción adulta con `NavMeshAgent`, locomoción articulada y
  orientación calculada desde la velocidad real.
- Pawdo como perro mestizo pequeño 3D con marcha y movimiento de cola.
- NavMesh runtime, obstáculos tallados, colliders y superficies semánticas.
- Raycast estricto: solo la raíz de `PlantInteractable` resuelve riego; el resto
  del terreno solo ordena movimiento.
- Lavanda con `WateringSocket` explícito. El avatar camina al socket, mira la
  planta y reproduce regadera y gotas antes de completar la acción.
- Editor local con preview verde/rojo. Solo acepta `PlanterPlot`, rechaza
  vacío, camino, obstáculos y límites, y permite cancelar sin mutación.
- Layout local JSON con `schemaVersion=1` y `baseRevision`; una colocación
  válida persiste y se restaura tras reiniciar el proceso.
- Manifiesto de cinco familias de activos con autoría, licencia, hash y GUID.
  No se usaron activos 3D de terceros.

## Alcance visual real

La captura corresponde a un vertical slice técnico original en true 3D. La
composición está ordenada, las flores permanecen en canteros y las personas,
Pawdo y la casa ocupan el mismo mundo con oclusión y sombras coherentes. Sin
embargo, los modelos son geometría procedural low-poly y materiales de color:
**no son todavía arte final casi real, fotorrealista ni de alta definición**.

Por tanto, la arquitectura e interacción pueden aprobarse ahora, pero no se
debe presentar esta apariencia como el acabado profesional definitivo pedido
para Play Store. Llegar a ese nivel requiere una pasada de producción con
modelos/rigs aprobados, animaciones de calidad y materiales PBR, manteniendo las
reglas y tests ya fijados en este hito.

## Evidencia automática final

| Control | Resultado |
|---|---|
| `dart analyze lib test` | sin hallazgos |
| Suite Flutter | 110/110 pruebas |
| Unity EditMode | 12/12, 0 fallos |
| Unity PlayMode | 2/2, 0 fallos |
| Geometría en PlayMode | más de 80 `MeshRenderer`; cero sprites requeridos |
| Superficies semánticas | 8 o más; planta y socket presentes |
| 100 raycasts físicos vacíos | ninguno resuelve `PlantInteractable` |
| Export Unity Library | éxito; 736,910,831 bytes en BuildReport |
| APK Flutter + Unity | éxito; 327,198,423 bytes |
| SHA-256 local | `A748F0E423A03387292EF890FE1A452DDF7F367DCC3AFB80B05EB6F7F42F4924` |
| SHA-256 del `base.apk` instalado | coincidencia exacta, byte por byte |
| ABI/binarios | ARM64; `libunity.so`, `libil2cpp.so`, `libmain.so`, `lib_burst_generated.so` |

Resultados preservados en `unity-vs2-editmode-results.xml` y
`unity-vs2-playmode-results.xml`. Los logs de ejecución están en
`docs/3d/evidence/vs2_unity_editmode.log`,
`docs/3d/evidence/vs2_unity_playmode.log` y
`docs/3d/evidence/vs2_unity_android_export.log`.

## Prueba física del APK exacto

Dispositivo: Samsung `SM-A315G`, serie `RF8R308G09V`, Android 12 / API 31,
ARM64, aproximadamente 4 GB de RAM y pantalla física 1080 × 2400. El APK final
se instaló y su hash se calculó directamente desde `/data/app/.../base.apk`.

| Control físico | Resultado |
|---|---|
| 100 toques sobre terreno vacío | `Vacíos 100`, `Riegos 0` |
| 100 movimientos del avatar principal | `Mov. 100`, `Giro incorrecto 0` |
| Serie horizontal alternada | 0 fallos de orientación en avatar principal y pareja |
| Toque exacto de la lavanda | 1 riego completado en su `WateringSocket` |
| Preview sobre camino | rojo; guardar deshabilitado |
| Preview dentro del cantero libre | verde; guardar habilitado |
| Cancelar preview | no modifica el layout persistido |
| Layout guardado anteriormente | restaurado después de reinstalar/reiniciar |
| Regreso a Flutter | `com.pawdo.app/.MainActivity` reanudada correctamente |
| Fallos fatales / OOM / ANR en muestra final | 0 / 0 / 0 |
| Surface de Unity en reposo/interacción | normalmente 39–40 FPS; piso de 30 cumplido |
| Memoria con runtime cargado | PSS 583,359 KiB; RSS 477,658 KiB |

La memoria incluye Flutter, Firebase, Unity y páginas compartidas o en swap;
no es todavía el techo de producción. El objetivo de 60 FPS y el perfil
CPU/GPU/temperatura prolongado siguen reservados para VS-5. Solo hay un equipo
físico conectado, por lo que la segunda gama/driver de la matriz completa queda
pendiente para VS-5.

## Incidencia encontrada y corregida

La primera automatización Android podía interpretar también un frame
`TouchPhase.Ended` como un gesto nuevo y obtuvo 110 órdenes tras 100 toques.
Se aisló la decisión en `PointerGesturePolicy`: un gesto táctil solo dispara en
`Began` y queda consumido hasta terminar. Se añadió regresión EditMode para
frames `Ended` repetidos, se reconstruyó Unity y Flutter, se reinstaló el APK y
la repetición final obtuvo exactamente 100/100 con cero riegos.

## Activación y rollback

El APK de validación se compiló con:

```text
PAWDO_UNITY_3D=true
PAWDO_UNITY_GARDEN_3D=true
PAWDO_UNITY_PET_3D=false
PAWDO_UNITY_INTERIOR_3D=false
```

Solo Jardín usa Unity en VS-2. Mascota e Interior conservan el fallback 2D
hasta sus hitos correspondientes. Apagar `PAWDO_UNITY_GARDEN_3D` devuelve la
ruta legacy sin migración destructiva ni cambios de economía/backend.

## Evidencia visual y diagnóstica

- `evidence/vs2_final_100_empty_taps_sm_a315g.png`: contador exacto 100/0 y
  orientación sin fallos.
- `evidence/vs2_final_exact_plant_watering_sm_a315g.png`: riego exacto
  completado.
- `evidence/vs2_final_placement_invalid_red_sm_a315g.png`: camino rechazado.
- `evidence/vs2_final_placement_valid_green_sm_a315g.png`: cantero aceptado.
- `evidence/vs2_final_current_sm_a315g.png`: layout persistido restaurado.
- `evidence/vs2_final_meminfo_sm_a315g.txt`: memoria del proceso.
- `evidence/vs2_final_logcat_sm_a315g.txt`: FPS del Surface y conteo de fallos.
- `evidence/vs2_apk_integrity_sm_a315g.txt`: tamaño y SHA-256 local/instalado.

## Puerta del hito

Los criterios técnicos de VS-2 están cumplidos: cero riegos en 100 vacíos,
orientación correcta en 100 desplazamientos, riego únicamente mediante planta,
colocación semántica válida/inválida y persistencia versionada. La bandera
permanece reversible.

La puerta visual sigue abierta deliberadamente. VS-3 no debe comenzar hasta
que el titular apruebe explícitamente este VS-2 o solicite antes una sustitución
del bloque procedural por arte 3D de producción.
