# Pawdo — reporte de optimización

Fecha de inventario inicial: 2026-08-06  
Estado: FASE 20 técnica completada; profiling físico pendiente.

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

### FASE 20

- Las cinco pestañas principales se construyen al abrirse por primera vez y luego conservan su estado. Inicio ya no crea de inmediato Chat, Mascota, Tienda y Perfil ni sus streams asociados.
- El latido de presencia pasó de 75 a 120 segundos: reduce 37.5% las escrituras periódicas y permanece dentro de la ventana de frescura visible de tres minutos. Inicio, reanudación, reconexión, cambio de sesión y salida siguen sincronizando inmediatamente.
- Se retiró `assets/images/interior/games_portal.png` (220,777 bytes), confirmado sin consumidores desde que el portal duplicado salió del flujo en FASE 8.
- Se retiraron una pantalla de login duplicada y tres archivos legacy vacíos, todos sin importaciones ni rutas activas.
- No se convirtieron spritesheets, fondos ni catálogos a WebP: requieren comparación visual y prueba física para evitar romper atlas, rutas dinámicas o documentos persistidos.

## Medición FASE 20

| Elemento | Resultado |
|---|---:|
| Assets finales | 50,351,206 bytes en 67 archivos |
| APK universal antes | 112,560,583 bytes |
| APK universal después | 112,339,592 bytes |
| Reducción APK universal | 220,991 bytes |
| AAB arm64 analizado | 72,544,764 bytes (69.2 MB reportados por Flutter) |
| Assets comprimidos dentro del AAB | 48 MB |
| APK armeabi-v7a | 71,481,306 bytes |
| APK arm64-v8a | 73,768,958 bytes |
| APK x86_64 | 75,261,986 bytes |

El análisis AAB confirma que los assets dominan el tamaño; el código Dart propio representa aproximadamente 895 KB AOT. El AAB generado es técnico y no está firmado para publicación.

## Seguimiento físico controlado

1. Medir RAM, GPU y jank en mundo, interior, Ludo y cambio de pestañas en dos teléfonos.
2. Capturar dimensiones, alpha y memoria decodificada antes de proponer conversiones adicionales.
3. Comparar PNG/WebP visualmente en recursos no sensibles a atlas o rutas persistidas.
4. Medir la descarga que Play Console calcula por dispositivo cuando exista firma de publicación.

## Tamaño final

La optimización técnica medible está completada. El tamaño definitivo de producción sigue pendiente de firma, Play Console, QA visual y profiling físico; no se debe confundir el AAB técnico con un artefacto publicable.
