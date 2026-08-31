# Spec: AAA Spatial Acoustics Phase 3 — Tactical Canyon Showcase Demo

## 1. Overview
The **Tactical Canyon Showcase Demo** (`scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn`) is the definitive 3D interactive showcase for the OpenDou AAA Spatial Acoustics system. It unifies all Phase 1 and Phase 2 physical acoustics features into an explorable, high-fidelity tactical environment.

---

## 2. Core Showcase Features

### 2.1 Volumetric Continuous River Emitter (`OpenDouSplineEmitter3D`)
- **Location:** Canyon River Gorge (Sector 1).
- **Behavior:** Sound emitter projects procedural water flow audio along a 3D spline (`Curve3D`). The virtual audio origin moves continuously along the river curve to match the closest point to the listener, eliminating point-source panning artifacts for wide continuous natural sounds.

### 2.2 Material Mass-Law & Obstruction Testing Lab
- **Location:** Materials Laboratory (Sector 3).
- **Behavior:** 4 side-by-side acoustic walls (`Concrete`, `Metal`, `Wood`, `Foliage`) blocking synthetic test emitters. Demonstrates physical transmission loss ($\text{TL}_{\text{dB}}$) and material cutoff frequencies in real time.

### 2.3 Inter-Room Reverb Coupling & Portal Sound Spread
- **Location:** Concrete Bunker & Steel Air-lock (Sector 2).
- **Behavior:** Connects exterior canyon acoustics to interior reinforced bunker via `OpenDouPortal3D`. Opening and closing the air-lock door dynamically couples the RT60 reverberation tail and widens sound spread from $15^\circ$ to $180^\circ$ at the threshold.

### 2.4 High-Speed Doppler & 4-Tier Acoustic LOD Governor
- **Location:** Drone Patrol Range (Sector 4).
- **Behavior:** A high-speed drone ($25\text{ m/s}$) orbits across distance boundaries ($0-60\text{m}$), demonstrating smooth Doppler pitch shifts ($[0.5, 2.0]$) and transition through LOD 0 (full physics), LOD 1 (medium), LOD 2 (low), and LOD 3 (virtualized culling).

### 2.5 HDR Audio Dynamic Range & Loudness Window
- **Location:** Tactical Firing Range (Sector 5).
- **Behavior:** Triggering high-energy explosive detonations expands the HDR loudness window, naturalistically ducking low-level canyon wind and ambient wildlife audio until the exponential release recovers.

### 2.6 Full Declarative Node Integration & Visualizers
- Integrates `OpenDouRoom3D`, `OpenDouPortal3D`, `OpenDouSplineEmitter3D`, `OpenDouEventPlayer3D`, `OpenDouAcousticDebugger3D`, and `OpenDouAudibleMonitor`.

---

## 3. Architecture & File Layout
```text
opendou/
├── scenes/demos/08_tactical_canyon/
│   ├── demo_tactical_canyon.tscn    # Declarative 3D scene tree
│   └── demo_tactical_canyon.gd      # Scene logic controller
├── tests/
│   └── test_tactical_canyon_demo.gd # Verification test suite
└── docs/specs/spec_aaa_spatial_phase3_tactical_canyon_demo.md
```
