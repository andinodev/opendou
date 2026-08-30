# Cyberpunk Infiltration AAA Showcase Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a high-end, immersive 3D showcase demo scene ("Cyberpunk Infiltration: Sector 7") demonstrating all OpenDou AAA audio systems working together in real time (multi-stem adaptive DAW music, Sabine room acoustics with portal diffraction, raycast occlusion, sidechain ducking matrix, surface switch containers, 250-voice pooling stress test, multi-language voice localization, and 2D spatial acoustic radar HUD).

**Architecture:** A declaratively-assembled `.tscn` scene with 4 contiguous acoustic sectors wired to a modular GDScript coordinator (`OpenDouCyberpunkInfiltrationDemo`). Logic connects directly to OpenDou's core runtime managers (`SpatialAcousticsManager`, `VoicePoolManager`, `AudioDuckingMatrix`, `AudioDialogueManager`, `MusicPlaylistManager`, and `OpenDouRadarView`).

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Audio Engine & Spatial Acoustics Core.

## Global Constraints
- Scene must be built as a declarative `.tscn` file (`scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`).
- GDScript code must use explicit static typing and English identifiers.
- All headless test suites must execute cleanly via `godot --headless -s tests/test_runner_cli.gd` with exit code 0.

---

### Task 1: Declarative 3D Scene Assembly (`demo_cyberpunk_infiltration.tscn`)

**Files:**
- Create: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Test: `tests/test_cyberpunk_demo.gd`

**Interfaces:**
- Produces: Declarative `.tscn` hierarchy with WorldEnvironment, DirectionalLight3D, LevelGeometry (Sectors 1 to 4), Player, Emitters, and Tactical HUD CanvasLayer.

- [ ] **Step 1: Write the failing test verifying scene file existence and structure**

```gdscript
# tests/test_cyberpunk_demo.gd
class_name TestCyberpunkDemo
extends RefCounted

const SCENE_PATH: String = "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn"

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists(SCENE_PATH):
		failures.append("Test 1 Failed: demo_cyberpunk_infiltration.tscn does not exist")
		return failures
		
	var scene_res = load(SCENE_PATH)
	if not scene_res or not (scene_res is PackedScene):
		failures.append("Test 1b Failed: demo_cyberpunk_infiltration.tscn failed to load as PackedScene")
		return failures
		
	var instance = scene_res.instantiate()
	if not instance:
		failures.append("Test 1c Failed: demo_cyberpunk_infiltration scene instantiation failed")
		return failures
		
	if not instance.has_node("LevelGeometry/Sector1_Rooftop") or not instance.has_node("LevelGeometry/Sector2_ServerRoom"):
		failures.append("Test 1d Failed: Scene missing Sector 1 or Sector 2 geometry nodes")
	if not instance.has_node("LevelGeometry/Sector3_FloodedDrainage") or not instance.has_node("LevelGeometry/Sector4_ExtractionArena"):
		failures.append("Test 1e Failed: Scene missing Sector 3 or Sector 4 geometry nodes")
	if not instance.has_node("TacticalHUD"):
		failures.append("Test 1f Failed: Scene missing TacticalHUD CanvasLayer node")
		
	instance.free()
	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL ("demo_cyberpunk_infiltration.tscn does not exist")

- [ ] **Step 3: Create the declarative `.tscn` scene file**

Assemble `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn` with CSG geometry for the 4 sectors, lighting, Player controller, and TacticalHUD.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn tests/test_cyberpunk_demo.gd
git commit -m "feat(demos): assemble declarative 3D scene for Cyberpunk Infiltration demo (Task 1)"
```

---

### Task 2: Scene Coordinator & Logic Controller (`demo_cyberpunk_infiltration.gd`)

**Files:**
- Create: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Test: `tests/test_cyberpunk_demo.gd`

**Interfaces:**
- Consumes: `SpatialAcousticsManager`, `AudioRoom`, `AudioPortal`, `VoicePoolManager`, `AudioDuckingMatrix`, `AudioDialogueManager`, `MusicPlaylistManager`.
- Produces: `OpenDouCyberpunkInfiltrationDemo` class with methods `teleport_to_sector(idx)`, `toggle_server_airlock()`, `set_combat_intensity(val)`, `set_voice_locale(loc)`, `trigger_siege_bombardment()`.

- [ ] **Step 1: Write the failing test for coordinator initialization and acoustic sectors**

```gdscript
# Add to tests/test_cyberpunk_demo.gd
	var demo = load("res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd").new()
	if demo.spatial_acoustics == null or demo.spatial_acoustics.rooms.size() < 3:
		failures.append("Test 2a Failed: SpatialAcousticsManager not initialized with 3 rooms")
	if demo.server_portal == null or demo.server_portal.portal_name != &"Server_Airlock":
		failures.append("Test 2b Failed: Server_Airlock portal not registered")
	if demo.music_director == null or demo.ducking_matrix == null:
		failures.append("Test 2c Failed: Music Director or Ducking Matrix not initialized")
		
	# Test airlock portal toggle
	demo.is_airlock_open = true
	demo.toggle_server_airlock()
	if demo.is_airlock_open or demo.server_portal.open_factor > 0.1:
		failures.append("Test 2d Failed: Server airlock portal toggle failed to close portal")
		
	demo.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `demo_cyberpunk_infiltration.gd` coordinator logic**

Implement `OpenDouCyberpunkInfiltrationDemo` with room registrations, portal diffraction setup, ducking matrix rules, music playlist initialization, and player teleportation logic.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn tests/test_cyberpunk_demo.gd
git commit -m "feat(demos): implement coordinator and acoustics logic for Cyberpunk Infiltration demo (Task 2)"
```

