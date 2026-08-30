## 1. Objective & Vision

Provide developers and sound designers with an **in-game and in-editor real-time 3D Volumetric Acoustic Iso-Bubble Debugger** (`OpenDouAcousticDebugger3D`).

Key Improvements:
1. **Editor Stealth & Cleanliness:** Off by default in editor (`show_in_editor = false`). Only renders for **explicitly selected audio emitters** in the Godot Editor or targeted nodes.
2. **True 3D Deformable Geodesic Iso-Bubble:** Replaces flat 2D discs with an organic **3D Geodesic Sphere Mesh (IcoSphere / Fibonacci Sphere sampling)** with 3D multi-axis ray probes that flatten against floors/ceilings and compress against walls in Orange/Red while stretching through open doorways/portals in Cyan.
3. **Volumetric Holographic Fresnel Bubble Shader (`acoustic_sound_field.gdshader`):** Transparent Fresnel rim glow + animated 3D acoustic wave ripples and grid lines.
4. **Multi-Selection & Focused Targeting:** Renders only the active/selected emitter(s) (`display_mode = Only_Selected`) to eliminate visual clutter.

---

## 2. 3D Geodesic Iso-Bubble Architecture

```text
               ┌───────────────────────┐  TECHO 🧱 (Rayo superior choca a 4m)
               │     🔴 (Se aplana)    │
               │         ▲             │
               │       ╱ │ ╲           │
      PARED 🧱 │ 🔴 ─── 🔊 Core ─── 🟢 ┼──────────▶ PASILLO / PUERTA ABIERTA 🚪
   (Se aplana) │       ╲ │ ╱           │            (Se estira como gota 3D)
               │         ▼             │
               │     🔴 (Se aplana)    │
               └───────────────────────┘  SUELO 🧱 (Se apoya en el piso)
```

### 2.1. Geodesic 3D Ray Sampling Algorithm
For each selected / targeted 3D audio emitter:
1. Generate $N$ spherical unit vectors ($\vec{u}_i$) using **Fibonacci Sphere / Geodesic Distribution** or $(\theta, \phi)$ rings ($N = 42$ to $64$ vertices with regular triangular indexing).
2. Cast 3D physics ray from `emitter_pos` along $\vec{u}_i$ up to `max_distance`:
   $$R_i = \begin{cases}
     \|\text{hit\_pos} - \text{emitter\_pos}\| & \text{if ray hits geometry} \\
     \text{max\_distance} & \text{if unobstructed}
   \end{cases}$$
3. Position vertex $V_i = \text{emitter\_pos} + \vec{u}_i \cdot R_i$.
4. Assign vertex color $C_i$:
   * If occluded ($R_i < \text{max\_distance} \cdot 0.95$): Orange/Red $C_i = \text{Color}(1.0, 0.3, 0.1, 0.5)$.
   * If unobstructed / open portal ($R_i \ge \text{max\_distance} \cdot 0.95$): Bright Cyan $C_i = \text{Color}(0.1, 0.85, 1.0, 0.6)$.
5. Build 3D indexed triangle mesh (`ImmediateMesh`) with normal calculations for smooth Fresnel shading.
6. Render inner 3D `unit_size` sphere core (Gold).

---

## 3. Volumetric Holographic Fresnel Bubble Shader (`acoustic_sound_field.gdshader`)

```glsl
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 base_color : source_color = vec4(0.1, 0.85, 1.0, 0.45);
uniform vec4 occluded_color : source_color = vec4(1.0, 0.35, 0.1, 0.45);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
uniform float wave_speed : hint_range(0.1, 10.0) = 2.5;
uniform float wave_frequency : hint_range(0.5, 20.0) = 3.0;

void fragment() {
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    float wave = sin((length(VERTEX) * wave_frequency - TIME * wave_speed) * 6.28318) * 0.5 + 0.5;
    vec4 final_col = mix(COLOR, base_color, 0.2);
    ALBEDO = final_col.rgb * (1.0 + wave * 0.4);
    ALPHA = clamp(final_col.a * (0.3 + 0.7 * fresnel + 0.3 * wave), 0.0, 1.0);
}
```

---

## 4. Selection & Display Modes

* **`display_mode` Enum:**
  * `Only_Selected` (Default): In Editor, renders only when one or more audio emitter nodes are selected in the Scene Tree. In Game, targets selected or focused emitters.
  * `Active_Audible_Only`: Renders currently playing emitters within hearing range.
  * `All_Emitters`: Global diagnostic mode.
* **`show_in_editor` (bool, default `false`):** Master switch for editor viewport rendering.

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
