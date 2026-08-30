# Technical Specification: OpenDou VST Modular Synth Rack Workstation (Mode 3)

**Module:** `addons/opendou/editor`, `addons/opendou/runtime/synth`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved / Ready for Implementation`

---

## 1. Objective & Vision

Elevate the procedural synthesis system in OpenDou Studio from a secondary configuration tab to a **First-Class Center Workspace Canvas (Mode 3: `⚡ Synth`)**, alongside `🕸️ Graph` (0), `🎼 Music` (1), and `🎙️ Voice` (2).

The new **VST / Eurorack Modular Synth Workstation** (`OpenDouSynthRackWorkspace`) replaces static numeric forms with tactile, interactive, and visually stunning controls:
1. **Dynamic Waveform & Sweeping Playhead Visualizer:** Animated vertical playhead bar sweeping across the waveform during audition playback with superimposed ADSR geometry.
2. **Interactive ADSR Curve Editor (`OpenDouADSREditor`):** 4 draggable control nodes ($A, D, S, R$) with glowing neon gradient fills.
3. **Virtual Rotary Knobs (`OpenDouKnob`):** Vertical click-and-drag knobs with neon status arcs and real-time numeric readouts for Cutoff, Resonance, Decay, LFO Rate/Depth, and Drive.
4. **Master FX & Voicing Rack:** Stereo Constant-Power Panning, Stereo Feedback Delay, Algorithmic Space Reverb, and Monophonic Portamento / Glide.
5. **Real-Time LED VU Level Meter:** Segmented green/yellow/red meter indicating output level and digital clipping warnings.
6. **Reactive Bottom Transport Bar:** Mode 3 context with octave shifting, loop toggling, audition transport, and instant preset saving.

---

## 2. Studio Workspace Architecture (Mode 3 Integration)

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🎧 OPENDOU STUDIO ── [ 🕸️ Graph (0) ] [ 🎼 Music (1) ] [ 🎙️ Voice (2) ] [ ⚡ Synth (3) ] ─── [ 💾 Save ] [ 🗗 Detach ]│
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│  PRESETS LIBRARY (Left)   │  🎛️ EURORACK / VST MODULAR SYNTH WORKSPACE (Center: OpenDouSynthRackWorkspace)   │
│  ├── 🌿 Wind_Canopy       │  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  ├── 🐦 Bird_Chirp        │  │ ∿ WAVEFORM & DYNAMIC PLAYHEAD VISUALIZER + VU METER                      │  │
│  ├── 💥 SciFi_Heavy_Expl  │  │  [ ADSR Curve Overlay + Sweeping Playhead | VU Meter: [████████░░] -3dB ] │  │
│  ├── 🎸 Plucked_Wood_Step │  └───────────────────────────────────────────────────────────────────────────┘  │
│  ├── ⚡ Thunder_Rumble     │  ┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐  │
│  ├── 🐝 Cyber_Hornet      │  │ 1. GENERATOR │ 2. ADSR ENV  │ 3. FILTER    │ 4. LFO / MOD │ 5. DRIVE/SAT │  │
│  ├── 🚗 EV_Electric_Engine│  │ [Karplus ▼]  │ [Drag Nodes] │ [LowPass ▼]  │ [Sine 85Hz]  │ [SoftClip ▼] │  │
│  │                        │  │ Pitch: 220Hz │ A: 0.05s     │ Cutoff: 3.2k │ Depth: 40%   │ Drive: 2.5x  │  │
│  │                        │  │ Var: ±12%    │ D: 0.20s     │ Q: 1.8       │ -> Amp       │ (tanh)       │  │
│  │                        │  │ Octave: 0    │ S: 0.00      │ Env Amt: 60% │ -> Cutoff    │              │  │
│  │                        │  │ Detune: 0    │ R: 0.10s     │              │              │              │  │
│  │                        │  ├──────────────┴──────────────┼──────────────┴──────────────┴──────────────┤  │
│  │                        │  │ 6. VOICING & STEREO PAN     │ 7. MASTER FX (Delay & Space Reverb)        │  │
│  │                        │  │ [ Mono / Poly ] Glide: 45ms │ Delay: [ 180ms | Fbk: 35% | Mix: 25% ]     │  │
│  │                        │  │ Pan: [ ───●─── ] (Center)   │ Reverb: [ Size: 0.7 | Damp: 0.4 | Mix: 20% ]│  │
│  ├── ➕ [ + New Preset ]  │  └─────────────────────────────┴────────────────────────────────────────────┘  │
│  └── 🗑️ [ Delete ]        │                                                                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 🎚️ TRANSPORT: [ ▶ Audition (Space) ] [ 🔁 Loop ] [ ⏹ Stop ] [ Octave: -1 [0] +1 ] [ Master Gain: -4.0 dB ]  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Interactive Custom UI Controls

### 3.1. `OpenDouKnob` (`addons/opendou/editor/controls/opendou_knob.gd`)
* **Interaction:** Vertical mouse drag with sensitivity scale. Double-click to reset to default.
* **Rendering:**
  * Base dark circular face with metallic border.
  * Arc track from $-135^\circ$ to $+135^\circ$ ($270^\circ$ sweep range).
  * Glowing neon active arc with accent color (Cyan, Orange, Purple, Green).
  * Needle pointer indicator.
  * Bottom label with formatted value (`"3.2 kHz"`, `"45 ms"`, `"+12 st"`).
* **Signals:** `value_changed(val: float)`.

### 3.2. `OpenDouADSREditor` (`addons/opendou/editor/controls/opendou_adsr_editor.gd`)
* **Interaction:** Click and drag on 4 circular handles:
  * **Handle A (Attack):** Moves along X ($0.001\text{s} - 2.0\text{s}$).
  * **Handle D (Decay):** Moves along X ($0.01\text{s} - 3.0\text{s}$) and connects to Sustain level.
  * **Handle S (Sustain):** Moves along Y ($0.0 - 1.0$).
  * **Handle R (Release):** Moves along X ($0.01\text{s} - 4.0\text{s}$).
* **Rendering:**
  * Filled gradient polygon under the curve.
  * High-contrast glowing neon outline.
  * Visual time grid lines.
* **Signals:** `adsr_changed(attack: float, decay: float, sustain: float, release: float)`.

### 3.3. `OpenDouWaveformPlayhead` (`addons/opendou/editor/controls/opendou_waveform_playhead.gd`)
* **Rendering:**
  * 16-bit PCM waveform drawn as dynamic bipolar polyline.
  * Superimposed ADSR envelope curve in translucent cyan.
  * Vertical glowing playhead line sweeping from $0.0$ to $1.0$ normalized position during audition.
* **Methods:** `set_waveform(samples: PackedFloat32Array)`, `set_playhead_progress(progress: float)`.

---

## 4. Modular DSP Core Mathematics (`ModularSynthEngine`)

To elevate raw procedural synthesis to production-ready studio quality, `ModularSynthEngine` implements four dedicated DSP algorithms:

### 4.1. Constant Power Stereo Panning
Eliminates center acoustic energy dips by preserving total signal power across the stereo panorama $Pan \in [-1.0, 1.0]$:

$$\theta = \frac{(Pan + 1.0) \cdot \pi}{4.0} \quad \left(\text{where } \theta \in \left[0, \frac{\pi}{2}\right]\right)$$

$$Gain_L = \cos(\theta), \quad Gain_R = \sin(\theta)$$

$$L[n] = S[n] \cdot Gain_L, \quad R[n] = S[n] \cdot Gain_R$$

**Invariant:** $Gain_L^2 + Gain_R^2 = \cos^2(\theta) + \sin^2(\theta) \equiv 1.0$ (Exact $-3.01\text{ dB}$ center attenuation).

---

### 4.2. Stereo Ping-Pong Feedback Delay with High-Frequency Damping
Simulates analog tape and bucket-brigade device (BBD) spatial delays with cross-fed reflections and natural high-frequency absorption:

```text
Input[n] ───┬───────────────────────────────────────────(+)──▶ Direct (1 - Mix)
            │                                            │
            ▼                                            ▼
      [ Left Delay D_L ] ──▶ [ LPF Damp ] ──▶ (x Feedback) ──┐
            ▲                                                │
            │ (Cross-Feedback in Ping-Pong Mode)             ▼
      [ Right Delay D_R ] ◀── [ LPF Damp ] ◀── (x Feedback) ──┘
