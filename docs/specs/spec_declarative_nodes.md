# Technical Specification: Declarative Custom Audio Nodes

**Module:** `addons/opendou/nodes`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved`

---

## 1. Objective & Requirements

Provide a complete suite of declarative, plug-and-play Godot custom nodes inheriting from standard Godot classes (`AudioStreamPlayer3D`, `AudioStreamPlayer2D`, `AudioStreamPlayer`, `Area3D`, `Node3D`, `Node`) that allow game developers and sound designers to drag and drop OpenDou audio entities into their scene hierarchies, configuring events, RTPCs, surface switches, Sabine room acoustics, portal diffraction, sidechain ducking, voice pooling, and multi-stem music directly through the Godot Inspector without requiring manual scripting.

### Functional Requirements
* **FR-1 (`OpenDouEventPlayer3D`):** Extends `AudioStreamPlayer3D`. Exposes Inspector `@export` groups for OpenDou Event linking, Game Syncs (RTPCs, Switches, States), 3D Spatial Acoustics & HRTF (Woodworth binaural, raycast occlusion with collision mask), Voice Pool prioritization & virtualization, and sidechain ducking bus categories.
* **FR-2 (`OpenDouEventPlayer2D`):** Extends `AudioStreamPlayer2D`. Exposes equivalent 2D parameters for 2D platformers and top-down games.
* **FR-3 (`OpenDouEventPlayer`):** Extends `AudioStreamPlayer`. Non-spatial player for UI sound effects, global voice-over dialogues, and non-diegetic audio.
* **FR-4 (`OpenDouRoom3D`):** Extends `Area3D`. Detects child `CollisionShape3D` to calculate volume ($V$) and surface area ($S$), computes Sabine reverberation decay ($RT_{60}$) based on acoustic material presets (Concrete, Wood, Glass, Curtains, Custom), and auto-registers in `SpatialAcousticsManager`. Supports trigger snapshots on player enter/exit.
* **FR-5 (`OpenDouPortal3D`):** Extends `Node3D`. Links two `OpenDouRoom3D` instances with an interactive `open_factor` (0.0 to 1.0) modulating acoustic diffraction and low-pass filtering.
* **FR-6 (`OpenDouReflector3D`):** Extends `Node3D`. Registers early specular reflection planes in `SpatialAcousticsManager`.
* **FR-7 (`OpenDouMusicPlayer`):** Extends `Node`. Automatically loads multi-stem suites (e.g. `Exploration_Ambient_Theme.tres`, `Dynamic_Combat_Suite.tres`) from `opendou_music_suites.json`, spawns synchronized stem players, and exposes `combat_intensity` and stinger triggers.
* **FR-8 (Editor Plugin Registration):** All 7 nodes must be registered in `addons/opendou/plugin.gd` via `add_custom_type` with dedicated SVG icons and appear in the Godot "Create New Node" dialog.

### Non-Functional Requirements
* **NFR-1 (Static Typing & Zero Overhead):** All node classes must use strict static GDScript typing and maintain sub-millisecond execution times.
* **NFR-2 (Backward Compatibility):** Inheriting directly from Godot audio stream players preserves all native properties (`volume_db`, `pitch_scale`, `bus`, `autoplay`, `playing`) while enriching them with OpenDou features.
* **NFR-3 (Automated Headless Testing):** All nodes must instantiate, serialize, and execute cleanly in `test_runner_cli.gd` with 100% test pass.

---

## 2. API Design & Class Signatures

### Node Manifest
1. `addons/opendou/nodes/opendou_event_player_3d.gd` (`OpenDouEventPlayer3D` extends `AudioStreamPlayer3D`)
2. `addons/opendou/nodes/opendou_event_player_2d.gd` (`OpenDouEventPlayer2D` extends `AudioStreamPlayer2D`)
3. `addons/opendou/nodes/opendou_event_player.gd` (`OpenDouEventPlayer` extends `AudioStreamPlayer`)
4. `addons/opendou/nodes/opendou_room_3d.gd` (`OpenDouRoom3D` extends `Area3D`)
5. `addons/opendou/nodes/opendou_portal_3d.gd` (`OpenDouPortal3D` extends `Node3D`)
6. `addons/opendou/nodes/opendou_reflector_3d.gd` (`OpenDouReflector3D` extends `Node3D`)
7. `addons/opendou/nodes/opendou_music_player.gd` (`OpenDouMusicPlayer` extends `Node`)

### Public Methods on `OpenDouEventPlayer3D` / `2D` / Global:
```gdscript
func play_event(name: StringName = &"") -> void
func set_rtpc(param_name: StringName, value: float) -> void
func set_switch(group: StringName, switch_value: StringName) -> void
func set_state(group: StringName, state_value: StringName) -> void
```

---

## 3. Test & Verification Plan

* [ ] Unit test for instantiation and Inspector properties of `OpenDouEventPlayer3D`, `2D`, and Global (`test_declarative_nodes.gd`).
* [ ] Unit test for `OpenDouRoom3D` Sabine volume calculation and automatic registration in `SpatialAcousticsManager`.
* [ ] Unit test for `OpenDouPortal3D` diffraction cutoff calculation and room linkage.
* [ ] Unit test for `OpenDouMusicPlayer` suite loading, stem creation, and intensity crossfading.
* [ ] Full test suite execution (`godot --headless -s tests/test_runner_cli.gd`) passing 100%.
