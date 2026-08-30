# AAA Spatial Acoustics Phase 1 Implementation Plan (TASK-051)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 1 of OpenDou's AAA Spatial Audio Engine: physical material mass-law transmission loss, strict obstruction vs. occlusion separation, atmospheric air damping, stabilized Doppler pitch modulation, and declarative volumetric 3D spline emitters (`OpenDouSplineEmitter3D`).

**Architecture:** Hybrid Physical Material Registry (`acoustic_material_registry.gd`) + Raycast Propagation Evaluator (`occlusion_manager.gd` / `spatial_acoustics_manager.gd`) + Spline Audio Stream Emitter (`opendou_spline_emitter_3d.gd`).

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Spatial Acoustics Subsystem.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`) to confirm 100% pass (exit code 0).

---

### Task 1: Physical Material Matrix & Mass-Law Calculation Engine

**Files:**
- Create: `addons/opendou/runtime/spatial/acoustic_material_registry.gd`
- Create: `tests/test_spatial_acoustics_phase1.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces:
  * `AcousticMaterialRegistry.get_singleton() -> AcousticMaterialRegistry`
  * `AcousticMaterialRegistry.get_material(mat_name: StringName) -> Dictionary`
  * `AcousticMaterialRegistry.calculate_transmission_loss(mat_name: StringName, thickness_m: float, center_freq: float = 1000.0) -> Dictionary`
  * `AcousticMaterialRegistry.register_custom_material(mat_name: StringName, density: float, resonance_lpf: float, absorption: float) -> void`

- [ ] **Step 1: Write failing tests in `tests/test_spatial_acoustics_phase1.gd`**
  - Add Test 1: Verify canonical materials in registry (`Concrete`, `Metal`, `Glass`, `Wood`, `Foliage`, `Water`, `Asphalt`) have correct density, resonance LPF, and absorption.
  - Add Test 2: Verify `calculate_transmission_loss` returns expected `attenuation_db` and `cutoff_lpf` for 0.1m, 0.5m, and 2.0m thick Concrete vs Wood.
  - Register `TestSpatialAcousticsPhase1Class` in `tests/test_all.gd`.

- [ ] **Step 2: Run tests to verify failure**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: FAIL with missing `AcousticMaterialRegistry` class.

- [ ] **Step 3: Implement `AcousticMaterialRegistry`**
  - Create `addons/opendou/runtime/spatial/acoustic_material_registry.gd` with canonical dictionary, mathematical formulas for mass-law loss and LPF resonance interpolation, custom material registration, and optional JSON loading.

- [ ] **Step 4: Run tests to verify pass**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - `git add addons/opendou/runtime/spatial/acoustic_material_registry.gd tests/test_spatial_acoustics_phase1.gd tests/test_all.gd`
  - `git commit -m "feat(spatial): implement AcousticMaterialRegistry with physical mass-law transmission (Task 1 - TASK-051)"`

---

### Task 2: Obstruction vs. Occlusion Splitting, Air Damping & Doppler Shift

**Files:**
- Modify: `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`
- Modify: `addons/opendou/runtime/spatial/occlusion_manager.gd`
- Modify: `tests/test_spatial_acoustics_phase1.gd`

**Interfaces:**
- Consumes:
  * `AcousticMaterialRegistry.get_singleton().calculate_transmission_loss()`
- Produces:
  * `SpatialAcousticsManager.calculate_air_absorption(distance: float) -> float`
  * `SpatialAcousticsManager.calculate_doppler_pitch(emitter_vel: Vector3, listener_vel: Vector3, rel_pos: Vector3, smoothed_vel: Vector3 = Vector3.ZERO) -> float`
  * `SpatialAcousticsManager.evaluate_acoustic_path(emitter: Node3D, listener: Node3D, collision_mask: int = 1) -> Dictionary`

