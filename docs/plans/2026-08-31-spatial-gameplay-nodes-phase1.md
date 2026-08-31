# Spatial Gameplay Nodes Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 1 of OpenDou's advanced spatial audio node suite: `OpenDouParameterArea3D` (RTPC parameter modulation volumes with priority blending, snapshots, cylindrical Y-axis ignore, and despawn safety) and `OpenDouMultiPositionEmitter3D` (large acoustic objects with closest-point tracking, multi-point blended gain, comb-filtering suppression, per-vertex occlusion, and dynamic mesh vertex extraction).

**Architecture:** Create two declarative nodes inheriting from Godot's `Area3D` and `AudioStreamPlayer3D` with dedicated SVG icons and plugin registration. Connect `OpenDouParameterArea3D` with `AudioEventManager` RTPCs and global snapshots, and `OpenDouMultiPositionEmitter3D` with `SpatialAcousticsManager` for per-vertex occlusion and interior envelopment.

**Tech Stack:** Godot 4.x, GDScript (Strict Static Typing), OpenDou Spatial Acoustics Engine, Vector Geometry.

## Global Constraints

- GDScript 2.0 with static typing for all variables, parameters, and return types.
- Follow hybrid language rule (Spanish for tasks/communication, English for code, symbols, and docs).
- Full TDD cycle: Write failing tests first, verify failure, implement minimal code, verify 100% pass with `godot --headless`.
- Zero audio artifacts (clicks, phase cancellation, comb filtering) and full despawn safety (`tree_exited`).

---

### Task 1: OpenDouParameterArea3D (RTPC Volumes, Blending, Snapshots & Hysteresis)

**Files:**
- Create: `addons/opendou/nodes/opendou_parameter_area_3d.gd`
- Create: `addons/opendou/icons/icon_parameter_area_3d.svg`
- Modify: `addons/opendou/plugin.gd`
- Test: `tests/test_parameter_area_3d.gd`

**Interfaces:**
- Consumes: `AudioEventManager` (for `set_rtpc_value`, `get_rtpc_value`), `AudioMixSnapshot` / Bus layout.
- Produces: `OpenDouParameterArea3D` node class extending `Area3D`.

- [ ] **Step 1: Write the failing tests in `tests/test_parameter_area_3d.gd`**

```gdscript
class_name TestParameterArea3DClass
extends RefCounted

const OpenDouParameterArea3DClass = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Instantiation and default properties
	var area = OpenDouParameterArea3DClass.new()
	if area == null:
		failures.append("Test 1 Failed: OpenDouParameterArea3D instantiation failed")
		return failures
	if area.parameter_name != &"" or area.interpolation_mode != 0 or area.priority != 0:
		failures.append("Test 1 Failed: Default property values mismatch")

	# Test 2: Radial Center Penetration (0.0 at edge, 1.0 at center)
	area.parameter_name = &"Radiation_Level"
	area.interpolation_mode = 0 # CENTER_RADIAL
	area.min_value = 0.0
	area.max_value = 100.0
	var calc_center = area.calculate_penetration_at(Vector3.ZERO, Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_center, 1.0):
		failures.append("Test 2 Failed: Radial penetration at center should be 1.0, got %.3f" % calc_center)
	var calc_edge = area.calculate_penetration_at(Vector3(10, 0, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_edge, 0.0):
		failures.append("Test 2 Failed: Radial penetration at edge should be 0.0, got %.3f" % calc_edge)

	# Test 3: Cylindrical Ignore-Y Calculation
	area.ignore_y_axis = true
	var calc_y_offset = area.calculate_penetration_at(Vector3(0, 50, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_y_offset, 1.0):
		failures.append("Test 3 Failed: Radial ignore_y_axis should be 1.0 despite high Y, got %.3f" % calc_y_offset)

	# Test 4: Axis Gradient Penetration (0.0 to 1.0 along gradient_axis)
	area.interpolation_mode = 1 # AXIS_GRADIENT
	area.gradient_axis = Vector3.UP
	var calc_bottom = area.calculate_penetration_at(Vector3(0, -5, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_bottom, 0.0):
		failures.append("Test 4 Failed: Axis gradient at bottom should be 0.0, got %.3f" % calc_bottom)
	var calc_top = area.calculate_penetration_at(Vector3(0, 5, 0), Vector3.ZERO, Vector3(10, 10, 10))
	if not is_equal_approx(calc_top, 1.0):
		failures.append("Test 4 Failed: Axis gradient at top should be 1.0, got %.3f" % calc_top)

	# Test 5: Conflict Resolution: MAX blend operation
	var val_max = OpenDouParameterArea3DClass.resolve_conflict([40.0, 75.0, 20.0], 0) # 0: MAX
	if val_max != 75.0:
		failures.append("Test 5 Failed: MAX blend operation should yield 75.0, got %.1f" % val_max)

	# Test 6: Conflict Resolution: ADD blend operation clamped to min/max
	var val_add = OpenDouParameterArea3DClass.resolve_conflict([30.0, 40.0], 1, 0.0, 100.0) # 1: ADD
	if val_add != 70.0:
		failures.append("Test 6 Failed: ADD blend operation should yield 70.0, got %.1f" % val_add)

	# Test 7: Conflict Resolution: REPLACE blend operation by Priority
	var val_rep = OpenDouParameterArea3DClass.resolve_priority_values([
		{"val": 30.0, "prio": 1},
		{"val": 90.0, "prio": 5},
		{"val": 10.0, "prio": 2}
	])
	if val_rep != 90.0:
		failures.append("Test 7 Failed: REPLACE priority resolution should yield 90.0, got %.1f" % val_rep)

	# Test 8: Target Snapshot Registration
	area.target_snapshot = &"Underwater_Mix"
	if area.target_snapshot != &"Underwater_Mix":
		failures.append("Test 8 Failed: target_snapshot property failed")

	# Test 9: Despawn & tree_exited Safety Handler
	var dummy_target = Node3D.new()
	area.register_target_entered(dummy_target)
	if not area.has_active_target(dummy_target):
		failures.append("Test 9 Failed: dummy_target should be registered")
	dummy_target.free()
	area.cleanup_invalid_targets()
	if area.get_active_targets_count() != 0:
		failures.append("Test 9 Failed: Freed target should be safely removed")

	# Test 10: Boundary Hysteresis Debouncing
	area.edge_hysteresis_ms = 150.0
	var debounce_res = area.evaluate_hysteresis_debounce(0.01, 50.0) # 50 ms elapsed
	if debounce_res == true:
		failures.append("Test 10 Failed: 50ms is below 150ms hysteresis threshold and should be debounced")

	area.free()
	return failures
```

