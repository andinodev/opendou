# Technical Specification: Sector 5 Biosphere 7.1 Surround Showcase

**Module:** `scenes/demos/07_cyberpunk_infiltration`, `addons/opendou/runtime`, `addons/opendou/nodes`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved / Ready for Implementation`

---

## 1. Objective & Overview

Add **Sector 5: Cyber-Biosphere Sanctuary** to [`demo_cyberpunk_infiltration.tscn`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn) to demonstrate true **7.1 Surround & 360° Spatial Immersion** using OpenDou declarative nodes (`OpenDouRoom3D`, `OpenDouPortal3D`, `OpenDouEventPlayer3D`, `OpenDouAudibleMonitor`).

The sector features a dense organic biodome with lush acoustic foliage absorption, crystal dome reflections, 8 discrete positional nature emitters matching 7.1 speaker axes, and an orbiting spatial wildlife emitter showcasing seamless circular panning.

---

## 2. 7.1 Surround Channel Layout & Spatial Emitter Mapping

| 7.1 Channel | Spatial Position (Rel to Center `(80, 0, 0)`) | Soundscape Layer | Synthesis Preset | Bus Category |
| :--- | :--- | :--- | :--- | :--- |
| **Front Left (FL)** | `(-6.0, 3.5, -6.0)` | Canopy Wind & Rustle | `"Wind_Canopy"` | `Ambience` |
| **Front Right (FR)** | `(6.0, 3.5, -6.0)` | Distant Waterfall / Stream | `"Water_Stream"` | `Ambience` |
| **Center (C)** | `(0.0, 2.0, -8.0)` | Exotic Synth Bird Chirps | `"Bird_Chirp"` | `SFX` |
| **LFE (Subwoofer)** | `(0.0, -0.5, 0.0)` | Seismic Thunder Rumble (<80Hz) | `"Thunder_Rumble"` | `SFX` |
| **Side Left (SL)** | `(-9.0, 1.5, 0.0)` | Cicada / Insect Swarm Left | `"Cicada_Swarm"` | `Ambience` |
| **Side Right (SR)** | `(9.0, 1.5, 0.0)` | Micro Foliage & Frog Croaks | `"Frog_Croak"` | `Ambience` |
| **Rear Left (RL)** | `(-6.0, 2.5, 6.0)` | Distant Atmospheric Rain | `"Rain"` | `Ambience` |
| **Rear Right (RR)** | `(6.0, 2.5, 6.0)` | Canopy Dripping & Twig Snaps | `"Water_Droplet"` | `Ambience` |
| **Orbiting 360°** | Continuous Orbit ($R = 5.0\text{m}$) | Orbiting Cyber Hornet | `"Engine"` / `"Tone"` | `SFX` |

---

## 3. Acoustic Room Design & Sabine Parameters

* **`OpenDouRoom3D` (`BiosphereRoom`):**
  * Center: `Vector3(80.0, 0.0, 0.0)`, Dimensions: `Vector3(30.0, 12.0, 30.0)`.
  * Material: `"Curtains"` (High organic absorption from dense vegetation, $\alpha = 0.60$).
  * Calculated Sabine $RT_{60} \approx 0.38\text{s}$ (Dry, articulate intimacy preventing phase wash).
* **`OpenDouPortal3D` (`ArenaToBiospherePortal`):**
  * Position: `Vector3(65.0, 1.5, 0.0)`, Width: $4.0\text{m}$.
  * Links `ExtractionArenaRoom` (Sector 4) with `BiosphereRoom` (Sector 5).

---

## 4. Procedural Synthesis Extensions in `AudioSynthesizer`

Extend `AudioSynthesizer` with procedural algorithms for organic nature:
1. `create_canopy_wind_loop(duration: float = 3.0) -> AudioStreamWAV`: Multi-band filtered pink noise with slow amplitude breathing.
2. `create_bird_chirp(frequency: float = 2400.0, duration: float = 0.35) -> AudioStreamWAV`: Frequency-modulated exponential chirps with harmonic overtones.
3. `create_thunder_rumble(duration: float = 2.5) -> AudioStreamWAV`: Sub-bass rumble (35 Hz - 75 Hz) with low-frequency saturation envelope.
4. `create_cicada_swarm_loop(duration: float = 2.0) -> AudioStreamWAV`: Amplitude-modulated resonant bandpass at 5.2 kHz.
5. `create_water_droplet(pitch: float = 1200.0) -> AudioStreamWAV`: Resonant impulse sine decay with pitch bend.

---

## 5. Verification Plan

* [ ] Unit tests in `tests/test_cyberpunk_demo.gd`:
  * Test Sector 5 node presence in `demo_cyberpunk_infiltration.tscn`.
  * Test 7.1 surround emitters configuration (`CanopyWind_FL`, `Waterfall_FR`, `Bird_C`, `Thunder_LFE`, `Cicada_SL`, `Frog_SR`, `Rain_RL`, `Droplet_RR`).
  * Test Teleport to Sector 5 (`teleport_to_sector(5)`).
  * Test Footstep surface detection returns `&"Foliage"` / `&"Dirt"`.
* [ ] Full regression suite execution (`godot --headless -s tests/test_runner_cli.gd`) passing 100%.
