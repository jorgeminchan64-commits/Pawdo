# ADR-001 — arquitectura híbrida Flutter + Unity

Estado: aceptado para vertical slice, pendiente de validación física
Fecha: 22 de agosto de 2026

## Contexto

Pawdo ya posee una aplicación Flutter funcional y un backend Firebase con
autoridad de servidor para pareja, chat, calendario, bienestar, economía,
tienda y mascota. El nuevo alcance exige avatares y perro con rig, navegación,
colisiones, sockets, IK, materiales PBR, iluminación y personalización 3D.

## Opciones evaluadas

### A. Mantener Flame y 2D/2.5D

Ventajas: menor costo inmediato, build conocido y reutilización total.

Desventajas: no resuelve volumen real, colliders 3D, IK, equipamiento sobre un
esqueleto, cama compartida ni navegación tridimensional. Continuar agregando
sprites reproduciría los errores actuales.

Decisión: descartada como arquitectura final; se conserva solo como fallback
durante la migración.

### B. Flutter + Unity as a Library a pantalla completa

Ventajas: preserva todos los flujos sociales y legales de Flutter, limita el
riesgo del backend y usa Unity únicamente donde aporta 3D real.

Desventajas: puente nativo, ciclo de vida más complejo y consumo de memoria del
runtime. Unity documenta que su integración como biblioteca soporta una sola
instancia, renderizado a pantalla completa y conserva memoria después de
descargar escenas.

Decisión: seleccionada.

### C. Migrar toda la aplicación a Unity

Ventajas: un único runtime visual.

Desventajas: reescritura de autenticación, chat, calendario, accesibilidad,
formularios, navegación y plugins móviles ya operativos; eleva mucho el riesgo
sin mejorar esos flujos.

Decisión: descartada.

## Decisión

- Flutter seguirá siendo el shell y la autoridad de UX no 3D.
- Unity ejecutará Mascota, Jardín e Interior como destinos de pantalla completa.
- Se fija `Unity 6000.3.20f1` durante el vertical slice. Unity identifica 6.3
  como LTS con soporte hasta diciembre de 2027.
- Render pipeline: URP móvil.
- Navegación: paquete oficial AI Navigation/NavMesh.
- Distribución de contenido: Addressables, primero local y posteriormente
  remoto solo si se valida integridad, versión y rollback.
- Unity no recibirá credenciales Firebase ni escribirá monedas directamente.
- Todo cambio económico será una intención enviada a Flutter, validada por una
  Cloud Function y devuelta como resultado firmado por el flujo existente.

## Fronteras

| Flutter/Firebase | Unity |
|---|---|
| Sesión, pareja y permisos | Presentación del contexto ya validado |
| Cloud Functions y economía | Intenciones de interacción |
| Chat, calendario y bienestar | Mascota, jardín e interior 3D |
| Navegación general | Navegación de agentes dentro de escenas |
| Consentimiento de micrófono | Animación facial y reproducción ya autorizada |
| Persistencia canónica | Estado visual temporal y caché de escena |

## Feature flag y rollback

Las rutas existentes permanecen disponibles. El shell elegirá entre experiencia
legacy y 3D mediante una bandera versionada. Si Unity falla al iniciar, excede
el presupuesto de memoria o pierde el puente, Flutter vuelve a la experiencia
legacy sin alterar inventario ni layouts canónicos.

No se elimina Flame hasta completar paridad, migración de layouts, prueba de
salida/entrada repetida y aprobación en pista interna.

## Consecuencias

- El UI de cada escena 3D debe vivir dentro de Unity porque la integración
  estándar es a pantalla completa.
- Deben medirse arranque, memoria retenida, pausa/reanudación y temperatura.
- Se necesita Android Build Support para la versión fijada; no está instalado
  al cerrar el Hito 0.
- iOS se documentará desde el inicio, pero el primer vertical slice se valida
  en Android.

## Fuentes primarias

- Unity 6 LTS y soporte: <https://unity.com/releases/unity-6/support>
- Unity as a Library: <https://docs.unity3d.com/Manual/UnityasaLibrary.html>
- Integración Android: <https://docs.unity3d.com/Manual/UnityasaLibrary-Android.html>
- AI Navigation: <https://docs.unity3d.com/Manual/com.unity.ai.navigation.html>
- Addressables: <https://docs.unity3d.com/Manual/com.unity.addressables.html>
- Android SpeechRecognizer:
  <https://developer.android.com/reference/android/speech/SpeechRecognizer>
