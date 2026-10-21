# Informe de implementación narrativa — Alice Dreams

> Criaturas rescatadas, Diario de Sueños, purificación de los ocho jefes y final. Plan: [`NARRATIVE_IMPLEMENTATION_PLAN.md`](NARRATIVE_IMPLEMENTATION_PLAN.md) · Datos: [`NARRATIVE_DATA_SCHEMA.md`](NARRATIVE_DATA_SCHEMA.md).
>
> Sin *commits* ni *push*. No se ha implementado ninguna de las 40 mejoras de `docs/LEVEL_IMPROVEMENTS.md`. No cambian el balance, los controles, la numeración de mundos ni los sprites oficiales.

## 1. Pruebas

Godot 4.7.2, *headless*. Las clases nuevas requieren `--import` una vez (paso ya documentado en `README_GODOT.md`).

| Verificación | Antes | Después |
|---|---|---|
| `CheckAll.tscn` | 0 fallos | **0 fallos** |
| `Tests.tscn` | 131 pruebas, 1 488 comprobaciones, 0 fallidas | **140 pruebas, 1 633 comprobaciones, 0 fallidas** |
| Piloto invulnerable (8 mundos) | Llega en 1-7 (el 5 con 30 000 fotogramas); el 8 no pasa de la tesela 140 | **Idéntico**. El bloqueo del Mundo 8 es previo (ver `LEVEL_IMPROVEMENTS.md` IMP-037) |

El único error en stderr de la suite es el JSON dañado que `test_save_manager` provoca a propósito.

**Pruebas nuevas** (`tests/run_tests.gd`, sección «Narrativa»):

| Prueba | Qué verifica |
|---|---|
| `test_narrative_registry` | 8 mundos; criaturas rescatables representativas (no todas) que **aparecen en los datos de su mundo** (protege la numeración 5↔6); nombres desde `EnemyDef`; recuerdos con recursos existentes |
| `test_narrative_save_compat` | Guardado antiguo sin campos narrativos: progreso y ajustes intactos; registro único de criaturas; rescatar no completa ni desbloquea mundos; persistencia tras recargar; limpieza de datos dañados; borrado de progreso |
| `test_narrative_rescue_once` | Derrota → rescate; `creature_rescued(1, "scratch")` **una vez**; ni el mismo enemigo ni la misma aparición cuentan dos veces; criaturas no seleccionadas sin cambios; efecto visible que desaparece solo; Alice no se detiene |
| `test_narrative_rescue_weapons` | Las **tres armas**: burbuja (la estrella extra sigue saliendo, sin duplicarse), pintura y tirachinas |
| `test_narrative_boss_purification` | Nubarrón: derrota original → purificación; estrella especial intacta; Alice libre; termina sola |
| `test_narrative_all_bosses_purify` | Jefes de los Mundos 2-7 con sus arenas reales |
| `test_narrative_journal` | Desbloqueo sólo al completar; datos de la página (nombres, criaturas, secretos, estrellas, sticker); página 5 = Tren; navegación con teclado, portada, cierre con Esc; acceso desde el menú (carrusel bloqueado mientras está abierto) y desde la victoria; celebración saltable que no activa el menú; aviso de página nueva |
| `test_narrative_celebration_pick` | 0 criaturas → sin celebración; 1 → una; muchas → máximo cinco, variadas |
| `test_narrative_ending` | 7 recuerdos visibles + gato (8.º); amanecer; final idéntico sin el diario completo; con el diario completo, el diario brilla; desfile en los créditos |
| `test_w8_boss_victory_and_ending` (ampliada) | El Rey Pesadelo queda purificado al abrazar al gato |
| `test_w8_awakening_and_credits` (actualizada) | Nuevas expectativas pedidas: frase «Y cuando Alice despertó…» y título `ALICE DREAMS` (igual de estricta que la anterior) |

**Revisión visual** con capturas OpenGL reales (`tests/Capture.tscn`, con opciones nuevas `complete`, `rescued`, `journal` y `t`): menú con el botón del diario, portada, página del Mundo 2, celebración en la victoria, purificación del Rey Siestón, habitación con los recuerdos, frase final y título.

