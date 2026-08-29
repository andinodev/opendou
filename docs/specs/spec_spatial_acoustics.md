# Technical Specification: Macro-Spatial Acoustics (Rooms & Portals and Acoustic Pathfinding) (OpenDou Core)

**Module:** `addons/opendou/runtime/spatial/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/010.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/010.md)

---

## 1. Objective & Scope

Realistic 3D acoustic simulation requires sound waves to respect building geometry and physical enclosures rather than traveling straight through concrete walls.

The **Macro-Spatial Acoustics (Rooms & Portals)** system transforms 3D levels into an **Acoustic Propagation Graph**:
1. **AudioRoom:** Represents an acoustic enclosure with unique reverberation and damping properties.
2. **AudioPortal:** Represents an aperture (doorway, window) connecting two rooms with dynamic aperture openness (`open_factor` $0.0 \to 1.0$) controlling Low-Pass Filtering (LPF).
3. **Acoustic Pathfinding:** Computes diffraction paths, virtual distance, and apparent origin of arrival through the nearest portal.

---

## 2. Acoustic Diffraction & Propagation Model

```mermaid
graph LR
    subgraph Room A (Emitter)
        E[Sound Emitter]
    end
    
    P1[Portal 1: Open Factor 1.0]
    
    subgraph Room B (Corridor)
        C[Corridor Node]
    end
    
    P2[Portal 2: Open Factor 0.5]
    
    subgraph Room C (Listener)
        L[Listener / Player]
    end
    
    E --> P1 --> C --> P2 --> L
```

### 2.1. Acoustic Path Outputs (`AcousticPath`)
1. **Virtual Distance:** $\text{dist}(E, P_1) + \sum \text{dist}(P_i, P_{i+1}) + \text{dist}(P_n, L)$
2. **Apparent Sound Origin:** Position of portal $P_n$ (diffraction point entering listener room).
3. **Diffraction LPF Cutoff:** $\min_{i} \left(\text{lerp}(200.0\text{ Hz}, 20000.0\text{ Hz}, \text{open\_factor}_i)\right)$

---

## 3. Acceptance Criteria (DoD)

1. Direct line of sight within the same room preserves exact Euclidean distance and full 20 kHz bandwidth.
2. Inter-room paths correctly calculate total zig-zag distance and assign apparent origin to the exit portal.
3. Closed or partially closed portals progressively attenuate high frequencies ($200\text{ Hz} \le f \le 20000\text{ Hz}$).
4. 100% automated test coverage in `tests/test_spatial_acoustics.gd`.
