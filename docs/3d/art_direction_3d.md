# Pawdo 3D — biblia visual inicial

Estado: puerta de concepto para vertical slice
Estilo: realismo estilizado adulto

## Promesa visual

Pawdo debe sentirse como un espacio privado que una pareja adulta desea habitar:
cálido, cuidado, contemporáneo y emocional. La estilización simplifica formas
para móvil, pero conserva anatomía, escala, materiales y movimiento creíbles.

Proporción objetivo: 65 % realismo y 35 % estilización. No se busca
fotorrealismo ni apariencia infantil.

## Lenguaje

- Siluetas limpias, proporciones humanas naturales y cabeza de tamaño creíble.
- Detalles románticos puntuales; evitar corazones repetidos y decoración kawaii.
- Bordes suaves producidos por luz y material, no por contornos de caricatura.
- Variación natural en madera, textiles, follaje y pelaje sin ruido excesivo.
- Interfaz sobria, tipografía clara, iconografía geométrica y movimiento corto.

Paleta base:

| Uso | Color |
|---|---|
| Rosa empolvado | `#C98D9C` |
| Vino | `#633347` |
| Crema | `#F3EADF` |
| Madera clara | `#A97855` |
| Verde botánico | `#506B55` |
| Oro discreto | `#B89A62` |
| Carbón de texto | `#29252A` |

Los colores se validarán en sRGB y bajo luz día, tarde y noche. El oro nunca
debe parecer plástico amarillo.

## Avatares

- Altura visual de 7 a 7.5 cabezas.
- Anatomía realista simplificada; manos y pies con volumen suficiente para IK.
- Rostros expresivos sin ojos sobredimensionados.
- Cabello por tarjetas o mallas optimizadas, con variantes compartiendo rig.
- Ropa modular con siluetas adultas contemporáneas. No sexualizar ni infantilizar.
- Tonos de piel tratados con material compartido y parámetros, no modelos
  separados.
- Idle con respiración mínima, cambios de peso y mirada contextual.

## Pawdo

Perro mestizo pequeño de proporciones plausibles, pelaje crema y canela y una
silueta propia. Debe ser cariñoso, no un cachorro de juguete.

- Ojos expresivos de tamaño anatómico.
- Hocico capaz de abrirse para ladrido y repetición de voz.
- Orejas, cola y mandíbula riggeadas.
- Pelaje mediante mapas y geometría controlada; no fur cards densas en móvil.
- Emociones por postura, orejas, cola, parpadeo y mirada, no por emojis flotantes.

## Jardín

- Arquitectura contemporánea cálida con guiños románticos discretos.
- Caminos legibles, canteros definidos y césped con espacios de descanso visual.
- Ninguna flor suelta fuera de un cantero, maceta o zona botánica autorizada.
- Árboles como puntos focales; evitar llenar todos los bordes con vegetación.
- Muebles exteriores a escala humana y con espacio de circulación.
- Tres presets de iluminación: mañana suave, golden hour y noche cálida.

## Interior

- Habitación físicamente coherente: paredes, suelo, puertas y ventanas con
  escala consistente.
- Cama de dos plazas, sofá, mesa, TV, plantas y cama de Pawdo organizados por
  función, no como elementos flotantes.
- Materiales PBR: madera, tela, metal pintado, cerámica y hojas.
- Iluminación horneada cálida; luces dinámicas solo cuando aporten interacción.
- La cama debe comunicar intimidad adulta sin contenido explícito.

## Cámara

- Perspectiva tres cuartos con lente equivalente aproximada de 35–45 mm.
- Cámara limitada a encuadres diseñados; no atravesar paredes ni acercarse al
  interior de las mallas.
- Zoom discreto para interacción, con transición amortiguada.
- Personajes completos y puntos de interacción siempre visibles.
- UI dentro del safe area y separada del espacio editable.

## Movimiento

- Blend Trees para velocidad y dirección.
- Aceleración y frenado visibles; evitar deslizamiento de pies.
- Giro con anticipación antes de iniciar acciones.
- Interacciones alineadas por sockets e IK.
- El perro reacciona con latencia natural y nunca se teletransporta a la vista.

## Presupuesto inicial del vertical slice

| Activo | LOD0 orientativo | Textura máxima |
|---|---:|---:|
| Avatar completo | 45–65k triángulos | 2K atlas |
| Ropa individual | 8–20k | 1K–2K |
| Pawdo | 30–45k | 2K |
| Mueble principal | 8–25k | 1K–2K |
| Planta | 3–12k | 1K |

Estas cifras son techos de prototipo, no objetivos de consumo. Cada activo debe
tener LOD, mips, compresión móvil y perfil medido.

## Rechazos automáticos

- Cabezas grandes, ojos de bebé o extremidades diminutas.
- Fondos 2D usados para fingir habitaciones 3D.
- Muebles sin escala común.
- Floraciones atravesando caminos o UI.
- Texturas con logos, marcas de agua o procedencia desconocida.
- Modelos generados sin topología, rig, licencia o autoría verificable.
- Copias visuales o sonoras de My Talking Tom u otra propiedad existente.

La aprobación final se hará sobre un vertical slice ejecutándose en Android,
no sobre una ilustración conceptual aislada.
