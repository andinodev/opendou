# Technical Specification: Dynamic Micro-Acoustics (Obstacle Raycasting & LPF Slew-Rate Smoothing) (OpenDou Core)

**Module:** `addons/opendou/runtime/spatial/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/011.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/011.md)

---

## 1. Objective & Scope

While **Macro-Acoustics (Rooms & Portals)** models indoor architectural propagation, **Micro-Acoustics** models line-of-sight occlusion caused by dynamic physical objects (vehicles, crates, moving walls, pillars).

This specification implements:
1. **Batched Physics Raycast Queries:** Centralized batch execution across physics space states to minimize CPU overhead.
2. **Multi-Point Partial Occlusion:** Multi-ray distribution (Center, Left, Right) to model smooth grazing angle attenuation.
3. **Temporal Slew-Rate Smoothing (Anti-Fluttering):** Exponential low-pass filter transition preventing acoustic pops when emitters pass behind narrow geometry.

---

## 2. Dynamic Occlusion Calculation

### 2.1. Multi-Ray Partial Occlusion Factor ($\Omega \in [0.0, 1.0]$)
$$\Omega = \frac{\sum_{i=1}^{N} \text{hit}_i}{N}$$

* **Target LPF:** $\text{TargetLPF} = \text{lerp}(20000.0\text{ Hz}, 1500.0\text{ Hz}, \Omega)$
* **Target Volume Attenuation:** $\text{TargetAtten}_{\text{dB}} = \Omega \times (-6.0\text{ dB})$

### 2.2. Slew-Rate Smoothing Equation
$$\text{CurrentLPF}_{t} = \text{CurrentLPF}_{t-1} + (\text{TargetLPF} - \text{CurrentLPF}_{t-1}) \times \text{clamp}(\kappa \cdot \Delta t, 0.0, 1.0)$$
where $\kappa = 8.0\text{ s}^{-1}$ (smoothing speed).

---

## 3. Acceptance Criteria (DoD)

1. Unobstructed line-of-sight maintains 20,000 Hz cutoff and 0 dB attenuation.
2. Fully occluded obstacles reduce target LPF to 1,500 Hz and apply -6 dB attenuation.
3. Temporal smoothing ensures continuous transition without discrete frequency jumps.
4. 100% automated test coverage in `tests/test_micro_acoustics.gd`.
