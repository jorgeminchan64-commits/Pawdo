# PAWDO — PRODUCTION READINESS REPORT

Fecha: 2026-08-12

## 1. Estado general

Roadmap FASE 0–25 completado en código y validación automatizada hasta donde permite el entorno. Pawdo no se declara publicada: quedan firma, Play Console, dos teléfonos, staging, dominio propio y gates operativos.

## 2. Funciones completadas

Cuenta y pareja seguras; Inicio; perfil; personajes; casa; jardín; mascota; chat de texto/foto/audio; álbum; calendario; contador; bienestar; widget; ubicación temporal; cine; economía; tienda; juegos; privacidad, exportación y borrado.

## 3. Problemas encontrados

Git inicial inválido, analizador con hallazgos, bootstrap frágil, reconexión parcial, timers en background, snapshots inseguros, perfil incompleto, escrituras demasiado amplias, medios sin validación suficiente, APK grande, permisos/Analytics innecesarios, App Check/Crashlytics ausentes, target 34, firma inexistente e icono adaptable mal construido.

## 4. Errores corregidos

Se restauró el baseline Git; analyze quedó limpio; se añadió bootstrap recuperable, backoff, idempotencia, lifecycle, validación defensiva, esquemas cerrados, reglas deny-by-default, medios acotados, borrado server-side, App Check, Crashlytics redactado, target 36, permisos mínimos e iconos correctos.

## 5. Mejoras de rendimiento

Pestañas construidas al primer uso, latido de presencia de 75 a 120 segundos (37.5% menos escrituras periódicas), timers/efectos pausados, paginación y miniaturas conservadas, assets y rutas huérfanas retiradas.

## 6. Optimización de recursos

Se eliminó un asset huérfano confirmado y código legacy; no se borraron candidatos dinámicos sin prueba. Material Icons aplica tree shaking. Se midieron APK universal, APK por ABI y AAB.

## 7. Mejoras visuales

Inicio contextual, perfil comercial, editor de personaje, estados coherentes en tienda, Casa/Jardín, icono adaptable transparente, icono temático monocromático, notificación blanca, app icon 512 y feature graphic.

## 8. Firebase

Auth, Firestore, Storage, Functions, Messaging, App Check y Crashlytics integrados. Functions usa 7.3.2 estable. Enforcement, staging y primer evento de consola siguen siendo gates externos.

## 9. Seguridad

Operaciones sensibles server-side, membresía autoritativa, idempotencia/rate limits, reglas cerradas, archivos por firma/tamaño/ruta/metadata, sin `AD_ID`, sin Analytics, claves de firma y credenciales excluidas de Git.

## 10. Privacidad

Identidad: Jorge Luis Minchan Huaman. Soporte: `soporte.pawdo@gmail.com`. Borrado: `borrado.pawdo@gmail.com`. Política/términos/borrado disponibles; borrador Data Safety preparado. `pawdo.site` y publicación del texto actualizado siguen pendientes.

## 11. Conectividad

Recuperación central por eventos y lifecycle, backoff acotado, reintento idempotente y estados accesibles. Las operaciones no serializables pueden requerir repetir la acción tras cierre de proceso.

## 12. Juegos

Diez juegos auditados y tres juegos locales nuevos. Snapshots defensivos, timers conscientes del lifecycle y recompensas/economía validadas en servidor.

## 13. Widgets

Widget adaptable con caché privada, relación, próximo evento y Te extraño; sin polling ni servicio permanente. Prueba física/reinicio pendiente.

## 14. Casa

Interacciones coherentes, zonas de muebles, revisión de layouts, conflictos protegidos y cambios sin guardar. FPS/táctil pendientes en hardware.

## 15. Jardín

Riego solo sobre vegetación, etapas sincronizadas, recompensa diaria server-side y edición con control de conflictos.

## 16. Mascota

Siete cuidados, necesidades/emociones, desgaste temporal, precondiciones y estado compartido transaccional.

## 17. Chat

Texto, rápidos, fotos y notas AAC de hasta 60 segundos; subida privada, reproducción autenticada, paginación, leído, borrado y recuperación.

## 18. Pruebas realizadas

78 Flutter + 57 Functions + 26 Firestore + 21 Storage = 182 automatizadas aprobadas. Analyze limpio. Android Lint: 0 errores/5 advertencias. Sitio legal: 4 pruebas. Cobertura Flutter medida en FASE 24: 10.7%, insuficiente para reemplazar QA física.

## 19. Resultado en teléfono 1

Pendiente. No se fabricó evidencia de dispositivo.

## 20. Resultado en teléfono 2

Pendiente. Requiere segunda cuenta, sincronización real, notificaciones, audio, widget, reconexión y permisos.

## 21. Tamaño inicial

APK baseline: 105.36 MiB, sin firma.

## 22. Tamaño final

APK universal técnico: 111,757,970 bytes (106.58 MiB). AAB técnico: 100,674,591 bytes (96.01 MiB). El crecimiento corresponde a módulos de producto y observabilidad; Play entregará APK optimizado por dispositivo.

## 23. Estado APK

Compila con API 36, pasa alineación ZIP 16 KB y permanece sin firma. No es el formato de publicación para una app nueva.

## 24. Estado AAB

Compila, contiene 12 ELF alineados a 16/64 KB y está sin firma. La upload key es el bloqueo inmediato.

## 25. Estado Play Store

Preparación técnica completa; publicación bloqueada por firma, consola, testers si aplica, capturas, Data Safety, clasificación, dominio, staging y matriz física.

## 26. Funciones aplazadas

Llamadas/video reales, IA externa de pago, 3D pesado, compras reales y proveedores costosos. También se difieren una actualización mayor Firebase, modularización de Functions y optimización visual agresiva.

## 27. Riesgos pendientes

Cobertura UI baja, backend aún no desplegado/probado destructivamente en staging, dependencias npm transitivas, App Check sin enforcement, Crashlytics sin evento interno, dominio propio ausente y artefacto sin firma.

## 28. Recomendaciones para Pawdo 1.1

Subir cobertura de integración sobre auth/pareja/chat; modularizar Functions por dominio; actualizar Firebase en etapas; medir RAM/FPS/batería con Android Vitals; mejorar recuperación entre procesos; evaluar Play Asset Delivery solo si el tamaño crece; ampliar accesibilidad y layouts grandes después de validar API 36.
