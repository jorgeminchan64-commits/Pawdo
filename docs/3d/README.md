# Pawdo 3D — expediente de producción

**Estado vigente y punto de reanudación:** [`current_status.md`](current_status.md).
Los informes VS conservan evidencia histórica; no describen por sí solos el
estado actual ni implican que la apariencia realista final esté terminada.

Este directorio contiene la puerta técnica y visual para reemplazar, de forma
gradual, Mascota, Jardín e Interior 2D por escenas 3D reales sin poner en riesgo
las funciones sociales y el backend ya desplegado.

Documentos del Hito 0:

- [`phase_0_audit.md`](phase_0_audit.md): línea base, hotfixes y evidencia.
- [`ADR-001-hybrid-unity-flutter.md`](ADR-001-hybrid-unity-flutter.md):
  decisión de arquitectura.
- [`art_direction_3d.md`](art_direction_3d.md): biblia visual inicial.
- [`asset_inventory_and_licenses.md`](asset_inventory_and_licenses.md):
  inventario y puerta de licencias.
- [`flutter_unity_bridge_contract.md`](flutter_unity_bridge_contract.md):
  frontera de datos y autoridad.
- [`vertical_slice_plan.md`](vertical_slice_plan.md): siguiente hito, QA y
  rollback.
- [`pawdo_bridge_v1.schema.json`](pawdo_bridge_v1.schema.json): esquema
  ejecutable del envelope v1.
- [`vs1_technical_report.md`](vs1_technical_report.md): avance y puertas de
  aceptación del esqueleto técnico.

Jorge ya autorizó continuar después de VS-1 y avanzar sin nuevas aprobaciones
por etapas. Consultar el estado vigente para las pruebas realizadas, los
pendientes técnicos y la diferencia entre geometría provisional y arte final.
