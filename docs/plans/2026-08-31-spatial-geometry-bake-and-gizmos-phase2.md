# Implementation Plan: Fase 2 — Horneado de Geometría Acústica y Gizmos 3D (TASK-056)

Phase 2 builds the offline geometry pre-baker `OpenDouAcousticGeometryBake` with custom Inspector tools, along with full in-viewport 3D gizmo visualization (`OpenDouGizmoPlugin3D`) across all OpenDou spatial audio nodes.

---

## User Review Required

> [!IMPORTANT]
> - `OpenDouAcousticGeometryBake` provides high-speed CPU acoustic raycasting without requiring physics layer collisions, allowing audio designers to bake complex environmental obstacles with lightweight simplified representations.
> - `OpenDouGizmoPlugin3D` handles all 8 spatial nodes cleanly inside the Godot 3D Editor Viewport.

---

## Proposed Changes

### 1. Spatial Geometry Baking System

#### [NEW] [`addons/opendou/nodes/opendou_acoustic_geometry_bake.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_acoustic_geometry_bake.gd)
- Extends `Node3D`, marked as `@tool`.
- Scans `MeshInstance3D` nodes in `target_group` or child tree.
- Simplifies faces according to `simplification_step`.
- Computes triangle centers, normals, and assigns acoustic material properties.
- Provides Möller–Trumbore CPU raycast testing (`raycast_baked_geometry(from, to)`).

#### [NEW] [`addons/opendou/icons/icon_acoustic_bake.svg`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/icons/icon_acoustic_bake.svg)
- Custom SVG icon for `OpenDouAcousticGeometryBake`.

#### [NEW] [`addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd)
- `EditorInspectorPlugin` displaying `⚡ Bake Acoustic Geometry` and `🗑️ Clear Baked Data` buttons in the Inspector dock when selecting `OpenDouAcousticGeometryBake`.

---

### 2. Viewport 3D Gizmos Plugin

#### [NEW] [`addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd)
- Extends `EditorNode3DGizmoPlugin`.
- Implements `_has_gizmo()` and `_redraw()` for:
  - `OpenDouRoom3D`
  - `OpenDouPortal3D`
  - `OpenDouReflector3D`
  - `OpenDouSplineEmitter3D`
  - `OpenDouGranularEmitter3D`
  - `OpenDouParameterArea3D`
  - `OpenDouMultiPositionEmitter3D`
  - `OpenDouAcousticGeometryBake`

---

### 3. Editor Plugin Registration

#### [MODIFY] [`addons/opendou/plugin.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/plugin.gd)
- Preload and register `OpenDouAcousticGeometryBakeClass` as custom type with `IconAcousticBake`.
- Preload and register `OpenDouGizmoPlugin3D` via `add_node_3d_gizmo_plugin()`.
- Preload and register `OpenDouAcousticGeometryBakeInspectorPlugin` via `add_inspector_plugin()`.
- Cleanly deregister all plugins in `_exit_tree()`.

---

### 4. Automated Verification Suite

#### [NEW] [`tests/test_acoustic_geometry_bake.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_acoustic_geometry_bake.gd)
- Test 1: Instantiation and default properties.
- Test 2: Child mesh scanning & triangle extraction.
- Test 3: Group-based mesh scanning (`target_group`).
- Test 4: Simplification step face sampling.
- Test 5: Acoustic material assignment and normal calculation.
- Test 6: Möller–Trumbore raycast hit detection.
- Test 7: Möller–Trumbore raycast miss detection.
- Test 8: Baked data clearing and statistics update.
- Test 9: Gizmo plugin node detection (`_has_gizmo`).
- Test 10: Inspector plugin object parsing (`_can_handle`).

#### [MODIFY] [`tests/test_all.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_all.gd)
- Register `TestAcousticGeometryBakeClass` in master test suite (+10 tests $\to$ Total 316 tests).

---

## Verification Plan

### Automated Tests
- Run full CLI test runner:
  ```powershell
  .\godot.cmd --headless --path . -s tests/test_runner_cli.gd
  ```
- Verify 316 tests pass with 0 failures and exit code 0.
