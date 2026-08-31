# OpenDou Tactical Canyon: Advanced DSP & SoundBank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 3D Granular Synthesis (`OpenDouGranularEmitter3D`), Physical Impulse Response (IR) Convolution in `OpenDouRoom3D`, and Monolithic Binary SoundBank packaging/streaming (`tactical_canyon.bnk`) integrated into the AAA Tactical Canyon demo with PBR visual materials and live HUD telemetry.

**Architecture:** First-class declarative nodes extending Godot's audio tree (`AudioStreamPlayer3D`, `Area3D`), discrete FIR convolution kernels (512 taps) for room acoustics, continuous real-time buffer pushing via `AudioStreamGeneratorPlayback` for granular textures, and binary chunk streaming from `.bnk` files with Prefetch RAM.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Core DSP (`ConvolutionReverbNode`, `AudioGranularSynthesizer`), OpenDou Runtime (`SoundBankManager`, `BankStreamPlayback`).

## Global Constraints

- Static GDScript typing (`-> void`, `: float`, `: StringName`, etc.) required on all methods and variables.
- All scene components must be mounted declaratively in `.tscn` files; scripts are reserved for control/telemetry.
- Headless execution safety: All audio generators and players must check `is_inside_tree()` and playback validity before buffer operations to ensure 100% tests pass on CLI runner.
- Every task must end with running `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` with exit code `0` and 0 failures.

---

### Task 1: Declarative `OpenDouGranularEmitter3D` Node

**Files:**
- Create: `addons/opendou/nodes/opendou_granular_emitter_3d.gd`
- Create: `addons/opendou/icons/icon_granular_emitter.svg`
- Modify: `addons/opendou/plugin.gd:40-60`
- Test: `tests/test_granular_emitter_3d.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Consumes: `AudioGranularSynthesizer` from `addons/opendou/core/dsp/audio_granular_synthesizer.gd`, `ModularSynthEngine` from `addons/opendou/runtime/synth/modular_synth_engine.gd`.
- Produces: `OpenDouGranularEmitter3D` class extending `AudioStreamPlayer3D` with exports for `source_stream`, `grain_size_ms`, `grain_rate_hz`, `position_jitter_ms`, `pitch_jitter_semitones`, `max_concurrent_grains`, and `auto_play_emitter`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_granular_emitter_3d.gd
class_name TestGranularEmitter3D
extends RefCounted

const OpenDouGranularEmitter3DClass = preload("res://addons/opendou/nodes/opendou_granular_emitter_3d.gd")
const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var emitter = OpenDouGranularEmitter3DClass.new()
	if emitter == null:
		failures.append("Test 1 Failed: Could not instantiate OpenDouGranularEmitter3D")
		return failures

	# Test default properties
	if emitter.grain_size_ms != 40.0 or emitter.grain_rate_hz != 45.0:
		failures.append("Test 2 Failed: Default grain parameters invalid")

	if emitter.max_concurrent_grains != 32 or emitter.auto_play_emitter != true:
		failures.append("Test 3 Failed: Default concurrency/autoplay invalid")

	# Test parameter modification
	emitter.set_grain_parameters(60.0, 80.0, 20.0, 4.0)
	if emitter.grain_size_ms != 60.0 or emitter.grain_rate_hz != 80.0:
		failures.append("Test 4 Failed: set_grain_parameters failed to update properties")

	# Test procedural buffer generation
	var block = emitter.synthesize_current_block(256)
	if block.size() != 256:
		failures.append("Test 5 Failed: synthesize_current_block did not return expected sample count")

	emitter.free()
	return failures
```

- [ ] **Step 2: Register test in `tests/test_all.gd` and verify failure**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL with script load error on `opendou_granular_emitter_3d.gd`.

- [ ] **Step 3: Implement `OpenDouGranularEmitter3D` and SVG Icon**

