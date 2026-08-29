# ADR 0001: Inicialización de Gobernanza y Arquitectura Modular

* **Estado:** Aceptada
* **Fecha:** 2026-08-29
* **Autor:** Danielillo & Antigravity Agent

---

## 1. Contexto y Problema

Al iniciar el proyecto `opendou` (plugin de Godot 4 para juegos de cartas y solvers), es indispensable establecer una base organizativa limpia que permita:
1. Mantener un desarrollo colaborativo fluido entre desarrollador humano y agentes de IA.
2. Soportar múltiples lenguajes (GDScript fuertemente tipado, C++ GDExtension / Rust).
3. Evitar el desorden de tareas y la pérdida de contexto en sesiones iterativas de programación.

---

## 2. Decisión Tomada

Se decide adoptar:
1. **Estructura Modular Completa:**
   * Archivo raíz de directivas `AGENTS.md` y reglas modulares en `.agents/rules/`.
   * Carpeta `docs/` con división en `architecture/`, `specs/`, `decisions/`, `tasks/` y `templates/`.
2. **Esquema Lingüístico Híbrido:**
   * Tareas operativas y reglas en **Español**.
   * Arquitectura técnica, código y documentación pública en **Inglés**.
3. **Flujo de Tareas Trazable:**
   * `docs/tasks/backlog.md` -> `docs/tasks/current.md` -> `docs/tasks/completed.md`.
4. **Arquitectura en 3 Capas Desacopladas:**
   * Capa 1: Lógica pura y solvers (sin dependencias visuales de nodos).
   * Capa 2: Adaptadores Godot (`Resource`, `RefCounted`, `Node`, señales).
   * Capa 3: UI y vistas reactivas.

---

## 3. Consecuencias

### Positivas (+)
* **Alta Testabilidad:** Permite ejecutar pruebas unitarias ultrarrápidas y headless sin necesidad de cargar la interfaz de Godot.
* **Consistencia de IA:** Los asistentes de IA tienen límites claros, reglas de tipado y protocolos de trabajo sin ambigüedades.
* **Escalabilidad:** Permite migrar algoritmos intensivos de cálculo a C++/Rust vía GDExtension en cualquier momento sin romper la API de GDScript.

### Negativas / Compromisos (-)
* Requiere mantener la sincronización de archivos de tareas y documentación tras cada sesión de trabajo.

---

## 4. Alternativas Consideradas

* **Estructura Plana / Todo en un solo archivo `TODO.md`:** Se descartó por insuficiente para proyectos modulares de mediana o gran escala con múltiples componentes (GDExtension, plugin, UI).
* **Monolito en GDScript acoplado a Nodos UI:** Se descartó porque imposibilita el uso de solvers de alto rendimiento y pruebas headless desacopladas.
