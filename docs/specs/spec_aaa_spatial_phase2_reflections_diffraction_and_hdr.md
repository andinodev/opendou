# Specification: AAA Spatial Acoustics Phase 2 — Early Reflections, Edge Diffraction, Room Coupling, Acoustic LOD & HDR Audio

**Status:** DRAFT  
**Author:** Antigravity / OpenDou Core Team  
**Date:** 2026-08-30  
**Phase:** 2 of 3 (TASK-052)  
**Related Idea:** `docs/ideas/021-aaa-spatial-acoustics-and-immersion.md`  
**Previous Phase:** `docs/specs/spec_aaa_spatial_phase1_propagation_and_splines.md`

---

## 1. Executive Summary

Phase 2 builds upon the physical foundation established in Phase 1 (Material Mass-Law, Air Damping, Doppler, and Spline Emitters) to introduce **high-order spatial acoustic realism and scalable performance**:
1. **6x Image-Source Early Reflections Raytracer:** Generates physical slapback, flutter echoes, and comb filtering based on real room boundary materials and geometry.
2. **Huygens-Fresnel Edge Diffraction:** Smoothly bends sound around geometric obstacle corners without abrupt volume dropoffs.
3. **Acoustic Room Coupling:** Chains room reverberations across connecting portal apertures.
4. **4-Tier Acoustic Level of Detail (LOD 0-3):** Throttles raycasting and physics overhead according to listener distance.
5. **HDR Audio Loudness Window:** Dynamic range compression and transient ducking modeled after Frostbite/Wwise HDR audio architectures.

---

## 2. Mathematical & Acoustic Formulations

### 2.1 6x Image-Source Early Reflections Raytracer (`AcousticReflectorEngine`)
For an emitter $E$ and listener $L$ in a 3D environment:
1. Cast 6 orthogonal rays ($\pm X, \pm Y, \pm Z$) from $E$ with length $r_{\text{max}} = 30.0\text{ m}$.
2. For each surface hit $S_i$ with normal $\vec{n}_i$:
   - Virtual image source position: $E'_i = E + 2 (\vec{n}_i \cdot (S_i - E)) \vec{n}_i$.
   - Total reflection path distance: $d_i = \|S_i - E\| + \|L - S_i\|$.
   - Arrival delay time: $t_i = \frac{d_i}{c}$ (where $c = 343.0\text{ m/s}$).
   - Material absorption $\alpha_i$ and cutoff $f_{\text{res}, i}$ queried from `AcousticMaterialRegistry`.
   - Reflection Gain:
     $$g_i = \text{clampf}\left(\frac{1.0 - \alpha_i}{\sqrt{1.0 + \frac{d_i}{5.0}}}, 0.0, 1.0\right)$$
   - Reflection Cutoff LPF: $f_{\text{lpf}, i} = \text{lerpf}(20000.0, f_{\text{res}, i}, \text{clampf}(d_i / 20.0, 0.0, 1.0))$.

### 2.2 Huygens-Fresnel Edge Diffraction
When direct line-of-sight between $E$ and $L$ is obstructed by a finite edge (e.g. column, wall corner):
1. Locate nearest edge vertex $V_{\text{edge}}$ between $E$ and $L$.
2. Compute diffraction shadow angle:
   $$\theta = \arccos\left(\frac{(V_{\text{edge}} - E) \cdot (L - V_{\text{edge}})}{\|V_{\text{edge}} - E\| \|L - V_{\text{edge}}\|}\right)$$
3. Apparent virtual direction bends towards $V_{\text{edge}}$.
4. Diffraction transmission filter:
   $$f_{\text{diffract}}(\theta) = \text{clampf}\left(20000.0 \cdot \cos^2\left(\frac{\theta}{2}\right), 400.0, 20000.0\right)$$
   $$\text{Gain}_{\text{diffract}}(\theta) = \text{clampf}\left(\cos\left(\frac{\theta}{2}\right), 0.1, 1.0\right)$$

### 2.3 Inter-Room Coupling
When sound occurs in Room $A$ connected to Room $B$ via Portal $P$:
1. Reverberation energy of Room $A$ excites Room $B$'s tail scaled by portal aperture area $A_p$:
   $$E_{\text{coupled}} = E_{\text{room } A} \cdot \left(\frac{A_p}{S_{\text{total } A}}\right) \cdot \text{OpenRatio}_P$$
2. Apparent sound spread expands from point source ($15^\circ$) when far to full immersive wrap ($180^\circ \to 360^\circ$) as listener enters the portal threshold.

### 2.4 4-Tier Acoustic Level of Detail (LOD 0-3)
| LOD | Distance Range | Physics & Raytracing Operations |
|---|---|---|
| **LOD 0** | $0\text{ m} \le d \le 10\text{ m}$ | Full 6x Early Reflections, Edge Diffraction, Dual-Ray Mass-Law, Doppler. |
| **LOD 1** | $10\text{ m} < d \le 25\text{ m}$ | Single-Ray Occlusion, Simplified Diffraction, Air Damping. |
| **LOD 2** | $25\text{ m} < d \le 50\text{ m}$ | Standard 3D Panning + Distance Attenuation Curve (0 raycasts). |
| **LOD 3** | $d > 50\text{ m}$ | Virtualized Voice Culling (0 CPU physics cost). |

### 2.5 HDR Audio Loudness Window (`HDRAudioManager`)
1. **Loudness Metric:** Track real-time audio power in dB FS ($P_{\text{dB}}$).
2. **Dynamic Window:** Window range $W = 40.0\text{ dB}$, top threshold $T_{\text{top}}$.
3. **Transient Compression:** If an event exceeds $T_{\text{top}}$ (e.g. explosion at $0\text{ dB FS}$ with $T_{\text{top}} = -6\text{ dB FS}$):
   - Dynamic floor shifts up: $T_{\text{floor}} = T_{\text{top}} - W$.
   - Quiet ambient sounds falling below $T_{\text{floor}}$ are ducked exponentially with release time $\tau_{\text{rel}} = 0.35\text{ s}$.

---

## 3. Architecture & Class Design

```text
addons/opendou/runtime/spatial/
├── acoustic_material_registry.gd       # (Phase 1) Physical Material Matrix & Mass Law
├── spatial_acoustics_manager.gd        # (Phase 1 & 2) Coordinator, Propagation & Path Evaluation
├── acoustic_reflector_engine.gd        # (Phase 2 [NEW]) 6x Image-Source Raytracer & Delays
├── edge_diffraction_engine.gd          # (Phase 2 [NEW]) Huygens-Fresnel Edge Diffraction
├── room_coupling_engine.gd             # (Phase 2 [NEW]) Inter-Room Reverb Excitation & Spread
├── acoustic_lod_controller.gd          # (Phase 2 [NEW]) 4-Tier LOD & Scalability Governor
└── hdr_audio_manager.gd                # (Phase 2 [NEW]) HDR Loudness Window & Transient Ducking
```

---

## 4. Verification Plan

1. **Unit & Integration Suite (`tests/test_spatial_acoustics_phase2.gd`):**
   - 6x raytracer reflections delay, material absorption, and gain calculation tests.
   - Edge diffraction angle computation and frequency cutoff attenuation curve tests.
   - Inter-room coupling energy transfer and portal spread expansion tests.
   - LOD 0-3 transition distances and voice culling validation.
   - HDR Audio loudness window tracking, dynamic ducking, and release curve timing.
2. **Direct CLI Runner Execution:**
   - Execute `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd` ensuring 100% tests pass (0 failures, 0 compilation errors).
