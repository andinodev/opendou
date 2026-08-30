# 3D Volumetric Acoustic Sound Field Debugger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a visual, geometry-conforming 3D acoustic sound field debugger (`OpenDouAcousticDebugger3D`) with volumetric pulsating GDShader ripples, wall-blocked boundary compression, portal sound leakage visualization, and emitter-to-listener ray occlusion debugging.

**Architecture:** Volumetric GDShader (`acoustic_sound_field.gdshader`) + Declarative Node (`OpenDouAcousticDebugger3D`) + Editor Plugin Type (`plugin.gd`) + Demo 7 Tactical HUD Integration (`demo_cyberpunk_infiltration`).

**Tech Stack:** Godot 4.7+, GDScript (static typing), GLSL Spatial Shader, OpenDou Spatial Audio Engine.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`) to confirm 100% pass (exit code 0).

---

### Task 1: Volumetric Shader, Adaptive Mesh Generator & Core Debugger Node

**Files:**
- Create: `addons/opendou/shaders/acoustic_sound_field.gdshader`
- Create: `addons/opendou/nodes/opendou_acoustic_debugger_3d.gd`
- Create: `tests/test_acoustic_debugger.gd`
- Modify: `tests/test_all.gd`

**Requirements:**
- In `acoustic_sound_field.gdshader`:
  * Spatial shader with `render_mode blend_add, depth_draw_never, cull_disabled, unshaded`.
  * Uniforms: `base_color`, `occluded_color`, `wave_speed`, `wave_frequency`, `pulse_intensity`.
  * Renders expanding concentric acoustic ripples modulated with vertex colors (`COLOR`).
- In `OpenDouAcousticDebugger3D` (`addons/opendou/nodes/opendou_acoustic_debugger_3d.gd`):
  * Extends `Node3D`.
  * `@export var enabled: bool = true`.
  * `@export var probe_ray_count: int = 24`.
  * `@export var show_unit_size_core: bool = true`.
  * `@export var show_occlusion_rays: bool = true`.
  * `@export_flags_3d_physics var collision_mask: int = 1`.
  * Starburst ray probe calculation:
    - Casts $N$ rays around horizontal azimuth $[0, 2\pi]$ per active 3D emitter up to `max_distance`.
    - If hit collider: compresses vertex distance and tints vertex Orange/Red.
    - If clear: extends vertex to `max_distance` and tints vertex Cyan/Green.
    - Generates dynamic `ImmediateMesh` with triangle fan for the outer perimeter and circular line strip for inner `unit_size`.
  * Emitter-to-listener ray occlusion:
    - Multi-ray cast to listener position (Green = Clear, Yellow = Partial, Red = Blocked).
  * Method `func toggle_debug() -> bool`.
- In `tests/test_acoustic_debugger.gd`:
  * Unit tests for node instantiation, starburst distances calculation, ray occlusion classification, and toggle logic.
- Register `TestAcousticDebuggerClass` in `tests/test_all.gd`.

- [ ] **Step 1: Write failing tests in `tests/test_acoustic_debugger.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Implement `acoustic_sound_field.gdshader` and `opendou_acoustic_debugger_3d.gd`**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit**

---

### Task 2: Editor Plugin Registration & Custom Icon

**Files:**
- Create: `addons/opendou/icons/icon_acoustic_debugger.svg`
- Modify: `addons/opendou/plugin.gd`
- Modify: `tests/test_acoustic_debugger.gd`

**Requirements:**
- Create clean SVG icon `icon_acoustic_debugger.svg` (sonar/acoustic waves + 3D box icon).
- Register `OpenDouAcousticDebugger3D` in `addons/opendou/plugin.gd` with its icon and script path.
- Add test in `test_acoustic_debugger.gd` asserting plugin custom type registration and valid icon resource.

- [ ] **Step 1: Write failing test in `tests/test_acoustic_debugger.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Create SVG icon and update `plugin.gd`**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit**

---

### Task 3: Cyberpunk Infiltration Demo Integration & Tactical HUD Controls

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

**Requirements:**
- In `demo_cyberpunk_infiltration.tscn`:
  * Add `AcousticDebugger` (`OpenDouAcousticDebugger3D`) under `LevelGeometry`.
  * Add `BtnToggleAcoustics` (`Button`) with text `"👁️ Sound Field: ON (G)"` in `TacticalHUD`.
- In `demo_cyberpunk_infiltration.gd`:
  * Connect `BtnToggleAcoustics.pressed` and handle `KEY_G` in `_unhandled_input(event)` to toggle `acoustic_debugger.toggle_debug()`.
  * Update HUD label dynamically to `"Sound Field: ON"` or `"Sound Field: OFF"`.
- In `tests/test_cyberpunk_demo.gd`:
  * Add test verifying `AcousticDebugger` node presence and HUD toggle button wiring.
- Update `docs/tasks/completed.md` documenting `TASK-048`.

- [ ] **Step 1: Write failing test in `tests/test_cyberpunk_demo.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Wire scene and script in demo 7**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit and complete task**
