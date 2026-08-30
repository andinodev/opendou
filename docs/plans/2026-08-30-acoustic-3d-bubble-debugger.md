# 3D Volumetric Acoustic Iso-Bubble & Multi-Selection Debugger Implementation Plan (TASK-049)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `OpenDouAcousticDebugger3D` to generate true **3D Deformable Geodesic Iso-Spheres (Acoustic Bubbles)** with spherical 3D ray probing (floors, ceilings, walls, doorways), Fresnel holographic shader, and **multi-selection targeting** (`show_in_editor = false` by default, `display_mode = Only_Selected`).

**Architecture:** Geodesic 3D Sphere Ray Probing + 3D Mesh Normal Generation + Holographic Fresnel Shader + Selection-Driven Filtering.

**Tech Stack:** Godot 4.7+, GDScript (static typing), GLSL Spatial Shader, OpenDou Spatial Audio Engine.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`) to confirm 100% pass (exit code 0).

---

### Task 1: 3D Geodesic Ray Probe Generator, Holographic Fresnel Shader & Multi-Selection Logic

**Files:**
- Modify: `addons/opendou/shaders/acoustic_sound_field.gdshader`
- Modify: `addons/opendou/nodes/opendou_acoustic_debugger_3d.gd`
- Modify: `tests/test_acoustic_debugger.gd`

**Requirements:**
- In `acoustic_sound_field.gdshader`:
  * Add `uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;`.
  * Compute spatial Fresnel glow: `float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);`.
  * Render 3D wave ripples based on `length(VERTEX)` and blend with Fresnel rim.
- In `OpenDouAcousticDebugger3D` (`addons/opendou/nodes/opendou_acoustic_debugger_3d.gd`):
  * Add `@export var show_in_editor: bool = false`.
  * Add `@export_enum("Only_Selected", "Active_Audible_Only", "All_Emitters") var display_mode: int = 0`.
  * Add `@export var selected_emitters: Array[NodePath] = []`.
  * Implement 3D Geodesic / Spherical Ray Sampling:
    * `func generate_sphere_probe_directions(rings: int = 6, segments: int = 12) -> Array[Vector3]`
    * `func calculate_spherical_bubble_mesh(emitter_pos: Vector3, max_dist: float, space_state: PhysicsDirectSpaceState3D = null, rings: int = 6, segments: int = 12) -> Dictionary`
      - Returns vertices, normals, colors (Orange/Red for hit, Cyan for clear), and triangular indices for the entire 3D bubble.
    * In editor (`Engine.is_editor_hint()`):
      - If `not show_in_editor`: do not render.
      - If `show_in_editor` and `display_mode == 0` (`Only_Selected`): inspect `EditorInterface.get_selection().get_selected_nodes()` and only render for selected audio emitters.
    * In runtime:
      - If `display_mode == 0` (`Only_Selected`): render for `selected_emitters` or focused emitter.
      - If `display_mode == 1` (`Active_Audible_Only`): render only currently playing emitters.
      - If `display_mode == 2` (`All_Emitters`): render all.
- In `tests/test_acoustic_debugger.gd`:
  * Tests for `show_in_editor` default `false`, `display_mode` enum, 3D sphere ray generation (top, bottom, lateral), spherical mesh dictionary (vertices, normals, indices), and selection filtering.

- [ ] **Step 1: Write failing tests in `tests/test_acoustic_debugger.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Implement 3D spherical bubble generator, Fresnel shader, and selection modes**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit**

---

### Task 2: Cyberpunk Demo Integration & Verification

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`
- Modify: `docs/tasks/current.md`

**Requirements:**
- In `demo_cyberpunk_infiltration.gd`:
  * When cycling sectors or clicking emitters, set `acoustic_debugger.selected_emitters` to focus the bubble on that specific emitter.
  * Update HUD label to reflect `[ 👁️ 3D Bubble: Focused / Target ]`.
- In `tests/test_cyberpunk_demo.gd`:
  * Verify 3D bubble targeting and HUD display.
- Update `docs/tasks/completed.md` documenting `TASK-049`.
- Run full test suite (`.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`, 100% pass, exit code 0).

- [ ] **Step 1: Write failing tests in `tests/test_cyberpunk_demo.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Update demo script and HUD**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit and complete task**
