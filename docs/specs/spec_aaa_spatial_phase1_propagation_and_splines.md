# Technical Specification: AAA Spatial Acoustics Phase 1 — Physical Propagation, Mass-Law Occlusion & Spline Emitters

**Module:** `addons/opendou/runtime/spatial`, `addons/opendou/nodes`, `addons/opendou/icons`  
**Author:** `OpenDou Audio Architecture Team`  
**Date:** `2026-08-30`  
**Status:** `Approved / Ready for Implementation Plan`

---

## 1. Objective & Architectural Scope

Implement **Phase 1 of OpenDou's AAA Spatial Audio Engine**:
1. **Acoustic Material Transmission & Mass Law:** Hybrid registry (`AcousticMaterialRegistry`) defining physical material properties (density, resonance LPF, absorption), thickness raycasting ($\Delta x$) with static acoustic collision filtering, and dual-penetration mass-law attenuation.
2. **Rigorous Obstruction vs. Occlusion Splitting:**
   * **Obstruction:** Same-room partial block $\to$ LPF filter on direct path only; room early reflections & reverb decay remain 100% unaffected.
   * **Occlusion:** Inter-room / solid barrier seal $\to$ Mass-law attenuation on direct path AND severe damping on late reverberation.
3. **Atmospheric Air Absorption & Smoothed Doppler Shift:** Frequency cutoff roll-off over distance and smoothed velocity Doppler frequency modulation.
4. **Volumetric Spline Emitter 3D (`OpenDouSplineEmitter3D`):** Declarative 3D continuous line/spline audio emitter for rivers, power lines, and wide barriers with AABB distance culling, `Curve3D.get_closest_point()` tracking, dynamic sound spread curve ($0^\circ \to 180^\circ \to 360^\circ$), and integrated air absorption.

---

## 2. Mathematical Formulations

### 2.1. Acoustic Mass Law & Structural Resonance LPF
For a sound wave of frequency $f$ penetrating a physical barrier of thickness $\Delta x$ meters and material density $\rho\text{ kg/m}^3$:
$$\text{Transmission Loss (TL)}_{\text{dB}} = \text{clamp}\left(20 \log_{10}(f \cdot \rho \cdot \Delta x) - 45.0, \; 0.0, \; 36.0\right)$$

$$\text{Effective Cutoff LPF} = \text{lerp}(20000.0, \; \text{Material.lpf\_resonance}, \; \text{clamp}(\Delta x / 0.5, \; 0.0, \; 1.0))$$

#### Standard Material Physical Matrix:
| Material | Density ($\text{kg/m}^3$) | Resonance LPF (Hz) | Absorption ($\alpha$) | Physical Acoustic Behavior |
| :--- | :---: | :---: | :---: | :--- |
| **Concrete / Stone** | $2400$ | $350$ | $0.05$ | Extreme occlusion; only deep sub-bass penetrates. |
| **Metal** | $7800$ | $1200$ | $0.02$ | High structural resonance; conducts low-mids. |
| **Glass** | $2500$ | $800$ | $0.03$ | Sharp frequency cut; retains bass, leaks highs. |
| **Wood** | $700$ | $2000$ | $0.15$ | High porosity; warm, balanced attenuation. |
| **Foliage** | $150$ | $4500$ | $0.85$ | Soft scattering; muffles transients without full seal. |
| **Water** | $1000$ | $600$ | $0.01$ | High fluid transmission, damped highs. |
| **Asphalt** | $2100$ | $400$ | $0.08$ | Dense ground absorption. |

### 2.2. Atmospheric Air Absorption (Distance High-Frequency Damping)
$$\text{Air Damping Cutoff}(d) = \text{clamp}\left(20000.0 \cdot e^{-0.015 \cdot d}, \; 800.0, \; 20000.0\right)$$

### 2.3. Stabilized Doppler Frequency Shift
With exponential smoothing factor $\alpha_{\text{smooth}} = 0.15$:
$$\vec{v}_{\text{rel}} = \text{lerp}(\vec{v}_{\text{rel}}, \; \vec{v}_{\text{emitter}} - \vec{v}_{\text{listener}}, \; \alpha_{\text{smooth}})$$
$$f' = f \cdot \text{clamp}\left(\frac{c + \vec{v}_{\text{listener}} \cdot \hat{u}}{c + \vec{v}_{\text{emitter}} \cdot \hat{u}}, \; 0.5, \; 2.0\right) \quad (\text{where } c = 343\text{ m/s})$$

