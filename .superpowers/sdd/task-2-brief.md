# Task 2 Brief: Pro DAW Add Track Modal with Live Synth Browser, Audition & Debouncing

## Files to touch:
- Modify: `addons/opendou/editor/opendou_music_timeline.gd`
- Modify: `tests/test_studio_advanced_ui.gd`
- Modify: `tests/test_all.gd`
- Modify: `docs/tasks/completed.md`
- Modify: `docs/tasks/current.md`

## Testing Command:
- You can run tests using:
  `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  or
  `powershell.exe -ExecutionPolicy Bypass -File .\run_tests.ps1`
- Exit code 0 means PASS.

## Requirements:
1. In `addons/opendou/editor/opendou_music_timeline.gd`:
   - Redesign `add_track_dialog` (min size `Vector2i(800, 550)`):
     * Card 1: Track Identity (`PanelContainer`) with `add_track_name_edit` and `add_track_color_picker`.
     * Card 2: Audio Source Engine (`PanelContainer`):
       - Toggle button bar: `btn_toggle_source_synth` (default active) vs `btn_toggle_source_file`.
       - File Source Box (`add_track_file_box`): `add_track_file_path_edit` + `btn_browse`.
       - Synth Source Box (`add_track_synth_box`):
         * Left column: Search filter `add_track_synth_search_edit` ("🔍 Search presets..."), Category Filter Buttons (`All`, `Pads`, `Leads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`), and `add_track_synth_item_list` (`ItemList`).
         * Connect `item_selected` to predictive auto-fill and debounced waveform/audition update.
         * Connect `item_activated` (double-click / Enter) to `_on_add_track_dialog_confirmed()` for instant track creation.
         * Right column: Metadata card (Name, Category, Timeline BPM sync), Audition Buttons `btn_audition_play` and `btn_audition_stop`, and waveform proxy view.
     * Card 3: Dynamic Automation & Routing (`PanelContainer`):
       - `add_track_min_spin` (0.0 to 1.0)
       - `add_track_max_spin` (0.0 to 1.0)
       - `add_track_bus_opt` (`Master`, `Music`, `Music_Percussion`, `Music_Pads`, `Music_Leads`)
   - Predictive Auto-Fill:
     * When selecting a preset, reads its category from `SynthPresetRegistry.get_preset_category(preset_name)`:
       - `"Pads"` $\to$ Color `#33bff2`, Bus `Music_Pads` (3), Range `[0.0, 0.6]`
       - `"Leads"` $\to$ Color `#fa3860`, Bus `Music_Leads` (4), Range `[0.6, 1.0]`
       - `"Bass"` $\to$ Color `#4dd973`, Bus `Music` (1), Range `[0.2, 0.8]`
       - `"Percussion"` $\to$ Color `#faa638`, Bus `Music_Percussion` (2), Range `[0.4, 1.0]`
       - `"Nature/Ambience"` $\to$ Color `#2ce8b8`, Bus `Music_Pads` (3), Range `[0.0, 0.5]`
       - `"SFX"` $\to$ Color `#bd42fa`, Bus `Music` (1), Range `[0.0, 1.0]`
     * Auto-populates `add_track_name_edit.text = "Layer %d: %s" % [next_idx, preset_name]`.
   - Debounce Timer (150ms):
     * A `Timer` that resets on rapid arrow navigation before generating the waveform preview proxy.
   - Resource Lifecycle & Memory Teardown:
     * `audition_player.stop()` and `audition_player.stream = null` when changing presets or closing dialog.
     * Teardown of all modal child nodes without leaving orphan nodes.
   - Headless CI Drawing Guard:
     * Waveform proxy control must only draw inside valid draw notifications, preventing `ERROR: Drawing is only allowed inside _draw()` in headless mode.

2. In `tests/test_studio_advanced_ui.gd`:
   - Add Test 12 covering:
     * Modal dialog size $\ge 800 \times 550\text{px}$.
     * Source toggling between Synth Preset and File.
     * Category filtering and live search matching.
     * Predictive auto-fill for Leads (`Cyber_Hornet`) and Ambience (`Wind_Canopy`).
     * Instant creation on item activation / confirm creating a track lane with `synth_preset` property.
     * Clean memory teardown without orphan nodes.
   - In `tests/test_all.gd`: Update test count for `TestStudioAdvancedUIClass` (from 11 to 12).

3. In `docs/tasks/completed.md` and `docs/tasks/current.md`:
   - Document `TASK-050` completion.

4. Run test runner and confirm 100% tests pass (exit code 0).
5. Commit:
   `git add addons/opendou/editor/opendou_music_timeline.gd tests/test_studio_advanced_ui.gd tests/test_all.gd docs/tasks/`
   `git commit -m "feat(studio): redesign Music DAW Add Track modal with live synth browser and audition (Task 2 - TASK-050)"`
