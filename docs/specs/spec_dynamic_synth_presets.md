# Technical Specification: Dynamic Modular Procedural Synth Engine & Preset Studio

**Module:** `addons/opendou/runtime/synth`, `addons/opendou/editor`, `addons/opendou/nodes`
**Author:** `OpenDou Audio Architecture Team`
**Date:** `2026-08-30`
**Status:** `Approved / Ready for Implementation`

---

## 1. Objective & Overview

Replace the static, hardcoded procedural synthesis `@export_enum` with a **Dynamic Modular Procedural Synthesis Engine & Preset Studio** (`SynthPresetRegistry`, `ModularSynthEngine`, `opendou_synth_presets.json`).

This system empowers sound designers to create, configure, audition, and save custom procedural audio presets in OpenDou Studio using modular DSP building blocks (Noise, FM, Physical Modeling Karplus-Strong, Wavetable Phase Modulation, Harmonic Buzz, Sub Rumble, Formants, Resonant Impulses) with stochastic anti-machinegun randomization, non-linear drive/saturation, dedicated pitch envelopes, multi-layer container compounding, and real-time game telemetry (RTPC) parameter modulation.

---

## 2. Core Architecture: Dual-Mode Hybrid Rendering

To achieve AAA fidelity without CPU budget degradation, the engine employs a **Dual-Mode Hybrid Pipeline**:

```text
                           ┌────────────────────────────────────────┐
                           │      SynthPresetDef (Preset JSON)      │
                           └──────────────────┬─────────────────────┘
                                              │
                    Are dynamic continuous RTPCs bound to DSP math?
                   (e.g., vehicle_rpm modulating FM index or Cutoff)
                                              │
                      ┌───────────────────────┴───────────────────────┐
                      ▼                                               ▼
              [ Mode A: Bake-on-Demand ]                      [ Mode B: Live Stream ]
           (Footsteps, Foley, Ambients)                     (Vehicles, Sci-Fi Thrusters)
  ┌───────────────────────────────────────────┐   ┌───────────────────────────────────────────┐
  │ • Synthesizes to AudioStreamWAV           │   │ • Streams via AudioStreamGenerator        │
  │ • Stochastic randomization applied per hit│   │ • 512-sample frame buffer in DSP loop     │
  │ • Runtime CPU cost: 0.00%                 │   │ • RTPCs modulate math in real-time        │
  │ • Caches instances in memory              │   │ • Lock-free atomic parameter sync         │
  └───────────────────────────────────────────┘   └───────────────────────────────────────────┘
```

1. **Mode A (Bake-on-Demand / Stochastic Cache):** For one-shots (footsteps, gunshots, impacts) and static looping beds (wind, cicadas, rain). Evaluates randomization ($\pm\text{freq\_var}$, $\pm\text{duration\_var}$), generates an `AudioStreamWAV` on demand or during loading, and caches it. Zero CPU load during playback.
2. **Mode B (Live Procedural Stream via `AudioStreamGenerator`):** For dynamic entities driven continuously by telemetry (electric motors, vehicle load, responsive wind gusts). Synthesizes blocks of 512 samples in real-time where RTPC parameters dynamically drive FM modulation index, filter cutoff, or harmonic balance.

---

## 3. Data Model (`opendou_synth_presets.json`)

```json
{
  "presets": {
    "SciFi_Heavy_Explosion": {
      "type": "Layer_Container",
      "loop_mode": false,
      "duration": 2.5,
      "duration_var": 0.15,
      "gain_db": 0.0,
      "layers": [
        {
          "name": "Impact_Transient",
          "generator_type": "Impulse_Ping",
          "base_freq": 1800.0,
          "base_freq_var": 0.08,
          "pitch_envelope": { "decay": 0.08, "amount_st": -24.0 },
          "gain_db": -2.0
        },
        {
          "name": "Debris_Body",
          "generator_type": "Filtered_Noise",
          "noise_color": "Brown",
          "envelope": { "attack": 0.01, "decay": 1.2, "sustain": 0.0, "release": 0.4 },
          "drive": { "type": "Soft_Clip", "amount": 1.8 },
          "filter": { "type": "LowPass", "cutoff_hz": 1200.0, "resonance_q": 1.5 },
          "gain_db": -4.0
        },
        {
          "name": "Sub_Seismic",
          "generator_type": "Sub_Rumble",
          "base_freq": 42.0,
          "envelope": { "attack": 0.05, "decay": 2.2, "sustain": 0.0, "release": 0.5 },
          "drive": { "type": "Foldback", "amount": 2.4 },
          "gain_db": 0.0
        }
      ]
    },
    "Plucked_Wood_Step": {
      "type": "Single_Generator",
      "generator_type": "Karplus_Strong",
      "base_freq": 220.0,
      "base_freq_var": 0.12,
      "decay_factor": 0.985,
      "damping": 0.35,
      "duration": 0.35,
      "gain_db": -6.0
    },
    "Cyber_Hornet_Swarm": {
      "type": "Single_Generator",
      "generator_type": "Harmonic_Buzz",
      "base_freq": 180.0,
      "harmonics": [0.5, 0.3, 0.15, 0.08],
      "envelope": { "attack": 0.1, "decay": 0.1, "sustain": 1.0, "release": 0.1 },
      "lfo": { "wave": "Sawtooth", "rate_hz": 85.0, "depth": 0.4, "target": "Amplitude" },
      "loop_mode": true,
      "duration": 1.5,
      "gain_db": -8.0
    },
    "EV_Electric_Engine": {
      "type": "Single_Generator",
      "generator_type": "Wavetable_PM",
      "base_freq": 120.0,
      "rtpc_bindings": {
        "base_freq": { "rtpc_name": "vehicle_rpm", "min_in": 0.0, "max_in": 8000.0, "min_out": 120.0, "max_out": 950.0 },
        "phase_modulation_index": { "rtpc_name": "vehicle_load", "min_in": 0.0, "max_in": 1.0, "min_out": 0.2, "max_out": 3.5 }
      },
      "phase_modulation_index": 1.2,
      "loop_mode": true,
      "duration": 2.0,
      "gain_db": -8.0
    }
  }
}
```

