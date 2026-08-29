# Regla 01: Estándares de Código y Estilo

## 1. GDScript (Godot 4.x)

* **Tipado Estático Obligatorio:** Todas las variables, parámetros de funciones y valores de retorno deben tener tipado estático explícito.
  ```gdscript
  # Correcto
  var card_count: int = 0
  func draw_card(player_id: StringName) -> CardData:
      ...

  # Incorrecto
  var card_count = 0
  func draw_card(player_id):
      ...
  ```
* **Nomenclatura:**
  * Archivos y carpetas: `snake_case.gd`
  * Clases y tipos de nodos: `PascalCase` (`class_name CardManager`)
  * Funciones, variables y señales: `snake_case` (Señales en pasado o acción clara: `card_played`, `round_ended`)
  * Constantes y Enums: `SCREAMING_SNAKE_CASE` o `PascalCase` para el Enum con miembros `SCREAMING_SNAKE_CASE`
* **Decoradores y Exports:**
  * Usar `@export`, `@export_group`, `@export_subgroup` para organizar inspectores limpios.
  * Usar `@onready` únicamente cuando la inicialización dependa del árbol de nodos.

---

## 2. C++ / GDExtension (Godot 4.x)

* **C++ Estándar:** C++17 o C++20 según la versión de `godot-cpp`.
* **Nomenclatura:**
  * Clases: `PascalCase` (heredan de `godot::Node`, `godot::RefCounted`, `godot::Resource`, etc.).
  * Métodos: `snake_case()` (para coincidir con las convenciones de GDScript y Godot bindings).
  * Miembros privados: prefijo `m_` o `_` (ej. `_card_deck` o `m_card_deck`).
* **Seguridad de Memoria:**
  * Uso de `godot::Ref<T>` para objetos derivados de `RefCounted`.
  * `memnew` / `memdelete` o punteros inteligentes para recursos propios según corresponda.
  * Registro explícito de métodos y señales en `_bind_methods()`.

---

## 3. Rust (gdext) / C# (si aplica)

* **Rust:** Seguir `clippy`, nomenclatura idiomática de Rust con wrappers `#[godot_api]` limpios.
* **C#:** Nomenclatura C# estándar (`PascalCase` para métodos públicos y propiedades, `_camelCase` para campos privados).

---

## 4. Principio de Claridad en Comentarios

* Comentarios de documentación pública en inglés utilizando formato estándar de Godot Doc:
  ```gdscript
  ## Evaluates if the played card combo beats the previous table cards.
  ## [param combo]: The candidate card combo played.
  ## [param previous]: The current active combo on the table.
  ## [returns]: True if valid play, false otherwise.
  func can_beat(combo: CardCombo, previous: CardCombo) -> bool:
  ```
