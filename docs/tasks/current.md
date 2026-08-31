# ⚡ Tarea Activa: TASK-058 — Demo 09: Nivel de Infiltración Táctica AAA

* **Documento de Especificación:** [`docs/specs/spec_tactical_infiltration_demo.md`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_tactical_infiltration_demo.md)
* **Plan de Implementación:** [`docs/plans/2026-08-31-tactical-infiltration-demo.md`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/plans/2026-08-31-tactical-infiltration-demo.md)
* **Estado:** ✅ Completado y Verificado
* **Checklist de Tareas:**
  * [x] **Task 1:** Construir escena declarativa `scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn` integrando los 13 tipos de nodos OpenDou, geometrías de nivel, mallas, rigs de personajes y HUD.
  * [x] **Task 2:** Implementar script controlador `scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.gd` con telemetría HUD, movimiento WASD/cámara, teletransporte por sectores, puerta blindada interactiva, diálogos tácticos y disparadores de audio.
  * [x] **Task 3:** Integrar en `scenes/demos/demo_hub.tscn` / `demo_hub.gd`, crear suite `tests/test_tactical_infiltration_demo.gd` (+10 tests) e integrar en `tests/test_all.gd` verificando 336 pruebas al 100%.
* **Criterios de Aceptación (Definition of Done):**
  * [x] La escena `.tscn` contiene e instancia de forma declarativa todos los nodos: `OpenDouAcousticGeometryBake`, `OpenDouParameterArea3D`, `OpenDouSplineEmitter3D`, `OpenDouGranularEmitter3D`, `OpenDouReflector3D`, `OpenDouRoom3D`, `OpenDouPortal3D`, `OpenDouMultiPositionEmitter3D`, `OpenDouAnimationSync`, `OpenDouMusicPlayer`, `OpenDouAudibleMonitor`, `OpenDouAcousticDebugger3D`, `OpenDouEventPlayer3D`.
  * [x] La telemetría en tiempo real del HUD muestra el sector activo, la habitación acústica, el tipo de superficie pisada (`Stone` vs `Metal`), valores de RTPCs, y estado de oclusión.
  * [x] 100% de tests unitarios y de integración pasando con código de salida 0 en `godot --headless` (336/336 tests).
