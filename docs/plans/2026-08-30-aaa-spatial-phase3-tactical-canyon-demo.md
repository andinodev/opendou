# Plan: AAA Spatial Acoustics Phase 3 — Tactical Canyon Showcase Demo

## Executive Summary
Implement the interactive 3D tactical showcase demo `scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn` to demonstrate and validate all Phase 1 and Phase 2 AAA spatial audio features, declarative 3D audio nodes, HUD controls, and real-time physics acoustics.

---

## Tasks Breakdown

### Task 1: Demo Logic Controller & Runtime Systems (`demo_tactical_canyon.gd`)
- Implement `OpenDouTacticalCanyonDemo` with:
  - Teleportation to 5 tactical sectors.
  - River spline emitter controller and closest virtual point listener query.
  - Interactive bunker air-lock door toggle with `OpenDouPortal3D` aperture update.
  - Material test lab evaluator comparing Concrete, Metal, Wood, and Foliage transmission loss.
  - High-speed drone orbit motion with Doppler evaluation and Acoustic LOD state updates.
  - HDR detonation trigger and dynamic range ducking.
  - Tactical HUD buttons, stats display, and acoustic visualizer toggle.

### Task 2: Declarative 3D Scene Assembly (`demo_tactical_canyon.tscn`)
- Build declarative `.tscn` scene with:
  - `WorldEnvironment` and directional lighting.
  - 5 Sector geometry zones with CSG meshes and collision bodies.
  - `OpenDouSplineEmitter3D` on Sector 1 riverbed with `Curve3D`.
  - `OpenDouRoom3D` nodes for Canyon Exterior, Bunker Interior, and Material Testing Chamber.
  - `OpenDouPortal3D` for the bunker doorway.
  - `OpenDouAcousticDebugger3D` for real-time sound field visualization.
  - Tactical HUD control canvas with top/bottom bars, stats panel, and `OpenDouAudibleMonitor`.

### Task 3: DemoHub Registration & Verification Test Suite (`test_tactical_canyon_demo.gd`)
- Register Demo 8 in `scenes/demos/demo_hub.gd` and `demo_hub.tscn`.
- Create unit/integration test suite `tests/test_tactical_canyon_demo.gd` testing:
  - Scene loading and node hierarchy integrity.
  - Teleportation to all 5 sectors.
  - Spline emitter closest point tracking.
  - Air-lock portal open/close state and reverb coupling.
  - Material mass law comparison (Concrete vs Metal vs Wood vs Foliage).
  - Doppler drone velocity evaluation and LOD tier transitions.
  - HDR detonation trigger and ducking recovery.
- Register in `tests/test_all.gd` and confirm 100% test pass.
