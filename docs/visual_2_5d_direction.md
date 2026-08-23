# Pawdo — dirección visual 2.5D de producción

## Resultado buscado

Pawdo usa una estética 2.5D romántica y cálida: escenarios pintados con
perspectiva tres cuartos, personajes animados por sprites y capas de
personalización, profundidad por la base de cada objeto, sombras de contacto y
movimiento ambiental discreto. No requiere modelos 3D pesados y mantiene un
rendimiento apropiado para Android.

La referencia visual aprobada está en
[`docs/art/pawdo_2_5d_art_direction.png`](art/pawdo_2_5d_art_direction.png).

## Lenguaje visual

- Perspectiva: tres cuartos coherente en jardín, casa, muebles, plantas y
  personajes.
- Paleta: rosa empolvado, ciruela, crema, madera cálida y verdes naturales.
- Luz: principal cálida desde arriba a la izquierda; sombras suaves y cortas.
- Materiales: textura pintada, volumen por gradientes y oclusión ambiental,
  contornos controlados y siluetas fáciles de leer.
- Interfaz: los controles permanecen nítidos y planos sobre el mundo 2.5D; el
  arte no contiene texto ni controles incrustados.

## Sistema de personajes

El personaje final usa el mismo renderer en el editor, el jardín y el interior.
Cada spritesheet conserva sus nueve filas de animación y cuatro fotogramas. Las
capas de cabello, piel, ropa y calzado se derivan de los sprites originales y
retienen sus luces, pliegues y sombras.

Opciones persistidas:

- base A o B;
- estilo y color de cabello;
- tono de piel;
- estilo y color de ropa;
- zapatillas o botas;
- accesorio;
- expresión;
- pose inicial.

Las máscaras reproducibles viven en `assets/images/avatars/layers/` y se
regeneran mediante `tool/generate_avatar_layer_masks.ps1`.

## Jardín y exterior

- La casa, árboles, flores, macetas, muebles y personajes se ordenan por la
  coordenada de sus pies o base.
- Todos los objetos verticales reciben una sombra de contacto proporcional a
  su tipo.
- La casa incorpora una sombra amplia y suave que la asienta sobre el césped.
- Plantas y flores tienen una microanimación independiente, suficientemente
  leve para no alterar su posición guardada.
- La edición eleva cinco píxeles el objeto y muestra un marco fino con
  manejadores; fuera del modo edición no se dibuja ningún control.
- Una capa ambiental compartida añade luz cálida, viñeta muy suave y motas
  deterministas.

## Interior

El interior comparte iluminación, profundidad, sombras, microanimación de
plantas y selección elevada. Las alfombras permanecen en la capa del piso;
cama, sofá, mesa, TV, lámpara, planta y cama de Pawdo usan su propia huella de
sombra. Los avatares y Pawdo pasan correctamente por delante o detrás según su
base.

## Rendimiento y estabilidad

- Las capas del avatar son PNG del mismo atlas y no multiplican componentes
  animados.
- La atmósfera usa dos shaders reutilizados y once partículas deterministas.
- La profundidad se calcula con enteros estables y desempate por identificador.
- La primera caminata autónoma de Pawdo espera 4.5 segundos para mantener una
  entrada clara y una captura inicial determinista.
- Los goldens se guardan en `test/goldens/` y protegen el avatar, jardín e
  interior contra regresiones visuales.

## Validación

```text
flutter test test/avatar_layer_assets_test.dart
flutter test test/avatar_renderer_visual_test.dart
flutter test test/world_scene_2_5d_visual_test.dart
flutter test
dart analyze
```

Las referencias visuales son de 800×500 para combinaciones de avatar y
1600×900 para jardín e interior.

## Registro de generación de la dirección artística

Modo: herramienta integrada de generación de imágenes, creación de un concepto
nuevo a partir de referencias visuales del proyecto.

Prompt final resumido:

> Professional mobile game 2.5D art-direction board for Pawdo, four coherent
> vignettes: romantic garden, house exterior, furnished interior and two
> distinct customizable couple avatars. Premium painted 2.5D, controlled
> outlines, readable silhouettes, ambient occlusion, consistent three-quarter
> perspective, blush/plum/cream/wood/green palette and warm upper-left light.
> No UI, text, logo, watermark or checkerboard.

La imagen generada se copió al repositorio para que la dirección visual no
dependa de una carpeta temporal.
