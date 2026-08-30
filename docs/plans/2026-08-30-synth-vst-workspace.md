# OpenDou VST Modular Synth Rack Workstation (Mode 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate procedural audio synthesis to a **First-Class Center Workspace Canvas (Mode 3: `⚡ Synth`)** in OpenDou Studio, featuring Eurorack/VST-style card modules, virtual rotary knobs, interactive draggable ADSR nodes, dynamic sweeping playhead waveform visualizer, stereo LED VU meter, constant-power panning, ping-pong delay, algorithmic FDN space reverb, and voice glide.

**Architecture:** Fullscreen center workspace (`OpenDouSynthRackWorkspace`) + custom UI controls (`OpenDouKnob`, `OpenDouADSREditor`, `OpenDouWaveformPlayhead`, `OpenDouVUMeter`) + Modular DSP extensions (`ModularSynthEngine`) + reactive Mode 3 transport bar in `OpenDouStudioMain`.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core Engine.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `godot --headless -s tests/test_runner_cli.gd` (exit code 0, 0 failures) before completing each task.
- Zero-waste layout: Studio center workspace occupies 100% width and height cleanly in floating or docked mode.

---

### Task 1: Core DSP Extensions (Stereo Panning, Ping-Pong Delay, FDN Reverb, Portamento/Glide)

