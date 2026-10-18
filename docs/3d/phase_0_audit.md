# Hito 0 — auditoría y hotfix de Pawdo 3D

Fecha: 22 de agosto de 2026, America/Lima
Repositorio: `C:\Users\Jorge\Downloads\pawdo\pawdo`

## Resultado

El motor actual es Flame con escenarios y actores 2D. No había proyecto Unity,
puente nativo ni activos 3D dentro del repositorio. Se conservaron Flutter,
Firebase, economía, tienda, layouts y contratos de backend.

La máquina sí tiene Unity `6000.3.20f1` y `6000.5.4f1`. Se selecciona
`6000.3.20f1` por pertenecer a Unity 6.3 LTS. Ninguna de las dos instalaciones
tiene todavía Android Build Support.

`flutter devices` encontró Windows, Chrome y Edge. No encontró teléfono ni
emulador Android. Por lo tanto, la reproducción, grabación y validación física
siguen abiertas. No se sustituyen con capturas doradas.

## Línea base previa al cambio

| Puerta | Resultado |
|---|---|
| `dart analyze lib test` | Sin problemas |
| Flutter | 95 pruebas aprobadas |
| Functions con emuladores | 57 pruebas aprobadas |
| Firestore Rules | 26 pruebas aprobadas |
| Storage Rules | 21 pruebas aprobadas |
| Total previo | 199 pruebas |

## Causas reproducidas por inspección

1. La fila lateral de los sprites fue dibujada mirando a la izquierda, pero el
   código la reflejaba como si mirara a la derecha.
2. Jardín e interior aceptaban como toque todo el rectángulo del PNG, incluidos
   píxeles completamente transparentes.
3. Árboles, arbustos y decoraciones florales se convertían en acción de riego
   sin tener un estado de planta interactiva.
4. Las posiciones guardadas del jardín se limitaban por el centro, no por el
   tamaño visual completo, y se restauraban sin comprobar colisiones ni zonas
   ocupadas por la interfaz.
5. La cama enviaba a los actores a offsets genéricos delante del mueble. Los
   fotogramas de sueño incluyen utilería pintada y no pueden representar a la
   pareja dentro del mismo colchón.
6. La mascota es una imagen estática en su pantalla principal; no existe aún
   rig, navegación, grabación de repetición, reconocimiento ni lip-sync.

## Hotfix aplicado

- `ActorFacingPolicy` expresa explícitamente que la hoja actual mira a la
  izquierda y corrige ambos sentidos horizontales.
- `AlphaHitMask` extrae una máscara de opacidad por activo. Si la máscara no se
  puede producir, la interacción falla de forma segura en vez de usar el
  rectángulo transparente.
- Solo `plant`, `special_plant` y `pot` pueden activar riego en el motor
  provisional.
- `GardenLayoutPolicy` exige que el objeto visual completo esté dentro del
  jardín y fuera de los controles inferior izquierdo y derecho.
- Los layouts antiguos inválidos buscan una posición válida cercana; las
  posiciones inválidas no se exportan.
- Las jardineras inferiores se desplazaron hacia dentro del área segura.
- La interacción 2D incorrecta de cama quedó desactivada. Tocar la cama muestra
  un aviso de migración 3D y no concede amor, energía ni monedas.

## Evidencia posterior

| Puerta | Resultado |
|---|---|
| `dart analyze lib test` | Sin problemas |
| Pruebas específicas del hotfix | 7 aprobadas |
| Flutter completo | 100 aprobadas |
| Functions con Firestore + Storage | 57 aprobadas |
| Firestore Rules | 26 aprobadas |
| Storage Rules | 21 aprobadas |
| Total posterior confirmado | 204 pruebas aprobadas |

La prueba horizontal verifica 100 destinos a la derecha y 100 a la izquierda.
La prueba de opacidad comprueba píxeles visibles, transparentes, casi
transparentes y coordenadas fuera del sprite. La referencia visual del jardín
se actualizó únicamente después de inspeccionar la imagen maestra, la nueva y
el diff aislado.

Se añadió además una regresión con 100 toques sobre píxeles transparentes. Su
formato, análisis y ejecución final quedaron confirmados el 23 de agosto de
2026.

## Puertas abiertas

- Conectar al menos un Android físico de gama media y uno de gama baja.
- Reproducir y grabar antes/después los cuatro errores reportados.
- Instalar Android Build Support exactamente para Unity `6000.3.20f1`.
- Crear el proyecto Unity y ejecutar pruebas EditMode/PlayMode.
- Producir activos 3D con licencia comercial registrada.
- Construir y aprobar el vertical slice definido en
  [`vertical_slice_plan.md`](vertical_slice_plan.md).

Las 204 pruebas ejecutadas del Hito 0 están verdes. La puerta física sigue
bloqueando declarar listo un APK 3D.
