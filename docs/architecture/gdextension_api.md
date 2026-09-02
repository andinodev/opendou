# GDExtension & Native Interoperability Guide

## 1. Overview

**OpenDou** supports native performance acceleration through Godot 4's **GDExtension** interface (using C++ via `godot-cpp` or Rust via `gdext`).

This guide specifies how native modules are structured, bound to the engine, and safely accessed from GDScript.

---

## 2. Interface Design Principles

1. **Clean Class Boundaries:**
   * Native classes extend `godot::RefCounted` for data/logic objects or `godot::Node` only if engine lifecycle hooks (`_process`, `_ready`) are strictly needed.
2. **Dual-Backend Support (Fallback Pattern):**
   * The plugin should provide a unified GDScript API facade. If the native GDExtension library is compiled and present, it routes computations to native code; otherwise, it falls back to pure GDScript implementation.
3. **Explicit Type Registrations:**
   * All exposed methods, properties, and signals must be registered in `_bind_methods()`.

---

## 3. Class Registration Example (C++ / `godot-cpp`)

```cpp
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace opendou {

class DouRuleEngine : public godot::RefCounted {
    GDCLASS(DouRuleEngine, godot::RefCounted);

protected:
    static void _bind_methods() {
        godot::ClassDB::bind_method(
            godot::D_METHOD("can_beat", "candidate_combo", "target_combo"),
            &DouRuleEngine::can_beat
        );
        godot::ClassDB::bind_method(
            godot::D_METHOD("evaluate_combo_type", "cards"),
            &DouRuleEngine::evaluate_combo_type
        );
    }

public:
    bool can_beat(const godot::Array &p_candidate, const godot::Array &p_target) const;
    int evaluate_combo_type(const godot::Array &p_cards) const;
};

} // namespace opendou
```

---

## 4. Build Structure & Targets

Native code lives in a dedicated top-level directory (e.g. `src/` or `native/`) and compiles binaries to `addons/opendou/bin/`:

```text
addons/opendou/
└── bin/
    ├── opendou.gdextension           # GDExtension manifest
    ├── libopendou.windows.template_debug.x86_64.dll
    ├── libopendou.windows.template_release.x86_64.dll
    ├── libopendou.linux.template_debug.x86_64.so
    └── ...
```

---

## 5. Memory & Thread Safety Rules

* Never retain raw C++ pointers to Godot objects that can be freed by the engine. Use `godot::Ref<T>` or `godot::ObjectID` + `Object::cast_to<T>()`.
* Core card evaluations and solvers should be **pure / const functions** whenever possible, allowing parallel evaluations across multiple threads without locking.

---

## 7. Estado real (Fase 7B, 2026-09-02)

Lo anterior era la guía; esto es lo que existe.

| Pieza | Dónde | Qué hace |
|---|---|---|
| `OpenDouSpatialStream` (`AudioStream`) | `native/src/spatial_stream.{h,cpp}` | Envuelve un `AudioStream` y produce estéreo espacializado por bloque: HRTF de Steam Audio, ITD por cabeza esférica (Woodworth, en C++), paso-bajo de oclusión (`cutoff_hz`), high-shelf por distancia con la fórmula de Godot (`shelf_db`, `shelf_cutoff_hz`), ganancia por distancia (`distance_gain`), y modo altavoces (`output_mode`) con paneo de potencia constante |
| `OpenDouSpatialStreamPlayback` | ídem | `_mix` con anillo de `frame_size` muestras; la latencia añadida es un bloque (11.6 ms a 512 @ 44.1 kHz) |
| `SteamAudioContext` | `native/src/steam_audio_context.{h,cpp}` | Contexto y HRTF globales; el HRTF se cambia en vivo por generación con cuenta de referencias |
| `dsp.h` | `native/src/dsp.h` | Biquad (LPF Butterworth, shelf de Godot), línea de retardo fraccionaria, Woodworth, paneo |
| Estáticas | `OpenDouSpatialStream.is_native_available()`, `get_frame_size()`, `get_steam_audio_version()`, `configure(frame_size)`, `set_hrtf_default()`, `set_hrtf_sofa(path)`, `get_hrtf_name()`, `get_hrtf_generation()`, `benchmark_block(voices)`, `benchmark_block_mode(voices, mode)` | La suite las usa para omitirse cuando la extensión no está, y para la guarda de coste |

**Doble backend, tal como quedó.** `OpenDouSpatialBackend.resolve(ajuste, extensión_presente)`
decide una vez al arrancar entre `godot` y `steam_audio` según el ajuste de proyecto
`opendou/spatial/backend` (`auto` por defecto). Con `steam_audio`, el pool crea anfitriones
`AudioStreamPlayer3D` **neutralizados** (paneo 0, atenuación desactivada, filtro 0 dB) con un
`OpenDouSpatialStream` permanente cada uno; el canal físico calcula dirección, distancia y
filtros con `OpenDouDistanceModel` (las fórmulas de Godot) y los empuja al stream. El
anfitrión es 3D y no plano porque el reverb por sala vive en `Area3D.reverb_bus`, que solo
alimentan los reproductores 3D, y `AudioServer` no expone a GDExtension el mapa de volúmenes
por bus. Con `godot`, todo es como antes de la Fase 7.

**Cómo se compila.** `native/build.sh`: fija godot-cpp `master` @ `26fb7ab` (API 4.7; no
existe rama 4.7) y Steam Audio 4.8.1 por SHA-256, compila ambos y firma ad hoc las dos
bibliotecas en `addons/opendou/bin/` (ignorado por git). Una `.dylib` descargada trae
`com.apple.quarantine` y macOS la rechaza sin eso. Solo macOS arm64 está verificado.

**Lo que hay que saber del hilo de audio.** `AudioStreamPlayback.mix_audio()` devuelve un
`PackedVector2Array` nuevo por bloque: una reserva de memoria en el hilo de audio por voz y
bloque. GDExtension no ofrece otro camino para tirar de un stream interno. Medido con
`benchmark_block`: ~18–23 µs por voz y bloque de 512 con la cadena completa; el techo vive en
`tests/dsp_budget.txt`.
