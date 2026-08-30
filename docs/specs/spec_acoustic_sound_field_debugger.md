# Technical Specification: 3D Volumetric Acoustic Sound Field Debugger

**Module:** `addons/opendou/nodes`, `addons/opendou/shaders`, `addons/opendou/runtime/spatial`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved / Ready for Implementation`

---

## 1. Objective & Vision

Provide developers and sound designers with an **in-game and in-editor real-time 3D acoustic sound field debugger** (`OpenDouAcousticDebugger3D`).

Instead of rigid bounding spheres that pass through solid walls, this system renders:
1. **Adaptive Geometry-Conforming Sound Field Mesh:** A dynamic 3D perimeter starburst/mesh projected from active 3D audio emitters (`unit_size` core to `max_distance`). Ray probes cast against the physics world compress the perimeter against solid walls (turning orange/red) and expand through open doors, airlocks, and portals (turning bright cyan/green).
2. **Volumetric Acoustic GDShader (`acoustic_sound_field.gdshader`):** Transparent Fresnel glow with pulsating acoustic wave ripples radiating outward and vertex-color-based occlusion blending.
3. **Emitter-to-Listener Direct Occlusion Rays:** Multi-ray debug lines between emitters and the player listener (Green = Clear Line of Sight, Yellow = Diffracted around portal, Red = Fully Occluded by obstacle).
4. **Interactive In-Game & Editor Toggle:** Hotkey `[ G ]` and HUD toggle button to inspect sound propagation dynamically in scenes like `demo_cyberpunk_infiltration.tscn`.

---

## 2. Architecture & Sound Field Mesh Generation

```text
                           WALL 🧱 (Ray hits at 3.0m)
                     ┌────────────────────────────────┐
                     │ 🔴 (Compressed boundary)       │
                     │       ▲                        │
                     │       │ ray                    │
                     │  ┌─────────┐                   │    OPEN AIRLOCK / PORTAL 🚪
                     │  │ 🔊 Core │ ─── ray (18m) ────┼───────────────────────────────▶ 🟢 (Expands to max_dist)
                     │  │(Unit 3m)│                   │
                     │  └─────────┘                   │
                     │       │ ray                    │
                     │       ▼                        │
                     │ 🔴 (Compressed boundary)       │
                     └────────────────────────────────┘
```

### 2.1. Starburst Ray Probe Algorithm
For each active `AudioStreamPlayer3D` or `OpenDouEventPlayer3D`:
1. Emit $N$ ray probes (default $N = 24$ or $32$) uniformly distributed around the azimuth $[0, 2\pi]$ at the emitter height (with optional vertical fan $\pm 30^\circ$).
2. Ray length target: $R_{target} = \max(\text{unit\_size} + 1.0, \text{max\_distance})$.
3. Physics Raycast:
   $$R_i = \begin{cases}
     \|\text{hit\_pos} - \text{emitter\_pos}\| & \text{if ray hits static/CSG collider} \\
     R_{target} & \text{if unobstructed}
   \end{cases}$$
4. Construct triangle fan mesh:
   * Center vertex $V_0 = \text{emitter\_pos}$ with color Gold/Cyan.
   * Outer perimeter vertices $V_i = \text{emitter\_pos} + \text{dir}_i \cdot R_i$.
   * Vertex color $C_i$:
     * If $R_i < R_{target} \cdot 0.95$: Occluded vertex (Orange/Red $C_i = \text{Color}(1.0, 0.35, 0.1, 0.45)$).
     * If $R_i \ge R_{target} \cdot 0.95$: Clear path / portal leak (Bright Cyan $C_i = \text{Color}(0.1, 0.9, 1.0, 0.6)$).
5. Generate inner core circle at radius $r = \text{unit\_size}$ representing the zero-attenuation zone ($0\text{dB}$).

---

## 3. Volumetric Acoustic Shader (`acoustic_sound_field.gdshader`)

```glsl
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 base_color : source_color = vec4(0.1, 0.8, 1.0, 0.4);
uniform vec4 occluded_color : source_color = vec4(1.0, 0.3, 0.1, 0.4);
uniform float wave_speed = 3.0;
uniform float wave_frequency = 4.0;
uniform float pulse_intensity = 0.5;

void fragment() {
    float dist = length(UV - vec2(0.5));
    float wave = sin((dist * wave_frequency - TIME * wave_speed) * 6.28318) * 0.5 + 0.5;
    vec4 final_col = mix(COLOR, base_color, 0.3);
    ALBEDO = final_col.rgb * (1.0 + wave * pulse_intensity);
    ALPHA = final_col.a * (0.6 + 0.4 * wave);
}
```

---

## 4. Emitter-to-Listener Multi-Ray Occlusion Visualizer

Between each active emitter and the listener position (e.g. `Player` camera / AudioListener3D):
* Cast 3 parallel rays: Center, Left ($+0.4\text{m}$ offset), Right ($-0.4\text{m}$ offset).
* Color code:
  * **3 Rays Clear:** Green Line (`Color(0.2, 1.0, 0.3, 0.8)`).
  * **1-2 Rays Hit:** Yellow/Orange Line (`Color(1.0, 0.8, 0.1, 0.8)`) — Partial Diffraction.
  * **3 Rays Blocked:** Red Line (`Color(1.0, 0.15, 0.15, 0.7)`) — Full Wall Occlusion.

---

## 5. Declarative Node API: `OpenDouAcousticDebugger3D`

* **File:** `addons/opendou/nodes/opendou_acoustic_debugger_3d.gd`
* **Base Class:** `Node3D`
* **Exported Properties:**
  * `@export var enabled: bool = true`
  * `@export var probe_ray_count: int = 24`
  * `@export var show_unit_size_core: bool = true`
  * `@export var show_occlusion_rays: bool = true`
  * `@export var show_portal_diffraction: bool = true`
  * `@export_flags_3d_physics var collision_mask: int = 1`
  * `@export var max_display_emitters: int = 16`
* **Public Methods:**
  * `func toggle_debug() -> bool`
  * `func update_sound_fields() -> void`
  * `func get_emitter_probe_distances(emitter: Node3D) -> PackedFloat32Array`

---

## 6. Verification & Test Plan

* **Unit Tests (`tests/test_acoustic_debugger.gd`):**
  * Test 1: Node instantiation, properties, and default values.
  * Test 2: Starburst ray probe calculation with unobstructed target distances.
  * Test 3: Wall collision ray probe clamping and occluded vertex color assignment.
  * Test 4: Emitter-to-listener multi-ray line classification (Green, Yellow, Red).
  * Test 5: Dynamic toggle `toggle_debug()` and visibility state.
  * Test 6: Custom type registration in `addons/opendou/plugin.gd`.
* **Cyberpunk Demo Integration:**
  * Verification in `demo_cyberpunk_infiltration.tscn` with `BtnToggleAcoustics` in `TacticalHUD` and `G` hotkey.
* **Regression Testing:**
  * `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (100% pass, 0 failures, exit code 0).
