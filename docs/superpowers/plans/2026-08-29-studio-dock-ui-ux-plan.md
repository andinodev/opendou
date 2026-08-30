# OpenDou Studio Suite - UI/UX & Floating Window Architecture Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the OpenDou Studio into a 100% edge-to-edge maximized workspace with zero wasted gray space, movable floating tool windows for HDR Mixer, Game Syncs, and Live Profiler, and a reactive context-aware bottom transport bar.

**Architecture:** The main editor runs in an auto-maximized `Window` (`Window.MODE_MAXIMIZED`) where the active workspace (Graph / Music / Voice) consumes 100% of the viewport. Auxiliary inspectors and mixing console operate as independent draggable `Window` modals spawned on demand. The bottom transport bar adapts its controls dynamically per workspace.

**Tech Stack:** Godot 4.7+, GDScript (Static Typing), Native Control Containers (`PanelContainer`, `HBoxContainer`, `VBoxContainer`, `ScrollContainer`), Window API.

## Global Constraints
- Pure English for code, variables, functions, and architecture.
- Strict static typing on all GDScript variables and function signatures.
- Zero gray void / dead space: all containers must use `Control.PRESET_FULL_RECT` and `size_flags_vertical = Control.SIZE_EXPAND_FILL`.
- 100% test pass rate with `godot --headless -s tests/test_runner_cli.gd`.

---

### Task 1: Auto-Maximized Window & Zero-Waste Root Layout

**Files:**
- Modify: `addons/opendou/editor/opendou_studio_main.gd`
- Modify: `addons/opendou/plugin.gd`
- Test: `tests/test_studio_advanced_ui.gd`

**Interfaces:**
- Produces: `OpenDouStudioMain.detach_and_maximize()` setting `Window.MODE_MAXIMIZED` and anchoring `content_container` to `PRESET_FULL_RECT`.
- Consumes: Godot `EditorPlugin.add_control_to_bottom_panel` and `_make_visible`.

- [ ] **Step 1: Write test asserting window maximization and full-rect layout**

```gdscript
# In tests/test_studio_advanced_ui.gd
var studio = OpenDouStudioMainClass.new()
studio.detach_and_maximize()
if studio.detached_window == null or studio.detached_window.mode != Window.MODE_MAXIMIZED:
    failures.append("Test: Studio detached window must be MODE_MAXIMIZED")
if studio.content_container.anchors_preset != Control.PRESET_FULL_RECT:
    failures.append("Test: Content container must have PRESET_FULL_RECT")
studio.reattach_to_dock()
studio.free()
```

- [ ] **Step 2: Run test runner to verify test execution**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: Test runs and passes/fails cleanly.

- [ ] **Step 3: Update `detach_and_maximize()` and root layout in `opendou_studio_main.gd`**

```gdscript
func detach_and_maximize() -> void:
    if is_detached:
        if detached_window:
            detached_window.mode = Window.MODE_MAXIMIZED
            detached_window.grab_focus()
        return
        
    var root = get_editor_root_node()
    if not root:
        return
        
    is_detached = true
    if dock_placeholder:
        dock_placeholder.visible = true
    if content_container:
        remove_child(content_container)
        
    detached_window = Window.new()
    detached_window.title = "🎧 OpenDou Audio Studio Suite (Maximized)"
    detached_window.min_size = Vector2i(1000, 600)
    detached_window.wrap_controls = false
    detached_window.close_requested.connect(reattach_to_dock)
    
    content_container.anchors_preset = Control.PRESET_FULL_RECT
    content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detached_window.add_child(content_container)
    root.add_child(detached_window)
    
    detached_window.popup_centered()
    detached_window.mode = Window.MODE_MAXIMIZED
    detached_window.grab_focus()
```

- [ ] **Step 4: Run test runner to verify it passes**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS with exit code 0.

- [ ] **Step 5: Commit changes**

```bash
git add addons/opendou/editor/opendou_studio_main.gd addons/opendou/plugin.gd tests/test_studio_advanced_ui.gd
git commit -m "feat(studio): configure auto-maximized window and zero-waste root layout (Task 1)"
```

---

### Task 2: Draggable Floating Tool Windows (HDR Mixer, Game Syncs, Live Profiler, SoundBanks)

**Files:**
- Modify: `addons/opendou/editor/opendou_studio_main.gd`
- Modify: `addons/opendou/editor/opendou_mixer_drawer.gd`
- Test: `tests/test_studio_advanced_ui.gd`

**Interfaces:**
- Produces: `OpenDouStudioMain.open_hdr_mixer_modal()`, `OpenDouStudioMain.open_syncs_modal()`, `OpenDouStudioMain.open_profiler_modal()`, `OpenDouStudioMain.open_banks_modal()`.

- [ ] **Step 1: Write tests for floating tool windows**

```gdscript
# In tests/test_studio_advanced_ui.gd
studio.open_hdr_mixer_modal()
studio.open_syncs_modal()
studio.open_profiler_modal()
studio.open_banks_modal()
if studio.mixer_dialog == null or studio.syncs_dialog == null or studio.profiler_dialog == null:
    failures.append("Test: Floating tool windows must be initialized")
```

- [ ] **Step 2: Implement floating window instantiations in `opendou_studio_main.gd`**

