# Task 3 Brief: Cyberpunk Infiltration Demo Integration & Tactical HUD Controls

## Files to touch:
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`
- Modify: `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`
- Modify: `docs/tasks/current.md`

## Testing Command:
- You can run tests using:
  `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`
  or
  `powershell.exe -ExecutionPolicy Bypass -File .\run_tests.ps1`
- Exit code 0 means PASS.

## Requirements:
1. In `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn`:
   - Add ExtResource for `opendou_acoustic_debugger_3d.gd`.
   - Add node `AcousticDebugger` under `LevelGeometry` with `script = ExtResource(...)`, `enabled = true`, `probe_ray_count = 24`, `show_unit_size_core = true`, `show_occlusion_rays = true`, `show_sound_field_mesh = true`.
   - Add button `BtnToggleAcoustics` (`Button`) with text `"👁️ Sound Field: ON (G)"` inside `TacticalHUD` (`UI/ControlsPanel/Margin/HBox`).
   - Add label `LblSoundField` inside `UI/HUDPanel/Margin/VBox` with text `"Sound Field: 24 Probes (ON)"`.

2. In `scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.gd`:
   - Declare `@onready var acoustic_debugger: OpenDouAcousticDebugger3D = get_node_or_null("LevelGeometry/AcousticDebugger")`
   - Declare `@onready var btn_toggle_acoustics: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnToggleAcoustics")`
   - Declare `@onready var lbl_sound_field: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblSoundField")`
   - Connect `btn_toggle_acoustics.pressed` to `_on_toggle_acoustics_pressed()`.
   - In `_unhandled_input(event)`: Handle `KEY_G` pressing to toggle acoustic debugger.
   - Implement `_on_toggle_acoustics_pressed()`:
     * Toggles `acoustic_debugger.toggle_debug()`
     * Updates button text to `"👁️ Sound Field: ON (G)"` / `"👁️ Sound Field: OFF (G)"`
     * Updates `_update_hud()`
   - In `_update_hud()`:
     * If `lbl_sound_field` is valid: update text to `"Sound Field: %s (%d Probes)" % ["ON" if (acoustic_debugger and acoustic_debugger.enabled) else "OFF", acoustic_debugger.probe_ray_count if acoustic_debugger else 24]`.

3. In `tests/test_cyberpunk_demo.gd`:
   - Add Test 27 asserting:
     * `AcousticDebugger` node exists in `demo_cyberpunk_infiltration.tscn` and is an `OpenDouAcousticDebugger3D`.
     * `BtnToggleAcoustics` exists in `TacticalHUD`.
     * Calling `_on_toggle_acoustics_pressed()` toggles debugger `enabled` state.

4. In `docs/tasks/completed.md`:
   - Document `TASK-048 - 3D Volumetric Acoustic Sound Field Debugger`.

5. In `docs/tasks/current.md`:
   - Set to None (completed).

6. Run test runner and confirm 100% tests pass (exit code 0).
7. Commit:
   `git add scenes/demos/07_cyberpunk_infiltration/ tests/test_cyberpunk_demo.gd docs/tasks/`
   `git commit -m "feat(demos): integrate OpenDouAcousticDebugger3D and tactical HUD toggle in Cyberpunk demo (Task 3 - TASK-048)"`
