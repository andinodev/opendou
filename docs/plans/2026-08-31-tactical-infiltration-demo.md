# Implementation Plan: Demo 09 — Nivel de Infiltración Táctica AAA (TASK-058)

Build the interactive showcase level `scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn` integrating all 13 OpenDou nodes and runtime spatial/DSP engines.

---

## User Review Required

> [!IMPORTANT]
> - All 13 OpenDou node types will be instantiated declaratively in `demo_tactical_infiltration.tscn`.
> - Player locomotion dynamically demonstrates `OpenDouAnimationSync`, automated surface raycasting (`detect_surface_at` between Stone and Metal), axis gradient parameter modulation in the toxic corridor, spline audio tracking, granular spore particles, acoustic baking, and multi-position engine emission.

---

## Proposed Changes

### 1. Infiltration Level Scene & Control Logic

#### [NEW] [`scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn)
- Declarative `.tscn` scene tree containing:
  - `Acoustic_Processor` (`OpenDouAcousticGeometryBake`)
  - `Outer_Cavern` (`OpenDouRoom3D`, `OpenDouReflector3D`, `OpenDouSplineEmitter3D`)
  - `Toxic_Corridor` (`OpenDouParameterArea3D`, `OpenDouGranularEmitter3D`)
  - `Bunker_Complex` (`OpenDouPortal3D`, `OpenDouRoom3D`, `OpenDouMultiPositionEmitter3D`)
  - `Player_Rig` (`CharacterBody3D`, `AudioListener3D`, `AnimationTree`, `OpenDouAnimationSync`)
  - `Elite_Enemy` (`CharacterBody3D`, `AnimationPlayer`, `OpenDouAnimationSync`, `OpenDouEventPlayer3D`)
  - `Dynamic_Soundtrack` (`OpenDouMusicPlayer`)
  - `Acoustic_Debugger` (`OpenDouAcousticDebugger3D`)
  - `TacticalHUD` (`CanvasLayer`, `OpenDouAudibleMonitor`)

#### [NEW] [`scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.gd)
- Controller script managing:
  - WASD / Arrow key movement and camera control.
  - Sector teleportation (Sector 1: Cavern, Sector 2: Toxic Corridor, Sector 3: Bunker Generator, Sector 4: Combat Overlook).
  - Interactive blast door toggling (`open_door()`, `close_door()`) with portal obstruction updates.
  - Radio dialogue triggers and enemy alert states.
  - Live HUD telemetry (current room, detected surface, active RTPCs, FPS, voice count).

---

### 2. Demo Hub Integration

#### [MODIFY] [`scenes/demos/demo_hub.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/demo_hub.gd)
- Add Demo 9 entry to `DEMO_SCENES` mapping.
- Connect launch button.

#### [MODIFY] [`scenes/demos/demo_hub.tscn`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/demo_hub.tscn)
- Add Demo 9 card in Hub UI.

---

### 3. Automated Verification Suite

#### [NEW] [`tests/test_tactical_infiltration_demo.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_tactical_infiltration_demo.gd)
- Test 1: Scene instantiation & tree validation of all 13 OpenDou nodes.
- Test 2: Sector teleportation positions.
- Test 3: Acoustic Geometry Bake execution and triangle extraction.
- Test 4: Toxic Corridor gradient RTPC modulation.
- Test 5: Blast door toggle and portal obstruction update.
- Test 6: Footstep surface detection (Stone in Cavern vs Metal in Bunker).
- Test 7: Generator multi-position closest point tracking.
- Test 8: Player AnimationSync blendspace speed extraction.
- Test 9: Enemy AnimationSync event dispatch.
- Test 10: HUD monitor and telemetry update.

#### [MODIFY] [`tests/test_all.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_all.gd)
- Register `TestTacticalInfiltrationDemoClass` in master test suite (+10 tests $\to$ Total 336 tests).

---

## Verification Plan

### Automated Tests
- Run full CLI test runner:
  ```powershell
  .\godot.cmd --headless --path . -s tests/test_runner_cli.gd
  ```
- Verify 336 tests pass with 0 failures and exit code 0.
