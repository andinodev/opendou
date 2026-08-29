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
