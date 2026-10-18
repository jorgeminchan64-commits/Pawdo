# Pawdo — punto de reanudación

Actualizado: 18 de octubre de 2026 (America/Lima).

## Pausa solicitada por uso

Jorge pidió pausar antes de agotar el uso disponible. Última consulta antes
de guardar: 84 % consumido en la ventana de cinco horas, 30 % en la semanal.
Consultar de nuevo al retomar; estos porcentajes no son un saldo de créditos.
No iniciar trabajo nuevo al acercarse al 90 % de cualquiera de los límites.

## Verificado hoy

- Corregido el rechazo de la voz al soltar el botón después del límite de
  diez segundos: acepta el búfer terminado aunque el micrófono haya parado.
  Impide encolar otra reproducción mientras se procesa/reproduce la anterior.
- Pruebas Android: 3/3, cero errores y cero omitidas. Antes de la corrección
  fallaban dos. Evidencia: `evidence/local-voice-current-results.xml`.
- Pruebas Flutter completas: 128/128. Registro: `../../flutter-current-tests.log`.
- Análisis Flutter: sin incidencias. Registro: `../../flutter-current-analyze.log`.
- ADB no detectó ningún teléfono; no se instaló ni validó esta compilación
  en hardware durante este bloque.

## Integración anterior conservada

- Export Unity del 17 de octubre: IL2CPP ARM64 generado correctamente en
  `unity-export/android`; todavía necesita compilar el binario IL2CPP con Gradle.
- Jardín e interior anunciados por el puente; la escena independiente de mascota
  permanece desactivada y conserva la pantalla Flutter. No enviar `pet` a Bootstrap.
- Materiales corregidos y captura real del interior:
  `evidence/interior-materials-current.png`. Se desactivó SRP Batcher tras
  reproducir mezcla de materiales con la configuración actual de Unity.
- Unity: 25 pruebas EditMode del 11 de octubre y 7 PlayMode del 13 de octubre
  aprobadas. Son resultados anteriores, no una ejecución nueva de hoy.

## Lo que sigue, sin repetir el trabajo ya verificado

1. Cerrar el hallazgo de revisión en `LocalVoiceController.kt`: los errores
   diferidos de `stopAndPlay` no comprueban `operationSession` antes de consumir
   el callback global. Intercalado: error de A pendiente; cancelar A; iniciar B
   y pedir reproducción; entregar error de A. Puede resolver/borrar el callback
   de B. Añadir regresión determinista y proteger los callbacks por generación.
   Revisar también el `cleanupPlayerAndFile()` del bloque obsoleto de `play()`
   y sus listeners para que ninguna sesión antigua afecte a la nueva.
   El hallazgo fue por revisión de código; aún no está corregido ni reproducido
   con prueba automatizada. Las tres pruebas actuales no cubren este caso.
2. Terminar una compilación ARM64 real, sin `skipIl2CppBuild` ni binarios de
   relleno. El intento actual se inició con:
   `flutter build apk --debug --target-platform android-arm64 --split-per-abi --dart-define=PAWDO_UNITY_3D=true --dart-define=PAWDO_UNITY_PET_3D=false`.
   Registro: `../../android-arm64-current-build.log`. No hay APK nuevo verificado.
   No confundir los APK antiguos de agosto con el resultado de este intento.
3. Antes de limpiar, conservar APK nuevo y pruebas fuera de `build`, verificar
   bibliotecas ARM64/IL2CPP reales y registrar SHA-256. Los respaldos previos
   están en `artifacts/before-android-refresh/`.
4. Tras finalizar procesos de compilación, ejecutar primero la vista previa de
   `tools/clear-project-cache.ps1` y luego `-Apply`. Solo cachés regenerables
   explícitas del proyecto. Hasta esta pausa NO se ha ejecutado `-Apply` y NO
   se ha declarado espacio liberado. No borrar fuentes, recursos originales,
   claves, datos de usuario, evidencias ni export Unity.
5. Validar micrófono, cancelación, regreso Flutter/Unity y rendimiento en un
   teléfono conectado; volver a ejecutar las pruebas tras las correcciones.

## Pendientes de producto que no deben darse por terminados

- Personajes y perro siguen siendo geometría provisional: no son los modelos
  realistas finales solicitados. Faltan modelos con rig, animaciones y licencias
  verificadas. Las texturas de superficie no sustituyen estos modelos.
- Falta validar rendimiento con SRP Batcher desactivado, publicación firmada
  y comprobaciones de Play Store. Una APK debug no es una entrega final de tienda.
- Mantener pendiente el dominio propio para las páginas legales; no declarar
  `pawdo.site` registrado/publicado sin realizar y verificar esa gestión.
- No se hicieron despliegues de backend ni cambios de credenciales hoy.

La revisión independiente no encontró otros problemas importantes en el filtro
de escenas o la lista de limpieza; no certifica audio físico ni realismo visual.
