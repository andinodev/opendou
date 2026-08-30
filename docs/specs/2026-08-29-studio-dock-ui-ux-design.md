# OpenDou Audio Studio Suite - UI/UX & Windowing Architecture Spec

**Status:** Approved  
**Date:** 2026-08-29  
**Target:** Godot 4.7+ / OpenDou Audio Middleware  

---

## 1. Overview & Problem Statement

The OpenDou Studio interface previously suffered from container layout issues:
1. **The Gray Void:** The bottom portion of the editor dock was dead, unused gray space due to missing `PRESET_FULL_RECT` and `SIZE_EXPAND_FILL` vertical container properties.
2. **Mixer Obstruction:** Embedding the HDR Console inside the main view with a vertical splitter stole vertical workspace height from the Graph and DAW.
3. **Context Inconsistency:** The bottom transport bar displayed SFX sliders (`Distance`, `Pitch Jitter`) regardless of whether the user was editing a music suite or voice localization table.
4. **Horizontal Squeezing:** Sidebars (*Game Syncs* and *Live Profiler*) crowded the central canvas.

---

## 2. Technical Architecture & Windowing Model

### 2.1 Maximized Main Studio Window
* **Auto-Maximize on Open:** When the plugin is activated or opened via the bottom panel or top Main Screen tab, it invokes `detach_and_maximize()` to spawn a dedicated window in `Window.MODE_MAXIMIZED`.
* **Zero-Waste Layout Structure:**
  * Root Container: `PanelContainer` with `anchors_preset = Control.PRESET_FULL_RECT`, `size_flags_horizontal = SIZE_EXPAND_FILL`, `size_flags_vertical = SIZE_EXPAND_FILL`.
  * Top Toolbar (34px): Mode switchers (`🌐 Graph`, `🎼 Music`, `🗣️ Voice`), event selector, save button, and quick launchers for floating tool windows (`[ 🎚️ HDR ]`, `[ 🎮 Syncs ]`, `[ 📊 Profiler ]`, `[ 📦 Banks ]`).
  * Center Canvas (100% Elastic Expansion): Active workspace (Graph Editor / Music DAW / Voice Grid) occupying the entire screen area edge-to-edge.
  * Bottom Bar (32px): Context-aware transport and status bar anchored to the bottom.

### 2.2 Independent Draggable Floating Tool Windows
To keep 100% of the main canvas available for creative work, auxiliary panels operate as independent, movable, resizable `Window` instances:

1. **🎚️ HDR Mixing Console & Ducking Matrix Window:**
   * Title: `"🎚️ OpenDou HDR Mixing Console & Ducking Matrix"`
   * Initial Size: `760x440` (resizable).
   * Contains Master, Music, SFX, Voice, Ambient channel strips with Solo `[ S ]` and Mute `[ M ]` buttons, editable dB `SpinBox` inputs, gain reduction LED meters, and the 4x4 Ducking Matrix grid editor.

2. **🎮 Game Syncs & Simulation Window:**
   * Title: `"🎮 OpenDou Game Syncs Manager"`
   * Initial Size: `460x480` (resizable).
   * Contains tabs for RTPCs (Parameter, Range, Default Value), States, and Switches, backed by persistent `opendou_syncs.json`.

3. **📊 Live Profiler & SoundBanks Window:**
   * Title: `"📊 OpenDou Live Profiler & Telemetry"`
   * Initial Size: `820x540` (resizable).
   * Contains Voice Stealing Ledger, High-Density DSP CPU (µs) performance graph with Time-Travel scrubbing, 2D Spatial Acoustic Radar (rooms, portals, reflections), and SoundBank compiler.

---

## 3. Context-Aware Bottom Transport Bar

The bottom transport bar mutates dynamically based on the active workspace:

* **Mode `🌐 Graph`:**
  * Audition Transport: `[ ▶ Play ]`, `[ ⏸ Pause ]`, `[ ⏹ Stop ]`.
  * Event Badge: `Audition: [Active_Event.tres]`.
  * Contextual RTPC Sliders: Exact sliders for the active event (e.g. `Distance (m)`, `RPM`, `Pitch Jitter (±)`).
  * Master Section: Master Volume slider + SpinBox, Stereo L/R Peak VU meter.

* **Mode `🎼 Music DAW`:**
  * Hides SFX distance/pitch sliders to avoid duplication with DAW controls.
  * Displays Real-Time Beat/Bar Counter (`⏱️ Bar 1 : Beat 1.0`), Tempo (`120 BPM`), Quantization Mode, and Dirty state indicator (`*`).
  * Master Section: Master Volume slider and Stereo VU meter.

* **Mode `🗣️ Voice`:**
  * Line Audition controls (`[ ▶ Play ]`, `[ ⏹ Stop ]`).
  * Vocal Quality Monitor: Voice RMS meter, Quick Locale Switcher (`EN`, `ES`, `JA`, `ZH`), and 2D Raw Audition Mode.
  * Master Section: Master Volume slider and Stereo VU meter.

---

## 4. Workspace Canvas Enhancements

* **Music DAW:** 280px wide track headers to prevent stem name clipping, universal horizontal/vertical `ScrollContainer`, solid triangular handles (▼) for Entry and Exit cues, and variation counters on sub-tracks (`[ 🎲 Var: N ]`).
* **Voice Grid:** 6-column metadata table (*Dialogue ID*, *Actor*, *Subtitle Text*, *Audio File*, *Status*, *Audition*) with native `FileDialog` browser per row.

---

## 5. Verification Plan

* **Automated Tests:** `godot --headless -s tests/test_runner_cli.gd` (100% pass rate).
* **UI Test Suite:** `tests/test_studio_advanced_ui.gd` asserting window maximization, floating tool window creation, and contextual transport bar switching.
