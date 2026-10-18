# Pawdo 3D — inventario y puerta de licencias

Actualizado el 2026-10-11: siete familias 3D procedurales originales y dos
familias de materiales escaneados de Poly Haven (CC0). Los personajes siguen
siendo modelos técnicos; aún falta sustituirlos por arte de producción.

Los mapas de madera y lino se descargaron de la API/CDN oficial. Autoría,
licencia, GUID y SHA-256 están registrados en `asset_manifest.json`, y su
procedencia en `Assets/Pawdo/Resources/Surfaces/SOURCES.md`. Se conservan como
recursos del proyecto; no son caché. Las secciones VS-2/VS-3 de abajo son el
registro histórico de agosto.

## Activos actuales

| Grupo | Ubicación | Formato | Uso durante migración | Estado 3D |
|---|---|---|---|---|
| Avatares y capas | `assets/images/avatars/` | PNG spritesheet | Fallback 2D | No reutilizable como modelo |
| Pawdo | `assets/images/pets/` | PNG spritesheet/imagen | Fallback 2D | Referencia de color solamente |
| Jardín | `assets/images/garden/` | PNG | Fallback y referencia | No reutilizable como geometría |
| Casa | `assets/images/houses/` | PNG | Fallback y referencia | No reutilizable como geometría |
| Interior | `assets/images/interior/` | PNG | Fallback y referencia | No reutilizable como geometría |
| Muebles | `assets/images/furniture/` | PNG | Fallback | No reutilizable como geometría |
| Audio actual | `assets/audio/` | Audio raster | Revisar caso por caso | Sin voz Pawdo 3D aprobada |
| Concepto 2.5D | `docs/art/` | PNG generado | Historial, no objetivo final | No es activo de producción 3D |
| VS-2 procedural | `unity/Pawdo3D/Assets/Pawdo/Core/Garden/` | Geometría 3D runtime + URP | Vertical slice técnico | Registrado; revisión visual pendiente |
| VS-3 interior | `unity/Pawdo3D/Assets/Pawdo/Core/Interior/` | Geometría 3D runtime + URP | Interior y camas técnicas | Registrado; revisión visual pendiente |

El registro anterior de dirección visual documenta generación interna de una
imagen conceptual, pero el repositorio no posee todavía un manifiesto uniforme
de autoría/licencia para cada raster histórico. Por ello ningún PNG se declara
automáticamente apto para derivar o entrenar activos 3D comerciales.

## Manifiesto obligatorio para cada activo nuevo

Cada modelo, textura, material, rig, animación y sonido deberá registrar:

```text
assetId
displayName
kind
sourceFile
sourceUrl (si aplica)
authorOrVendor
acquiredAt
licenseId
licenseDocument
commercialUseAllowed
modificationAllowed
redistributionInCompiledAppAllowed
aiGeneratedOrAssisted
trainingOrReferenceInputs
attributionRequired
thirdPartyMarks
reviewedBy
sha256
unityGuid
lods
textureBudget
notes
```

El manifiesto versionado se guardará como
`unity/Pawdo3D/Assets/Pawdo/AssetManifest/asset_manifest.json`. Los comprobantes
privados de compra no se versionarán; se custodiarán fuera del repositorio y el
manifiesto conservará su identificador.

## Activos mínimos del vertical slice

- Dos bases humanas compatibles con un mismo humanoid rig.
- Dos peinados, dos tonos de piel y una prenda intercambiable por avatar.
- Pawdo con rig facial y corporal.
- Una habitación modular.
- Cama con dos `SleepSocket` y puntos de entrada.
- Cama de Pawdo.
- Jardín pequeño con terreno, camino, cantero y límites.
- Una planta con `PlantInteractable` y `WateringSocket`.
- Regadera, partículas de agua y animación compatible.
- Materiales PBR, iluminación y probes.
- Animaciones de locomoción, giro, riego, acostarse/levantarse y reacción de voz.
- Sonidos originales de ambiente, pasos, Pawdo y UI.

## Reglas de adquisición

1. No comprar activos sin aprobación específica del propietario.
2. No usar descargas “gratis” sin texto de licencia verificable.
3. No usar modelos extraídos de juegos, videos o repositorios de terceros.
4. No usar logos, voces ni personajes confundibles con otra marca.
5. Todo activo asistido por IA debe conservar prompt, entradas y herramienta.
6. Un activo sin manifiesto no entra en Addressables ni en un build distribuible.
7. Antes de publicar, ejecutar una revisión humana completa de atribuciones.

## Estado de la puerta

| Puerta | Estado |
|---|---|
| Inventario legacy | Registrado por familias |
| Plantilla de manifiesto | Definida |
| Manifiesto VS-3 | 7/7 familias registradas en `asset_manifest.json` |
| Autoría/licencia VS-2/VS-3 procedural | Original Pawdo, uso comercial permitido, sin terceros |
| Modelos 3D de producción final | Pendiente de selección/aprobación |
| Licencias comerciales de terceros | No aplican hasta VS-3; pendientes si se adquieren modelos finales |
| Sonido/voz original | Pendiente |
| Validación funcional VS-3 en dispositivo | Aprobada: 25/25 ciclos limpios |
| Aprobación visual de producción | Pendiente |

## Registro VS-2

El manifiesto versionado registra dos avatares adultos procedurales, Pawdo 3D,
el entorno de jardín/casa y la lavanda interactiva. Todo fue creado como
geometría runtime original para Pawdo, con asistencia de Codex, sin modelos,
texturas, rigs, animaciones ni sonidos de terceros. El hash del fuente visual
canónico y el GUID de Unity están consignados por activo.

Esta autorización legal no equivale a aprobación artística. Los activos VS-2
son un bloque funcional móvil con materiales de color y textura cero; antes de
considerarlos arte de producción deberán sustituirse o refinarse con mallas,
rigs, animación y materiales PBR aprobados expresamente por el titular.

## Registro VS-3

El manifiesto añade el interior modular y el conjunto de cama doble con dos
`SleepSocket` más la cama exclusiva de Pawdo. Son geometría y semántica
originales, sin dependencias de modelos, texturas, animaciones o sonidos de
terceros. La validación física acredita su funcionamiento, no su calidad como
arte final para tienda.