```gdscript
var mixer_dialog: Window
var syncs_dialog: Window
var profiler_dialog: Window

func _create_modals() -> void:
    mixer_dialog = Window.new()
    mixer_dialog.title = "🎚️ OpenDou HDR Mixing Console & Ducking Matrix"
    mixer_dialog.size = Vector2i(780, 460)
    mixer_dialog.visible = false
    mixer_dialog.close_requested.connect(func(): mixer_dialog.visible = false)
    mixer_dialog.add_child(mixer_drawer)
    add_child(mixer_dialog)
    
    syncs_dialog = Window.new()
    syncs_dialog.title = "🎮 OpenDou Game Syncs Manager"
    syncs_dialog.size = Vector2i(460, 480)
    syncs_dialog.visible = false
    syncs_dialog.close_requested.connect(func(): syncs_dialog.visible = false)
    syncs_dialog.add_child(game_syncs_panel)
    add_child(syncs_dialog)
    
    profiler_dialog = Window.new()
    profiler_dialog.title = "📊 OpenDou Live Profiler & SoundBanks"
    profiler_dialog.size = Vector2i(840, 540)
    profiler_dialog.visible = false
    profiler_dialog.close_requested.connect(func(): profiler_dialog.visible = false)
    profiler_dialog.add_child(right_tabs)
    add_child(profiler_dialog)
```

- [ ] **Step 3: Run test runner to verify pass**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS with exit code 0.

- [ ] **Step 4: Commit changes**

```bash
git add addons/opendou/editor/opendou_studio_main.gd addons/opendou/editor/opendou_mixer_drawer.gd tests/test_studio_advanced_ui.gd
git commit -m "feat(studio): implement independent draggable floating tool windows (Task 2)"
```

---

### Task 3: Reactive Context-Aware Bottom Transport Bar

**Files:**
- Modify: `addons/opendou/editor/opendou_transport_bar.gd`
- Modify: `addons/opendou/editor/opendou_studio_main.gd`
- Test: `tests/test_studio_advanced_ui.gd`

**Interfaces:**
- Produces: `OpenDouTransportBar.set_workspace_context(mode: int)` where `0 = Graph`, `1 = Music`, `2 = Voice`.

- [ ] **Step 1: Write test for contextual transport bar adaptation**

```gdscript
# In tests/test_studio_advanced_ui.gd
studio.set_workspace_mode(OpenDouStudioMain.WorkspaceMode.MODE_GRAPH)
if studio.transport_bar.current_workspace_mode != 0:
    failures.append("Test: Transport bar must be in Graph mode")
studio.set_workspace_mode(OpenDouStudioMain.WorkspaceMode.MODE_MUSIC_DAW)
if studio.transport_bar.current_workspace_mode != 1:
    failures.append("Test: Transport bar must be in Music mode")
studio.set_workspace_mode(OpenDouStudioMain.WorkspaceMode.MODE_DIALOGUE_GRID)
if studio.transport_bar.current_workspace_mode != 2:
    failures.append("Test: Transport bar must be in Dialogue mode")
```

- [ ] **Step 2: Update `opendou_transport_bar.gd` and connect mode changes**

```gdscript
func set_workspace_context(mode: int) -> void:
    current_workspace_mode = mode
    clear_dynamic_controls()
    match mode:
        0: # Graph Workspace
            target_event_label.text = "Audition: [%s]" % str(current_event_name)
            set_audition_event(current_event_name)
        1: # Music DAW Workspace
            target_event_label.text = "Audition: [🎼 Dynamic_Combat_Suite]"
            _add_music_transport_controls()
        2: # Dialogue Grid Workspace
            target_event_label.text = "Audition: [🗣️ Dialogue_Voice_Bank]"
            _add_dialogue_transport_controls()
```

- [ ] **Step 3: Run test runner to verify pass**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS with exit code 0.

- [ ] **Step 4: Commit changes**

```bash
git add addons/opendou/editor/opendou_transport_bar.gd addons/opendou/editor/opendou_studio_main.gd tests/test_studio_advanced_ui.gd
git commit -m "feat(studio): implement reactive context-aware bottom transport bar (Task 3)"
```

---

### Task 4: Workspace Canvas Polish & Verification

**Files:**
- Modify: `addons/opendou/editor/opendou_music_timeline.gd`
- Modify: `addons/opendou/editor/opendou_dialogue_grid.gd`
- Modify: `tests/test_studio_advanced_ui.gd`

**Interfaces:**
- Produces: 280px track headers, triangular cue handles (▼), 6-column metadata dialogue grid.

- [ ] **Step 1: Write test verifying music timeline and dialogue grid expansions**

```gdscript
var timeline = OpenDouMusicTimelineClass.new()
if timeline.size_flags_vertical != Control.SIZE_EXPAND_FILL:
    failures.append("Test: Music timeline must have SIZE_EXPAND_FILL")
timeline.free()

var grid = OpenDouDialogueGridClass.new()
if grid.size_flags_vertical != Control.SIZE_EXPAND_FILL:
    failures.append("Test: Dialogue grid must have SIZE_EXPAND_FILL")
grid.free()
```

- [ ] **Step 2: Run test runner to verify test execution**

Run: `godot --headless -s tests/test_runner_cli.gd`
Expected: PASS with exit code 0.

- [ ] **Step 3: Commit changes**

```bash
git add addons/opendou/editor/opendou_music_timeline.gd addons/opendou/editor/opendou_dialogue_grid.gd tests/test_studio_advanced_ui.gd
git commit -m "feat(studio): polish workspace canvas sizing and cue handles (Task 4)"
```