- [ ] **Step 2: Run test suite to verify it fails**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL (file or class not found).

- [ ] **Step 3: Implement `addons/opendou/nodes/opendou_parameter_area_3d.gd` & SVG icon**

Create `addons/opendou/icons/icon_parameter_area_3d.svg` and implement `addons/opendou/nodes/opendou_parameter_area_3d.gd` with full enum `InterpolationMode { CENTER_RADIAL, AXIS_GRADIENT, BINARY_TRIGGER }`, `BlendOperation { MAX, ADD, REPLACE }`, mathematical formulations, `Curve` mapping, conflict resolvers, despawn connection to `target.tree_exited`, and hysteresis debounce timers.

- [ ] **Step 4: Register in `addons/opendou/plugin.gd`**

Register `OpenDouParameterArea3D` with `add_custom_type` and remove on `_exit_tree`.

- [ ] **Step 5: Run test to verify it passes**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: PASS (exit code 0).

- [ ] **Step 6: Commit Task 1**

```bash
git add addons/opendou/nodes/opendou_parameter_area_3d.gd addons/opendou/icons/icon_parameter_area_3d.svg addons/opendou/plugin.gd tests/test_parameter_area_3d.gd
git commit -m "feat(nodes): implement OpenDouParameterArea3D with conflict resolution, snapshots, and despawn safety (Task 1)"
```

---

### Task 2: OpenDouMultiPositionEmitter3D (Large Objects, Comb-Filter Suppression & Vertex Occlusion)

**Files:**
- Create: `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd`
- Create: `addons/opendou/icons/icon_multi_position_emitter_3d.svg`
- Modify: `addons/opendou/plugin.gd`
- Test: `tests/test_multi_position_emitter_3d.gd`

**Interfaces:**
- Consumes: `SpatialAcousticsManager` (for `evaluate_acoustic_path` and occlusion), `AudioStreamPlayer3D`.
- Produces: `OpenDouMultiPositionEmitter3D` node class extending `AudioStreamPlayer3D`.

- [ ] **Step 1: Write the failing tests in `tests/test_multi_position_emitter_3d.gd`**

