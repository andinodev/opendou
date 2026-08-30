# ⚡ Tarea Activa: TASK-047 - Armonización de Superficies Físicas y Acústica de Salas 3D

* **Estado:** 🚧 En Progreso
* **Rama / Commit Base:** `main` (`e7f440d`)
* **Responsable:** OpenDou Audio Architecture Team
* **Fecha de Inicio:** 2026-08-30

---

## 🎯 Objetivo de la Tarea

Armonizar el catálogo de `SurfaceType` en `opendou_syncs.json`, dotar a `OpenDouRoom3D` y `AudioRoom` con la propiedad `@export var floor_surface: StringName` y una paleta expandida de materiales físicos (`Concrete`, `Metal`, `Wood`, `Glass`, `Water`, `Curtains`, `Foliage`, `Outdoor`, `Custom`), expandir los algoritmos de síntesis procedural de pisadas en `AudioSynthesizer`, e implementar la resolución inteligente en 3 niveles de superficies (`detect_surface_at`) en `SpatialAcousticsManager`.

---

## 📋 Criterios de Aceptación (Definition of Done)

* [ ] `opendou_syncs.json` contiene la lista estandarizada de `SurfaceType`: `["Asphalt", "Concrete", "Foliage", "Glass", "Metal", "Mud", "Stone", "Tile", "Water", "Wood"]`.
* [ ] `AudioSynthesizer.create_footstep()` sintetiza convincentemente audio procedural para todos los tipos de superficies (`Tile`, `Foliage`, `Concrete`, `Metal`, `Water`, `Wood`, `Stone`, `Mud`, `Glass`, `Asphalt`).
* [ ] `OpenDouRoom3D` expone `@export var floor_surface: StringName = &"Concrete"` y `material_preset` ampliado con coeficientes de absorción física estándar.
* [ ] `AudioRoom` almacena `var floor_surface: StringName` y `var material_preset: String`.
* [ ] `SpatialAcousticsManager` implementa `detect_surface_at(pos: Vector3, world_3d: World3D = null) -> StringName` resolviendo: 1. Raycast Physics Directo $\to$ 2. `AudioRoom.floor_surface` $\to$ 3. Fallback `&"Concrete"`.
* [ ] `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn` y `demo_cyberpunk_infiltration.gd` actualizan sus salas y utilizan `spatial_acoustics.detect_surface_at()`.
* [ ] Suite de pruebas unitarias (`tests/test_declarative_nodes.gd` y `tests/test_spatial_acoustics.gd`) cubre la detección de superficies y propiedades de salas.
* [ ] Todas las pruebas pasan al 100% con `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (código de salida 0).
