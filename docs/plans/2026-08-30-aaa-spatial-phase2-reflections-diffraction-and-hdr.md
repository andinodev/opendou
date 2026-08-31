# Implementation Plan: AAA Spatial Acoustics Phase 2 — Early Reflections, Edge Diffraction, Room Coupling, Acoustic LOD & HDR Audio (TASK-052)

**Status:** READY FOR REVIEW  
**Author:** Antigravity / OpenDou Core Team  
**Date:** 2026-08-30  
**Phase:** 2 of 3 (TASK-052)  
**Spec Reference:** `docs/specs/spec_aaa_spatial_phase2_reflections_diffraction_and_hdr.md`

---

## 1. Overview & Architecture

Phase 2 introduces high-fidelity physical propagation modules into OpenDou:
- **`AcousticReflectorEngine` (`addons/opendou/runtime/spatial/acoustic_reflector_engine.gd`):** 6x image-source raytracer computing surface reflection arrival delays ($t_i = (d_1+d_2)/c$), material absorption gains ($g_i = (1-\alpha)/\sqrt{1+d/5}$), and reflection LPF.
- **`EdgeDiffractionEngine` (`addons/opendou/runtime/spatial/edge_diffraction_engine.gd`):** Huygens-Fresnel obstacle edge finder, shadow angle calculation, virtual sound origin bending, and smooth diffraction lowpass filtering ($f = 20000 \cdot \cos^2(\theta/2)$).
- **`RoomCouplingEngine` (`addons/opendou/runtime/spatial/room_coupling_engine.gd`):** Energy coupling across portals, inter-room reverb tail excitation, and proximity-based angular sound spread.
- **`AcousticLODController` (`addons/opendou/runtime/spatial/acoustic_lod_controller.gd`):** 4-tier LOD governor (LOD 0: Full 6x raytracing, LOD 1: Single raycast, LOD 2: 3D Panning, LOD 3: Virtual Voice Culling).
- **`HDRAudioManager` (`addons/opendou/runtime/spatial/hdr_audio_manager.gd`):** Dynamic range loudness window, transient peak detection, and background ambient ducking with smooth exponential release.

---

## 2. Bite-Sized Implementation Tasks

### Task 1: 6x Image-Source Early Reflections Raytracer (`AcousticReflectorEngine`)
- **TDD:** Create `tests/test_spatial_acoustics_phase2.gd` with Test 1 & Test 2:
  - Test 1: 6x ray generation, reflection arrival delays for distance $10\text{ m}$ ($t \approx 0.029\text{ s}$), and virtual image source coordinate calculation.
  - Test 2: Material absorption responses (Metal reflection gain > Foliage reflection gain, LPF cutoff matching material resonance).
- **Implementation:** Implement `addons/opendou/runtime/spatial/acoustic_reflector_engine.gd`.
- **Verification:** Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`.
- **Commit:** `feat(spatial): implement 6x image-source early reflections raytracer (Task 1 - TASK-052)`

### Task 2: Huygens-Fresnel Obstacle Edge Diffraction (`EdgeDiffractionEngine`)
- **TDD:** Add Test 3 & Test 4 in `tests/test_spatial_acoustics_phase2.gd`:
  - Test 3: Edge shadow angle calculation around an obstacle corner.
  - Test 4: Virtual origin bending towards corner and diffraction LPF cutoff curve ($f(\theta)$).
- **Implementation:** Implement `addons/opendou/runtime/spatial/edge_diffraction_engine.gd`.
- **Verification:** Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`.
- **Commit:** `feat(spatial): implement Huygens-Fresnel edge diffraction engine (Task 2 - TASK-052)`

### Task 3: Inter-Room Reverb Coupling & Portal Sound Spread (`RoomCouplingEngine`)
- **TDD:** Add Test 5 & Test 6 in `tests/test_spatial_acoustics_phase2.gd`:
  - Test 5: Reverb tail energy coupling across portals connecting reverberant rooms.
  - Test 6: Angular sound spread calculation ($15^\circ$ distant $\to 180^\circ$ at portal threshold).
- **Implementation:** Implement `addons/opendou/runtime/spatial/room_coupling_engine.gd`.
- **Verification:** Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`.
- **Commit:** `feat(spatial): implement inter-room reverb coupling and portal sound spread (Task 3 - TASK-052)`

### Task 4: 4-Tier Acoustic LOD & Voice Culling Governor (`AcousticLODController`)
- **TDD:** Add Test 7 & Test 8 in `tests/test_spatial_acoustics_phase2.gd`:
  - Test 7: LOD evaluation by distance ($0-10\text{m} \to \text{LOD 0}$, $10-25\text{m} \to \text{LOD 1}$, $25-50\text{m} \to \text{LOD 2}$, $>50\text{m} \to \text{LOD 3}$).
  - Test 8: Feature enablement flags matching assigned LOD level.
- **Implementation:** Implement `addons/opendou/runtime/spatial/acoustic_lod_controller.gd`.
- **Verification:** Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`.
- **Commit:** `feat(spatial): implement 4-tier Acoustic LOD and scalability governor (Task 4 - TASK-052)`

### Task 5: HDR Audio Dynamic Range Loudness Window (`HDRAudioManager`)
- **TDD:** Add Test 9 & Test 10 in `tests/test_spatial_acoustics_phase2.gd`:
  - Test 9: HDR loudness window tracking and dynamic ducking threshold on loud transient events.
  - Test 10: Smooth exponential release decay over time.
- **Implementation:** Implement `addons/opendou/runtime/spatial/hdr_audio_manager.gd`.
- **Verification:** Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (confirm 100% tests pass).
- **Commit:** `feat(spatial): implement HDR Audio dynamic range loudness window and complete TASK-052 (Task 5)`

---

## 3. Definition of Done
- All 5 sub-tasks implemented with dedicated unit tests in `tests/test_spatial_acoustics_phase2.gd`.
- `tests/test_all.gd` registered with updated test count.
- `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` passes 100% (code 0, 0 failures).
- `docs/tasks/completed.md` and `docs/tasks/current.md` updated.
