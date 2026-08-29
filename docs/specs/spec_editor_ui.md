# Technical Specification: OpenDou Authoring Suite & Multi-Window Editor UI (Godot 4.7+)

**Module:** `addons/opendou/editor/`
**Status:** Approved / In Progress
**Reference Requirements:** Maximize screen real estate via Main Screen Tab, Multi-Window Floating Dialogs, and Dock Panels.

---

## 1. Objective & Scope

The **OpenDou Authoring Suite** provides sound designers with a professional middleware workspace inside Godot 4.7+.

To maximize screen workspace and support multi-monitor desktop setups, the UI is architected into 3 flexible presentation modes:
1. **Main Screen Workspace (`EditorPlugin.make_visible`):** Full-screen center view alongside "2D", "3D", and "Script".
2. **Detachable Floating Window (`Window` / Multi-Window OS Support):** Pop-out window capable of moving to a second monitor.
3. **Bottom / Side Dock Panel:** Compact transport bar and real-time profiler for rapid testing during level design in the 3D viewport.

---

## 2. Architecture & UI Component Layout

```mermaid
graph TD
    subgraph OpenDouStudioRoot [OpenDou Studio Root Container]
        HeaderBar[Header Bar: Window Detach Button | Connect TCP | Live Status]
        
        subgraph MainSplit [HSplitContainer]
            subgraph LeftPane [Hierarchy & Banks Browser]
                TreeEvents[Event & Bank TreeView]
                BankActions[Compile .bank Button]
            end
            
            subgraph CenterPane [Inspector & Logic Node Canvas]
                EventProperties[Event & Modulator Properties]
                RTPCSliders[RTPC & State Faders]
            end
            
            subgraph RightPane [Live Profiler & 3D Acoustic Radar]
                RadarCanvas[3D Audio Radar (Listener + Voices)]
                VoiceMeters[Active Voices & RAM Usage Meters]
            end
        end
        
        TransportDeck[Bottom Transport Bar: Play | Stop | Pause | Master Volume]
    end
```

---

## 3. UI Modules & Components

1. **`OpenDouStudioMain` (`addons/opendou/editor/opendou_studio_main.gd`):** The primary view container with multi-panel layout and floating window detach trigger.
2. **`OpenDouRadarView` (`addons/opendou/editor/opendou_radar_view.gd`):** Custom `Control` that uses `_draw()` to render a high-performance 2D radar view of the 3D listener position and active sound emitters in real-time.
3. **`OpenDouTransportBar` (`addons/opendou/editor/opendou_transport_bar.gd`):** Play/Stop/Pause transport controls and RTPC test faders.
4. **`OpenDouBankPanel` (`addons/opendou/editor/opendou_bank_panel.gd`):** Interface for selecting audio streams, configuring prefetch buffer size, and compiling monolithic `.bank` files.
5. **`OpenDouEditorPlugin` (`addons/opendou/plugin.gd`):** Configures editor main screen tab, bottom dock, and floating window instantiation.

---

## 4. Acceptance Criteria (DoD)

1. **Workspace Flexibility:** OpenDou can be viewed as a full Main Screen tab, embedded in a Dock, or popped out into a native OS Window.
2. **Interactive 3D Radar:** Radar canvas renders listener in center and positions active sound instances with color-coded virtualization indicators.
3. **Live Telemetry & Faders:** RTPC sliders and transport buttons trigger live audio playback and modulation.
4. **One-Click Bank Compiler:** Bank panel initiates `SoundBankCompiler` and generates `.bank` binary files directly to disk.
5. **Headless Verification:** All underlying UI controllers and canvas math verified with unit tests in `tests/test_editor_ui.gd`.
