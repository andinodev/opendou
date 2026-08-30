# Dynamic Surface & Room Acoustic Harmonization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harmonize the `SurfaceType` game sync palette, integrate physical floor surface bindings and expanded acoustic absorption presets into `OpenDouRoom3D` and `AudioRoom`, expand procedural footstep DSP in `AudioSynthesizer`, and implement 3-tier intelligent surface detection (`detect_surface_at`) in `SpatialAcousticsManager`.

**Architecture:** Data catalog (`opendou_syncs.json`) + DSP Synthesizer (`AudioSynthesizer`) + Declarative Nodes (`OpenDouRoom3D`, `AudioRoom`) + Spatial Manager (`SpatialAcousticsManager`) + Demo 7 Integration (`demo_cyberpunk_infiltration`).

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Spatial Audio Engine.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`) to confirm 100% pass (exit code 0).

---

### Task 1: Standardized Surface Palette & Procedural Footstep DSP Expansion

**Files:**
- Modify: `opendou_syncs.json`
- Modify: `addons/opendou/runtime/audio_synthesizer.gd`
- Modify: `tests/test_synth_nature.gd`

**Requirements:**
- Update `opendou_syncs.json`: Set `switches.SurfaceType` to `["Asphalt", "Concrete", "Foliage", "Glass", "Metal", "Mud", "Stone", "Tile", "Water", "Wood"]`.
- Update `AudioSynthesizer.create_footstep(surface: StringName, variation: int = 1) -> AudioStreamWAV`:
  * `&"Tile"`: Sharp high-frequency click (2800Hz / 4200Hz clicks + crisp noise).
  * `&"Foliage"` / `&"Grass"`: Crunchy organic rustle (filtered pink noise burst + rustle transient).
  * `&"Stone"` / `&"Asphalt"`: Low-mid rocky thud (220Hz + crunchy impact).
  * `&"Mud"`: Squishy low-pass thud (90Hz resonance + damp envelope).
  * `&"Glass"`: Resonant glass transient (3400Hz ping + noise).
  * `&"Wood"`, `&"Concrete"`, `&"Metal"`, `&"Water"`: Preserve existing DSP synthesis.
- Unit tests in `tests/test_synth_nature.gd` verifying all 10 surfaces generate valid `AudioStreamWAV` streams.

- [ ] **Step 1: Write failing tests in `tests/test_synth_nature.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Update `opendou_syncs.json` and `AudioSynthesizer.create_footstep()`**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit**

---

### Task 2: Declarative Room Floor Surface & Acoustic Presets

**Files:**
- Modify: `addons/opendou/runtime/spatial/audio_room.gd`
- Modify: `addons/opendou/nodes/opendou_room_3d.gd`
- Modify: `tests/test_declarative_nodes.gd`

**Requirements:**
- In `AudioRoom`: Add `var floor_surface: StringName = &"Concrete"` and `var material_preset: String = "Concrete"`.
- In `OpenDouRoom3D`:
  * Expand `material_preset` enum to: `("Concrete", "Metal", "Wood", "Glass", "Water", "Curtains", "Foliage", "Outdoor", "Custom")`.
  * Update `get_absorption()`:
    - `"Concrete"`: 0.05
    - `"Metal"`: 0.02
    - `"Wood"`: 0.15
    - `"Glass"`: 0.03
    - `"Water"`: 0.01
    - `"Curtains"`: 0.60
    - `"Foliage"`: 0.85
    - `"Outdoor"`: 0.95
    - `"Custom"`: `absorption_coefficient`
  * Add `@export var floor_surface: StringName = &"Concrete"`.
  * Pass `floor_surface` and `material_preset` to `runtime_room` in `register_in_manager()` and `calculate_sabine_reverb()`.
- Unit tests in `tests/test_declarative_nodes.gd` verifying absorption presets and `floor_surface` propagation.

- [ ] **Step 1: Write failing tests in `tests/test_declarative_nodes.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Implement in `audio_room.gd` and `opendou_room_3d.gd`**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit**

---

### Task 3: Intelligent 3-Tier Surface Detection Engine & Cyberpunk Demo Integration

**Files:**
- Modify: `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `tests/test_spatial_acoustics.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

**Requirements:**
- In `SpatialAcousticsManager`:
  * Implement `detect_surface_at(pos: Vector3, world_3d: World3D = null) -> StringName`:
    - Priority 1: Direct 3D physics raycast downward ($pos + (0, 0.5, 0) \to pos + (0, -1.5, 0)$). Checks metadata `surface_type`, physics material resource name, or collider name keyword.
    - Priority 2: Enclosing `AudioRoom.floor_surface` from `get_room_at_position(pos)`.
    - Priority 3: Fallback `&"Concrete"`.
- In `demo_cyberpunk_infiltration.tscn`:
  * Configure room `floor_surface` properties:
    - `RooftopRoom`: `floor_surface = &"Concrete"`
    - `ServerRoomArea`: `floor_surface = &"Metal"`
    - `DrainageRoom`: `floor_surface = &"Water"`
    - `ExtractionArenaRoom`: `floor_surface = &"Tile"`
    - `BiosphereRoom`: `floor_surface = &"Foliage"`
- In `demo_cyberpunk_infiltration.gd`:
  * Update `detect_footstep_surface(pos: Vector3)` to call `spatial_acoustics.detect_surface_at(pos, get_world_3d())`.
- Unit tests in `tests/test_spatial_acoustics.gd` and `tests/test_cyberpunk_demo.gd`.
- Update `docs/tasks/completed.md` documenting `TASK-047`.

- [ ] **Step 1: Write failing tests in `tests/test_spatial_acoustics.gd`**
- [ ] **Step 2: Run tests to verify failure**
- [ ] **Step 3: Implement `detect_surface_at()` and wire demo scene**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Commit and complete task**