```

1. **Delay Buffer Lengths:**
   $$D_L = \text{clampi}(\text{round}(time\_ms \cdot sample\_rate / 1000.0), 1, MAX\_DELAY)$$
   $$D_R = \text{clampi}(\text{round}(D_L \cdot 1.333), 1, MAX\_DELAY) \quad (\text{Ping-Pong Spatial Offset})$$

2. **One-Pole Low-Pass Damping:**
   $$DampFilter[n] = (1.0 - \text{damping}) \cdot BufOut[n] + \text{damping} \cdot DampFilter[n - 1]$$

3. **Wet/Dry Mix:**
   $$Out_L[n] = (1.0 - \text{mix}) \cdot In_L[n] + \text{mix} \cdot Wet_L[n]$$
   $$Out_R[n] = (1.0 - \text{mix}) \cdot In_R[n] + \text{mix} \cdot Wet_R[n]$$

---

### 4.3. Algorithmic Space Reverb (Schroeder-Moorer FDN Architecture)
A lightweight, zero-latency multi-channel Feedback Delay Network (FDN) combining parallel comb filters with prime sample delays and cascaded all-pass diffusers:

```text
Input ──▶ [ Comb Filter 1 (Prime T1) ] ──┬──▶ [ Allpass Diffuser 1 ] ──▶ [ Allpass Diffuser 2 ] ──▶ Stereo Matrix ──▶ Output
      ──▶ [ Comb Filter 2 (Prime T2) ] ──┤
      ──▶ [ Comb Filter 3 (Prime T3) ] ──┤
      ──▶ [ Comb Filter 4 (Prime T4) ] ──┘
