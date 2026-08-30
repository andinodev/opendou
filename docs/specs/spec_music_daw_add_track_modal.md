# Technical Specification: Music DAW Pro "Add Track" Dialog & Synth Integration

**Module:** `addons/opendou/editor/opendou_music_timeline.gd`, `opendou_synth_presets.json`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved / Ready for Plan & Implementation`

---

## 1. Objective & Vision

Upgrade the OpenDou Music Timeline's **"Add Track / Stem Layer" modal dialog** from a basic static popup into a **high-productivity AAA DAW Workstation component**.

### Core Pillars:
1. **Seamless Synth & File Integration:** Native support for both physical audio files (`.wav / .ogg`) and procedural synth presets (`SynthPresetRegistry` / `ModularSynthEngine`) via clean segmented toggle buttons.
2. **Embedded Synth Preset Library Browser:** Integrated search bar, deterministic category filters (`Pads`, `Leads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`), 150ms debounced navigation, double-click instant track instantiation, and live tempo-synced audition player.
3. **Predictive Auto-Fill & Bus Routing:** Instant automatic assignment of track name, layer index, DAW color coding, and audio bus routing (`Music_Pads`, `Music_Leads`, `Music_Percussion`, `Music`).
4. **Editor Cleanliness & Headless CI Safety:** Robust memory management, zero orphan nodes (`queue_free()` on dialog exit), and headless drawing guards.

---

## 2. UI Layout & Component Hierarchy

```text
┌────────────────────────────────────────────────────────────────────────┐
│  ➕ Add New Music Track / Stem Layer                       [ _ ][ X ]  │
├────────────────────────────────────────────────────────────────────────┤
│  [ 🏷️ 1. Track Identity ]                                              │
│  Track Name: [ Layer 5: Cyber_Hornet               ]  Color: [ 🟩 ]     │
├────────────────────────────────────────────────────────────────────────┤
│  [ 🔊 2. Audio Source Engine ]                                         │
│  Source Type: [ ⚡ Procedural Synth Preset (Active) ] [ 📁 Audio File ]  │
│                                                                        │
│  ┌───────────────────────────┬───────────────────────────────────────┐ │
│  │ 🔍 Search presets...      │ 🏷️ Category: Leads / Arps              │ │
│  │ [All][Pads][Leads][Bass]  │ Preset: Cyber_Hornet                  │ │
│  │                           │ BPM Sync: 120.0 BPM (Timeline Match)  │ │
│  │ Preset List:              │                                       │ │
│  │ • Wind_Canopy             │ [ ▶ Audition Preset ]   [ ⏹ Stop ]    │ │
│  │ • Cyber_Hornet      ◀     │ ------------------------------------  │ │
│  │ • Thunder_Rumble          │ Waveform Preview (1s Proxy):          │ │
│  │ • Bass_Sub_Reese          │ [ ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿ ] │ │
│  └───────────────────────────┴───────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────┤
│  [ 🎚️ 3. Dynamic Interactive Automation & Routing ]                    │
│  Intensity Range: [Min: 0.20 ▾] ─── [Max: 0.80 ▾]                      │
│  Output Audio Bus: [ Music_Leads ▾ ]                                   │
├────────────────────────────────────────────────────────────────────────┤
│                                            [ Cancel ]  [ Create Track ]│
└────────────────────────────────────────────────────────────────────────┘
```

* **Window Size:** Min `800 x 550 px` centered popup dialog.
* **Layout Structure:**
  * **Card 1: Track Identity (`PanelContainer`):**
    * `add_track_name_edit` (`LineEdit`).
    * `add_track_color_picker` (`ColorPickerButton`).
  * **Card 2: Audio Source Engine (`PanelContainer`):**
    * Segmented Toggle Buttons: `[ ⚡ Procedural Synth Preset ]` vs `[ 📁 Audio File (.wav/.ogg) ]`.
    * **File Mode Box:** `LineEdit` with file path + `Button` (`📁 Browse...`) opening `FileDialog`.
    * **Synth Mode Split View:**
      * **Left Column:** Live `LineEdit` search filter + Tag Category filter buttons (`All`, `Pads`, `Leads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`) + `ItemList` of available presets.
      * **Right Column:** Preset metadata card + `Button` (`[ ▶ Audition ]` / `[ ⏹ Stop ]`) + Waveform preview panel.
  * **Card 3: Automation & Routing (`PanelContainer`):**
    * `add_track_min_spin` (`SpinBox`, step `0.05`, min `0.0`, max `1.0`).
    * `add_track_max_spin` (`SpinBox`, step `0.05`, min `0.0`, max `1.0`).
    * `add_track_bus_opt` (`OptionButton`: `Master`, `Music`, `Music_Percussion`, `Music_Pads`, `Music_Leads`).

---

## 3. Data Flow & Behavioral Architecture

### 3.1. Preset Category Schema in `opendou_synth_presets.json`
Each synth preset object specifies an explicit `"category"` string:
* `"category": "Pads"` $\to$ Color `#33bff2` (Cyan), Bus `Music_Pads`, Intensity Range `[0.0, 0.6]`.
* `"category": "Leads"` $\to$ Color `#fa3860` (Pink/Red), Bus `Music_Leads`, Intensity Range `[0.6, 1.0]`.
* `"category": "Bass"` $\to$ Color `#4dd973` (Emerald Green), Bus `Music`, Intensity Range `[0.2, 0.8]`.
* `"category": "Percussion"` $\to$ Color `#faa638` (Amber/Orange), Bus `Music_Percussion`, Intensity Range `[0.4, 1.0]`.
* `"category": "Nature/Ambience"` $\to$ Color `#2ce8b8` (Teal), Bus `Music_Pads`, Intensity Range `[0.0, 0.5]`.
* `"category": "SFX"` $\to$ Color `#bd42fa` (Purple), Bus `Music`, Intensity Range `[0.0, 1.0]`.

### 3.2. Debounced Keyboard Navigation (150ms)
When navigating the preset `ItemList` via arrow keys ($\uparrow / \downarrow$):
1. Immediately update text selections and category badges.
2. Restart internal `Timer` (`debounce_timer.start(0.15)`).
3. On timeout: generate the 1-second waveform proxy and load the audition stream buffer without locking the main thread.

### 3.3. Double-Click Quick Instantiation
* Connecting `item_activated` (double click / Enter key) on the preset `ItemList` directly triggers `_on_add_track_dialog_confirmed()`, instantiating the track lane in the DAW immediately.

### 3.4. Lifecycle & Resource Teardown (Orphan Prevention)
* The modal's internal `audition_player` is added as a child of the dialog.
* When changing presets, `audition_player.stop()` is called and `audition_player.stream = null` releases the previous PCM buffer.
* On `_exit_tree()` or modal closing, all sub-resources are explicitly stopped and freed.

---

## 4. Verification & Testing Plan

* **Unit & Integration Suite (`tests/test_studio_advanced_ui.gd`):**
  * **Test 12:**
    * Open `open_add_track_dialog()` and assert minimum size is at least $800 \times 550\text{px}$.
    * Toggle between `Procedural Synth Preset` and `Audio File`.
    * Verify search filter and category filtering (`Pads`, `Leads`, `Bass`, `Percussion`).
    * Verify predictive auto-fill (Track Name, Color, Audio Bus).
    * Verify double-click / instant confirmation creating a track with valid synth preset binding.
    * Verify clean teardown with no orphan nodes or leaked `AudioStream` buffers.
* **CLI Automated Test Runner:**
  * Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`).
  * Must achieve 100% pass rate (exit code 0, 0 failures).
