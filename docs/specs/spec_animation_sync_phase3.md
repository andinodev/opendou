# OpenDou Specification: Animation-Driven Audio Sync (Phase 3 - TASK-057)

---

## 1. Overview & Objectives

Phase 3 introduces [`OpenDouAnimationSync`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_animation_sync.gd), a declarative bridge between Godot's animation subsystem (`AnimationPlayer`, `AnimationTree`) and the OpenDou Audio Engine.

It provides frame-accurate sound synchronization for footsteps, weapon reloads, melee impacts, character vocalizations, and continuous RTPC parameter modulation driven by `AnimationTree` blend spaces (e.g. locomotion speed, strafe velocity).

---

## 2. Technical Architecture & Component Design

### 2.1 `OpenDouAnimationSync` (`addons/opendou/nodes/opendou_animation_sync.gd`)

```text
OpenDouAnimationSync (Node)
├── Target Connections
│   ├── animation_player: AnimationPlayer
│   ├── animation_tree: AnimationTree
│   └── target_emitter: Node (OpenDouEventPlayer3D / 2D / Core Event Manager)
├── Declarative Event Mapping
│   ├── event_bindings: Dictionary (StringName -> Array[Dictionary])
│   │   └── {"Run": [{"time": 0.25, "event": "Footstep_Run"}, {"time": 0.65, "event": "Footstep_Run"}]}
│   └── auto_detect_surface: bool = true
├── BlendSpace RTPC Sync
│   ├── blend_space_sync_enabled: bool = true
│   └── blend_space_rtpc_map: Dictionary (String -> StringName)
│       └── {"parameters/Locomotion/blend_position": &"Locomotion_Speed"}
└── Public Callback & Sync API
    ├── trigger_audio_event(event_name: StringName) -> void
    ├── trigger_footstep(foot_index: int = 0, surface_override: StringName = &"") -> void
    ├── set_rtpc_from_animation(rtpc_name: StringName, value: float) -> void
    ├── bind_animation_player(player: AnimationPlayer) -> void
    ├── bind_animation_tree(tree: AnimationTree) -> void
    └── process_blend_space_rtpcs() -> void
```

---

## 3. Key Functional Behaviors

### 3.1 Animation Method Track Callbacks
When an `AnimationPlayer` calls method tracks during animation playback, `OpenDouAnimationSync` provides direct slots:
* `play_audio_event(event_name: StringName)`
* `footstep(foot_index: int = 0, surface_override: StringName = &"")`
* `set_rtpc(param_name: StringName, val: float)`

### 3.2 Automated Surface Material Detection
When `footstep()` is called without an explicit surface override:
1. Performs dynamic floor querying using `SpatialAcousticsManager.detect_surface_at(global_pos)`.
2. Updates the `SurfaceType` game sync switch/state.
3. Dispatches the contextual footstep event on the bound target emitter or position.

### 3.3 Continuous BlendSpace RTPC Synchronization
On every physics/process tick:
1. Queries active blend positions from bound `AnimationTree`.
2. Normalizes parameters and dispatches updates to `AudioEventManager.set_rtpc_value()`.

---

## 4. Definition of Done (DoD) & Acceptance Criteria

1. `OpenDouAnimationSync` node compiles cleanly and is registered in `plugin.gd` with custom SVG icon `icon_animation_sync.svg`.
2. Handles direct animation method calls (`play_audio_event`, `footstep`, `set_rtpc`).
3. Supports declarative time-based timeline triggers mapped to animation clips.
4. Supports continuous `AnimationTree` blend space parameter extraction to RTPCs.
5. Handles automatic surface query integration via `SpatialAcousticsManager`.
6. Full test coverage in `tests/test_animation_sync.gd` (+10 tests).
7. 100% of all test suites passing (326+ total tests) in `godot --headless` CLI with exit code 0.
