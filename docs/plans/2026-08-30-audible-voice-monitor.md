# Audible Voice Monitor & Loudness Inspector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a real-time **Audible Voice Monitor & Loudness Inspector** (`OpenDouAudibleMonitor`) that identifies active sounds at the listener's position, calculates their effective perceived loudness (dB) with distance attenuation, occlusion, and ducking, and ranks them in descending order for debugging, gameplay AI, and editor profiling.

**Architecture:** Core calculation service (`AudibleVoiceMonitor`) returning sorted `AudibleVoiceInfo` structs + Declarative CanvasLayer overlay (`OpenDouAudibleMonitor`) with live VU meters and bus category color coding + Profiler panel integration.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core Engine.

---

### Task 1: Core Service & Loudness Calculation Engine (`AudibleVoiceMonitor` and `AudibleVoiceInfo`)

**Files:**
- Create: `addons/opendou/runtime/audible_voice_monitor.gd`
- Create: `tests/test_audible_monitor.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- `AudibleVoiceInfo`: Data struct for active voice telemetry.
- `AudibleVoiceMonitor`: Static/service methods `collect_audible_voices(tree: SceneTree, listener_pos: Vector3, ducking_matrix: AudioDuckingMatrix = null, min_db_threshold: float = -60.0) -> Array[AudibleVoiceInfo]`

- [ ] **Step 1: Write failing test verifying loudness calculations and sorting**

```gdscript
# tests/test_audible_monitor.gd
class_name TestAudibleMonitor
extends RefCounted

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var MonitorClass = load("res://addons/opendou/runtime/audible_voice_monitor.gd")
	if not MonitorClass:
		failures.append("Test 1a Failed: audible_voice_monitor.gd failed to load")
		return failures
	
	# Test distance attenuation calculation
	var atten_close = MonitorClass.calculate_distance_attenuation_db(1.0, 2.5, 15.0)
	var atten_far = MonitorClass.calculate_distance_attenuation_db(10.0, 2.5, 15.0)
	if atten_close < atten_far:
		failures.append("Test 1b Failed: Closer distance should have higher/less-attenuated volume")
		
	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `AudibleVoiceMonitor` and `AudibleVoiceInfo`**

Implement distance attenuation, occlusion mapping, ducking reduction, inaudibility threshold filtering, and descending sort.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/audible_voice_monitor.gd tests/test_audible_monitor.gd tests/test_all.gd
git commit -m "feat(telemetry): implement AudibleVoiceMonitor loudness calculation engine (Task 1)"
```

---

### Task 2: In-Game Debug HUD Overlay Node (`OpenDouAudibleMonitor`)

**Files:**
- Create: `addons/opendou/nodes/opendou_audible_monitor.gd`
- Create: `addons/opendou/icons/icon_audible_monitor.svg`
- Modify: `addons/opendou/plugin.gd`
- Modify: `tests/test_audible_monitor.gd`

**Interfaces:**
- Produces: `OpenDouAudibleMonitor` extending `CanvasLayer` with `@export var toggle_key: Key = KEY_F8`, dynamic VU level meters, category coloring, and distance/occlusion badges.

- [ ] **Step 1: Write failing test for `OpenDouAudibleMonitor` node**

Add tests for node instantiation, toggle functionality, and plugin custom type registration.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `OpenDouAudibleMonitor` and register custom type**

Build the declarative CanvasLayer HUD with reactive UI and register it in `plugin.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_audible_monitor.gd addons/opendou/icons/icon_audible_monitor.svg addons/opendou/plugin.gd tests/test_audible_monitor.gd
git commit -m "feat(nodes): implement declarative OpenDouAudibleMonitor HUD overlay (Task 2)"
```

---

### Task 3: Integration in Cyberpunk Infiltration Demo & Profiler Panel

**Files:**
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `addons/opendou/editor/opendou_profiler_panel.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

- [ ] **Step 1: Write failing test verifying monitor presence in Cyberpunk Infiltration demo**

Add assertion in `tests/test_cyberpunk_demo.gd` checking for `OpenDouAudibleMonitor` node.

- [ ] **Step 2: Update demo scene, script, and profiler panel**

Add `OpenDouAudibleMonitor` to `demo_cyberpunk_infiltration.tscn`, wire a toggle button in the Tactical HUD, and update `OpenDouProfilerPanel`.

- [ ] **Step 3: Run full test suite**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing with exit code 0)

- [ ] **Step 4: Commit & Complete Task**

```bash
git add scenes/demos/07_cyberpunk_infiltration/ addons/opendou/editor/opendou_profiler_panel.gd tests/test_cyberpunk_demo.gd docs/tasks/completed.md
git commit -m "feat(demos): integrate OpenDouAudibleMonitor in Cyberpunk demo and Studio profiler (Task 3)"
```
