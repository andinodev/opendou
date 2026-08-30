# Biosphere 7.1 Surround Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create **Sector 5: Cyber-Biosphere Sanctuary (7.1 Surround)** in [`demo_cyberpunk_infiltration.tscn`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn) demonstrating 7.1 discrete channel mapping, high foliage acoustic absorption, organic procedural audio synthesis, and 360° orbiting wildlife panning.

**Architecture:** Procedural nature synthesis in `AudioSynthesizer` + declarative 7.1 `OpenDouEventPlayer3D` emitters + `OpenDouRoom3D` with Sabine vegetation absorption + HUD integration.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core Engine.

---

### Task 1: Nature Audio Procedural Synthesis Extensions

**Files:**
- Modify: `addons/opendou/runtime/audio_synthesizer.gd`
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd`
- Modify: `addons/opendou/nodes/opendou_event_player.gd`
- Create: `tests/test_synth_nature.gd`
- Modify: `tests/test_all.gd`

- [ ] **Step 1: Write test for new nature synthesis algorithms**

```gdscript
# tests/test_synth_nature.gd
class_name TestSynthNature
extends RefCounted

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var Synth = load("res://addons/opendou/runtime/audio_synthesizer.gd")
	
	var wind = Synth.create_canopy_wind_loop(1.0)
	if wind == null or wind.data.is_empty():
		failures.append("Test 1 Failed: create_canopy_wind_loop returned null or empty data")
		
	var bird = Synth.create_bird_chirp(2400.0, 0.2)
	if bird == null or bird.data.is_empty():
		failures.append("Test 2 Failed: create_bird_chirp returned null or empty data")
		
	var thunder = Synth.create_thunder_rumble(1.0)
	if thunder == null or thunder.data.is_empty():
		failures.append("Test 3 Failed: create_thunder_rumble returned null or empty data")
		
	var cicada = Synth.create_cicada_swarm_loop(1.0)
	if cicada == null or cicada.data.is_empty():
		failures.append("Test 4 Failed: create_cicada_swarm_loop returned null or empty data")
		
	var drop = Synth.create_water_droplet(1200.0)
	if drop == null or drop.data.is_empty():
		failures.append("Test 5 Failed: create_water_droplet returned null or empty data")
		
	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement synthesis methods and presets**

Add algorithms in `AudioSynthesizer` and preset matches in `OpenDouEventPlayer3D` and `OpenDouEventPlayer`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/audio_synthesizer.gd addons/opendou/nodes/ tests/test_synth_nature.gd tests/test_all.gd
git commit -m "feat(synth): implement procedural nature synthesis algorithms and presets (Task 1)"
```

---

### Task 2: Declarative 3D Assembly of Sector 5 (Biosphere 7.1) in Scene

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `tests/test_cyberpunk_demo.gd`

- [ ] **Step 1: Write test checking Sector 5 nodes in scene**

Add test assertions in `tests/test_cyberpunk_demo.gd` for `Sector5_Biosphere`, `BiosphereRoom`, `CanopyWind_FL`, `Waterfall_FR`, `Bird_C`, `Thunder_LFE`, `Cicada_SL`, `Frog_SR`, `Rain_RL`, `Droplet_RR`, `OrbitingBeeEmitter`, and `BtnSector5`.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Assemble Sector 5 in `demo_cyberpunk_infiltration.tscn`**

Build greenhouse dome CSG geometry, materials, emerald lighting, `OpenDouRoom3D`, `OpenDouPortal3D`, and 7.1 discrete positional emitters.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn tests/test_cyberpunk_demo.gd
git commit -m "feat(demos): assemble Sector 5 Biosphere 7.1 surround in cyberpunk scene (Task 2)"
```

---

### Task 3: Gameplay Coordinator Integration & Telemetry Verification

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

- [ ] **Step 1: Implement Sector 5 teleport, footstep surface, and orbiting audio in coordinator**

Update `SECTOR_POSITIONS`, `detect_footstep_surface()`, `_connect_ui()`, and add orbiting wildlife movement in `_process()`.

- [ ] **Step 2: Run full regression test suite**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing, exit code 0)

- [ ] **Step 3: Commit and update documentation**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd tests/test_cyberpunk_demo.gd docs/tasks/completed.md
git commit -m "feat(demos): wire Sector 5 7.1 surround teleportation and 360 orbiting audio (Task 3)"
```