```

1. **Prime Delay Comb Filters with Feedback:**
   $$y_{comb}[n] = x[n] + g_{comb} \cdot \left((1 - d) \cdot y_{comb}[n - T_k] + d \cdot y_{comb}[n - T_k - 1]\right)$$
   where $g_{comb} = 0.70 + 0.28 \cdot \text{room\_size}$ and $d = \text{damping} \cdot 0.45$.

2. **Cascaded All-Pass Diffusion Stages ($g_{ap} = 0.5$):**
   $$y_{ap}[n] = -g_{ap} \cdot x_{ap}[n] + x_{ap}[n - D_{ap}] + g_{ap} \cdot y_{ap}[n - D_{ap}]$$

3. **Stereo Decorrelation:**
   Odd comb outputs sum to the Left channel; even comb outputs sum to the Right channel with inverted diffusion phase for an expansive, lush stereo field.

---

### 4.4. Monophonic Portamento / Pitch Glide
Calculates continuous logarithmic frequency transitions across consecutive notes without phase discontinuities:

$$f[n] = f[n - 1] + \alpha \cdot (f_{target} - f[n - 1])$$

$$\alpha = 1.0 - \exp\left(-\frac{1.0}{\max(0.001, glide\_time\_sec) \cdot sample\_rate}\right)$$

This ensures natural, organic frequency slides for lead synths, sci-fi sirens, and expressive basslines.

---

## 5. Preset JSON Schema Update (`opendou_synth_presets.json`)

```json
{
  "Bird_Chirp": {
    "type": "Single_Generator",
    "generator_type": "FM_Chirp",
    "base_freq": 2400.0,
    "base_freq_var": 0.08,
    "frequency_sweep": { "start_mult": 1.4, "end_mult": 0.85, "trill_rate": 18.0 },
    "pitch_envelope": { "decay": 0.15, "amount_st": -12.0 },
    "envelope": { "attack": 0.05, "decay": 0.25, "sustain": 0.1, "release": 0.1, "var": 0.1 },
    "filter": { "type": "BandPass", "cutoff_hz": 2800.0, "resonance_q": 2.5 },
    "pan": 0.15,
    "fx": {
      "delay": { "enabled": true, "time_ms": 180.0, "feedback": 0.35, "mix": 0.25 },
      "reverb": { "enabled": true, "room_size": 0.65, "damping": 0.4, "mix": 0.20 }
    },
    "voice": { "mode": "Mono", "glide_ms": 0.0 },
    "loop_mode": true,
    "duration": 3.0,
    "gain_db": -6.0
  }
}
```

---

## 6. Verification & Test Plan

* [ ] **Unit Tests (`tests/test_synth_vst_workspace.gd`):**
  * Test 1: `OpenDouKnob` value clamping, mouse dragging, signal emissions.
  * Test 2: `OpenDouADSREditor` handle clamping, drag updates, and signal emissions.
  * Test 3: `OpenDouWaveformPlayhead` sample loading and playhead progress updates.
  * Test 4: `ModularSynthEngine` Stereo Panning, Delay FX, and Reverb FX.
  * Test 5: `OpenDouSynthRackWorkspace` instantiation, rack module population, and preset binding.
  * Test 6: `OpenDouStudioMain` Mode 3 (`⚡ Synth`) switching and transport bar synchronization.
* [ ] **Regression Suite:** `godot --headless -s tests/test_runner_cli.gd` (100% pass, 0 failures, exit code 0).
