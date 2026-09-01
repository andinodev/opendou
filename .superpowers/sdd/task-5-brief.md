# Task 5 Brief: Demo Hub Registration & Comprehensive Test Suite

## Files to touch:
- Modify: `scenes/demos/demo_hub.gd`
- Modify: `scenes/demos/demo_hub.tscn`
- Modify: `tests/test_cyberpunk_demo.gd`
- Modify: `docs/tasks/completed.md`

## Requirements:
1. In `scenes/demos/demo_hub.gd`:
   - Add entry `7: "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn"` in `DEMO_SCENES`.
   - Wire `btn_launch7` to `switch_to_demo(7)`.
2. In `scenes/demos/demo_hub.tscn`:
   - Add a Hero Showcase Card for Demo 7: `[ 🎮 Launch Demo 7: Cyberpunk Infiltration (AAA Showcase) ]`.
3. In `tests/test_cyberpunk_demo.gd`:
   - Verify `DemoHub` contains key `7` pointing to `07_cyberpunk_infiltration`.
   - Ensure all tests pass.
4. In `docs/tasks/completed.md`:
   - Add entry for `TASK-041 - Cyberpunk Infiltration AAA Showcase Demo` documenting all implemented systems and verification.
5. Run `godot --headless -s tests/test_runner_cli.gd` and verify 100% pass (exit code 0).
6. Commit:
   `git add scenes/demos/demo_hub.gd scenes/demos/demo_hub.tscn tests/test_cyberpunk_demo.gd docs/tasks/completed.md`
   `git commit -m "feat(demos): register Cyberpunk Infiltration in DemoHub and complete TASK-041 (Task 5)"`