## 2. Archivos creados

| Ruta | Función |
|---|---|
| `godot/scripts/narrative/dream_narrative_registry.gd` | `DreamNarrative`: datos por mundo (criaturas rescatables, reflexión, forma purificada, recuerdo/sticker). Sin nombres de mundos |
| `godot/scripts/narrative/rescued_creature_manager.gd` | `RescuedCreatureManager`: valida, deduplica, guarda y emite `creature_rescued(world_id, creature_id)` |
| `godot/scripts/narrative/rescued_creature.gd` + `godot/scenes/narrative/RescuedCreature.tscn` | Efecto de liberación (chispas, destello, salto, corazón, se eleva; ≈1,6 s, sin colisiones) |
| `godot/scripts/narrative/rescue_celebration.gd` + `godot/scenes/narrative/RescueCelebration.tscn` | Celebración de 1-5 criaturas, saltable, bloquea la entrada de debajo |
| `godot/scripts/narrative/boss_purification.gd` + `godot/scenes/narrative/BossPurification.tscn` | Purificación común de jefes (luz, anillo de estrellas, corazones, reacción de Alice, aviso) |
| `godot/scripts/narrative/dream_journal_entry.gd` | `DreamJournalEntry`: datos de una página |
| `godot/scripts/narrative/dream_journal_manager.gd` | `DreamJournalManager`: páginas calculadas desde el guardado, páginas nuevas, diario completo |
| `godot/scripts/ui/dream_journal.gd` + `godot/scenes/ui/DreamJournal.tscn` | Libro: portada, papel, esquinas, paso de página animado, teclado/ratón/táctil |
| `godot/scripts/ui/dream_journal_page.gd` + `godot/scenes/ui/DreamJournalPage.tscn` | Contenido de la doble página (o portada o página bloqueada) |
| `docs/narrative/*.md` | Plan, esquema de datos y este informe |

## 3. Archivos modificados

| Ruta | Cambio |
|---|---|
| `godot/scripts/entities/enemy.gd` | `rescue_done`; en `_enter_DEFEATED` llama a `level.rescue_creature()` (los dos caminos de derrota). Nada más cambia |
| `godot/scripts/levels/level.gd` | Crea `rescues` (`RescuedCreatureManager`) y expone `rescue_creature()` |
| `godot/scripts/levels/boss_arena.gd` | `DEFAULT_BOSS_NAME`; `purify_boss()` al recibir `defeated_at` (no bloquea la estrella ni el portal); la victoria recibe `rescued` y `newPage` |
| `godot/scripts/levels/world8_boss_arena.gd` | Al abrazar al gato: `bossPurified` y aviso de página nueva (la transformación original no cambia) |
| `godot/scripts/core/save_manager.gd` | `narrativeVersion`, `journal.seen`, `worlds[N].rescued`; `add_rescued`, `get_rescued`, `journal_seen`, `mark_journal_seen`; `_merge` tolerante; `mark_world_completed` conserva los rescates |
| `godot/scripts/core/game_state.gd` | `rescued` en cada partida nueva |
| `godot/scripts/ui/victory.gd` | Celebración, botón «Diario de Sueños» (último de la lista) y aviso «¡Página nueva!» |
| `godot/scripts/ui/menu.gd` | Botón «Diario de Sueños» (abre la página del mundo seleccionado en el carrusel) con indicador «¡Nuevo!» |
| `godot/scripts/cinematics/alice_awakening.gd` | Amanecer progresivo; 7 recuerdos + gato; brillo de los recuerdos al mirar; diario brillante si está completo; frase final pedida en dos líneas; título `ALICE DREAMS` |
| `godot/scripts/cinematics/credits.gd` | Desfile de hasta 6 criaturas liberadas |
| `godot/tests/run_tests.gd` | 9 pruebas nuevas, 1 ampliada, 1 actualizada |
| `godot/tests/capture.gd` | Opciones de captura para la narrativa |

## 4. Funcionalidades

