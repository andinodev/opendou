# Technical Specification: OpenDou AAA Demo Suite & Showcase Scenes (Godot 4.7+)

**Module:** `scenes/demos/`
**Status:** Approved / In Progress
**Reference Requirements:** Dedicated demonstration scenes highlighting AAA audio capabilities that vanilla Godot cannot perform natively.

---

## 1. Objective & Scope

This specification defines a comprehensive suite of interactive demonstration scenes for **Godot 4.7+**. Each scene is isolated and designed to showcase advanced middleware audio features:

```text
scenes/demos/
├── demo_hub.tscn               # Master showcase launcher with scene selector & telemetry
├── 01_spatial_rooms_portals/   # Macro-Acoustics: Doorway diffraction, Rooms & Portals
├── 02_massive_voice_stress/    # 250+ Emitters: Voice Stealing, Prioritization & Virtual Tracking
├── 03_surface_switches_3d/     # 3D Character Controller: Dynamic Footstep Surfaces & Shuffle
├── 04_vehicle_blend_rpm/       # Engine Simulator: RPM Spline Crossfading with O(1) LUT & Silence Culling
├── 05_dynamic_occlusion_ray/   # Moving Obstacles: Multi-ray Physics Occlusion & Slew-Rate Smoothing
└── 06_soundbank_streaming/     # Prefetch RAM Instant Attack & RingBuffer Disk Streaming
```

---

## 2. Detailed Scene Breakdown

### 🎯 Demo 01: Macro-Acoustics & Acoustic Pathfinding (`01_spatial_rooms_portals`)
* **What Vanilla Godot Lacks:** `AudioStreamPlayer3D` cannot calculate sound diffraction through open/closed doorways or bend apparent sound origins along acoustic paths.
* **Demonstration:**
  * Two enclosed rooms (`AudioRoom`) connected by an interactive swinging door (`AudioPortal`).
  * Sound source inside Room A; listener moves around Room B.
  * Opening/closing the door dynamically modulates diffraction distance, apparent origin, and low-pass filtering ($200\text{ Hz} \le \text{LPF} \le 20000\text{ Hz}$).

### ⚡ Demo 02: Massive Voice Starvation & Virtual Tracking (`02_massive_voice_stress`)
* **What Vanilla Godot Lacks:** 200+ `AudioStreamPlayer3D` instances consume high CPU DSP cycles mixing inaudible sounds at distance; lacks dynamic voice stealing and virtual tracking.
* **Demonstration:**
  * 250 active sound emitters in a stress grid.
  * Hardware voice pool capped at 16 physical channels.
  * Dynamic weight calculation ($W = \text{Base} \times \text{Vol} \times \text{Dist}$), hysteresis (+5%), anti-clicking micro-fades (15ms), and pitch-scaled virtual timeline tracking.

### 👟 Demo 03: Dynamic Footsteps & Surface Switches (`03_surface_switches_3d`)
* **What Vanilla Godot Lacks:** Requires complex hardcoded scripts per surface.
* **Demonstration:**
  * Playable 3D character walking over Wood, Concrete, Metal Grate, and Water surfaces.
  * Single event post: `OpenDou.post_event(&"Footstep", player)`.
  * `AudioSwitchContainer` selects surface branch; `AudioRandomContainer` applies shuffle-bag anti-repetition and pitch/volume jitter.

### 🏎️ Demo 04: Vehicle Engine RPM Crossfading (`04_vehicle_blend_rpm`)
* **What Vanilla Godot Lacks:** No multi-layer spline blend crossfading with silence culling ($\le -80\text{ dB}$) and $O(1)$ LUT curve acceleration.
* **Demonstration:**
  * Tachometer accelerator pedal (0 to 8000 RPM).
  * `AudioBlendContainer` seamlessly crossfades *Idle, Low, Mid, High, Redline* layers with pitch scaling.

### 🧱 Demo 05: Dynamic Moving Obstacle Raycast Occlusion (`05_dynamic_occlusion_ray`)
* **What Vanilla Godot Lacks:** Abrupt volume/filter changes in native Godot cause audio pops and zipper noise.
* **Demonstration:**
  * Moving pillar/wall translating between emitter and listener.
  * Multi-ray raycasting calculating fractional occlusion $\Omega \in [0.0, 1.0]$.
  * Temporal slew-rate smoothing ($\kappa = 8.0\text{ s}^{-1}$) eliminating audio artifacts.

### 📦 Demo 06: Monolithic SoundBank Prefetch & Streaming (`06_soundbank_streaming`)
* **What Vanilla Godot Lacks:** Godot loads individual files into memory or requires multiple open file handles.
* **Demonstration:**
  * Instant zero-latency playback from RAM prefetch slice transitioning seamlessly to disk ring-buffer streaming from a single monolithic `.bank` file with underrun protection.

---

## 3. Acceptance Criteria (DoD)

1. Each demo scene functions stand-alone and can be launched from the master `demo_hub.tscn`.
2. Clean on-screen UI overlay with controls, descriptions, and real-time telemetry gauges.
3. 100% automated test coverage for demo helper controllers in `tests/test_demo_suite.gd`.
