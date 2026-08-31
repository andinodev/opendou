# Implementation Plan: Fase 3 — Sincronización de Audio por Animación (TASK-057)

Phase 3 implements [`OpenDouAnimationSync`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_animation_sync.gd) to bind Godot's animation pipeline (`AnimationPlayer` and `AnimationTree`) with OpenDou's events, footsteps, and continuous RTPC modulations.

---

## Proposed Changes

### 1. Declarative Animation Sync Node

#### [NEW] [`addons/opendou/nodes/opendou_animation_sync.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_animation_sync.gd)
- Extends `Node`, marked as `@tool`.
- Supports bindings to `AnimationPlayer` and `AnimationTree`.
- Method track receivers: `play_audio_event(event_name)`, `footstep(foot_index, surface_override)`, `set_rtpc(param_name, val)`.
- Declarative timeline mappings: `event_bindings` dictionary.
- Continuous blend space parameter extraction to RTPCs.
- Surface detection integration with `SpatialAcousticsManager`.

#### [NEW] [`addons/opendou/icons/icon_animation_sync.svg`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/icons/icon_animation_sync.svg)
- Custom SVG icon for `OpenDouAnimationSync`.

---

### 2. Editor Plugin Registration

#### [MODIFY] [`addons/opendou/plugin.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/plugin.gd)
- Register `OpenDouAnimationSyncClass` as custom type with `IconAnimationSync`.
- Clean deregistration in `_exit_tree()`.

---

### 3. Automated Verification Suite

#### [NEW] [`tests/test_animation_sync.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_animation_sync.gd)
- Test 1: Instantiation and default properties.
- Test 2: Direct method callback `play_audio_event`.
- Test 3: Footstep dispatch with automatic surface detection.
- Test 4: Footstep dispatch with surface override.
- Test 5: Animation RTPC modulation callback (`set_rtpc`).
- Test 6: `AnimationPlayer` binding and animation change tracking.
- Test 7: Declarative time-based event triggering.
- Test 8: `AnimationTree` blend space parameter extraction.
- Test 9: Target emitter routing (forwarding to `OpenDouEventPlayer3D`).
- Test 10: Robustness against missing or freed animation nodes.

#### [MODIFY] [`tests/test_all.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/tests/test_all.gd)
- Register `TestAnimationSyncClass` in master test suite (+10 tests $\to$ Total 326 tests).

---

## Verification Plan

### Automated Tests
- Run full CLI test runner:
  ```powershell
  .\godot.cmd --headless --path . -s tests/test_runner_cli.gd
  ```
- Verify 326 tests pass with 0 failures and exit code 0.
