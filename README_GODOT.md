# Guardiana de los Sueños — versión Godot 4

Migración nativa a **Godot 4.7 (GDScript 2.0)** del juego Phaser 3 de este repositorio. Es el mismo juego: el Mundo 1 *El Reino de las Nubes de Algodón* (secciones A–E), la protagonista, las tres armas, los tres monstruos, todos los obstáculos, los checkpoints y la batalla contra Nubarrón, con los sprites originales y los mapas, tiempos y valores del código Phaser.

El proyecto Phaser sigue intacto y funcionando (`npm run dev`). La versión Godot vive entera en `godot/`.

## 1. Ejecutar en Windows

Requisito: **Godot 4.7** (estable, versión estándar, no la .NET). Probado con `Godot_v4.7.2-stable_win64.exe`.

### Desde el editor
1. Abre Godot y pulsa **Importar**.
2. Selecciona `godot/project.godot` de este repositorio.
3. La primera vez Godot importa las texturas (unos segundos).
4. Pulsa **F5** (Ejecutar proyecto).

### Desde la línea de comandos
```bat
cd ruta\al\repositorio
"C:\ruta\Godot_v4.7.2-stable_win64.exe" --path godot
```

### Exportar un ejecutable
El proyecto incluye el preset **Windows Desktop** (`godot/export_presets.cfg`). Con las plantillas de exportación 4.7.2 instaladas (Editor → Gestionar plantillas de exportación):
```bat
"C:\ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --export-release "Windows Desktop" export/windows/AliceDreams.exe
```
El resultado (`godot/export/windows/AliceDreams.exe`, ~110 MB con el motor y los datos incluidos) es un único archivo autónomo. El preset incluye los `*.json` de `data/` y excluye `tests/` y `tools/`.

## 2. Controles

| Acción | Teclado | Táctil |
|---|---|---|
| Moverse | A / D o ← / → | `◀` `▶` |
| Saltar (mantener = más alto) | Espacio | A |
| Correr | Shift (mantener) | RUN |
| Disparar | J (el lanzaburbujas admite mantener pulsado) | B |
| Apuntar hacia arriba | W / ↑ + J | `▲` + B |
| Cambiar de arma | K | ARMA |
| Pausa | Esc o P | II |
| Menús | ↑ ↓ / W S + Enter / Espacio / J, o ratón / táctil | táctil |

Los botones táctiles aparecen solos en dispositivos táctiles. Para verlos en escritorio: `godot --path godot -- --touch` (equivale a `?touch=1`).
Para ver las hitboxes: en el editor, menú **Depurar → Formas de colisión visibles** (equivale a `?debug=1`).

## 3. Estructura

```
godot/
  project.godot            480x270, escalado sin suavizado, capas de colisión, acciones, autoloads
  export_presets.cfg       exportación a Windows
  data/                    DATOS GENERADOS desde el código Phaser (no editar a mano)
    worlds/world1.json       mapa del Mundo 1 (src/data/world1.js)
    worlds/world1_boss.json  arena de Nubarrón (WORLD1.boss)
    weapons/weapons.json     armas (src/weapons/weaponDefs.js)
    enemies/enemies.json     monstruos (src/entities/enemyDefs.js)
    tuning.json              movimiento y cámara (src/config/tuning.js)
    atlases.json             regiones de cada fotograma de los atlas Phaser
    characters.json          animaciones del manifest.json
  resources/               recursos nativos
    player/ enemies/ bosses/ effects/   PNG originales + SpriteFrames (.tres)
    tilesets/world1/       teselas, objetos y TileSet con colisión
    backgrounds/world1/    cielo, nubes y elementos de fondo
    weapons/*.tres         WeaponDef (editables en el inspector)
    enemies/*.tres         EnemyDef
    effects/flash.gdshader destello blanco al golpear al jefe
    ASSETS_REPORT.md       qué sprites son originales, reutilizados o generados
  scenes/
    main/Main.tscn         arranque y pantalla de carga
    menus/                 Menu, Pause, Victory
    worlds/World1.tscn     Mundo 1 (secciones A-E)
    bosses/                World1Boss (arena) y Nubarron
    player/Player.tscn     protagonista (CharacterBody2D)
    enemies/               Scratch (Arañitas), Spit (Escupitín), Flea (Pulgoso)
    weapons/Projectile.tscn proyectil común
    ui/HUD.tscn            interfaz
  scripts/
    core/      constantes, autoloads (Assets, SaveManager, AudioManager, GameState, Fader),
               máquina de estados, temporizadores, sintetizador de audio, cambio de escena
    entities/  Player, PlayerAnimator, Enemy (base), Nubarron, WeaponDef/EnemyDef
    ai/        comportamiento de cada monstruo
    weapons/   WeaponManager, Projectile, WeaponDef
    levels/    Level (motor común), LevelBuilder, World1, BossArena, parallax, registro de mundos
    objects/   nubes, puentes, plataformas, cojín, obstáculos, corriente, estrellas, armas, banderas…
    systems/   cámara, entrada, efectos, partículas, checkpoints, aparición de enemigos
    ui/        HUD, menús, botones de nube, fuente pixel, controles táctiles
  tools/
    convert_phaser.mjs     paso 1: atlas + datos Phaser -> godot/data y godot/resources
    build_resources.gd     paso 2: SpriteFrames, TileSet, WeaponDef y EnemyDef
  tests/                   verificación (no se exporta)
```

