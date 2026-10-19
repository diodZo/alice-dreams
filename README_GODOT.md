# Guardiana de los Sueños — versión Godot 4

Migración nativa a **Godot 4.7 (GDScript 2.0)** del juego Phaser 3 de este repositorio, ampliada con el **Mundo 2: El Reino de los Crayones Encantados** (ver `WORLD2_REPORT.md`). Es el mismo juego: el Mundo 1 *El Reino de las Nubes de Algodón* (secciones A–E), la protagonista, las tres armas, los tres monstruos, todos los obstáculos, los checkpoints y la batalla contra Nubarrón, con los sprites originales y los mapas, tiempos y valores del código Phaser.

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

### Recursos del Mundo 2

Se generan desde las cuatro imágenes oficiales de `imagenes/` (`word_2.png`, `tilesets_world_2.png`, `enemies_world_2.png`, `jefemundo2.png`), con Python + Pillow + NumPy + SciPy:

```bat
python tools/world2/prepare_world2_assets.py --debug
python tools/world2/world2_level.py
"C:\ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --import
"C:\ruta\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tools/build_resources.gd
```

Las cajas de recorte se corrigen a mano en `tools/world2/world2_sources.json`; `--debug` deja hojas de comprobación en `tools/out/world2/`.

## 5. Añadir un mundo (3 a 8)

El Mundo 2 es la referencia: `tools/world2/world2_level.py` genera sus datos y `world2.gd` sólo hereda de `DoorLevel`.

1. Escribir los datos del mundo con la forma de `data/world2/world2.json` (terreno, plataformas, `rulers`, `paints`, enemigos, estrellas, `frames`, `background`, `door`...).
2. Crear `scenes/worlds/WorldN.tscn`: un `Node2D` con un script que herede de `DoorLevel` y `data_path`/`scene_key`.
3. Arena: una escena con `scripts/levels/boss_arena.gd` y sus datos (`boss.scene`, `boss.name`, textos, música, `worldId`, `frameBoth`). El jefe nuevo sólo tiene que ofrecer la misma interfaz que `Nubarron`/`Garabato`.
4. Gráficos: un pipeline como `tools/world2/` que deje sus atlas en `godot/data/worldN/` y añadir el paquete en `Assets.PACKS`.
5. Registrarlo en `scripts/levels/world_registry.gd` y en `scripts/core/router.gd`.

Cada mundo define en sus datos tileset, fondo, longitud, secciones, terreno, plataformas, enemigos, obstáculos, coleccionables, checkpoints, música, puerta/portal y arena del jefe. Física, controles, combate, HUD y guardado no se duplican.

## 6. Pruebas

Desde la raíz del repositorio (`G` = ruta a `Godot_v4.7.2-stable_win64_console.exe`):

```bat
REM 1. todos los scripts compilan y todas las escenas/recursos cargan
%G% --headless --path godot res://tests/CheckAll.tscn

REM 2. pruebas automáticas (comprobaciones de los Mundos 1 a 5)
%G% --headless --path godot --fixed-fps 60 res://tests/Tests.tscn

REM 3. piloto automático: recorre un mundo con los controles normales hasta la puerta del jefe
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=1 godmode max_frames=15000
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=2 godmode max_frames=20000
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=3 godmode max_frames=25000
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=4 max_frames=30000
%G% --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=5 max_frames=30000
REM    "hits" añade dónde se produce cada golpe o caída

REM 4. capturas para revisión visual (ventana)
%G% --path godot res://tests/Capture.tscn -- scene=World1 x=186 y=12 frames=60 out=C:/tmp/c.png
```

Las pruebas, el piloto y las capturas usan archivos de guardado propios (`user://test_save.json`, `user://tools_save.json`): no tocan el progreso guardado.

## 7. Guardado

`user://save.json` → en Windows `%APPDATA%\Godot\app_userdata\Alice Dreams - Guardiana de los Sueños\save.json`.
Guarda: mundo desbloqueado, mundos completados con mejor marca de estrellas, estrella especial y mejor tiempo, y las preferencias de música y efectos. Si el archivo falta o está dañado se usan valores por defecto (el dañado se conserva como `save.json.bad`). No comparte nada con el guardado de la versión Phaser (que vive en el `localStorage` del navegador).

## 8. Audio

Igual que en Phaser, **todos los sonidos y la música son provisionales**: se sintetizan al arrancar (`scripts/core/synth.gd`, port directo de `SynthSounds.js`: mismas ondas, notas, envolventes y partituras). Para usar archivos reales, cópialos a `godot/resources/audio/` y asígnalos en `scripts/core/audio_config.gd` (p. ej. `"jump": "res://resources/audio/jump.ogg"`). La música del Mundo 2 se reconoce sola si existen `world2_theme.ogg`, `garabato_boss.ogg` y `world2_victory.ogg` en esa carpeta. Si una ruta no existe se vuelve al sonido provisional: la falta de audio nunca bloquea el juego.
# Mundo 3

El Reino de los Peluches Dormilones está integrado en la selección de mundos. Incluye sus cinco secciones, tres enemigos, mecánicas de sueño y Rey Siestón. Los recursos pueden regenerarse con:

```powershell
python tools/world3/prepare_world3_assets.py
python tools/world3/world3_level.py
```

Consulta `WORLD3_REPORT.md` para el inventario de contenido y validaciones.

# Mundo 4

El Reino de las Burbujas se abre desde el carrusel del menú principal al completar el Mundo 3. Incluye cinco secciones, agua con natación, géiseres, columnas de burbujas, rodillos, jabones, tres enemigos y el Rey Patoburbuja. Los recursos se regeneran con:

```powershell
python tools/world4/prepare_world4_assets.py --debug
python tools/world4/world4_level.py
```

Música opcional: `world4_theme.ogg`, `rey_patoburbuja_boss.ogg` y `world4_victory.ogg` en `godot/resources/audio/`. Consulta `WORLD4_REPORT.md` para el detalle por etapas y las validaciones.

# Mundo 5

Sueños Cósmicos — Islas en el Cielo se abre desde el carrusel del menú principal al completar el Mundo 4. Incluye cinco secciones, plataformas de estrella (sólidas y trampolines), lunas crecientes (fijas, móviles y en órbita), toboganes arcoíris, cohetes móviles, cascadas de luz que suben, estrellas que caen, nubes explosivas, tres enemigos (Estrellita Fugaz, Meteorito Travieso y Cohetito Centinela) y Luna Estelar. Los recursos se regeneran con:

```powershell
python tools/world5/prepare_world5_assets.py --debug
python tools/world5/world5_level.py
```

Música opcional: `world5_theme.ogg`, `luna_estelar_boss.ogg` y `world5_victory.ogg` en `godot/resources/audio/`. Consulta `WORLD5_REPORT.md` para el detalle por etapas y las validaciones.
