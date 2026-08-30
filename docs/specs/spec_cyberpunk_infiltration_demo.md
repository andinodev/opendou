# Technical Specification: Cyberpunk Infiltration AAA Showcase Demo

**Module:** `scenes/demos/07_cyberpunk_infiltration`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved`

---

## 1. Objective & Requirements

Provide a state-of-the-art interactive 3D demo scene that showcases the full suite of OpenDou AAA audio middleware capabilities running concurrently in real time, including dynamic multi-stem DAW music, Sabine room acoustics with portal diffraction, dynamic raycast occlusion, sidechain ducking matrix, surface switch containers, voice pooling stress testing, localized multi-language dialogues, and in-game 2D spatial acoustic radar telemetry.

### Functional Requirements
* **FR-1 (Declarative Scene Hierarchy):** Built strictly as a declarative `.tscn` file (`scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`) containing 4 interconnected sectors:
  1. *Sector 1 (Rooftop Rain & Catwalks):* Exterior rain synthesis, metallic catwalks, early reflection wall reflectors (`AcousticReflector`).
  2. *Sector 2 (Server Airlock & Interior Room):* Clean acoustic room (`AudioRoom` $RT_{60} = 0.7s$), airlock door with `AudioPortal` demonstrating diffraction and low-pass filtering on close.
  3. *Sector 3 (Flooded Drainage Conduit):* Water basin triggering `Underwater` mix snapshot, Sabine $RT_{60} = 3.5s$, and splash footstep variations.
  4. *Sector 4 (Extraction Helipad & Combat Arena):* Turrets with dynamic pillar raycast occlusion, radio beacon, and siege bombardment spawner.
* **FR-2 (Adaptive Music Sequencer):** Runtime integration with `MusicPlaylistManager` (`Infiltration_Intro` $\rightarrow$ `Stealth_Loop` $\rightarrow$ `Combat_Alert` $\rightarrow$ `Extraction_Outro`) and `CombatIntensity` RTPC (0.0 = stealth pads, 0.5 = tense percussion, 1.0 = heavy beat & lead synths).
* **FR-3 (HDR Mixing & Sidechain Ducking):** Real-time `AudioDuckingMatrix` where tactical radio dialogue ducks music by -16 dB with smooth gain reduction meters on HUD, and explosion transients auto-duck background environmental noise via `AudioHDREngine`.
* **FR-4 (Footstep Surface Switch Container):** Dynamic ground detection under player triggering appropriate footstep audio samples (`Metal_Catwalk`, `Tile_Floor`, `Water_Splash`, `Concrete_Helipad`).
* **FR-5 (Voice Pool Stress Test):** Bombardment trigger spawning 250 concurrent emitters, demonstrating deterministic 16-voice hardware pooling and 234 virtualized voices with time retention.
* **FR-6 (Multi-Language Voice Localization):** Runtime language toggle (`EN`, `ES`, `JA`, `ZH`) playing localized tactical radio transmissions with on-screen subtitles.
* **FR-7 (Cyberpunk Tactical HUD & Telemetry):**
  - Sector teleportation bar (`[ 1. Rooftop ]`, `[ 2. Server Room ]`, `[ 3. Flooded Conduit ]`, `[ 4. Extraction Arena ]`).
  - 2D Spatial Radar overlay (`OpenDouRadarView`) displaying player position/orientation, emitter positions, acoustic room bounds, and diffraction rays.
  - Live telemetry card displaying active physical voices (16), virtual voices, DSP $\mu s$, active snapshot, room $RT_{60}$, and portal occlusion %.

### Non-Functional Requirements
* **NFR-1 (Performance & 60 FPS):** All spatial acoustics, raycast occlusion, ducking matrices, and voice pool resolutions must execute within $\le 0.5\text{ ms}$ per physics frame.
* **NFR-2 (Zero Code-Generated Full UIs):** All 3D meshes, lights, audio listeners, cameras, and UI nodes must be declaratively wired inside the `.tscn` file; `.gd` scripts are strictly for logic and signal bindings.
* **NFR-3 (Headless Test Verification):** Scene and coordinator must instantiate and execute cleanly in headless CLI test runners without crashing.

---

## 2. API Design & Interfaces

### Class: `OpenDouCyberpunkInfiltrationDemo`
```gdscript
class_name OpenDouCyberpunkInfiltrationDemo
extends Node3D

## Master coordinator for Cyberpunk Infiltration AAA Showcase Demo

var voice_pool: VoicePoolManager
var spatial_acoustics: SpatialAcousticsManager
var live_update_server: LiveUpdateServer
var music_director: MusicPlaylistManager
var ducking_matrix: AudioDuckingMatrix
var dialogue_manager: AudioDialogueManager

func teleport_to_sector(sector_idx: int) -> void:
    pass

func toggle_server_airlock() -> void:
    pass

func trigger_siege_bombardment() -> void:
    pass

func set_combat_intensity(intensity: float) -> void:
    pass

func set_voice_locale(locale_code: String) -> void:
    pass
```

---

## 3. Data Structures & Scene Manifest

### Scene Path
* `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
* `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`

### Demo Hub Registration
* Added as Demo 7 and prominent showcase hero card in `scenes/demos/demo_hub.tscn` and `scenes/demos/demo_hub.gd`.

---

## 4. Test & Verification Plan

* [ ] Headless instantiation and system initialization verification (`test_cyberpunk_demo.gd`).
* [ ] Teleportation and sector acoustic parameter verification.
* [ ] Airlock portal diffraction and occlusion toggle verification.
* [ ] Voice pool 250-emitter bombardment stress test and voice stealing verification.
* [ ] Multi-language dialogue switching and ducking matrix attenuation verification.
* [ ] Full regression suite execution (`godot --headless -s tests/test_runner_cli.gd`) passing 100%.