Autoloads (servicios globales justificados): `Assets` (catálogo de recursos), `SaveManager` (progreso), `AudioManager` (sonido), `GameState` (estado de la partida, equivale al *registry* de Phaser) y `Fader` (fundidos de pantalla).

## 4. Regenerar recursos y datos

Los recursos ya están generados y versionados. Si cambian los atlas (`npm run assets` en el proyecto Phaser) o los datos (`src/data/world1.js`, `weaponDefs.js`, `enemyDefs.js`, `tuning.js`):

```bat
node godot/tools/convert_phaser.mjs
"C:\ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --import
"C:\ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tools/build_resources.gd
```

- **Paso 1 (Node ≥ 14, sin dependencias)** lee `public/assets/manifest.json` y cada atlas JSON de Phaser, copia los PNG originales (sin modificarlos) y escribe las regiones de cada fotograma; además **evalúa los módulos JS originales** y vuelca sus datos a JSON. Los mapas y valores son, por construcción, los mismos que usa Phaser.
- **Paso 2 (Godot)** crea los `SpriteFrames` con un `AtlasTexture` por fotograma (región exacta, sin recortes ni desplazamientos, el origen lo fija cada escena), el `TileSet` 16×16 con colisión y los recursos de armas y enemigos.

## 5. Añadir un mundo (2 a 8)

1. Escribir `src/data/world2.js` con la misma forma que `world1.js` (o directamente `godot/data/worlds/world2.json`).
2. Añadir su exportación en `tools/convert_phaser.mjs` (como `WORLD1`) y regenerar.
3. Crear `scenes/worlds/World2.tscn`: un `Node2D` con `scripts/levels/level.gd` (o una subclase para reglas propias, como `world1.gd`) y `data_path = "res://data/worlds/world2.json"`, `scene_key = "World2"`.
4. Si tiene jefe: su arena (`scenes/bosses/World2Boss.tscn`, subclase de `Level` como `boss_arena.gd`) y la escena del jefe.
5. Registrarlo en `scripts/levels/world_registry.gd` y en `scripts/core/router.gd`.

Cada mundo define en sus datos tileset, fondo, longitud, secciones, terreno, plataformas, enemigos, obstáculos, coleccionables, checkpoints, música, puerta/portal y arena del jefe. Física, controles, combate, HUD y guardado no se duplican.

## 6. Pruebas

Desde la raíz del repositorio (`G` = ruta a `Godot_v4.7.2-stable_win64_console.exe`):

```bat
REM 1. todos los scripts compilan y todas las escenas/recursos cargan
%G% --headless --path godot res://tests/CheckAll.tscn

REM 2. pruebas automáticas (125 comprobaciones: datos, física, armas, enemigos, jefe, guardado)
%G% --headless --path godot --fixed-fps 60 res://tests/Tests.tscn

REM 3. piloto automático: recorre el Mundo 1 con los controles normales hasta la puerta del castillo
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- godmode max_frames=15000

REM 4. capturas para revisión visual (ventana)
%G% --path godot res://tests/Capture.tscn -- scene=World1 x=186 y=12 frames=60 out=C:/tmp/c.png
```

Las pruebas usan `user://test_save.json` y lo borran al terminar: no tocan el progreso guardado.

## 7. Guardado

`user://save.json` → en Windows `%APPDATA%\Godot\app_userdata\Alice Dreams - Guardiana de los Sueños\save.json`.
Guarda: mundo desbloqueado, mundos completados con mejor marca de estrellas, estrella especial y mejor tiempo, y las preferencias de música y efectos. Si el archivo falta o está dañado se usan valores por defecto (el dañado se conserva como `save.json.bad`). No comparte nada con el guardado de la versión Phaser (que vive en el `localStorage` del navegador).

## 8. Audio

Igual que en Phaser, **todos los sonidos y la música son provisionales**: se sintetizan al arrancar (`scripts/core/synth.gd`, port directo de `SynthSounds.js`: mismas ondas, notas, envolventes y partituras). Para usar archivos reales, cópialos a `godot/resources/audio/` y asígnalos en `scripts/core/audio_config.gd` (p. ej. `"jump": "res://resources/audio/jump.ogg"`). Si una ruta no existe se vuelve al sonido provisional: la falta de audio nunca bloquea el juego.
