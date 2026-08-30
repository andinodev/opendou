# Technical Specification: Audible Voice Monitor & Active Sound Inspector

**Module:** `addons/opendou/runtime`, `addons/opendou/nodes`, `addons/opendou/editor`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Draft / In Review`

---

## 1. Objective & Overview

Provide a real-time **Audible Voice Monitor & Loudness Inspector** that identifies all actively audible sounds at the listener's position, calculates their effective perceived loudness (integrating base gain, 3D distance attenuation, physical wall occlusion, sidechain ducking, and bus gain), and dynamically ranks them from highest to lowest intensity for runtime debugging, gameplay perception systems (stealth/hearing), and editor profiling.

### Functional Requirements
* **FR-1 (`AudibleVoiceMonitor` Service):** Computes `effective_db` for all active audio emitters and `EventInstance` voices. Excludes culled, stopped, or inaudible sounds ($< -60\text{ dB}$). Sorts voices in descending order of loudness.
* **FR-2 (`OpenDouAudibleMonitor` HUD Overlay Node):** A plug-and-play declarative `CanvasLayer` / `Control` overlay with toggle key (`F8`), visual VU level meters, category color coding (Voice = Cyan, SFX = Orange, Music = Magenta, Ambience = Green), and contextual badges (Distance, Occlusion %, Ducking dB, Priority).
* **FR-3 (Singleton API):** Exposes `AudioEventManager.get_audible_voices()` for gameplay AI and scripts.
* **FR-4 (Studio Profiler Integration):** Enhances `OpenDouProfilerPanel` with real-time loudness ranking of audible voices.

---

## 2. Calculation Model: Effective Perceived Loudness

For any 3D sound emitter at distance $d$:
$$\text{DistanceAtten}_{\text{dB}} = \text{clampf}\left(20 \cdot \log_{10}\left(\frac{\text{unit\_size}}{\max(d, 0.1)}\right), -60.0, 0.0\right) \quad \text{if } d \le \text{max\_distance} \text{ else } -\infty$$

$$\text{Effective}_{\text{dB}} = \text{VolumeBase}_{\text{dB}} + \text{DistanceAtten}_{\text{dB}} + \text{OcclusionAtten}_{\text{dB}} + \text{DuckingReduction}_{\text{dB}} + \text{BusGain}_{\text{dB}}$$

Voices with $\text{Effective}_{\text{dB}} < \text{threshold}$ (default: $-60\text{ dB}$) are discarded from the audible list.

---

## 3. Class Signatures

### `AudibleVoiceInfo` (`RefCounted`)
```gdscript
class_name AudibleVoiceInfo
extends RefCounted

var emitter_name: StringName = &""
var event_name: StringName = &""
var bus_category: StringName = &"SFX"
var effective_db: float = -60.0
var raw_volume_db: float = 0.0
var distance_attenuation_db: float = 0.0
var occlusion_factor: float = 0.0
var ducking_reduction_db: float = 0.0
var distance_meters: float = 0.0
var is_3d: bool = false
var priority: float = 50.0
```

### `OpenDouAudibleMonitor` (`CanvasLayer` / `Control`)
```gdscript
class_name OpenDouAudibleMonitor
extends CanvasLayer

@export var enabled: bool = true
@export var toggle_key: Key = KEY_F8
@export var max_items_displayed: int = 10
@export var min_db_threshold: float = -55.0
@export var poll_interval: float = 0.05
```

---

## 4. Verification Plan

* [ ] Unit test in `tests/test_audible_monitor.gd` verifying:
  * Accurate calculation of effective loudness with distance, occlusion, and ducking.
  * Correct sorting (highest dB voice at index 0).
  * Inaudible sound culling ($< -60\text{ dB}$).
  * `OpenDouAudibleMonitor` instantiation and toggle visibility.
* [ ] Integration verification in `demo_cyberpunk_infiltration.tscn`.
* [ ] Full regression suite execution (`godot --headless -s tests/test_runner_cli.gd`) passing 100%.
