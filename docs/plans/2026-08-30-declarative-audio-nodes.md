# Declarative Custom Audio Nodes Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a complete suite of 7 declarative custom Godot nodes (`OpenDouEventPlayer3D`, `OpenDouEventPlayer2D`, `OpenDouEventPlayer`, `OpenDouRoom3D`, `OpenDouPortal3D`, `OpenDouReflector3D`, `OpenDouMusicPlayer`) allowing developers to drag, drop, and configure all OpenDou audio middleware features directly in the Godot Inspector without manual scripting.

**Architecture:** Custom nodes inheriting directly from standard Godot nodes (`AudioStreamPlayer3D`, `AudioStreamPlayer2D`, `AudioStreamPlayer`, `Area3D`, `Node3D`, `Node`) with typed `@export` properties and seamless binding to OpenDou runtime managers (`SpatialAcousticsManager`, `VoicePoolManager`, `AudioDuckingMatrix`, `AudioDialogueManager`).

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core Engine.

## Global Constraints
- Custom nodes must extend standard Godot nodes to preserve full native functionality while enriching them.
- All code must be strictly typed GDScript with English identifiers.
- All 7 nodes must be registered via `add_custom_type` in `addons/opendou/plugin.gd`.
- Full test suite must pass with exit code 0 via `godot --headless -s tests/test_runner_cli.gd`.

---

### Task 1: Event Players Suite (`OpenDouEventPlayer3D`, `OpenDouEventPlayer2D`, `OpenDouEventPlayer`)

**Files:**
- Create: `addons/opendou/nodes/opendou_event_player_3d.gd`
- Create: `addons/opendou/nodes/opendou_event_player_2d.gd`
- Create: `addons/opendou/nodes/opendou_event_player.gd`
- Create: `tests/test_declarative_nodes.gd`

**Interfaces:**
- Produces: `OpenDouEventPlayer3D`, `OpenDouEventPlayer2D`, `OpenDouEventPlayer` with methods `play_event()`, `set_rtpc()`, `set_switch()`, `set_state()`.

- [ ] **Step 1: Write failing test verifying instantiation and Inspector properties**

```gdscript
# tests/test_declarative_nodes.gd
class_name TestDeclarativeNodes
extends RefCounted

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	var P3DClass = load("res://addons/opendou/nodes/opendou_event_player_3d.gd")
	if not P3DClass:
		failures.append("Test 1a Failed: opendou_event_player_3d.gd failed to load")
		return failures
		
	var p3d = P3DClass.new()
	if not (p3d is AudioStreamPlayer3D):
		failures.append("Test 1b Failed: OpenDouEventPlayer3D must inherit AudioStreamPlayer3D")
	p3d.event_name = &"Gunshot_Rifle"
	p3d.set_rtpc(&"RPM", 0.75)
	if p3d.rtpc_bindings.get(&"RPM") != 0.75:
		failures.append("Test 1c Failed: set_rtpc did not store RTPC binding")
	p3d.set_switch(&"Surface", &"Metal")
	if p3d.active_switch != &"Metal":
		failures.append("Test 1d Failed: set_switch did not update active_switch")
	p3d.free()
	
	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `OpenDouEventPlayer3D`, `2D`, and Global**

Implement the 3 player node classes with Inspector `@export` groups for events, RTPCs, switches, states, voice management, occlusion, and ducking.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_event_player_3d.gd addons/opendou/nodes/opendou_event_player_2d.gd addons/opendou/nodes/opendou_event_player.gd tests/test_declarative_nodes.gd
git commit -m "feat(nodes): implement declarative event player nodes 3D, 2D and global (Task 1)"
```

---

### Task 2: Spatial Environment Nodes (`OpenDouRoom3D`, `OpenDouPortal3D`, `OpenDouReflector3D`)

**Files:**
- Create: `addons/opendou/nodes/opendou_room_3d.gd`
- Create: `addons/opendou/nodes/opendou_portal_3d.gd`
- Create: `addons/opendou/nodes/opendou_reflector_3d.gd`
- Modify: `tests/test_declarative_nodes.gd`

**Interfaces:**
- Produces: `OpenDouRoom3D` (Sabine auto-calculation), `OpenDouPortal3D` (diffraction and room link), `OpenDouReflector3D`.

- [ ] **Step 1: Write failing test verifying Sabine RT60 calculation and portal linkage**

