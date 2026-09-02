# OpenDou

**OpenDou** is a 100% open-source, high-performance **Audio Engine & Middleware** designed natively for modern versions of **Godot Engine (4.7+ / 4.x)**.

It provides an open, royalty-free alternative to proprietary audio solutions such as **Wwise** and **FMOD Studio**, bridging the gap between game audio design and low-level engine audio architecture.

---

## 🚀 Key Pillars

> **Estado de implementacion.** OpenDou es hoy **100% GDScript**: no hay ni una
> linea de C++ ni de Rust en el repositorio. La capa GDExtension descrita en
> `docs/architecture/gdextension_api.md` esta **planificada**, no implementada.
> El motor orquesta reproductores nativos de Godot, que es quien hace la mezcla
> en C++ y quien aporta la atenuacion 3D, el paneo y el filtro por voz.

1. **Decoupled Event & Action Dispatcher:**
   * Trigger complex sound behaviors via events (`OpenDou.post_event("Play_Footstep", self)`) without coupling sounds to scene nodes.
   * Full **Game Syncs** support: Continuous/Discrete **RTPCs**, Entity **Switches**, Global **States**, and Musical **Triggers**.
2. **Virtual Voice System & Dynamic Voice Stealing:**
   * Zero-cost playback tracking for inaudible/distant sound sources without burning CPU or DSP cycles.
   * Deterministic voice-stealing algorithms based on dynamic priority (`Base Priority - (Distance * Factor)`).
3. **SoundBank Pipeline & Zero-Latency Prefetching:**
   * Binary `.bank` packaging with metadata tables and high-efficiency audio compression.
   * Monolithic `.bank` packaging with a contiguous RAM prefetch block, preloaded on demand as playable `AudioStreamWAV` resources (one file, deterministic packaging, per-stream lazy load).
4. **Spatial Audio, Rooms & Portals:**
   * Acoustic propagation modeling through rooms, portals, and geometric obstruction/occlusion.
   * Raycast-assisted environmental filtering leveraging Godot's `PhysicsServer3D`.
5. **Live Update TCP Server & Profiling Backend:**
   * Real-time bidirectional parameter, bus, and curve tuning while the game runs.
   * Live telemetry capturing physical/virtual voice counts, DSP load, and memory usage.

---

## 📁 Project Structure

```text
opendou/
├── .agents/                      # AI assistant modular rulebooks (style, architecture, workflow)
├── AGENTS.md                     # Core rules & guidelines for AI assistants
├── GEMINI.md                     # Antigravity/Gemini workspace config
├── README.md                     # This file
├── docs/                         # Centralized documentation
│   ├── README.md                 # Documentation navigation index
│   ├── architecture/             # Audio engine design, GDExtension specs & engine comparisons
│   │   ├── overview.md           # System architecture & audio pipeline
│   │   ├── gdextension_api.md    # Bindings GDExtension C++/Rust (PLANIFICADO, no implementado)
│   │   ├── audio-engine_godot.md # Native Godot audio engine analysis
│   │   ├── audio-engine_wwise.md # Wwise architecture & feature breakdown
│   │   ├── audio-engine_fmod.md  # FMOD architecture & feature breakdown
│   │   └── audio-engine-comparison.md # Cross-engine matrix & module roadmap
│   ├── specs/                    # Detailed technical specifications
│   ├── decisions/                # Architecture Decision Records (ADRs)
│   ├── tasks/                    # Task management (Roadmap, Current, Backlog, Completed)
│   └── templates/                # Standardized templates for tasks, ADRs, and specs
├── addons/
│   └── opendou/                  # Godot 4.x Editor Plugin directory
│       ├── plugin.cfg            # Plugin manifest
│       └── plugin.gd             # Plugin entry point
└── tests/                        # Automated tests suite
```

---

## 📖 Documentation Quick Links

* [Documentation Hub (docs/README.md)](docs/README.md)
* [Audio Engine Architecture Overview](docs/architecture/overview.md)
* [Engine Comparison Matrix](docs/architecture/audio-engine-comparison.md)
* [Active Tasks (docs/tasks/current.md)](docs/tasks/current.md)
* [Backlog (docs/tasks/backlog.md)](docs/tasks/backlog.md)
* [Project Roadmap (docs/tasks/roadmap.md)](docs/tasks/roadmap.md)

---

## 🛠️ Getting Started

1. Open this repository in Godot 4.7+ (or 4.3+).
2. Enable the **OpenDou Audio Middleware** plugin in `Project -> Project Settings -> Plugins`.
3. Check `docs/tasks/current.md` for active milestones and `docs/tasks/backlog.md` for the technical task queue.