### 2.4. Spline Closest-Point & Angular Spread
$$P_{\text{closest}} = \text{Curve3D.get_closest_point}(\vec{P}_{\text{listener}})$$
$$\text{Spread Degrees} = \text{SoundSpreadCurve.sample\_baked}(\text{clamp}(1.0 - \frac{\|\vec{P}_{\text{listener}} - P_{\text{closest}}\|}{\text{max\_distance}}, \; 0.0, \; 1.0)) \cdot 180.0^\circ$$

---

## 3. Data Structures & Component Interfaces

### 3.1. `AcousticMaterialRegistry` (`acoustic_material_registry.gd`)
* **Singleton API:**
  * `func get_material(mat_name: StringName) -> Dictionary`
  * `func calculate_transmission_loss(mat_name: StringName, thickness_meters: float, center_freq: float = 1000.0) -> Dictionary`
    * Returns `{"attenuation_db": float, "cutoff_lpf": float}`.
  * `func register_custom_material(mat_name: StringName, density: float, resonance_lpf: float, absorption: float) -> void`
  * `func load_from_json(path: String = "res://opendou_acoustic_materials.json") -> void`

### 3.2. `OcclusionManager` & `SpatialAcousticsManager` Enhancements
* **Dual-Ray Thickness Raycast:**
  * Dispatches forward ray from emitter to listener, and reverse ray from listener to emitter on `acoustic_collision_mask` (default layer 1).
  * Computes $\Delta x = \|\text{hit}_{\text{forward}} - \text{hit}_{\text{reverse}}\|$.
  * Caches $\Delta x$ per collider RID with linear smoothing to avoid frame-to-frame spikes.
* **Separation of Obstrucción vs. Oclusión:**
  * `evaluate_acoustic_path(emitter: Node3D, listener: Node3D)` returns:
    * `obstruction_factor`: Applied exclusively to the emitter's direct sound audio filter.
    * `occlusion_factor`: Applied to both the direct sound and the room reverberation send level.

### 3.3. `OpenDouSplineEmitter3D` (`opendou_spline_emitter_3d.gd`)
* **Inherits:** `AudioStreamPlayer3D`
* **Exported Properties:**
  * `@export var curve: Curve3D`
  * `@export var sound_spread_curve: Curve`
  * `@export var enable_air_absorption: bool = true`
  * `@export var enable_doppler: bool = true`
  * `@export_flags_3d_physics var acoustic_collision_mask: int = 1`
* **Internal Behavior:**
  * In `_physics_process(delta)`:
    1. AABB / Distance-squared check: if distance to listener $> \text{max\_distance} + 10.0\text{m}$, skips spline point calculations.
    2. Calls `curve.get_closest_point(listener_pos)` to update virtual emitter transform smoothly.
    3. Samples `sound_spread_curve` to adjust audio spread angle.
    4. Evaluates air absorption and Doppler pitch modulation.

---

## 4. Verification & Testing Plan

* **Unit Tests (`tests/test_spatial_acoustics_phase1.gd`):**
  * **Test 1:** Canonical material properties in `AcousticMaterialRegistry` (Concrete, Metal, Glass, Wood, Foliage).
  * **Test 2:** Mass-law transmission loss calculation across variable wall thicknesses ($0.1\text{m}, 0.5\text{m}, 2.0\text{m}$).
  * **Test 3:** Obstruction vs. Occlusion evaluation (direct path filtering vs. reverb send damping).
  * **Test 4:** Air absorption exponential decay over distance ($5\text{m}, 20\text{m}, 80\text{m}$).
  * **Test 5:** Smoothed Doppler pitch calculation with speed clamping ($0.5\times$ to $2.0\times$).
  * **Test 6:** `OpenDouSplineEmitter3D` closest-point tracking along a 3-point `Curve3D`.
  * **Test 7:** Spread angle curve sampling and AABB distance culling.
  * **Test 8:** Custom type registration in `plugin.gd` and SVG icon loading.
* **Automated Test Runner:**
  * Run `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` (100% pass rate, exit code 0).