```gdscript
# Add to tests/test_declarative_nodes.gd
	var RoomClass = load("res://addons/opendou/nodes/opendou_room_3d.gd")
	var PortalClass = load("res://addons/opendou/nodes/opendou_portal_3d.gd")
	var ReflectorClass = load("res://addons/opendou/nodes/opendou_reflector_3d.gd")
	
	var room = RoomClass.new()
	room.room_name = &"Vault_Room"
	room.material_preset = "Concrete"
	room.calculate_sabine_reverb(Vector3(10, 4, 10))
	if room.calculated_rt60 <= 0.1:
		failures.append("Test 2a Failed: OpenDouRoom3D failed to calculate Sabine RT60")
		
	var portal = PortalClass.new()
	portal.open_factor = 0.5
	var lpf = portal.get_diffraction_lpf()
	if lpf > 15000.0 or lpf < 1000.0:
		failures.append("Test 2b Failed: OpenDouPortal3D diffraction LPF calculation mismatch")
		
	room.free()
	portal.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `OpenDouRoom3D`, `OpenDouPortal3D`, and `OpenDouReflector3D`**

Implement spatial environment nodes with auto-registration into `SpatialAcousticsManager` and Sabine reverberation formula.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_room_3d.gd addons/opendou/nodes/opendou_portal_3d.gd addons/opendou/nodes/opendou_reflector_3d.gd tests/test_declarative_nodes.gd
git commit -m "feat(nodes): implement declarative room, portal, and reflector spatial nodes (Task 2)"
```

---

### Task 3: Declarative Multi-Stem Music Player (`OpenDouMusicPlayer`)

**Files:**
- Create: `addons/opendou/nodes/opendou_music_player.gd`
- Modify: `tests/test_declarative_nodes.gd`

**Interfaces:**
- Produces: `OpenDouMusicPlayer` extending `Node` with methods `play()`, `stop()`, `set_combat_intensity(val)`, `trigger_stinger(name)`.

- [ ] **Step 1: Write failing test verifying music suite loading and stem creation**

```gdscript
# Add to tests/test_declarative_nodes.gd
	var MusicPlayerClass = load("res://addons/opendou/nodes/opendou_music_player.gd")
	var music_node = MusicPlayerClass.new()
	music_node.suite_name = &"Exploration_Ambient_Theme.tres"
	music_node.load_suite()
	if music_node.stem_players.size() < 2:
		failures.append("Test 3a Failed: OpenDouMusicPlayer failed to load stems for Exploration_Ambient_Theme.tres")
	music_node.set_combat_intensity(0.9)
	if not is_equal_approx(music_node.combat_intensity, 0.9):
		failures.append("Test 3b Failed: OpenDouMusicPlayer set_combat_intensity failed")
	music_node.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `OpenDouMusicPlayer`**

Implement `OpenDouMusicPlayer` with dynamic suite loading, stem players instantiation, and real-time intensity crossfading.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_music_player.gd tests/test_declarative_nodes.gd
git commit -m "feat(nodes): implement declarative OpenDouMusicPlayer node (Task 3)"
```

---

### Task 4: Editor Plugin Registration & Custom Type Icons

**Files:**
- Modify: `addons/opendou/plugin.gd`
- Create: Vector SVG icons in `addons/opendou/icons/`
- Modify: `tests/test_runner_cli.gd`
- Modify: `tests/test_all.gd`
- Modify: `docs/tasks/completed.md`

**Interfaces:**
- Produces: Editor custom type registration for all 7 nodes appearing in Godot's Create Node dialog.

- [ ] **Step 1: Write failing test verifying custom type registration**

```gdscript
# Add to tests/test_declarative_nodes.gd
	var plugin_script = load("res://addons/opendou/plugin.gd")
	if not plugin_script:
		failures.append("Test 4a Failed: plugin.gd failed to load")
```

- [ ] **Step 2: Register custom types in `plugin.gd` and create SVG icons**

Add `add_custom_type` calls in `plugin.gd` for all 7 nodes and create clean vector SVG icons.

- [ ] **Step 3: Run full test suite to verify 100% passing**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing with exit code 0)

- [ ] **Step 4: Commit & update task docs**

```bash
git add addons/opendou/plugin.gd addons/opendou/icons/ tests/test_declarative_nodes.gd tests/test_runner_cli.gd tests/test_all.gd docs/tasks/completed.md
git commit -m "feat(nodes): register declarative audio nodes in editor plugin and complete TASK-042 (Task 4)"
```
