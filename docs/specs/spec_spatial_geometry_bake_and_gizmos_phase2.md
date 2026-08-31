# OpenDou Specification: Acoustic Geometry Bake & Viewport 3D Gizmos (Phase 2 - TASK-056)

---

## 1. Overview & Objectives

Phase 2 of the OpenDou Spatial Audio expansion introduces tooling for offline acoustic geometry preprocessing and comprehensive in-editor 3D viewport visualization:

1. **`OpenDouAcousticGeometryBake` (`Node3D`):**
   * Pre-scans, simplifies, and bakes static scene geometry (`MeshInstance3D`, `StaticBody3D`) tagged under acoustic groups (e.g., `AcousticObstacle`, `AcousticRoom`) or direct children into a lightweight, spatial bounding hierarchy (BVH / Triangle AABB clusters).
   * Maps acoustic absorption, scattering, and transmission properties from `AcousticMaterialRegistry` onto baked geometry partitions.
   * Provides rapid CPU-side raycast evaluation for occlusion, early reflections, and diffraction paths without overhead on physics engines.
   * Includes custom Inspector Tool actions (`Bake Acoustic Geometry`, `Clear Baked Data`).

2. **`OpenDouGizmoPlugin3D` (`EditorNode3DGizmoPlugin`):**
   * Real-time in-viewport 3D gizmo renderers for all OpenDou spatial audio nodes:
     * `OpenDouRoom3D`: Volume wireframe colored by acoustic material + RT60 display.
     * `OpenDouPortal3D`: Aperture rectangle, acoustic normal vector, and angular sound spread arc.
     * `OpenDouReflector3D`: Reflector plane quad, normal vector, and first-order specular bounce paths.
     * `OpenDouSplineEmitter3D`: Continuous spline path curve and closest-projection point.
     * `OpenDouGranularEmitter3D`: Grain spawn radius sphere and volumetric dispersion bounds.
     * `OpenDouParameterArea3D`: Spherical/cylindrical radial penetration gradient & axis direction.
     * `OpenDouMultiPositionEmitter3D`: Multi-vertex constellation mesh, point nodes, and centroid.
     * `OpenDouAcousticGeometryBake`: Baked acoustic triangle wireframe and spatial AABBs.

---

## 2. Technical Specifications & Architectures

### 2.1 `OpenDouAcousticGeometryBake` (`addons/opendou/nodes/opendou_acoustic_geometry_bake.gd`)

```text
OpenDouAcousticGeometryBake (Node3D)
├── Exported Configuration
│   ├── target_group: StringName = &"AcousticObstacle"
│   ├── scan_child_meshes: bool = true
│   ├── default_acoustic_material: StringName = &"Concrete"
│   ├── simplification_step: int = 1
│   ├── generate_bvh: bool = true
│   └── auto_bake_on_ready: bool = false
├── Baked Data Cache
│   ├── baked_triangles: Array[Dictionary] (v0, v1, v2, normal, center, material)
│   ├── baked_aabbs: Array[AABB]
│   └── stats: Dictionary (mesh_count, triangle_count, total_volume)
└── Public Methods
    ├── bake_geometry(root_node: Node = null) -> Dictionary
    ├── clear_baked_data() -> void
    ├── get_baked_triangle_count() -> int
    ├── raycast_baked_geometry(from: Vector3, to: Vector3) -> Dictionary
    └── export_to_resource(path: String) -> bool
```

#### Ray-Triangle Acoustic Intersection:
Uses Möller–Trumbore intersection algorithm for rapid CPU evaluation of ray $\vec{R}(t) = \vec{O} + t\vec{D}$ against triangle vertices $(\vec{V}_0, \vec{V}_1, \vec{V}_2)$:
$$\vec{E}_1 = \vec{V}_1 - \vec{V}_0, \quad \vec{E}_2 = \vec{V}_2 - \vec{V}_0$$
$$\vec{T} = \vec{O} - \vec{V}_0, \quad \vec{P} = \vec{D} \times \vec{E}_2, \quad \vec{Q} = \vec{T} \times \vec{E}_1$$
$$t = \frac{\vec{Q} \cdot \vec{E}_2}{\vec{P} \cdot \vec{E}_1}, \quad u = \frac{\vec{P} \cdot \vec{T}}{\vec{P} \cdot \vec{E}_1}, \quad v = \frac{\vec{Q} \cdot \vec{D}}{\vec{P} \cdot \vec{E}_1}$$

---

### 2.2 `OpenDouGizmoPlugin3D` (`addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd`)

* Registered as an `EditorNode3DGizmoPlugin` in `plugin.gd`.
* Configures custom materials and lines for each node type:
  * `ROOM_MATERIAL`: Green/Emerald line `#4caf50`
  * `PORTAL_MATERIAL`: Amber/Gold line `#ffb300`
  * `REFLECTOR_MATERIAL`: Cyan line `#00bcd4`
  * `SPLINE_MATERIAL`: Electric Blue line `#00e5ff`
  * `GRANULAR_MATERIAL`: Purple line `#ab47bc`
  * `PARAMETER_AREA_MATERIAL`: Teal line `#26a69a`
  * `MULTI_POINT_MATERIAL`: Blue line `#42a5f5`
  * `BAKE_MATERIAL`: Orange line `#ff9800`

---

## 3. Definition of Done (DoD) & Acceptance Criteria

1. `OpenDouAcousticGeometryBake` compiles cleanly, extracts geometry from target groups and child meshes, computes triangle normals and material properties, and provides fast Möller-Trumbore raycasting.
2. `OpenDouAcousticGeometryBakeInspectorPlugin` provides interactive Editor buttons (`Bake Acoustic Geometry`, `Clear Baked Data`) and status readout.
3. `OpenDouGizmoPlugin3D` dynamically draws 3D wireframe gizmos for all 8 spatial audio nodes in the Godot 3D editor viewport.
4. Registered in `plugin.gd` with dedicated SVG icon (`icon_acoustic_bake.svg`).
5. Complete test coverage with new test suite `tests/test_acoustic_geometry_bake.gd` (+10 tests) and gizmo plugin verification.
6. 100% of all unit/integration tests passing (316+ tests) in headless CLI runner with exit code 0.