---

### Task 3: Footstep Surface Detection & 250-Voice Siege Bombardment

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Test: `tests/test_cyberpunk_demo.gd`

**Interfaces:**
- Consumes: `VoicePoolManager`, `AudioEventDef`, `EventInstance`, `AudioSynthesizer`.
- Produces: `detect_footstep_surface(position: Vector3) -> StringName`, `trigger_siege_bombardment()`.

- [ ] **Step 1: Write the failing test for surface switch and voice stress bombardment**

```gdscript
# Add to tests/test_cyberpunk_demo.gd
	var demo_stress = load("res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd").new()
	# Surface detection test
	var surf_roof = demo_stress.detect_footstep_surface(Vector3(-25, 1, 0))
	var surf_server = demo_stress.detect_footstep_surface(Vector3(0, 1, 0))
	var surf_drain = demo_stress.detect_footstep_surface(Vector3(25, 1, 0))
	var surf_heli = demo_stress.detect_footstep_surface(Vector3(50, 1, 0))
	if surf_roof != &"Metal" or surf_server != &"Tile" or surf_drain != &"Water" or surf_heli != &"Concrete":
		failures.append("Test 3a Failed: Footstep surface detection mismatch for sectors")
		
	# Bombardment test
	demo_stress.trigger_siege_bombardment()
	if demo_stress.bombardment_instances.size() != 250:
		failures.append("Test 3b Failed: Siege bombardment did not spawn 250 audio event instances")
	var phys_count = demo_stress.voice_pool.get_active_physical_count()
	if phys_count > 16:
		failures.append("Test 3c Failed: Hardware voice pool exceeded 16 physical voices")
		
	demo_stress.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement surface detection and bombardment logic**

Implement `detect_footstep_surface()` and `trigger_siege_bombardment()` in `demo_cyberpunk_infiltration.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd tests/test_cyberpunk_demo.gd
git commit -m "feat(demos): add surface switch detection and 250-voice siege bombardment (Task 3)"
```

---

### Task 4: Interactive Tactical HUD & Spatial Radar Integration

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Test: `tests/test_cyberpunk_demo.gd`

**Interfaces:**
- Consumes: `OpenDouRadarView`, `AudioDialogueTable`, `AudioDuckingMatrix`.
- Produces: Interactive HUD telemetry display, sector selector buttons, language toggle, and 2D spatial acoustic radar.

- [ ] **Step 1: Write the failing test for HUD telemetry updates and dialogue ducking**

```gdscript
# Add to tests/test_cyberpunk_demo.gd
	var demo_hud = load("res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn").instantiate()
	demo_hud._ready()
	
	# Test localized dialogue and ducking
	demo_hud.play_tactical_radio_line(&"sec_clear_01", "es")
	if demo_hud.dialogue_manager.current_language != "es":
		failures.append("Test 4a Failed: Dialogue language failed to switch to Spanish")
	var gr = demo_hud.ducking_matrix.get_gain_reduction_db(&"Voice", &"Music")
	if gr > -10.0:
		failures.append("Test 4b Failed: Ducking matrix failed to attenuate Music when Voice is active")
		
	# Test radar view binding
	if demo_hud.radar_view == null or not (demo_hud.radar_view is OpenDouRadarView):
		failures.append("Test 4c Failed: Radar view not wired to OpenDouRadarView")
		
	demo_hud.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement HUD binding, radar updates and dialogue ducking**

Wire TacticalHUD controls in `demo_cyberpunk_infiltration.gd` to update telemetry every physics tick and render spatial acoustic radar data.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn tests/test_cyberpunk_demo.gd
git commit -m "feat(demos): wire tactical HUD, localized radio ducking, and 2D spatial radar (Task 4)"
```

---

### Task 5: Demo Hub Registration & Comprehensive Test Suite

**Files:**
- Modify: `scenes/demos/demo_hub.gd`
- Modify: `scenes/demos/demo_hub.tscn`
- Modify: `tests/test_runner_cli.gd`
- Test: `tests/test_cyberpunk_demo.gd`
- Docs: `docs/tasks/completed.md`

**Interfaces:**
- Consumes: Demo 7 scene and coordinator.
- Produces: Showcase entry button in DemoHub and automated test suite execution.

- [ ] **Step 1: Write the failing test for DemoHub Demo 7 registration**

```gdscript
# Add to tests/test_cyberpunk_demo.gd
	var hub = load("res://scenes/demos/demo_hub.tscn").instantiate()
	hub._ready()
	if not hub.DEMO_SCENES.has(7) or not hub.DEMO_SCENES[7].contains("07_cyberpunk_infiltration"):
		failures.append("Test 5a Failed: DemoHub DEMO_SCENES dictionary missing Demo 7 registration")
	hub.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Register Demo 7 in DemoHub and test runner**

Update `scenes/demos/demo_hub.gd` and `scenes/demos/demo_hub.tscn` to include Demo 7 hero launcher card, and register `TestCyberpunkDemo` in `tests/test_runner_cli.gd`.

- [ ] **Step 4: Run full test suite to verify 100% passing**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing with exit code 0)

- [ ] **Step 5: Commit & update task docs**

```bash
git add scenes/demos/demo_hub.gd scenes/demos/demo_hub.tscn tests/test_runner_cli.gd tests/test_cyberpunk_demo.gd docs/tasks/completed.md
git commit -m "feat(demos): register Cyberpunk Infiltration in DemoHub and test suite (Task 5)"
```