```gdscript
class_name TestMultiPositionEmitter3DClass
extends RefCounted

const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var emitter = OpenDouMultiPositionEmitter3DClass.new()
	if emitter == null:
		failures.append("Test 1 Failed: OpenDouMultiPositionEmitter3D instantiation failed")
		return failures

	# Test 1: Closest Point Tracking
	emitter.emission_points = [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(40, 0, 0)]
	emitter.rendering_mode = 0 # CLOSEST_POINT_TRACKING
	var closest = emitter.get_closest_point_to(Vector3(18, 0, 0))
	if closest != Vector3(20, 0, 0):
		failures.append("Test 1 Failed: Closest point to (18, 0, 0) should be (20, 0, 0), got %s" % str(closest))

	# Test 2: Multi-Point Blended Position & Weights
	emitter.rendering_mode = 1 # MULTI_POINT_BLENDED
	emitter.cull_distance = 50.0
	var blended = emitter.calculate_blended_position(Vector3(10, 0, 0))
	if not is_equal_approx(blended.x, 10.0):
		failures.append("Test 2 Failed: Symmetrical blended position between 0 and 20 should be ~10.0, got %.2f" % blended.x)

	# Test 3: Envelopment Transition inside AABB
	emitter.envelopment_on_inside = true
	var is_inside = emitter.is_position_inside_emission_volume(Vector3(10, 0, 0))
	if not is_inside:
		failures.append("Test 3 Failed: Position (10, 0, 0) should be inside emission volume AABB")
	var is_outside = emitter.is_position_inside_emission_volume(Vector3(100, 0, 0))
	if is_outside:
		failures.append("Test 3 Failed: Position (100, 0, 0) should be outside emission volume AABB")

	# Test 4: Dynamic Vertices API (add, remove, clear, set)
	emitter.clear_emission_points()
	if emitter.emission_points.size() != 0:
		failures.append("Test 4 Failed: clear_emission_points did not empty array")
	emitter.add_emission_point(Vector3(5, 5, 5))
	emitter.add_emission_point(Vector3(15, 5, 5))
	if emitter.emission_points.size() != 2:
		failures.append("Test 4 Failed: add_emission_point size mismatch")
	emitter.remove_emission_point(0)
	if emitter.emission_points.size() != 1 or emitter.emission_points[0] != Vector3(15, 5, 5):
		failures.append("Test 4 Failed: remove_emission_point failed")

	# Test 5: Dynamic Points Extraction from MeshInstance3D
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(10, 2, 4)
	mesh_inst.mesh = box
	emitter.update_points_from_mesh(mesh_inst, 1)
	if emitter.emission_points.size() < 4:
		failures.append("Test 5 Failed: update_points_from_mesh extracted insufficient vertices: %d" % emitter.emission_points.size())
	mesh_inst.free()

	# Test 6: Comb-Filtering Random Phase Offset Generation
	emitter.random_phase_offset = true
	var offset1 = emitter.get_vertex_micro_phase_offset(0)
	var offset2 = emitter.get_vertex_micro_phase_offset(1)
	if offset1 == offset2:
		failures.append("Test 6 Failed: Vertex phase offsets should be distinct to prevent comb filtering")

	# Test 7: Vertex Occlusion Raycast Origin
	emitter.vertex_occlusion = true
	var occ_origin = emitter.get_occlusion_raycast_origin(Vector3(18, 0, 0))
	if occ_origin != Vector3(15, 5, 5): # active vertex
		failures.append("Test 7 Failed: Occlusion raycast origin should be the active closest vertex")

	# Test 8: Cull Distance Boundary
	var should_cull = emitter.should_cull_at_distance(Vector3(200, 0, 0))
	if not should_cull:
		failures.append("Test 8 Failed: Position at 200m should be culled with cull_distance 50m")

	emitter.free()
	return failures
```

- [ ] **Step 2: Run test suite to verify it fails**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL (file or class not found).

- [ ] **Step 3: Implement `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd` & SVG icon**

Create `addons/opendou/icons/icon_multi_position_emitter_3d.svg` and implement `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd` with enum `RenderingMode { CLOSEST_POINT_TRACKING, MULTI_POINT_BLENDED }`, closest vertex tracker, blended centroid weighting, pseudo-random micro-phase and pitch offsets per vertex, interior AABB envelopment diffuse mode, and `MeshInstance3D` vertex extraction.

- [ ] **Step 4: Register in `addons/opendou/plugin.gd`**

Register `OpenDouMultiPositionEmitter3D` with `add_custom_type` and remove on `_exit_tree`.

- [ ] **Step 5: Run test to verify it passes**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: PASS (exit code 0).

- [ ] **Step 6: Commit Task 2**

```bash
git add addons/opendou/nodes/opendou_multi_position_emitter_3d.gd addons/opendou/icons/icon_multi_position_emitter_3d.svg addons/opendou/plugin.gd tests/test_multi_position_emitter_3d.gd
git commit -m "feat(nodes): implement OpenDouMultiPositionEmitter3D with vertex occlusion, comb-filter suppression, and mesh vertex extraction (Task 2)"
```

---

### Task 3: Test Suite Integration & Task Tracking (TASK-055)

**Files:**
- Modify: `tests/test_all.gd`
- Modify: `docs/tasks/current.md`
- Modify: `docs/tasks/completed.md`

- [ ] **Step 1: Register Test Suites in `tests/test_all.gd`**

Register `TestParameterArea3DClass` (10 tests) and `TestMultiPositionEmitter3DClass` (8 tests) in `tests/test_all.gd`. Total test count will increase from 288 to 306.

- [ ] **Step 2: Run full test suite and confirm 100% pass**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: Total: 306 tests, exit code 0, 0 failures.

- [ ] **Step 3: Update `docs/tasks/current.md` and `docs/tasks/completed.md`**

Record TASK-055 completion and acceptance in project documentation.

- [ ] **Step 4: Commit Task 3**

```bash
git add tests/test_all.gd docs/tasks/current.md docs/tasks/completed.md
git commit -m "chore(tests): integrate Phase 1 spatial gameplay nodes test suites and complete TASK-055"
```
