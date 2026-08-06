# Pawdo — reporte de optimización

Fecha de inventario inicial: 2026-08-06  
Estado: baseline; no se eliminaron ni convirtieron assets en FASE 0/1.

## Tamaños iniciales

| Elemento | Tamaño |
|---|---:|
| Carpeta `assets` | 50,571,983 bytes (48.23 MiB) |
| 65 PNG | 50,495,995 bytes |
| 3 MP3 | 75,988 bytes |
| APK release universal | 110,478,165 bytes (105.36 MiB) |
| Build previo antes de `flutter clean` | Aproximadamente 2.98 GB |

## Mayores assets

| Archivo | Bytes |
|---|---:|
| `assets/images/backgrounds/garden_basic.png` | 2,753,847 |
| `assets/images/backgrounds/room_basic.png` | 2,170,167 |
| `assets/images/garden/tree_big_love.png` | 2,090,725 |
| `assets/images/avatars/avatar_girl_pro_spritesheet.png` | 1,885,591 |
| `assets/images/ui/pawdo_brand_master.png` | 1,876,620 |
| `assets/images/avatars/avatar_boy_pro_spritesheet.png` | 1,860,414 |
| `assets/images/houses/house_basic.png` | 1,815,568 |
| `assets/images/pets/dog_pro_spritesheet.png` | 1,781,266 |
| `assets/images/interior/background_room_pastel.png` | 1,744,980 |
| `assets/images/actions/couple_sitting_table.png` | 1,653,579 |

## Duplicados y uso

- Duplicados binarios SHA-256: 0.
- Candidatos sin referencia literal desde Dart: 21 archivos, 11,658,717 bytes.
- No se deben eliminar automáticamente. Rutas de dados, fichas, sprites, casas o catálogos pueden construirse dinámicamente o persistirse en Firebase.
- Antes de eliminar: inspeccionar `asset_paths.dart`, catálogos de tienda, Flame, datos persistidos y documentos Firebase; luego probar dos dispositivos.

## Optimizaciones realizadas

- `flutter clean` retiró artefactos locales obsoletos; esto reduce disco de desarrollo, no el tamaño distribuido.
- Flutter aplicó tree-shaking a Material Icons: 1,645,184 → 17,464 bytes en el APK.
- No se convirtió PNG a WebP y no se degradó ningún asset.

## Plan controlado para FASE 20

1. Generar AAB firmado de prueba y medir descarga por ABI/dispositivo.
2. Capturar dimensiones, alpha y memoria decodificada de cada PNG.
3. Confirmar referencias estáticas, dinámicas y remotas.
4. Comparar PNG/WebP visualmente en assets no sensibles a atlas/sprites.
5. Mantener rutas compatibles o migración gradual para catálogos persistidos.
6. Perfilar RAM, GPU y jank en mundo, interior, Ludo y cambio de pestañas.
7. Registrar cada conversión/eliminación con tamaño inicial/final y rollback.

## Tamaño final

Sin cambio intencional en FASE 0/1. El tamaño final de producción queda pendiente; no debe declararse optimizado hasta completar medición AAB, QA visual y pruebas físicas.

