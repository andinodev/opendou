# Technical Specification: Automatic Modulators (AHDSR & LFO) (OpenDou Core)

**Module:** `addons/opendou/resources/modulators/`, `addons/opendou/runtime/modulators/`
**Status:** Approved / In Progress
**Reference Document:** [docs/ideas/007.md](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/ideas/007.md)

---

## 1. Objective & Scope

**Modulators** are autonomous parameter generators that progress over time inside each `EventInstance` without requiring continuous code updates from gameplay scripts.

This specification implements two core modulators:
1. **AHDSR Envelope Generator:** Multi-stage envelope (Attack, Hold, Decay, Sustain, Release) triggered on play and release on stop.
2. **LFO (Low Frequency Oscillator):** Periodic continuous waveform oscillator (Sine, Triangle, Square, Sawtooth) for tremolo, vibrato, and filter sweeps.

---

## 2. Mathematical Models

### 2.1. AHDSR State Machine
```text
State:     [ATTACK] ──▶ [HOLD] ──▶ [DECAY] ──▶ [SUSTAIN] ──▶ (Key Off) ──▶ [RELEASE] ──▶ [IDLE]
Output:     0.0 -> 1.0    1.0      1.0 -> S        S                         S -> 0.0      0.0
```

1. **Attack:** $\text{gain} = \frac{t}{T_{\text{attack}}} \in [0.0, 1.0]$
2. **Hold:** $\text{gain} = 1.0$ for duration $T_{\text{hold}}$
3. **Decay:** $\text{gain} = 1.0 - (1.0 - S) \times \left(\frac{t}{T_{\text{decay}}}\right) \in [1.0, S]$
4. **Sustain:** $\text{gain} = S$ (held indefinitely while playing)
5. **Release:** $\text{gain} = S_{\text{release\_start}} \times \left(1.0 - \frac{t}{T_{\text{release}}}\right) \in [S, 0.0]$

### 2.2. LFO Waveforms ($f \text{ in Hz, phase } \phi \in [0.0, 1.0]$)
$$\phi \leftarrow (\phi + f \times \Delta t) \pmod{1.0}$$
* **SINE:** $\text{raw} = \sin(2\pi \phi)$
* **TRIANGLE:** $\text{raw} = 1.0 - 4.0 \times \left|\phi - 0.5\right|$
* **SQUARE:** $\text{raw} = 1.0 \text{ if } \phi < 0.5 \text{ else } -1.0$
* **SAWTOOTH:** $\text{raw} = 2.0 \times \phi - 1.0$

$$\text{Output} = \text{raw} \times \text{depth}$$

---

## 3. Accumulated Property Calculation

Within `EventInstance.update_parameters()`:
$$\text{Property}_{\text{final}} = \text{Base} + \sum \text{RTPC} + \sum \text{ModulatorOutput}$$

---

## 4. Acceptance Criteria (DoD)

1. AHDSR transitions smoothly through all 5 stages without discontinuities.
2. LFO produces exact periodic wave values across all 4 waveforms.
3. Modulators integrate cleanly into `AudioEventDef` and `EventInstance`.
4. 100% automated test coverage in `tests/test_modulators.gd`.
