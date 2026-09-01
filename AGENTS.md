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
   * Separar la lógica pura (reglas del motor/audio) de los adaptadores del motor Godot y de las capas visuales/UI.
5. **Construcción Declarativa de Escenas (`.tscn`):**
   * Toda escena (demos, sandbox, herramientas) DEBE construirse como un archivo `.tscn` con sus nodos 3D/2D, UI, cámaras, luces y componentes montados visualmente en el árbol de escenas.
   * Los scripts `.gd` deben reservarse para la lógica de control, reactividad y conexión de señales, evitando la generación procedimental manual de interfaces completas por código.

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
* **Al finalizar:** **OBLIGATORIO:** Ejecutar `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1` (o `.\godot.cmd --headless --path . -s tests/test_runner_cli.gd`) y confirmar que todos los tests pasen al 100% (código de salida 0, sin errores ni advertencias de compilación/parseo). Solo entonces actualizar la documentación relevante y mover la tarea a `completed.md`. Si algún test o parseo falla, se debe corregir y verificar antes de continuar.

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

## 5. Ejecutar los tests (obligatorio antes de dar algo por hecho)

Usa **siempre** `./run_tests.sh` (macOS/Linux) o `run_tests.ps1` (Windows). No
invoques Godot a mano: el runner hace tres comprobaciones que la suite por si
sola no hace, y sin ellas es posible reportar exito con el motor roto.

1. **`SCRIPT ERROR` y `Parse Error` son fatales.** En GDScript una llamada a un
   metodo inexistente emite error, aborta la funcion que la contiene y devuelve
   `null`. Un test puede por tanto reportar PASSED mientras el motor grita: asi
   convivieron durante 58 tareas un "337/337 PASSED" con cinco defectos reales.
2. **Trinquete de fugas de ObjectDB.** El techo vive en `tests/leak_budget.txt`
   con su justificacion escrita. Si sube, investiga antes de tocar el numero:
   cada subida de esta fase delato fugas preexistentes (399 objetos en total).
3. **Regeneracion de la cache de clases.** Un `class_name` recien anadido **no
   existe como tipo global** hasta que Godot regenera
   `.godot/global_script_class_cache.cfg`, y sin editor eso solo ocurre al
   importar. Anotar un tipo nuevo antes de eso produce `Parse Error: Could not
   find type ... in the current scope`, tumba la compilacion de toda la suite y
   deja a Godot colgado. El runner compara los `class_name` declarados con los
   que la cache conoce e importa solo si falta alguno.

Nota para evitar un diagnostico equivocado: las funciones **estaticas con
`await` y tipo de retorno propio funcionan correctamente entre scripts**. Si una
falla al compilar, la causa es el punto 3, no la corrutina.

Aserciones de audio: no cuentes frames fijos para afirmar silencio. En headless
el bucle corre a maxima velocidad, asi que los frames no son proporcionales al
tiempo de audio. Usa `OpenDouAudioProbe.await_silence()`.

---

## 6. Reglas Modulares de Referencia

Para directivas detalladas, consulta:
* [Reglas de Estilo y Código](.agents/rules/01_code_style.md)
* [Reglas de Arquitectura y Patrones](.agents/rules/02_architecture.md)
* [Flujo de Trabajo y Commits](.agents/rules/03_workflow.md)
