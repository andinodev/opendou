# Music DAW Pro "Add Track" Dialog & Synth Integration Plan (TASK-050)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the OpenDou Music DAW's "Add Track" modal dialog into an $800 \times 550\text{px}$ AAA split-view workstation with seamless procedural synth preset browsing, category tagging, predictive auto-fill, tempo-synced auditioning, debounced navigation, and clean memory lifecycle management.

**Architecture:** Deterministic JSON Category Schema (`opendou_synth_presets.json`) + Registry Query API (`synth_preset_registry.gd`) + 3-Card Pro DAW Modal Dialog (`opendou_music_timeline.gd`) with live audition player and double-click fast track creation.

**Tech Stack:** Godot 4.7+, GDScript (static typing), OpenDou Modular Synth Engine & Timeline Sequencer.

## Global Constraints
- Hybrid Language Model: Spanish for chat/tasks, English for code/docs/specs/comments.
- TDD & Verification: Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (or `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`) to confirm 100% pass (exit code 0).

---

### Task 1: Preset Category Schema & Registry Query API

**Files:**
- Modify: `opendou_synth_presets.json`
- Modify: `addons/opendou/runtime/synth/synth_preset_registry.gd`
- Modify: `tests/test_synth_preset_registry.gd`

**Interfaces:**
- Produces:
  * `SynthPresetRegistry.get_preset_category(preset_name: StringName) -> String`
  * `SynthPresetRegistry.get_presets_by_category(category: String) -> Array[StringName]`
  * `SynthPresetRegistry.get_all_categories() -> Array[String]`

- [ ] **Step 1: Write failing tests in `tests/test_synth_preset_registry.gd`**
  - Add Test 8 asserting:
    * `get_all_categories()` returns categories (`"Pads"`, `"Leads"`, `"Bass"`, `"Percussion"`, `"Nature/Ambience"`, `"SFX"`).
    * `get_preset_category(&"Cyber_Hornet")` returns `"Leads"`.
    * `get_preset_category(&"Wind_Canopy")` returns `"Nature/Ambience"`.
    * `get_presets_by_category("Leads")` returns array containing `&"Cyber_Hornet"`.

- [ ] **Step 2: Run tests to verify failure**
  - Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: FAIL with missing methods / category key.

- [ ] **Step 3: Update `opendou_synth_presets.json` and `synth_preset_registry.gd`**
  - Add `"category"` field to all presets in `opendou_synth_presets.json`.
  - Implement `get_preset_category()`, `get_presets_by_category()`, and `get_all_categories()` in `synth_preset_registry.gd`.

- [ ] **Step 4: Run tests to verify pass**
  - Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - `git add opendou_synth_presets.json addons/opendou/runtime/synth/synth_preset_registry.gd tests/test_synth_preset_registry.gd`
  - `git commit -m "feat(synth): add category schema and query API in SynthPresetRegistry (Task 1 - TASK-050)"`

---

### Task 2: Pro DAW Add Track Modal with Live Synth Browser, Audition & Debouncing

**Files:**
- Modify: `addons/opendou/editor/opendou_music_timeline.gd`
- Modify: `tests/test_studio_advanced_ui.gd`
- Modify: `docs/tasks/completed.md`
- Modify: `docs/tasks/current.md`

**Interfaces:**
- Consumes:
  * `SynthPresetRegistry.get_singleton().get_all_categories()`
  * `SynthPresetRegistry.get_singleton().get_presets_by_category()`
  * `ModularSynthEngine.synthesize_wav(preset, duration, bpm)`

**Requirements:**
- In `opendou_music_timeline.gd`:
  * Rebuild `add_track_dialog` ($800 \times 550\text{px}$ minimum size):
    - Card 1: Track Identity (`add_track_name_edit`, `add_track_color_picker`).
    - Card 2: Audio Source Engine:
      * Segmented toggle buttons (`[ ⚡ Procedural Synth Preset ]` vs `[ 📁 Audio File ]`).
      * Audio File container: `LineEdit` + `Button` (`Browse...`).
      * Synth Preset container (Split view):
        - Left column: Search `LineEdit`, category toggle buttons (`All`, `Pads`, `Leads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`), `ItemList` of presets with `item_activated` (double click / Enter) connected to confirm.
        - Right column: Preset info card, BPM sync indicator (`bpm`), `[ ▶ Audition ]` / `[ ⏹ Stop ]` button, waveform proxy.
    - Card 3: Dynamic Interactive Automation & Routing (`add_track_min_spin`, `add_track_max_spin`, `add_track_bus_opt`).
  * Debounce timer: 150ms delay on arrow navigation before generating proxy waveform.
  * Predictive auto-fill:
    - `"Pads"` $\to$ Color `#33bff2` (Cyan), Bus `Music_Pads`, Range `[0.0, 0.6]`.
    - `"Leads"` $\to$ Color `#fa3860` (Pink/Red), Bus `Music_Leads`, Range `[0.6, 1.0]`.
    - `"Bass"` $\to$ Color `#4dd973` (Green), Bus `Music`, Range `[0.2, 0.8]`.
    - `"Percussion"` $\to$ Color `#faa638` (Amber), Bus `Music_Percussion`, Range `[0.4, 1.0]`.
    - `"Nature/Ambience"` $\to$ Color `#2ce8b8` (Teal), Bus `Music_Pads`, Range `[0.0, 0.5]`.
  * Track creation via `_on_add_track_dialog_confirmed()`:
    - Sets track `audio_file_path = ""` and metadata `synth_preset = preset_name`.
    - Updates stem players using `SynthPresetRegistry.get_preset_stream()`.
  * Proper resource cleanup: `audition_player.stop()`, `audition_player.stream = null`, `queue_free()` on dialog exit.
  * Headless drawing guard: ensure waveform proxy doesn't attempt `_draw` outside valid draw notifications.

- [ ] **Step 1: Write failing tests in `tests/test_studio_advanced_ui.gd`**
  - Add Test 12 asserting:
    * Modal dimensions $\ge 800 \times 550\text{px}$.
    * Toggle source switching between Synth Preset and File.
    * Category filtering and search query matching.
    * Predictive auto-fill of Name, Color, and Audio Bus.
    * Double-click item activation instantiating track with `synth_preset`.
    * Teardown of audition stream without orphan nodes.

- [ ] **Step 2: Run tests to verify failure**
  - Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: FAIL with missing UI components / test assertions.

- [ ] **Step 3: Implement redesigned Add Track modal in `opendou_music_timeline.gd`**
  - Build the 3-card layout, split-view synth browser, debounced navigation, and auto-fill.

- [ ] **Step 4: Run tests to verify pass**
  - Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  - Expected: 100% tests pass (exit code 0, 0 failures).

- [ ] **Step 5: Document and Commit**
  - Update `docs/tasks/completed.md` and `docs/tasks/current.md`.
  - `git add addons/opendou/editor/opendou_music_timeline.gd tests/test_studio_advanced_ui.gd docs/tasks/`
  - `git commit -m "feat(studio): redesign Music DAW Add Track modal with live synth browser and audition (Task 2 - TASK-050)"`
