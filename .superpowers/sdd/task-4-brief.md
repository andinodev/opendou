# Task 4 Brief: Mode 3 Workspace Integration in OpenDou Studio & Transport Bar

## Files to touch:
- Modify: `addons/opendou/editor/opendou_studio_main.gd`
- Modify: `addons/opendou/editor/opendou_transport_bar.gd`
- Modify: `tests/test_studio_advanced_ui.gd`
- Modify: `docs/tasks/completed.md`

## Testing Command:
- You can run tests using:
  `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  or
  `powershell.exe -ExecutionPolicy Bypass -File .\run_tests.ps1`
- Exit code 0 means PASS.

## Requirements:
1. In `addons/opendou/editor/opendou_studio_main.gd`:
   - Declare `const OpenDouSynthRackWorkspaceClass = preload("res://addons/opendou/editor/opendou_synth_rack_workspace.gd")`.
   - Declare `var synth_workspace: PanelContainer`.
   - In `_build_ui()`:
     * Add Mode 3 to `mode_selector`: `mode_selector.add_item("⚡ Synth", 3)`.
     * In `center_workspace_box`: instantiate `synth_workspace = OpenDouSynthRackWorkspaceClass.new()`, add as child, set `synth_workspace.visible = false`.
   - In `set_workspace_mode(mode: int)`:
     * When `mode == 3`:
       - `graph_editor.visible = false`
       - `music_timeline.visible = false`
       - `dialogue_grid.visible = false`
       - `synth_workspace.visible = true`
       - `locale_selector.visible = false`
       - `snap_selector.visible = false`
       - `transport_bar.set_workspace_context(3)`
     * When `mode == 0, 1, 2`: set `synth_workspace.visible = false`.

2. In `addons/opendou/editor/opendou_transport_bar.gd`:
   - In `set_workspace_context(mode: int)`:
     * When `mode == 3`:
       - Set active badge: `"⚡ Synth Preset Studio"`.
       - Show audition buttons (`btn_play`, `btn_stop`, `btn_loop`).
       - Adapt faders for synth context (e.g. Octave shift or Master Gain).

3. In `tests/test_studio_advanced_ui.gd`:
   - Add Test 11 testing Mode 3 switching:
     * `studio.set_workspace_mode(3)` makes `synth_workspace.visible == true` while hiding graph, music, and voice.
     * Transport bar context updates to Mode 3.

4. In `docs/tasks/completed.md`:
   - Document `TASK-046 - OpenDou VST Modular Synth Rack Workstation (Mode 3)`.

5. Run test runner and confirm 100% tests pass (exit code 0).
6. Commit:
   `git add addons/opendou/editor/ tests/test_studio_advanced_ui.gd docs/tasks/completed.md`
   `git commit -m "feat(studio): integrate Mode 3 Synth Workstation and complete TASK-046 (Task 4)"`
