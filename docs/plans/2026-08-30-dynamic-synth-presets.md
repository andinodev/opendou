# Dynamic Modular Procedural Synth Engine & Preset Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dynamic **Modular Procedural Audio Synthesizer & Preset Studio** (`ModularSynthEngine`, `SynthPresetRegistry`, `opendou_synth_presets.json`) that eliminates rigid hardcoded enums, supports 9 modular DSP generators, physical modeling (Karplus-Strong), wavetable phase modulation, stochastic randomization, multi-layer compounding, and real-time RTPC telemetry modulation in OpenDou Studio.

**Architecture:** Dual-Mode Hybrid Pipeline (Bake-on-Demand for one-shots/ambients + Live Procedural Stream with lock-free atomic parameter sync for continuous vehicle/engine telemetry) + JSON storage + Studio Tab 4 Preset Rack + Dynamic Inspector Property List.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core Engine.

## Global Constraints
- Hybrid Language Model: Spanish for tasks/chat, English for code/docs/specs/comments.
- TDD & Verification: Run `godot --headless -s tests/test_runner_cli.gd` (exit code 0, 0 failures) before completing each task.
- Zero hardcoded enums in player nodes: dynamic `_get_property_list()` query against `SynthPresetRegistry`.

---

### Task 1: Core Modular DSP Engine & All 9 Generators (`ModularSynthEngine`)

