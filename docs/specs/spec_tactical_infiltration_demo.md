# OpenDou Specification: Tactical Infiltration Showcase Demo (TASK-058)

---

## 1. Overview & Objectives

The **Tactical Infiltration Showcase Demo (Demo 09)** is a dark fantasy / tactical infiltration environment designed to demonstrate the complete OpenDou node suite working in harmony in an interactive, performant 3D level.

It validates:
1. **Offline Acoustic Geometry Baking (`OpenDouAcousticGeometryBake`):** Static obstacles pre-processed into lightweight acoustic triangles for CPU Möller–Trumbore occlusion raycasting.
2. **Dynamic Gradient Volume (`OpenDouParameterArea3D`):** Toxic Spore Corridor modulated along the Z-axis (`AXIS_GRADIENT`) driving RTPC `Toxic_Tension` and triggering global acoustic snapshots.
3. **Continuous Spline River (`OpenDouSplineEmitter3D`):** Underground subterranean toxic river with continuous curve tracking.
4. **Volumetric Spore Particles (`OpenDouGranularEmitter3D`):** Stochastic granular micro-emitter generating ambient toxic spore particles.
5. **Early Reflections (`OpenDouReflector3D`):** First-order acoustic reflections from cavern rock walls.
6. **Multi-Room Coupling & Portals (`OpenDouRoom3D`, `OpenDouPortal3D`):**
   * `Outer_Cavern` (Stone floor, natural reverb).
   * `Generator_Room` (Metal floor, short metallic reverb).
   * `Access_Portal` linking both sectors with dynamic opening/closing door obstruction.
7. **Massive Distributed Source (`OpenDouMultiPositionEmitter3D`):** Multi-vertex `Main_Generator` engine with closest-vertex tracking and comb-filter phase compensation.
8. **Animation Synchronization & Footsteps (`OpenDouAnimationSync`):**
   * Player Rig: `AnimationTree` blend space driving fatigue/speed RTPC + `footstep()` callbacks querying floor surface dynamically (Metal vs Stone).
   * Elite Enemy: `AnimationPlayer` driving voice alerts and patrol method tracks.
9. **Interactive Soundtrack (`OpenDouMusicPlayer`):** Tension and combat intensity transitions.
10. **Tactical Telemetry & Visualizers (`OpenDouAudibleMonitor`, `OpenDouAcousticDebugger3D`):** In-game tactical HUD showing live audio metrics, dialogue radio telemetry, and 3D volumetric acoustic fields.

---

## 2. Scene Architecture (`scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn`)

```text
World_Root (Node3D - demo_tactical_infiltration.gd)
├── Level_Lighting
│   ├── DirectionalLight3D
│   └── WorldEnvironment
├── Acoustic_Processor (OpenDouAcousticGeometryBake)
├── Environment_Geometry
│   ├── Outer_Cavern (OpenDouRoom3D - Floor: Stone, absorption: Stone)
│   │   ├── Cavern_Floor_Mesh (MeshInstance3D - Group: AcousticObstacle, meta: stone)
│   │   ├── Cavern_Reflector (OpenDouReflector3D)
│   │   └── Underground_River (OpenDouSplineEmitter3D)
│   ├── Toxic_Corridor (OpenDouParameterArea3D - AXIS_GRADIENT)
│   │   ├── Toxic_Spores (OpenDouGranularEmitter3D)
│   │   └── Corridor_Mesh (MeshInstance3D - Group: AcousticObstacle, meta: concrete)
│   └── Bunker_Complex
│       ├── Access_Portal (OpenDouPortal3D)
│       │   └── Blast_Door (StaticBody3D)
│       └── Generator_Room (OpenDouRoom3D - Floor: Metal, absorption: Metal)
│           ├── Bunker_Floor_Mesh (MeshInstance3D - Group: AcousticObstacle, meta: metal)
│           └── Main_Generator (OpenDouMultiPositionEmitter3D)
├── Characters
│   ├── Player_Rig (CharacterBody3D)
│   │   ├── CollisionShape3D
│   │   ├── AudioListener3D
│   │   ├── AnimationTree
│   │   └── AnimationSync (OpenDouAnimationSync)
│   └── Elite_Enemy (CharacterBody3D)
│       ├── CollisionShape3D
│       ├── AnimationPlayer
│       ├── VoiceEmitter (OpenDouEventPlayer3D)
│       └── EnemyAnimationSync (OpenDouAnimationSync)
├── Systems
│   ├── Dynamic_Soundtrack (OpenDouMusicPlayer)
│   └── Acoustic_Debugger (OpenDouAcousticDebugger3D)
└── TacticalHUD (CanvasLayer)
    ├── AudibleMonitor (OpenDouAudibleMonitor)
    ├── TelemetryPanel (PanelContainer)
    └── ControlsPanel (PanelContainer)
```

---

## 3. Definition of Done (DoD) & Acceptance Criteria

1. Declarative `.tscn` file created at `scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.tscn` with all physical geometries, lighting, rooms, portals, emitters, character rigs, and UI.
2. Control script `scenes/demos/09_tactical_infiltration/demo_tactical_infiltration.gd` implementing sector teleportation, interactive blast doors, player movement, enemy patrolling, HUD telemetry, and audio triggers.
3. Integrated into `scenes/demos/demo_hub.tscn` and `demo_hub.gd` as Demo 09.
4. Comprehensive test suite in `tests/test_tactical_infiltration_demo.gd` (+10 tests).
5. 100% of all unit/integration tests passing (336+ tests) in `godot --headless` CLI with exit code 0.