---

## 4. Modular DSP Generators Specification

1. **`Filtered_Noise`**: White, Pink (1/f filter), or Brown (1/f² integration) noise through configurable Biquad filter (LPF/HPF/BPF/Notch) with ADSR envelope.
2. **`FM_Chirp`**: 2-operator frequency modulation synthesis with exponential chirp curves and trill vibrato.
3. **`Karplus_Strong`**: Physical string / bar modeling via delay-line feedback loop with low-pass damping filter. Simulates plucked strings, resonant wood steps, and organic impacts.
4. **`Wavetable_PM`**: Phase modulation and wavetable scanning across sinusoidal, saw, and square wave vectors with dynamic modulation index.
5. **`Harmonic_Buzz`**: Additive multi-harmonic series with fluttering LFO amplitude modulation for insects, engines, and alarms.
6. **`Sub_Rumble`**: Low-frequency non-linear sub-bass generator (30 Hz - 75 Hz) with harmonic distortion.
7. **`Resonant_Formant`**: Triple-band formant filter modeling vocal tract resonances for amphibian frogs and creature growls.
8. **`Impulse_Ping`**: Resonant impulse excitation with rapid non-linear upward pitch glide for water droplets and tactile UI pings.
9. **`Basic_Wave`**: Standard Sine, Saw, Square, Triangle waves with ADSR.

---

## 5. Non-Linear Drive & Saturation Algorithms

Each generator and layer supports non-linear distortion to add analog presence:
* **`Soft_Clip`**: $y = \tanh(\text{drive} \cdot x)$
* **`Hard_Clip`**: $y = \text{clampf}(\text{drive} \cdot x, -1.0, 1.0)$
* **`Foldback`**: $y = \sin(\text{drive} \cdot x)$ (creates rich upper harmonics without harsh digital clipping).

---

## 6. OpenDou Studio Integration: Synth Presets Builder

Added to **OpenDou Game Syncs Panel** as **Tab 4: `⚡ Synth Presets`**:
* **Preset List Sidebar**: Create, clone, rename, and delete presets.
* **Layer Hierarchy Rack**: Add and remove layers in `Layer_Container` presets.
* **Modular Parameter Controls**:
  * Generator selector, Base Frequency, Frequency Variation ($\pm\%$).
  * Pitch Envelope (Attack, Decay, Semitone Shift).
  * Amplitude ADSR Envelope & Variation ($\pm\%$).
  * LFO Modulation (Waveform, Rate Hz, Depth %, Target).
  * Filter (Type, Cutoff Hz, Resonance Q).
  * Drive / Saturation (Type, Amount).
  * RTPC Binder (Target Parameter, RTPC Name, In/Out Curve Mapping).
* **Interactive Waveform Visualizer**: Draws the synthesized waveform / envelope preview.
* **Audition Transport**: Real-time Play, Loop, and Stop auditioning directly in the dock.

---

## 7. Declarative Nodes Integration (Inspector-First)

* **`OpenDouEventPlayer3D` / `OpenDouEventPlayer2D` / `OpenDouEventPlayer`:**
  * Replaces rigid `@export_enum` with dynamic `_get_property_list()` inspection query reading `SynthPresetRegistry.get_preset_names()`.
  * Preserves full backward compatibility: string presets in `.tscn` seamlessly resolve against the JSON registry.
  * In `_ready()`, queries `SynthPresetRegistry.get_preset_stream(preset_name, rng_seed)` or instantiates the live procedural stream if RTPCs are linked.

---

## 8. Verification & Testing Plan

* [ ] **Unit Tests (`tests/test_dynamic_synth_presets.gd`):**
  * Test 1: `SynthPresetRegistry` JSON loading, serialization, and preset list retrieval.
  * Test 2: `ModularSynthEngine` generation for all 9 generator types.
  * Test 3: `Layer_Container` multi-layer compounding and gain balancing.
  * Test 4: Stochastic randomization consistency ($\pm\text{freq\_var}$, $\pm\text{duration\_var}$).
  * Test 5: RTPC curve interpolation on live procedural streams.
  * Test 6: Non-linear drive modes (Soft_Clip, Hard_Clip, Foldback).
  * Test 7: Declarative nodes dynamic preset resolution without hardcoded enums.
* [ ] **Integration Verification:**
  * Run `demo_cyberpunk_infiltration.tscn` verifying all 5 sectors and 7.1 surround emitters resolve presets from `opendou_synth_presets.json`.
* [ ] **Regression Suite:** `godot --headless -s tests/test_runner_cli.gd` (100% pass, exit code 0).
