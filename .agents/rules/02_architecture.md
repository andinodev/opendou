# Regla 02: Arquitectura y Patrones de Diseño

## 1. Separación de Responsabilidades (Layered Design)

El proyecto `opendou` debe estructurarse en 3 capas desacopladas:

```text
┌─────────────────────────────────────────────────────────┐
│                     3. CAPA UI / VISTAS                 │
│         (Nodos 2D/Control, Animaciones, Sprites)        │
└───────────────────────────▲─────────────────────────────┘
                            │ (Escucha Señales)
┌───────────────────────────┴─────────────────────────────┐
│                 2. CAPA ADAPTADOR GODOT                 │
│      (Nodes, Resources, GDExtension Wrapper, Manager)   │
└───────────────────────────▲─────────────────────────────┘
                            │ (Invoca Lógica / Serializa)
┌───────────────────────────┴─────────────────────────────┐
│                 1. CAPA NÚCLEO / LÓGICA PURA            │
│   (Reglas de cartas, validadores, solvers, estado puro) │
└─────────────────────────────────────────────────────────┘
```

### Directrices por Capa:
1. **Núcleo (Core Logic):**
   * Debe ser independiente de la jerarquía visual de Godot (puede ejecutarse headless o mediante tests sin interfaz).
   * Puede estar implementado en C++ (GDExtension), Rust o GDScript puro (`RefCounted`).
2. **Adaptador Godot (Engine Adapter):**
   * Encapsula los estados del juego en `Resource` o `Node`.
   * Expone señales (`signal card_played`, `signal turn_started`, `signal score_updated`).
3. **Capa UI (View / Presentation):**
   * Escucha señales del adaptador para reproducir animaciones y actualizar gráficos.
   * **Nunca manipula el estado del juego directamente**, sino que emite intenciones al gestor/adaptador.

---

## 2. Comunicación por Señales vs Llamadas Directas

* **Hacia Abajo (Padre a Hijo o Manager a Módulo):** Llamadas a métodos directos (`card_manager.play_card(...)`).
* **Hacia Arriba (Hijo a Padre o Estado a UI):** Señales (`signal`).
* Evitar el acoplamiento cruzado o `get_node("../../../OtroNodo")`. Preferir inyección de dependencias o exports de referencias.

---

## 3. Estado Inmutable y Determinismo

* Las jugadas de cartas y el estado del juego deben ser serializables a `Dictionary` o bytes para permitir:
  * Pruebas unitarias reproducibles.
  * Replays o guardado de partidas.
  * Sincronización multijugador o evaluación de IA de jugadores (bot solvers).

---

## 4. Construcción Declarativa de Escenas (`.tscn`)

* Toda escena visible (escenas de demostración, sandboxes interactivos, paneles de herramientas complejos) **DEBE construirse como un archivo `.tscn` estructurado**.
* Los nodos visuales (mallas 3D, geometrías CSG, cámaras, luces, contenedores UI `MarginContainer`, `VBoxContainer`, `Sliders`, `Labels`, etc.) deben residir declarativamente en el `.tscn` para que cualquier desarrollador pueda inspeccionar, editar y previsualizar la escena directamente en el editor visual de Godot 4.x.
* Los scripts `.gd` deben enfocarse exclusivamente en la lógica de control, reactividad de parámetros y conexión de señales (mediante `@onready` o `@export`), evitando la generación procedimental manual de árboles completos de UI o nodos 3D por código.

