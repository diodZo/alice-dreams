# Plan de implementación narrativa — Alice Dreams

> Fase 0 (auditoría y línea base) de la expansión narrativa: criaturas rescatadas, Diario de Sueños, purificación de jefes y final. Escrito antes de modificar código.

## 1. Línea base

| Verificación | Resultado (Godot 4.7.2, *headless*) |
|---|---|
| `res://tests/CheckAll.tscn` | 0 fallos |
| `--fixed-fps 60 res://tests/Tests.tscn` | **131 pruebas, 1 488 comprobaciones correctas, 0 fallidas** (el único error en stderr es el JSON dañado que provoca `test_save_manager` a propósito) |

La cifra de 131 pruebas citada en `LEVEL_IMPROVEMENTS.md` es la actual.

## 2. Lo que ya existe y se reutiliza

| Necesidad | Mecanismo real encontrado | Decisión |
|---|---|---|
| Derrota de enemigos | `Enemy._enter_DEFEATED` (`scripts/entities/enemy.gd`). Las 9 IA que lo sobrescriben llaman a `super(prev, data)`. Dos caminos: derrota normal (animación + desvanecido en 1,1 s) y burbuja → estrella (`toStar`) | Gancho único en `Enemy._enter_DEFEATED` → `level.rescue_creature(self)` |
| Recompensa en estrella | `Enemy.convert_to_star` → `Level.spawn_bonus_star` | No se toca: el rescate se suma, no sustituye |
| Mundo actual | `GameState.world` (id de jugador, sale de `data.id`) | Fuente de verdad del mundo del rescate |
| Registro de mundos | `WorldRegistry.WORLDS` (nombres, `victorySub`, sprite del jefe vencido) | El diario lee nombres y forma del jefe de aquí; **no se repiten nombres de mundos** |
| Derrota de jefes 1-7 | Cada jefe termina su derrota en su forma tierna **oficial** (fotogramas `defeated` dormidos/felices; Nubarrón se convierte en nubecita) y entonces emite `defeated_at` → `BossArena.on_boss_defeated` | Capa común de purificación en `BossArena.on_boss_defeated`, **no bloqueante**: no cambia fases, tiempos ni la estrella especial |
| Jefe 8 | `ReyPesadelo` ya hace DEFEATED → TRANSFORMING (`NightmareTransformation`) → CAT (`PurpleCat`); `world8_boss_arena.gd` gestiona abrazo, luz del castillo, guardado y paso al despertar | Se conserva; se añade el registro narrativo |
| Victoria | `scripts/ui/victory.gd` (recibe `GameState.entry`) | Celebración de criaturas + botón del diario |
| Menú / selección de mundos | `scripts/ui/menu.gd` con el carrusel (`WorldCarousel`) | Botón del diario que abre la página del mundo seleccionado |
| Final | `scripts/cinematics/alice_awakening.gd` (habitación, amanecer, gato a los pies), `credits.gd` | Se añaden los recuerdos, la frase final y el título |
| Guardado | `SaveManager` (`user://save.json`, versión 2, `_merge` tolerante) | Campos nuevos opcionales; los guardados anteriores cargan igual |
| Pruebas | `tests/run_tests.gd` (lista de pruebas + `check()`) | Pruebas nuevas `test_narrative_*` en la misma suite |

## 3. Arquitectura elegida

Sin autoloads nuevos (la guía pide evitar gestores globales innecesarios):

```text
godot/scripts/narrative/
    dream_narrative_registry.gd   class_name DreamNarrative  — datos por mundo (criaturas rescatables,
                                  reflexión, recuerdo/sticker, forma purificada). Sin nombres de mundos.
    rescued_creature_manager.gd   class_name RescuedCreatureManager (RefCounted, uno por nivel) —
                                  valida, deduplica, guarda y emite creature_rescued(world_id, creature_id)
    rescued_creature.gd           efecto de liberación (partículas + forma tierna, no bloquea)
    rescue_celebration.gd         celebración de 1-5 criaturas (saltable)
    boss_purification.gd          capa común de purificación de jefes
    dream_journal_entry.gd        class_name DreamJournalEntry — datos de una página
    dream_journal_manager.gd      class_name DreamJournalManager — construye páginas, páginas nuevas
godot/scenes/narrative/
    RescuedCreature.tscn, RescueCelebration.tscn, BossPurification.tscn
godot/scripts/ui/
    dream_journal.gd, dream_journal_page.gd
godot/scenes/ui/
    DreamJournal.tscn, DreamJournalPage.tscn
```

`narrative_event_bus.gd` (sugerido en el encargo) **no se crea**: la señal `creature_rescued` vive en el gestor del nivel y las demás notificaciones ya pasan por `GameState` (banner/toast). Un bus global no aportaría nada.

## 4. Decisiones de diseño

1. **Criaturas rescatables:** dos tipos representativos por mundo (no todos los enemigos). Identificador estable = clave del tipo de enemigo (`scratch`, `pompa`…), que ya es estable en datos, escenas y guardado. Las gomitas (`gomilito_mini`) no son rescatables.
2. **Un rescate por enemigo:** bandera en el enemigo + diccionario de ids de aparición en `GameState` (sobrevive a “Volver al checkpoint”, que recarga la escena).
3. **Persistencia:** se guarda el **tipo** rescatado por mundo en el momento del rescate (sólo escribe si el tipo es nuevo: como mucho dos escrituras por mundo). La página del diario sólo se desbloquea al completar el mundo (`completed`), como pide el encargo.
4. **Purificación:** los sprites oficiales `defeated` ya son la forma tierna; la capa común añade luz, anillo de estrellas, corazones, reacción de Alice (corazón sobre ella, sin congelarla) y el aviso de nueva página. La estrella especial y el portal siguen igual.
5. **Celebración:** en la pantalla de victoria (Mundos 1-7), con las criaturas rescatadas en esa partida (1-5). Mundo 8: las criaturas rescatadas desfilan en los créditos.
6. **Diario:** portada + 8 páginas. Página bloqueada hasta completar el mundo. Navegación con las acciones existentes (`move_left/right`, `menu_*`, `pause`), ratón y táctil.
7. **Final:** se mantienen las escenas existentes; se añaden siete recuerdos en la habitación (el octavo es el gato que ya duerme a los pies de la cama), la frase final pedida y el título `ALICE DREAMS`. Con el diario completo aparece además el diario brillando en la mesilla.
8. **Arte:** no hay sprites de “forma liberada” para enemigos ni ilustraciones de diario. Se reutilizan sprites oficiales y se dibujan por código (libro, papel) como *placeholder* documentado.

## 5. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Cambiar el ritmo de combate | Todo efecto narrativo se dibuja en `fx_root` y nunca congela a Alice ni retrasa señales existentes |
| Romper pruebas de menús (índices de `MenuList`) | Botones nuevos al final de las listas |
| Guardados antiguos | Campos opcionales con valores por defecto en `SaveManager._merge`; prueba específica |
| Prueba del despertar | El texto final cambia por petición explícita: la prueba se actualiza a la nueva expectativa, igual de estricta |