- [ ] **Step 1: Write failing tests in `tests/test_spatial_acoustics_phase1.gd`**
  - Add Test 3: Verify `calculate_air_absorption` produces smooth exponential cutoff curve over distance (e.g. 5m, 20m, 80m).
  - Add Test 4: Verify `calculate_doppler_pitch` correctly shifts frequency up when approaching and down when receding, clamped to $[0.5, 2.0]$.
  - Add Test 5: Verify `evaluate_acoustic_path` separates `obstruction_factor` (direct LPF only) from `occlusion_factor` (direct + reverb damping) with dual-penetration thickness.

- [ ] **Step 2: Run tests to verify failure**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: FAIL with missing methods on `SpatialAcousticsManager`.

- [ ] **Step 3: Implement Obstruction/Occlusion splitting, Air Damping and Doppler in `SpatialAcousticsManager` & `OcclusionManager`**
  - Add `calculate_air_absorption()`.
  - Add `calculate_doppler_pitch()` with velocity smoothing.
  - Implement dual-penetration thickness raycast and path evaluation on `acoustic_collision_mask`.

- [ ] **Step 4: Run tests to verify pass**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - `git add addons/opendou/runtime/spatial/ tests/test_spatial_acoustics_phase1.gd`
  - `git commit -m "feat(spatial): implement obstruction vs occlusion separation, air damping and Doppler (Task 2 - TASK-051)"`

---

### Task 3: Volumetric 3D Spline Emitter (`OpenDouSplineEmitter3D`) & Plugin Registration

**Files:**
- Create: `addons/opendou/icons/icon_spline_emitter_3d.svg`
- Create: `addons/opendou/nodes/opendou_spline_emitter_3d.gd`
- Modify: `addons/opendou/plugin.gd`
- Modify: `tests/test_spatial_acoustics_phase1.gd`
- Modify: `tests/test_all.gd`
- Modify: `docs/tasks/completed.md`
- Modify: `docs/tasks/current.md`

**Interfaces:**
- Consumes:
  * `SpatialAcousticsManager.calculate_air_absorption()`
  * `SpatialAcousticsManager.calculate_doppler_pitch()`
- Produces:
  * `OpenDouSplineEmitter3D` (Node3D / AudioStreamPlayer3D)

- [ ] **Step 1: Write failing tests in `tests/test_spatial_acoustics_phase1.gd`**
  - Add Test 6: Verify `OpenDouSplineEmitter3D` instantiation, exported properties (`curve`, `sound_spread_curve`, `enable_air_absorption`, `enable_doppler`, `acoustic_collision_mask`).
  - Add Test 7: Verify closest point tracking on a 3-point `Curve3D` along an L-shaped path, and distance AABB culling when listener is far.
  - Add Test 8: Verify plugin registration and SVG icon loading.

- [ ] **Step 2: Run tests to verify failure**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: FAIL with missing `OpenDouSplineEmitter3D` class/icon.

- [ ] **Step 3: Implement `OpenDouSplineEmitter3D`, SVG Icon and Plugin Registration**
  - Create `addons/opendou/icons/icon_spline_emitter_3d.svg`.
  - Create `addons/opendou/nodes/opendou_spline_emitter_3d.gd` with distance AABB guard, `Curve3D.get_closest_point()`, spread curve sampling, air damping, and Doppler integration.
  - Register custom type in `addons/opendou/plugin.gd`.
  - Update `docs/tasks/completed.md` and `docs/tasks/current.md`.

- [ ] **Step 4: Run tests to verify pass**
  - Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: 100% tests pass (exit code 0, 0 failures).

- [ ] **Step 5: Document and Commit**
  - `git add addons/opendou/nodes/opendou_spline_emitter_3d.gd addons/opendou/icons/icon_spline_emitter_3d.svg addons/opendou/plugin.gd tests/ docs/tasks/`
  - `git commit -m "feat(nodes): create OpenDouSplineEmitter3D volumetric audio emitter and complete TASK-051 (Task 3)"`
