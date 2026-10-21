# Esquema de datos narrativos — Alice Dreams

> Formato real de los datos de la expansión narrativa. Adapta el ejemplo conceptual del encargo al guardado existente (`user://save.json`, `SaveManager`). Los guardados anteriores cargan sin cambios: todos los campos nuevos son opcionales.

## 1. Identificadores estables

| Concepto | Identificador | Ejemplo | Fuente |
|---|---|---|---|
| Mundo | número que ve el jugador (`WorldRegistry.WORLDS[].id`) | `5` = Tren de Juguete (archivos `world6`) | `scripts/levels/world_registry.gd` |
| Criatura | clave del tipo de enemigo (`EnemyDef.key` / `EnemySpawner.SCENES`) | `"scratch"`, `"pompa"`, `"fantasmita"` | `godot/data/**/enemies.json` |
| Aparición de una criatura en un nivel | `spawn.id` del `EnemySpawner` | `"world1:e3"` | `level.gd` (sólo en memoria) |
| Página del diario | número de mundo | `3` | — |

Nunca se guardan referencias a nodos de escena.

## 2. Guardado (`user://save.json`)

Campos añadidos (en **negrita**) sobre la estructura existente:

```json
{
  "version": 2,
  "unlockedWorld": 4,
  "worlds": {
    "1": {
      "completed": true, "bestStars": 97, "totalStars": 144, "specialStar": true,
      "bestTime": 412000, "completedAt": "2026-10-21T10:00:00",
      "rescued": ["scratch", "spit"]
    },
    "3": {
      "completed": false, "bestStars": 0, "totalStars": 0, "specialStar": false,
      "bestTime": 0, "completedAt": "",
      "rescued": ["rabbit"]
    }
  },
  "settings": {"music": true, "sfx": true},
  "adventureCompleted": false,
  "adventureCompletedAt": "",
  "narrativeVersion": 1,
  "journal": {"seen": [1, 2]}
}
```

| Campo | Tipo | Significado | Escritura |
|---|---|---|---|
| `worlds[N].rescued` | `Array[String]` sin duplicados | Tipos de criatura liberados alguna vez en el mundo N | `SaveManager.add_rescued(N, id)`, sólo si el tipo es nuevo (como mucho dos escrituras por mundo). Si el mundo aún no tenía entrada se crea con `completed: false` |
| `narrativeVersion` | `int` | Versión de este esquema (`DreamNarrative.VERSION`) | Valor por defecto |
| `journal.seen` | `Array[int]` | Páginas del diario ya vistas (para el aviso de «página nueva») | `SaveManager.mark_journal_seen(N)` al mostrar la página |

**Derivados (no se guardan, se calculan):**

| Dato del diario | Cálculo |
|---|---|
| Página desbloqueada | `worlds[N].completed` (sólo al completar el mundo, nunca por visitarlo) |
| Jefe purificado | igual que la página: el mundo completado |
| Secretos descubiertos | `magicCrayons` + `dreamCollectibles` del mundo (ya existían) frente al total de sus datos |
| Sticker especial | página desbloqueada y todos los secretos encontrados |
| Página nueva | desbloqueada y no incluida en `journal.seen` |
| Diario completo | las ocho páginas con todas sus criaturas y su sticker |
| Final completado | `adventureCompleted` (ya existía) |

**Compatibilidad** (`SaveManager._merge`, prueba `test_narrative_save_compat`):
- Sin los campos nuevos → valores por defecto (`rescued` vacío, `journal.seen` vacío).
- Valores inválidos → se filtran (`rescued` sólo cadenas sin repetir, `journal.seen` sólo enteros).
- `mark_world_completed` conserva `rescued`.
- `reset_progress` borra también la narrativa (conserva los ajustes, como antes).
- `version` sigue siendo 2 (la numeración de mundos no cambia).

## 3. Estado de la partida (`GameState`, en memoria)

| Clave | Tipo | Significado |
|---|---|---|
| `rescued` | `Dictionary` `{spawn.id: tipo}` | Criaturas liberadas en esta partida del mundo. Evita contar dos veces la misma aparición y sobrevive a «Volver al checkpoint» (que recarga la escena). Alimenta la celebración |
| `bossPurified` | `bool` | El jefe de esta partida ya se purificó |

Datos de entrada de la pantalla de victoria (`GameState.entry`), añadidos a los existentes: `rescued` (lista de tipos, uno por criatura) y `newPage` (`bool`).

## 4. Datos por mundo (`DreamNarrative.WORLDS`, `scripts/narrative/dream_narrative_registry.gd`)

| Mundo | Rescatables | Recuerdo / sticker (recurso existente) | Forma purificada (texto) |
|---|---|---|---|
| 1 | `scratch`, `spit` | `world1_objects/cloud_face_small` | una nubecita feliz |
| 2 | `crayon`, `brush` | `world2_objects/magic_crayon_red` | un dibujo sonriente de mil colores |
| 3 | `rabbit`, `pillow` | personaje `rabbit`, `idle` 0 | un peluche dormilón y cariñoso |
| 4 | `bubble_fish`, `pompa` | `world4_objects/duck_a` | un patito de goma amistoso |
| 5 | `payasito`, `vagoncito` | `world6_objects/train_loco` | una locomotora de juguete alegre |
| 6 | `estrellita`, `meteorito` | `world5_objects/special_star` (con brillo) | una lunita luminosa y tranquila |
| 7 | `cuppy`, `gomilito` | `world7_objects/candy_lolli` | un pastelito juguetón |
| 8 | `fantasmita`, `murcibola` | personaje `gato_morado`, `sleep` 0 | un gatito morado adorable |

Cada entrada tiene además `reflection` (frase de Alice). Los nombres de mundos, jefes y criaturas **no** están en este registro: salen de `WorldRegistry`, de los datos de cada arena (`boss.name`; el Mundo 1 usa `BossArena.DEFAULT_BOSS_NAME`) y de `EnemyDef.display_name`. La prueba `test_narrative_registry` comprueba que cada criatura rescatable aparece en los datos de su mundo (protege la numeración 5↔6).

## 5. Eventos

| Evento | Emisor | Cuándo | Garantías |
|---|---|---|---|
| `creature_rescued(world_id: int, creature_id: String)` | `RescuedCreatureManager` (uno por nivel, `level.rescues`) | Al entrar una criatura rescatable en `DEFEATED` (derrota normal o burbuja → estrella) | Una vez por enemigo (`Enemy.rescue_done`) y por aparición (`GameState.rescued`) |
| `finished` | `BossPurification` | Al terminar la purificación (2,6 s) | No retrasa la estrella especial ni el portal |
| `finished` | `RescueCelebration` | Al terminar o saltar la celebración | Bloquea la entrada de la pantalla de debajo mientras dura |
| `closed` | `DreamJournal` | Al cerrar el diario | — |