**Files:**
- Create: `addons/opendou/runtime/synth/modular_synth_engine.gd`
- Create: `tests/test_modular_synth_engine.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `ModularSynthEngine` (static class):
  - `static func generate_layer_samples(layer_dict: Dictionary, duration: float, sample_rate: int = 44100, rng_seed: int = 0) -> PackedFloat32Array`
  - `static func apply_drive(sample: float, drive_type: String, drive_amount: float) -> float`
  - `static func synthesize_wav(preset_dict: Dictionary, rng_seed: int = 0) -> AudioStreamWAV`

- [ ] **Step 1: Write failing test for ModularSynthEngine**

```gdscript
# tests/test_modular_synth_engine.gd
class_name TestModularSynthEngine
extends RefCounted

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var EngineClass = load("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
	if EngineClass == null:
		failures.append("Test 1 Failed: modular_synth_engine.gd failed to load")
		return failures
		
	# Test Karplus-Strong physical modeling
	var ks_layer = {
		"generator_type": "Karplus_Strong",
		"base_freq": 220.0,
		"base_freq_var": 0.05,
		"decay_factor": 0.98,
		"damping": 0.3,
		"duration": 0.3
	}
	var ks_samples = EngineClass.generate_layer_samples(ks_layer, 0.3)
	if ks_samples.is_empty():
		failures.append("Test 2 Failed: Karplus-Strong generated empty sample array")
		
	# Test Wavetable Phase Modulation
	var pm_layer = {
		"generator_type": "Wavetable_PM",
		"base_freq": 150.0,
		"phase_modulation_index": 2.0,
		"duration": 0.5
	}
	var pm_samples = EngineClass.generate_layer_samples(pm_layer, 0.5)
	if pm_samples.is_empty():
		failures.append("Test 3 Failed: Wavetable_PM generated empty sample array")
		
	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `ModularSynthEngine`**

Implement all 9 generators (`Filtered_Noise`, `FM_Chirp`, `Karplus_Strong`, `Wavetable_PM`, `Harmonic_Buzz`, `Sub_Rumble`, `Resonant_Formant`, `Impulse_Ping`, `Basic_Wave`), pitch envelopes, ADSR envelopes, LFOs, and non-linear drive (`Soft_Clip`, `Hard_Clip`, `Foldback`).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/synth/modular_synth_engine.gd tests/test_modular_synth_engine.gd tests/test_all.gd
git commit -m "feat(synth): implement ModularSynthEngine with 9 DSP generators and non-linear drive (Task 1)"
```

---

### Task 2: Preset Registry, Layer Containers & Persistence (`SynthPresetRegistry` & `opendou_synth_presets.json`)

**Files:**
- Create: `addons/opendou/runtime/synth/synth_preset_registry.gd`
- Create: `opendou_synth_presets.json`
- Create: `tests/test_synth_preset_registry.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `SynthPresetRegistry` (`RefCounted` / Singleton helper):
  - `load_presets(json_path: String = "res://opendou_synth_presets.json") -> bool`
  - `save_presets(json_path: String = "res://opendou_synth_presets.json") -> bool`
  - `get_preset_names() -> Array[StringName]`
  - `get_preset(preset_name: StringName) -> Dictionary`
  - `set_preset(preset_name: StringName, preset_dict: Dictionary) -> void`
  - `delete_preset(preset_name: StringName) -> void`
  - `get_preset_stream(preset_name: StringName, rng_seed: int = 0) -> AudioStreamWAV`

- [ ] **Step 1: Write failing test for `SynthPresetRegistry`**

Test JSON serialization, layer compounding in `Layer_Container`, and preset streaming.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `SynthPresetRegistry` and seed `opendou_synth_presets.json`**

Seed default presets (`Wind_Canopy`, `Bird_Chirp`, `Thunder_Rumble`, `Cicada_Swarm`, `Frog_Croak`, `Water_Droplet`, `Cyber_Hornet`, `SciFi_Heavy_Explosion`, `Plucked_Wood_Step`, `EV_Electric_Engine`, `Rain_Atmosphere`, `Server_Hum`, `Water_Stream`).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/synth/synth_preset_registry.gd opendou_synth_presets.json tests/test_synth_preset_registry.gd tests/test_all.gd
git commit -m "feat(synth): implement SynthPresetRegistry and persistent JSON presets storage (Task 2)"
```

---

### Task 3: Studio UI — Synth Preset Builder Rack in Game Syncs Panel

**Files:**
- Modify: `addons/opendou/editor/opendou_game_syncs_panel.gd`
- Modify: `tests/test_studio_advanced_ui.gd`

**Interfaces:**
- Enhances: `OpenDouGameSyncsPanel` with **Tab 4: `⚡ Synth Presets`**:
  - Left sidebar with preset list (`Tree` / `ItemList`), `+ New`, `Clone`, `Delete`.
  - Right rack with Generator selector, Frequency / Variation, Pitch Envelope, Amplitude ADSR, LFO Modulation, Filter, Drive, and Layer Container manager.
  - Interactive Waveform preview (`Control` drawing audio buffer).
  - Audition transport (`Play`, `Loop`, `Stop`).

- [ ] **Step 1: Write failing test for Synth Presets UI tab**

Add test assertions verifying Tab 4 exists, preset tree is populated, and selecting a preset updates parameter rack.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement Synth Presets tab and rack in `opendou_game_syncs_panel.gd`**

Connect UI controls to `SynthPresetRegistry`, wire audition playback, and wire save button.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/editor/opendou_game_syncs_panel.gd tests/test_studio_advanced_ui.gd
git commit -m "feat(studio): add dynamic Synth Presets Builder Rack in Game Syncs Panel (Task 3)"
```

---

### Task 4: Declarative Nodes Dynamic Inspector Integration & Demo Verification

**Files:**
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd`
- Modify: `addons/opendou/nodes/opendou_event_player_2d.gd`
- Modify: `addons/opendou/nodes/opendou_event_player.gd`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `tests/test_declarative_nodes.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

**Interfaces:**
- Eliminates hardcoded `@export_enum`.
- Implements dynamic property list via `_get_property_list()` showing all presets in `opendou_synth_presets.json`.
- In `_ready()`, queries `SynthPresetRegistry.get_preset_stream(synth_preset)` with stochastic variation.

- [ ] **Step 1: Write failing test for dynamic node preset resolution**

Verify declarative nodes dynamically resolve any custom preset name without hardcoded enums.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Update declarative nodes and Cyberpunk Infiltration demo**

Update node scripts to query `SynthPresetRegistry` and verify all 5 sectors in `demo_cyberpunk_infiltration.tscn` play seamlessly.

- [ ] **Step 4: Run full regression test suite**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing, exit code 0)

- [ ] **Step 5: Commit and complete task**

```bash
git add addons/opendou/nodes/ scenes/demos/07_cyberpunk_infiltration/ tests/ docs/tasks/completed.md
git commit -m "feat(nodes): integrate dynamic synth presets in declarative nodes and complete TASK-045 (Task 4)"
```