**Files:**
- Modify: `addons/opendou/runtime/synth/modular_synth_engine.gd`
- Create: `tests/test_synth_vst_workspace.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces in `ModularSynthEngine`:
  - `static func apply_stereo_panning(mono_samples: PackedFloat32Array, pan: float) -> PackedFloat32Array` (Interleaved stereo: [L0, R0, L1, R1...])
  - `static func apply_delay_fx(stereo_samples: PackedFloat32Array, time_ms: float, feedback: float, damping: float, mix: float, sample_rate: int = 44100) -> PackedFloat32Array`
  - `static func apply_reverb_fx(stereo_samples: PackedFloat32Array, room_size: float, damping: float, mix: float, sample_rate: int = 44100) -> PackedFloat32Array`
  - `static func apply_glide_pitch(freq_start: float, freq_target: float, glide_time_sec: float, progress_t: float) -> float`
  - `synthesize_wav(preset_dict: Dictionary, rng_seed: int = 0) -> AudioStreamWAV` updated to output 16-bit stereo WAV when panning or FX are enabled.

- [ ] **Step 1: Write failing test for DSP extensions**

```gdscript
# tests/test_synth_vst_workspace.gd
class_name TestSynthVstWorkspace
extends RefCounted

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var EngineClass = load("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
	if EngineClass == null:
		failures.append("Test 1 Failed: modular_synth_engine.gd failed to load")
		return failures

	# Test 1: Constant Power Stereo Panning
	var mono = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var stereo_center = EngineClass.apply_stereo_panning(mono, 0.0)
	if stereo_center.size() != 8:
		failures.append("Test 1 Failed: stereo_center size must be 8 (interleaved L/R)")
	else:
		var p_center = stereo_center[0] * stereo_center[0] + stereo_center[1] * stereo_center[1]
		if absf(p_center - 1.0) > 0.01:
			failures.append("Test 1 Failed: constant power panning must preserve total power at center")

	return failures
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement DSP extensions in `modular_synth_engine.gd`**

Implement `apply_stereo_panning`, `apply_delay_fx` (Ping-Pong with damping), `apply_reverb_fx` (Schroeder-Moorer comb + allpass FDN), and `apply_glide_pitch`. Update `synthesize_wav()` to apply FX chain and output stereo WAVs.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/synth/modular_synth_engine.gd tests/test_synth_vst_workspace.gd tests/test_all.gd
git commit -m "feat(synth): implement stereo panning, ping-pong delay, FDN reverb, and glide in ModularSynthEngine (Task 1)"
```

---

### Task 2: Interactive VST Custom Controls (`OpenDouKnob`, `OpenDouADSREditor`, `OpenDouWaveformPlayhead`, `OpenDouVUMeter`)

**Files:**
- Create: `addons/opendou/editor/controls/opendou_knob.gd`
- Create: `addons/opendou/editor/controls/opendou_adsr_editor.gd`
- Create: `addons/opendou/editor/controls/opendou_waveform_playhead.gd`
- Create: `addons/opendou/editor/controls/opendou_vu_meter.gd`
- Modify: `tests/test_synth_vst_workspace.gd`

**Interfaces:**
- Produces:
  - `OpenDouKnob` (extends `Control`): `@export var min_value: float`, `@export var max_value: float`, `@export var value: float`, `signal value_changed(val: float)`.
  - `OpenDouADSREditor` (extends `Control`): `@export var attack: float`, `@export var decay: float`, `@export var sustain: float`, `@export var release: float`, `signal adsr_changed(a, d, s, r)`.
  - `OpenDouWaveformPlayhead` (extends `Control`): `func set_waveform(samples: PackedFloat32Array)`, `func set_playhead(progress: float)`.
  - `OpenDouVUMeter` (extends `Control`): `func set_level(db_left: float, db_right: float)`.

- [ ] **Step 1: Write failing test for VST custom controls**

Test knob dragging/clamping, ADSR handle dragging, playhead scrubbing, and VU meter level normalization.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement all 4 custom controls**

Implement `opendou_knob.gd`, `opendou_adsr_editor.gd`, `opendou_waveform_playhead.gd`, and `opendou_vu_meter.gd` with neon vector drawing, mouse interactions, and tooltips.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/editor/controls/ tests/test_synth_vst_workspace.gd
git commit -m "feat(studio): create OpenDouKnob, OpenDouADSREditor, WaveformPlayhead, and VUMeter controls (Task 2)"
```

---

### Task 3: Fullscreen VST Synth Rack Workspace Canvas (`OpenDouSynthRackWorkspace`)

**Files:**
- Create: `addons/opendou/editor/opendou_synth_rack_workspace.gd`
- Modify: `tests/test_synth_vst_workspace.gd`

**Interfaces:**
- Produces: `OpenDouSynthRackWorkspace` (extends `PanelContainer`):
  - Left panel: Preset Library tree, `➕ New`, `🗑️ Delete`.
  - Center/Right panel:
    - Waveform + Sweeping Playhead Visualizer + Superimposed ADSR + Stereo VU Meter.
    - Modular Cards Rack:
      * 1. Generator Card (all 9 types, Pitch, Octave, Detune, Randomization).
      * 2. ADSR Interactive Curve Card (`OpenDouADSREditor`).
      * 3. Filter Card (LowPass, HighPass, BandPass, Notch, Cutoff Knob, Resonance Q Knob).
      * 4. LFO & Mod Matrix Card (Wave, Rate, Depth, Target).
      * 5. Drive / Saturation Card (Soft_Clip, Hard_Clip, Foldback, Drive Knob).
      * 6. Voicing & Pan Card (Mono/Poly, Glide Time Knob, Stereo Pan Knob).
      * 7. Master FX Card (Delay Time, Feedback, Mix + Reverb Size, Damping, Mix).
  - Audition transport integration (`Play`, `Loop`, `Stop`, `Save`).

- [ ] **Step 1: Write failing test for `OpenDouSynthRackWorkspace`**

Test workspace instantiation, preset loading into cards, knob synchronization, and audition playback.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Implement `OpenDouSynthRackWorkspace`**

Assemble all cards, wire two-way parameter bindings to `SynthPresetRegistry`, wire audition playback with live sweeping playhead animation in `_process(delta)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/editor/opendou_synth_rack_workspace.gd tests/test_synth_vst_workspace.gd
git commit -m "feat(studio): implement OpenDouSynthRackWorkspace full-screen VST modular rack (Task 3)"
```

---

### Task 4: Mode 3 Workspace Integration in OpenDou Studio & Transport Bar

**Files:**
- Modify: `addons/opendou/editor/opendou_studio_main.gd`
- Modify: `addons/opendou/editor/opendou_transport_bar.gd`
- Modify: `tests/test_studio_advanced_ui.gd`
- Modify: `docs/tasks/completed.md`

**Interfaces:**
- Enhances:
  - `OpenDouStudioMain`: Adds Mode 3: `⚡ Synth` to `mode_selector`, mounts `synth_rack_workspace` in `center_workspace_box`, switches visibility on Mode 3.
  - `OpenDouTransportBar`: Adapts controls when `set_workspace_context(3)` is called (audition buttons, octave shift fader, real-time VU meter, save preset).

- [ ] **Step 1: Write failing test for Mode 3 studio integration**

Test switching `studio.set_workspace_mode(3)` shows `synth_rack_workspace` and updates transport bar.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: FAIL

- [ ] **Step 3: Wire Mode 3 in `opendou_studio_main.gd` and `opendou_transport_bar.gd`**

Connect mode switching, transport bar signals, save button shortcuts (`Ctrl+S`), and document `TASK-046` in `docs/tasks/completed.md`.

- [ ] **Step 4: Run full regression test suite**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS (All tests passing, exit code 0)

- [ ] **Step 5: Commit and complete task**

```bash
git add addons/opendou/editor/opendou_studio_main.gd addons/opendou/editor/opendou_transport_bar.gd tests/test_studio_advanced_ui.gd docs/tasks/completed.md
git commit -m "feat(studio): integrate Mode 3 Synth Workstation and complete TASK-046 (Task 4)"
```
