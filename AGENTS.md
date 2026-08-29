# Directrices para Asistentes de IA (AGENTS.md)

Este documento es la **fuente única de verdad** para el comportamiento, arquitectura, gestión de tareas y desarrollo asistido por IA en el proyecto **OpenDou**.

---

## 1. Filosofía y Reglas Fundamentales de Operación

1. **Cero Asunciones Críticas:**
   * Si un requerimiento es ambiguo, impacta la arquitectura o introduce dependencias pesadas, documenta las alternativas o consulta antes de realizar cambios destructivos.
2. **Modelo Lingüístico Híbrido:**
   * **Español:** Comunicación con el usuario, definición de reglas, gestión de tareas en `docs/tasks/` y notas operativas.
   * **Inglés:** Nombres de variables/clases/funciones en el código, arquitectura técnica (`docs/architecture/`), especificaciones (`docs/specs/`) y comentarios de código público.
3. **Desarrollo Guiado por Calidad (TDD / Verificación Continua):**
   * Todo módulo, adaptador o función debe contar con casos de prueba o plan de verificación reproducible antes de considerarse completada.
4. **Diseño Modular y Desacoplado:**
   * Separar la lógica pura (reglas del juego de cartas/motor) de los adaptadores del motor Godot y de las capas visuales/UI.

---

## 2. Flujo de Gestión de Tareas

Toda tarea debe seguir este ciclo estricto a través de `docs/tasks/`:

```text
[ docs/tasks/backlog.md ] ──▶ [ docs/tasks/current.md ] ──▶ [ docs/tasks/completed.md ]
     (Planificada)                  (En ejecución)                  (Verificada)
```

### Protocolo:
* **Al iniciar:** Mover la tarea de `backlog.md` a `current.md`, asegurando que cuente con *Criterios de Aceptación (Definition of Done)* claros.
* **Durante el desarrollo:** Marcar pasos con checklists `[ ]` / `[x]`.
* **Al finalizar:** Verificar pruebas, actualizar la documentación relevante y mover la tarea a `completed.md` con fecha y resumen de cambios.

---

## 3. Registro de Decisiones de Arquitectura (ADRs)

Cuando se tome una decisión que afecte:
* Elección de lenguajes (GDScript vs C++ GDExtension vs Rust).
* Protocolos de red, sincronización o serialización de estados.
* Estructuras de datos centrales de cartas, mazos o reglas.

**Se DEBE crear un ADR** en `docs/decisions/` siguiendo la plantilla `docs/templates/template_adr.md` y numerado correlativamente (ej. `0002-nombre-decision.md`).

---

## 4. Estructura de Directorios

```text
opendou/
├── .agents/rules/          # Reglas modulares detalladas (estilo, arquitectura, workflow)
├── AGENTS.md               # Este archivo (reglas generales)
├── GEMINI.md               # Compatibilidad con herramientas de Gemini
├── README.md               # Portada del proyecto y guía de inicio
├── docs/                   # Documentación centralizada
│   ├── architecture/       # Diseño técnico y subsistemas (EN)
│   ├── specs/              # Especificaciones funcionales y de módulos (EN)
│   ├── decisions/          # Architecture Decision Records (ADRs)
│   ├── tasks/              # Gestión de tareas (ES) (roadmap, current, backlog, completed)
│   └── templates/          # Plantillas estándar para ADRs, specs y tareas
├── addons/opendou/         # Plugin distribuible para Godot 4.x
│   ├── plugin.cfg          # Configuración del plugin
│   └── plugin.gd           # Entrypoint en el editor de Godot
└── tests/                  # Pruebas unitarias y de integración
```

---

## 5. Reglas Modulares de Referencia

Para directivas detalladas, consulta:
* [Reglas de Estilo y Código](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/.agents/rules/01_code_style.md)
* [Reglas de Arquitectura y Patrones](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/.agents/rules/02_architecture.md)
* [Flujo de Trabajo y Commits](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/.agents/rules/03_workflow.md)