Create `addons/opendou/nodes/opendou_granular_emitter_3d.gd`:
```gdscript
@icon("res://addons/opendou/icons/icon_granular_emitter.svg")
@tool
class_name OpenDouGranularEmitter3D
extends AudioStreamPlayer3D

## Declarative 3D Spatial Granular Synthesizer for OpenDou.
## Generates continuous asynchronous audio grains with Hanning windowing, time-stretch, and stochastic pitch modulation.

const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")

@export_group("Granular Configuration")
@export var source_stream: AudioStreamWAV = null:
	set(val):
		source_stream = val
		_rebuild_synthesizer()

@export_range(5.0, 200.0, 1.0) var grain_size_ms: float = 40.0:
	set(val):
		grain_size_ms = val
		if _granular_synth:
			_granular_synth.grain_size_ms = val

@export_range(1.0, 200.0, 1.0) var grain_rate_hz: float = 45.0:
	set(val):
		grain_rate_hz = val
		if _granular_synth:
			_granular_synth.grain_rate_hz = val

@export_range(0.0, 50.0, 1.0) var position_jitter_ms: float = 15.0:
	set(val):
		position_jitter_ms = val
		if _granular_synth:
			_granular_synth.position_jitter_ms = val

@export_range(0.0, 12.0, 0.5) var pitch_jitter_semitones: float = 2.0:
	set(val):
		pitch_jitter_semitones = val
		if _granular_synth:
			_granular_synth.pitch_jitter_semitones = val

@export_range(1, 64, 1) var max_concurrent_grains: int = 32:
	set(val):
		max_concurrent_grains = val
		if _granular_synth:
			_granular_synth.max_concurrent_grains = val

@export var auto_play_emitter: bool = true
@export var bus_category: String = "SFX"

var _granular_synth: AudioGranularSynthesizer = null
var _playback: AudioStreamGeneratorPlayback = null
var _generator_stream: AudioStreamGenerator = null

func _init() -> void:
	_granular_synth = AudioGranularSynthesizerClass.new()
	_rebuild_synthesizer()

func _ready() -> void:
	if not Engine.is_editor_hint():
		_setup_audio_generator()
		if auto_play_emitter and is_inside_tree():
			play_granular()

func _setup_audio_generator() -> void:
	if stream == null or not (stream is AudioStreamGenerator):
		_generator_stream = AudioStreamGenerator.new()
		_generator_stream.mix_rate = 44100.0
		_generator_stream.buffer_length = 0.1
		stream = _generator_stream

func _rebuild_synthesizer() -> void:
	if _granular_synth == null:
		return
	var samples: PackedFloat32Array = PackedFloat32Array()
	if source_stream != null and source_stream.data.size() > 0:
		var raw_data = source_stream.data
		samples.resize(raw_data.size() / 2)
		for i in range(samples.size()):
			var b0 = raw_data[i * 2]
			var b1 = raw_data[i * 2 + 1]
			var val16 = b0 | (b1 << 8)
			if val16 >= 32768:
				val16 -= 65536
			samples[i] = float(val16) / 32768.0
	else:
		# Fallback procedural grain texture
		var fallback_dict: Dictionary = {
			"type": "Single_Generator",
			"generator_type": "Filtered_Noise",
			"noise_type": "Brown",
			"duration": 1.0,
			"filter": {"type": "BandPass", "cutoff_hz": 1200.0, "resonance_q": 2.0},
			"gain_db": -6.0
		}
		var synth_wav = ModularSynthEngineClass.synthesize_wav(fallback_dict)
		if synth_wav and synth_wav.data.size() > 0:
			var raw_data = synth_wav.data
			samples.resize(raw_data.size() / 2)
			for i in range(samples.size()):
				var b0 = raw_data[i * 2]
				var b1 = raw_data[i * 2 + 1]
				var val16 = b0 | (b1 << 8)
				if val16 >= 32768:
					val16 -= 65536
				samples[i] = float(val16) / 32768.0

	_granular_synth.source_samples = samples
	_granular_synth.grain_size_ms = grain_size_ms
	_granular_synth.grain_rate_hz = grain_rate_hz
	_granular_synth.position_jitter_ms = position_jitter_ms
	_granular_synth.pitch_jitter_semitones = pitch_jitter_semitones
	_granular_synth.max_concurrent_grains = max_concurrent_grains

func set_grain_parameters(size_ms: float, rate_hz: float, pos_jitter_ms: float, pitch_jitter: float) -> void:
	grain_size_ms = size_ms
	grain_rate_hz = rate_hz
	position_jitter_ms = pos_jitter_ms
	pitch_jitter_semitones = pitch_jitter

func synthesize_current_block(num_samples: int) -> PackedFloat32Array:
	if _granular_synth == null:
		return PackedFloat32Array()
	return _granular_synth.generate_block(num_samples)

func play_granular() -> void:
	if not playing and is_inside_tree():
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func stop_granular() -> void:
	if playing:
		stop()
		_playback = null

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not playing or _playback == null or not is_inside_tree():
		return
	var frames_avail = _playback.get_frames_available()
	if frames_avail > 0:
		var samples = synthesize_current_block(frames_avail)
		for i in range(frames_avail):
			var s = samples[i] if i < samples.size() else 0.0
			_playback.push_frame(Vector2(s, s))
```

