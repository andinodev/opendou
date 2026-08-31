# ⚡ Tarea Activa: TASK-056 — Horneado de Geometría Acústica y Gizmos 3D de Viewport (Fase 2)

* **Documento de Especificación:** [`docs/specs/spec_spatial_geometry_bake_and_gizmos_phase2.md`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_spatial_geometry_bake_and_gizmos_phase2.md)
* **Plan de Implementación:** [`docs/plans/2026-08-31-spatial-geometry-bake-and-gizmos-phase2.md`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/plans/2026-08-31-spatial-geometry-bake-and-gizmos-phase2.md)
* **Estado:** ✅ Completado y Verificado
* **Checklist de Tareas:**
  * [x] **Task 1:** Implementar `OpenDouAcousticGeometryBake` (`Node3D`), icono SVG, inspector plugin `OpenDouAcousticGeometryBakeInspectorPlugin` con botones interactivos y raycast Möller–Trumbore.
  * [x] **Task 2:** Implementar `OpenDouGizmoPlugin3D` (`EditorNode3DGizmoPlugin`) con renderizado 3D de wireframes y vectores para los 8 nodos espaciales en el Viewport 3D.
  * [x] **Task 3:** Registrar componentes en `addons/opendou/plugin.gd`, implementar suite `tests/test_acoustic_geometry_bake.gd` (+10 tests) e integrar en `tests/test_all.gd` verificando 316 pruebas al 100%.
* **Criterios de Aceptación (Definition of Done):**
  * [x] `OpenDouAcousticGeometryBake` extrae triángulos desde mallas hijas y grupos (`target_group`), simplifica la geometría con `simplification_step`, asocia propiedades de `AcousticMaterialRegistry` y ejecuta trazado de rayos Möller–Trumbore en CPU sin sobrecargar el motor de físicas.
  * [x] `OpenDouAcousticGeometryBakeInspectorPlugin` inyecta botones `⚡ Bake Acoustic Geometry` y `🗑️ Clear Baked Data` en el Inspector de Godot.
  * [x] `OpenDouGizmoPlugin3D` dibuja en el Viewport 3D de Godot todos los contornos, vectores normales, arcos de spread y vértices de los 8 nodos espaciales (`Room`, `Portal`, `Reflector`, `SplineEmitter`, `GranularEmitter`, `ParameterArea`, `MultiPositionEmitter`, `GeometryBake`).
  * [x] 100% de tests unitarios y de integración pasando con código de salida 0 en `godot --headless` (316/316 tests).
