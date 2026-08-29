# Regla 03: Flujo de Trabajo, Tareas y Commits

## 1. Ciclo de Vida de una Tarea

1. **Selección:** Seleccionar la tarea prioritaria en `docs/tasks/backlog.md` y trasladarla a `docs/tasks/current.md`.
2. **Definición:** Asegurar que la tarea cuente con:
   * Objetivo claro.
   * Archivos involucrados.
   * Criterios de aceptación (Definition of Done).
3. **Ejecución y Verificación:**
   * Desarrollar paso a paso.
   * Escribir pruebas unitarias o de integración en `tests/`.
   * Ejecutar la verificación antes de declarar la tarea terminada.
4. **Cierre:** Trasladar la tarea a `docs/tasks/completed.md` con su fecha de entrega y notas de cambios.

---

## 2. Convenciones de Commits (Conventional Commits)

Utilizar el estándar de mensajes de commit en inglés o español con prefijo semántico:

* `feat: add card combo evaluator module`
* `fix: correct hand ranking calculation for rockets`
* `refactor: extract GDExtension bridge into dedicated adapter`
* `docs: update architecture overview for state machine`
* `test: add unit tests for doudizhu card comparison`
* `chore: update gitignore and build flags`

---

## 3. Pruebas y Validación Previa a Completar

* Todo código nuevo debe ser verificado.
* **Comprobación Mandatoria:** Ejecutar `godot --headless -s tests/test_runner_cli.gd` y validar que el resultado sea 100% positivo (código de salida 0, 0 fallos, 0 errores de compilación).
* No asumir que algo compila o funciona sin ejecutar la comprobación técnica disponible. Si se detecta un error o falla, se debe corregir y verificar antes de proceder o dar por terminada la tarea.