- [ ] **Step 4: Register custom node in `plugin.gd` and run tests**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: PASS (all tests passing, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_granular_emitter_3d.gd addons/opendou/icons/icon_granular_emitter.svg addons/opendou/plugin.gd tests/test_granular_emitter_3d.gd tests/test_all.gd
git commit -m "feat(nodes): implement OpenDouGranularEmitter3D real-time granular synthesizer node (Task 1)"
```

---

### Task 2: Physical Impulse Response (IR) Convolution in `OpenDouRoom3D`

**Files:**
- Modify: `addons/opendou/nodes/opendou_room_3d.gd`
- Modify: `addons/opendou/runtime/spatial/audio_room.gd`
- Modify: `addons/opendou/core/dsp/convolution_reverb_node.gd`
- Test: `tests/test_room_convolution.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Consumes: `ConvolutionReverbNode` FIR time-domain discrete convolution from `addons/opendou/core/dsp/convolution_reverb_node.gd`.
- Produces: `OpenDouRoom3D` with `reverb_mode` (`ALGORITHMIC`, `CONVOLUTION_IR`, `HYBRID`), `impulse_response_stream`, `convolution_wet_db`, and `convolution_dry_db`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_room_convolution.gd
class_name TestRoomConvolution
extends RefCounted

const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const ConvolutionReverbNodeClass = preload("res://addons/opendou/core/dsp/convolution_reverb_node.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var room = OpenDouRoom3DClass.new()
	if room == null:
		failures.append("Test 1 Failed: Could not instantiate OpenDouRoom3D")
		return failures

	# Test reverb modes enum
	if room.reverb_mode != OpenDouRoom3DClass.ReverbMode.ALGORITHMIC:
		failures.append("Test 2 Failed: Default reverb mode should be ALGORITHMIC")

	room.reverb_mode = OpenDouRoom3DClass.ReverbMode.CONVOLUTION_IR
	if room.reverb_mode != OpenDouRoom3DClass.ReverbMode.CONVOLUTION_IR:
		failures.append("Test 3 Failed: Failed to switch reverb mode to CONVOLUTION_IR")

	# Test calibrated FIR kernel processing
	var ir_kernel = PackedFloat32Array()
	ir_kernel.resize(512)
	for i in range(512):
		ir_kernel[i] = exp(-float(i) / 64.0) * sin(float(i) * 0.2)

	var conv = ConvolutionReverbNodeClass.new(ir_kernel)
	var input_signal = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
	var output_signal = conv.process_block(input_signal)

	if output_signal.size() != 5:
		failures.append("Test 4 Failed: Convolution output signal size mismatch")

	if absf(output_signal[0] - 1.0) > 0.1:
		failures.append("Test 5 Failed: Convolution direct signal passthrough mismatch")

	room.free()
	return failures
```

- [ ] **Step 2: Register test in `tests/test_all.gd` and verify failure**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL with property `reverb_mode` not found.

- [ ] **Step 3: Update `OpenDouRoom3D` and `AudioRoom`**

Update `addons/opendou/nodes/opendou_room_3d.gd`:
- Add `enum ReverbMode { ALGORITHMIC, CONVOLUTION_IR, HYBRID }`
- Add `@export var reverb_mode: ReverbMode = ReverbMode.ALGORITHMIC`
- Add `@export var impulse_response_stream: AudioStreamWAV = null`
- Add `@export_range(-60.0, 0.0, 0.5) var convolution_wet_db: float = -6.0`
- Add `@export_range(-60.0, 0.0, 0.5) var convolution_dry_db: float = 0.0`
- Add method `set_reverb_mode(mode: ReverbMode)` and propagate to runtime `audio_room.gd`.

- [ ] **Step 4: Run tests and verify success**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_room_3d.gd addons/opendou/runtime/spatial/audio_room.gd tests/test_room_convolution.gd tests/test_all.gd
git commit -m "feat(spatial): implement physical IR convolution reverb mode in OpenDouRoom3D (Task 2)"
```

---

### Task 3: Monolithic Binary SoundBank Builder & Runtime Pipeline

**Files:**
- Create: `addons/opendou/runtime/soundbank_builder.gd`
- Modify: `addons/opendou/runtime/soundbank_manager.gd`
- Modify: `addons/opendou/runtime/soundbank.gd`
- Modify: `addons/opendou/runtime/bank_stream_playback.gd`
- Test: `tests/test_soundbank_packaging_and_streaming.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Consumes: `SoundBank` and `SoundBankManager` from `addons/opendou/runtime/`.
- Produces: `SoundBankBuilder.build_bank(target_path, entries_dict)` and `SoundBankManager.get_bank_telemetry(bank_name)`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_soundbank_packaging_and_streaming.gd
class_name TestSoundBankPackagingAndStreaming
extends RefCounted

const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var target_bank_path = "user://test_tactical_pack.bnk"
	var entries: Dictionary = {
		"Gunshot_Rifle": {
			"is_prefetch": true,
			"sample_rate": 44100,
			"samples": PackedFloat32Array([0.0, 0.8, -0.6, 0.4, -0.2, 0.0])
		},
		"Radio_Chatter": {
			"is_prefetch": false,
			"sample_rate": 44100,
			"samples": PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
		}
	}

	var build_ok = SoundBankBuilderClass.build_bank(target_bank_path, entries)
	if not build_ok:
		failures.append("Test 1 Failed: SoundBankBuilder failed to create binary bnk file")
		return failures

	var mgr = SoundBankManagerClass.new()
	var bank = mgr.load_bank(target_bank_path, &"test_tactical_pack")
	if bank == null:
		failures.append("Test 2 Failed: SoundBankManager failed to load generated bank")
		return failures

	var telem = mgr.get_bank_telemetry(&"test_tactical_pack")
	if not telem.has("prefetch_ram_bytes") or telem["prefetch_ram_bytes"] <= 0:
		failures.append("Test 3 Failed: SoundBank telemetry missing prefetch_ram_bytes")

	mgr.unload_bank(&"test_tactical_pack")
	DirAccess.remove_absolute(target_bank_path)
	return failures
```

- [ ] **Step 2: Register test in `tests/test_all.gd` and verify failure**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL with `SoundBankBuilder` missing.

- [ ] **Step 3: Implement `SoundBankBuilder` and Telemetry in `SoundBankManager`**

Implement binary serializer in `addons/opendou/runtime/soundbank_builder.gd` with binary packing format `OPNDOU_BNK_v1`.
Add `get_bank_telemetry(bank_name)` to `SoundBankManager`.

- [ ] **Step 4: Run tests and verify success**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/soundbank_builder.gd addons/opendou/runtime/soundbank_manager.gd addons/opendou/runtime/soundbank.gd tests/test_soundbank_packaging_and_streaming.gd tests/test_all.gd
git commit -m "feat(soundbank): implement SoundBankBuilder and telemetry monitoring in SoundBankManager (Task 3)"
```

---

### Task 4: Tactical Canyon Scene Integration, PBR Materials & Tactical HUD Telemetry

**Files:**
- Modify: `scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn`
- Modify: `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`
- Modify: `tests/test_tactical_canyon_demo.gd`

**Interfaces:**
- Consumes: `OpenDouGranularEmitter3D`, `OpenDouRoom3D` convolution mode, `SoundBankBuilder`, `SoundBankManager`.
- Produces: Updated `.tscn` with cliffside granular emitter, convolution bunker chamber, SoundBank live stream, PBR materials, and tactical HUD controls (`C`, `V`, `B`).

- [ ] **Step 1: Update integration test assertions in `tests/test_tactical_canyon_demo.gd`**

Add Test 9 (Granular Emitter existence & parameter modulation), Test 10 (Room Convolution A/B toggle), and Test 11 (SoundBank runtime loading and clean unload).

- [ ] **Step 2: Run test to verify failure**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: FAIL on missing granular and convolution nodes in scene.

- [ ] **Step 3: Mount `OpenDouGranularEmitter3D`, PBR materials and HUD in `demo_tactical_canyon.tscn` & `.gd`**

1. Add `CliffsideGranularEmitter` under `Sector1_RiverGorge`.
2. Configure `BunkerRoomArea` with `reverb_mode = CONVOLUTION_IR`.
3. Add PBR materials (`StandardMaterial3D`) to CSG nodes in Sector 1, 2, 3, 4, 5.
4. Update `demo_tactical_canyon.gd`:
   - Auto-build `res://banks/tactical_canyon.bnk` in `_ready()` if missing and load via `SoundBankManager`.
   - Add toggle methods: `toggle_reverb_convolution()`, `toggle_granular_preset()`.
   - Connect keys `C`, `V`, `B` in `_unhandled_input()`.
   - Update HUD labels with Granular, Convolution, and SoundBank streaming telemetry.
   - Call `SoundBankManager.unload_bank(&"tactical_canyon")` in `_exit_tree()` or on back to Hub.

- [ ] **Step 4: Run full test suite to verify 100% pass**

Run: `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
Expected: STATUS: PASSED with exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scenes/demos/08_tactical_canyon/ tests/test_tactical_canyon_demo.gd
git commit -m "feat(demos): integrate granular emitter, IR convolution, SoundBank streaming and PBR visual materials in Tactical Canyon (Task 4)"
```