| Sistema | Estado | Detalle |
|---|---|---|
| Criaturas rescatadas | **Operativo** | 2 tipos por mundo, las tres armas, sin duplicados, persistencia por tipo, sin congelar a Alice, la estrella extra intacta |
| Celebración del nivel | **Operativo** | Mundos 1-7 en la pantalla de victoria; Mundo 8 en el desfile de créditos (no hay pantalla de victoria en el final) |
| Diario de Sueños | **Operativo** | Portada + 8 páginas; desbloqueo sólo al completar; accesible desde el menú/carrusel y la victoria |
| Navegación con mando | **Parcial** | El diario usa acciones del Input Map; el proyecto todavía no tiene eventos de mando (ver IMP-017). No se añadieron para no tocar controles |
| Purificación de jefes 1-7 | **Operativo** | Capa común sobre su forma tierna oficial (`defeated`) |
| Rey Pesadelo → gato | **Operativo** (ya existía) | Se mantiene la transformación original; se añade el registro narrativo |
| Despertar, 8 recuerdos, gato, frase y título | **Operativo** | La reacción «Alice se incorpora» y el gato ya existían |
| Variante con diario completo | **Operativo** | Detalle visual opcional; el final es el mismo para todos |
| Final rejugable | **Operativo** | «Ver el final» del menú (ya existía), ahora con los recuerdos |

## 5. Recursos pendientes (*placeholders*)

| Recurso que falta | Ahora se usa | Dónde integrarlo |
|---|---|---|
| Versión liberada/tierna de las 16 criaturas rescatables (2-4 cuadros: saludo, salto, agradecimiento) | Su fotograma `idle` con destello y halo | `rescued_creature.gd`, `rescue_celebration.gd`, `dream_journal_page.gd` |
| Ilustraciones de cabecera de las 8 páginas | Islas del mapa de mundos (`world_map_bg.png`, también provisionales) | `dream_journal_page.gd → _left()` |
| Portada, textura de papel, esquinas y stickers del diario | Dibujo por código y fotogramas existentes | `dream_journal.gd → BookArt`, `DreamNarrative.memento` |
| Sprite del diario sobre la mesilla | Rectángulos | `alice_awakening.gd → _diary_glow()` |
| «Caja de crayones» (Mundo 2) | Un crayón mágico (`magic_crayon_red`) | `DreamNarrative.WORLDS[2].memento` |
| Pequeña luna del Mundo 6 en forma purificada | Fotograma oficial `defeated` de Luna Estelar | — |
| Animación de Alice acariciando al gato | El abrazo existente (`PurpleCat.cuddle`) | `purple_cat.gd` |
| Música y sonidos propios (liberación, diario, página nueva) | Efectos sintetizados existentes (`pickup`, `magic_reveal`, `checkpoint`, `ui_*`) | `audio_config.gd` |

## 6. Riesgos y limitaciones

- **Sin prueba jugada por personas.** El ritmo de los efectos, la legibilidad del diario para la edad objetivo y la duración de la celebración (4,2 s, saltable) están verificados por pruebas y capturas, no por jugadores.
- **Aleatoriedad:** los efectos nuevos usan el generador aleatorio global, igual que los existentes. En el piloto automático cambia ligeramente el recuento de estrellas (±1-3) frente a antes; el recorrido y los tiempos no cambian.
- **Texto del diario a escala 1** (fuente 5×7 del juego, como el HUD), en tinta oscura sobre papel claro y con títulos a escala 2. Conviene validarlo en pantalla real.
- **Rescates de un mundo no completado** se guardan (por tipo) y aparecen al desbloquear su página: es intencionado y está documentado.
- El bloqueo previo del piloto en el Mundo 8 (IMP-037) no se ha tocado, por estar fuera del alcance.

## 7. Estado final

El juego compila y carga entero (CheckAll 0 fallos). Las 140 pruebas pasan y los ocho mundos mantienen su recorrido automático. Flujo narrativo verificado por pruebas: rescate en nivel → guardado → celebración en la victoria → página nueva → diario; purificación de los 8 jefes; final con recuerdos, frase, título y créditos con desfile. Verificado además en capturas renderizadas. No verificado: una partida completa jugada a mano de principio a fin.
