# 📚 Centro de Documentación de OpenDou Audio Engine

Bienvenido a la base de conocimiento de **OpenDou**, el motor de audio y middleware de alto rendimiento 100% código abierto para **Godot Engine 4.7+**.

---

## 🗺️ Mapa de Navegación

### 1. Gestión de Tareas y Desarrollo (Español)
* 🗺️ [Roadmap del Proyecto](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/tasks/roadmap.md) - Visión global, fases del motor e hitos.
* ⚡ [Tareas Activas (Current)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/tasks/current.md) - Trabajo en curso del sprint / sesión.
* 📋 [Backlog](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/tasks/backlog.md) - Banco de tareas técnicas clasificadas por módulo.
* ✅ [Tareas Completadas](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/tasks/completed.md) - Historial de entregas y changelog.

---

### 2. Arquitectura Técnica y Análisis Comparativo (English / Español)
* 🏛️ [Audio Engine Architecture Overview](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/overview.md) - Diseño de subsistemas, diagramas y pipeline de mezcla.
* ⚡ [Event & Action Dispatcher Architecture](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/event-dispatcher.md) - Diseño detallado del gestor de eventos y RTPCs.
* 🌳 [Logic Containers & Decision Tree](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/logic-container.md) - Patrón Composite para Random, Switch, Blend y Sequence.
* 🎙️ [Virtual Voice & Resource Management](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/voice-pooling.md) - Virtualización a coste cero y algoritmos de robo de voz.
* 🎛️ [Game Syncs & Central Manager](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/006-gestor-central.md) - Gestión de RTPCs, States, Switches y aceleración LUT.
* 🌊 [Automatic Modulators (AHDSR & LFO)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/007.md) - Envolventes y osciladores de baja frecuencia.
* 📦 [SoundBanks & Streaming Pipeline](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/soundbanks-pipelines.md) - Formato binario monolítico y prefetching en RAM.
* 🔄 [RingBuffer & Stitching Handshake](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/009.md) - Búfer circular SPSC y empalme prefetch-a-disco.
* 🚪 [Macro-Spatial Acoustics (Rooms & Portals)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/010.md) - Grafo espacial, difracción y pathfinding.
* 🎯 [Micro-Spatial Acoustics (Raycasting & Slew Rate)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/011.md) - Oclusión física directa y suavizado LPF.
* 🌐 [Live Update & Profiler (TCP & TLV)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/012.md) - Sincronización en caliente y servidor TCP.
* 📡 [Real-Time Voice Telemetry & Radar](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/013.md) - Snapshot de telemetría y radar espacial 3D.
* 📊 [Cross-Engine Comparison Matrix](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/audio-engine-comparison.md) - Comparativa técnica Godot vs Wwise vs FMOD.
* 🤖 [Godot Audio Engine Analysis](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/audio-engine_godot.md) - Análisis en profundidad de las capacidades nativas de Godot 4.3+/4.7+.
* 🔊 [Wwise Architecture Breakdown](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/audio-engine_wwise.md) - Desglose de SoundEngine, Actor-Mixer, Game Syncs y Spatial Audio.
* 🎛️ [FMOD Architecture Breakdown](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/audio-engine_fmod.md) - Desglose de Studio API, Core API, DSP graph y Live Update.
* 🔌 [GDExtension & Native API Guide](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/architecture/gdextension_api.md) - Interoperabilidad nativa C++/Rust.

---

### 3. Especificaciones Técnicas (Specs)
* 📄 [Spec 01: Event & Action Dispatcher](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_event_dispatcher.md) - Requisitos, diagramas UML y contratos de API.
* 📄 [Spec 02: Audio Logic Containers](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_logic_containers.md) - Composite Pattern, Random, Switch, Blend y Sequence.
* 📄 [Spec 03: Virtual Voice System & Stealing](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_voice_pooling.md) - Pools de voces, peso dinámico, micro-fades y virtualización.
* 📄 [Spec 04: Zero-Cost Virtual Tracking & Bus Routing](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_virtual_tracking.md) - Avance con pitch, auto-expiración, enrutamiento a buses y micro-fades.
* 📄 [Spec 05: Central Game Syncs & LUT Acceleration](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_game_syncs.md) - Estados, Switches, RTPCs globales y LUT O(1).
* 📄 [Spec 06: Automatic Modulators (AHDSR & LFO)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_modulators.md) - Envolventes AHDSR y osciladores LFO periódicos.
* 📄 [Spec 07: Monolithic SoundBanks (.bank) & Prefetch](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_soundbanks.md) - Empaquetado binario, prefetch en RAM y streaming desde disco.
* 📄 [Spec 08: Lock-Free Audio RingBuffer & Stitching](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_ringbuffer_stitching.md) - Búfer circular y empalme prefetch a disco.
* 📄 [Spec 09: Macro-Spatial Acoustics (Rooms & Portals)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_spatial_acoustics.md) - Grafo espacial, difracción y pathfinding acústico.
* 📄 [Spec 10: Dynamic Micro-Acoustics & Raycast Slew-Rate](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_micro_acoustics.md) - Raycasting físico y suavizado temporal de oclusión.
* 📄 [Spec 11: Live Update & Profiler (TCP Server & TLV)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_live_update.md) - Sincronización en caliente y telemetría de rendimiento.
* 📄 [Spec 12: Real-Time Voice Telemetry & 3D Audio Profiler](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_voice_telemetry.md) - Snapshot de telemetría y radar espacial 3D.
* 📄 [Spec 13: Authoring Suite & Multi-Window Editor UI](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_editor_ui.md) - Suite de edición, radar 3D y ventanas emergentes multi-monitor.
* 📄 [Spec 14: AAA Interactive Demo Suite & Showcases](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/specs/spec_demo_suite.md) - Escenas interactivas de demostración técnica.

---

### 4. Registro de Decisiones de Arquitectura (ADRs)
* 📜 [ADR Index & Guidelines](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/decisions/README.md) - Índice de decisiones técnicas.
* 📄 [ADR-0001: Inicialización de Gobernanza y Estructura Modular](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/decisions/0001-init-architecture.md)
* 📄 [ADR-0002: Arquitectura del Motor de Audio Open-Source OpenDou](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/decisions/0002-audio-middleware-architecture.md)

---

### 5. Plantillas Estandarizadas (Templates)
* 📝 [Plantilla de Tarea](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/templates/template_task.md)
* 📝 [Plantilla de Decisión Arquitectónica (ADR)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/templates/template_adr.md)
* 📝 [Plantilla de Especificación Técnica (Spec)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/templates/template_spec.md)

---

## 🤖 Guía para Asistentes de IA
Si estás operando como asistente de IA en este repositorio, revisa y cumple las reglas establecidas en:
* [AGENTS.md (Directrices de IA)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/AGENTS.md)
* [Reglas de Código (.agents/rules/01_code_style.md)](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/.agents/rules/01_code_style.md)
