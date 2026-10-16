# Plan de migración Phaser 3 → Godot 4 — Alice Dreams, Guardiana de los Sueños

Rama de trabajo: `godot-migration`. El proyecto Phaser (`src/`, `public/`, `imagenes/`, `tools/`, `index.html`, `package.json`) **no se modifica**: todo lo nuevo vive en `godot/` y en estos tres documentos.

## 1. Auditoría del proyecto Phaser (el código es la fuente de verdad)

| Área | Archivos auditados | Hallazgos clave |
|---|---|---|
| Configuración | `src/config/gameConfig.js`, `tuning.js`, `audioConfig.js`, `package.json` | 480×270, `pixelArt`, `roundPixels`, escalado FIT. Arcade Physics, gravedad 900. Teselas de 16 px. Profundidades `DEPTH` (BG −100 … UI_WORLD 50). |
| Escenas | `src/scenes/*.js` | Boot → Preload → Menu → World1 → Boss → Victory; Pause y HUD superpuestas. `LevelScene` es el motor común; `World1Scene` y `BossScene` sólo aportan datos y reglas propias. |
| Mundo | `src/data/world1.js`, `worlds.js` | 475×25 teselas (7.600 px) + arena 40×17 (representa 7.600–8.000 px). 5 secciones (0/1200/2800/4500/6500 px). 16 rectángulos de terreno, 16 bloques, 9 nubes, 4 puentes, 2 nubes móviles, 4 de vapor, 1 cojín, 1 corriente, 2 burbujas con pinchos, 138 estrellas (+6 en la arena), 13 enemigos, 2 checkpoints, 3 armas, 13 carteles, 48 decorados, puerta del castillo. |
| Protagonista | `entities/Player.js`, `PlayerAnimator.js`, `systems/InputController.js` | Caminar 95, correr 150 px/s; acel. suelo 950 / decel. 1200; aire 620 / 380; salto −335, corte −120; caída máx. 430; coyote 100 ms; buffer 120 ms; invulnerable 1.300 ms; aturdida 350 ms; retroceso (150, −170); rebote al pisar −250; pose de ataque 260 ms. Hitbox 12×30 (celda 42×44, 1 px sobre los pies). Animación separada de la física. |
| Enemigos | `entities/Enemy.js`, `ScratchMonster.js`, `SpitMonster.js`, `FleaMonster.js`, `enemyDefs.js`, `systems/EnemySpawner.js` | Máquina de estados IDLE/PATROL/ALERT/ATTACK/HURT/TRAPPED/DEFEATED. Detección por rango y altura, reacción, enfriamiento. Arañitas: arañazo (proyectil 170 ms). Escupitín: guarda distancia 85–170, aviso 550 ms, gota con gravedad 170. Pulgoso: retrocede a <90 px, pulga balística (t=0,95 s, g=520, 1 rebote). Aparición por cercanía a cámara (margen 80, máx. 6, retirada a 320 px). |
| Armas | `weapons/weaponDefs.js`, `WeaponManager.js`, `Projectile.js` | Burbuja (230 ms, 185 px/s, atrapa, mantener = ráfaga), pintura (380 ms, 255 px/s, 1 daño, ralentiza 2,5 s), tirachinas (650 ms, 235 px/s, vy −150, g 520, 2 daño, retroceso 160). Daño al jefe 1/2/3. Apuntar arriba = 0,7·v en ambos ejes. Proyectil genérico con pool (24 / 48). |
| Jefe | `bosses/Nubarron.js`, `scenes/BossScene.js` | 40 PV, hitbox 60×46. Fases al 65 % y 30 %: velocidades 38/62/90, intervalos 1.500/1.250/950 ms, descansos 1.300/1.300/1.500 ms, patrones fijos. Ataques WIND, SHOOT, TRIPLE, RAIN, SUMMON, DASH; avisos ("!" + anillo); descanso vulnerable; derrota → estrella especial → portal → guardado. |
| Plataformas y peligros | `entities/Platforms.js`, `Hazards.js`, `Collectibles.js`, `Checkpoint.js`, `Sign.js` | Nubes unidireccionales (franja de 10 px, 3 px bajo el borde), puentes con cuerpo de 8 px, nube elástica −540, móviles con vaivén coseno, vapor (se deshace a 560 ms, vuelve a 2.600 ms), cojín −600 (200 ms de espera), corriente (fuerza 1.500, máx. −190), burbujas con pinchos (tween seno). |
| Sistemas | `systems/*.js` | LevelBuilder (autotiling de 4×4 variantes), parallax (scrollFactor), efectos de partículas, checkpoints en el registro, audio sintetizado, SaveManager en localStorage. |
| Interfaz | `ui/GameHUD.js`, `CloudButton.js`, `PixelFont.js`, `TouchControls.js`, `scenes/MenuScene.js`, `PauseScene.js`, `VictoryScene.js` | HUD como escena aparte que lee el registro. Fuente pixel 5×7 propia con contorno y tildes. Botones de nube navegables con teclado. 8 botones táctiles multitáctiles. |
| Recursos | `public/assets/manifest.json`, atlas `*.json`, `tools/prepare_assets.py`, `asset_sources.py`, `ASSETS_REPORT.md` | Atlas JSON (hash) **sin recortes** (`trimmed:false`): celdas uniformes por personaje (42×44, 44×28, 34×28, 30×26, 166×82). 26 fotogramas de Nubarrón. Correr y caer reutilizan fotogramas. Cielo, nubes de fondo, portal y corazones generados por el script. |
| Audio | `systems/AudioManager.js`, `SynthSounds.js` | No hay archivos de audio: 23 efectos y 3 músicas sintetizados con WebAudio. |

Diferencias documentación/código detectadas: ninguna relevante. El README dice "Nubarrón 40 PV" y el código usa `maxHp = 40` (se conserva).

## 2. Tabla de equivalencias

| Phaser (src/) | Godot (godot/) | Notas |
|---|---|---|
| `main.js`, `config/gameConfig.js` | `project.godot`, `scripts/core/constants.gd` | 480×270, stretch `viewport` + `keep` (= FIT), filtro *nearest*, snap de píxeles, 60 Hz de física. |
| `config/tuning.js`, `weapons/weaponDefs.js`, `entities/enemyDefs.js`, `data/world1.js` | `data/*.json` (generados) + `resources/weapons/*.tres` (`WeaponDef`) + `resources/enemies/*.tres` (`EnemyDef`) | Se generan evaluando los módulos JS originales con Node: los valores son idénticos por construcción. |
| `BootScene` + `PreloadScene` | `scenes/main/Main.tscn` (`scripts/ui/boot.gd`) + autoload `Assets` | Pantalla de carga mientras se sintetiza la música. |
| `AnimationManager` + atlas Phaser | `resources/**/<clave>_frames.tres` (`SpriteFrames`) | Generados por `tools/build_resources.gd` con `AtlasTexture` por fotograma. |
| `PlaceholderFactory` | `Assets.placeholder()` / `mark_placeholder()` | Mismo cuadro magenta/negro y aviso en el menú. |
| `MenuScene` | `scenes/menus/Menu.tscn` (`menu.gd`) | Botones en `VBoxContainer`. |
| `LevelScene` | `scripts/levels/level.gd` (`class_name Level`) | Motor común; reloj `now` pausable; ganchos `on_create/on_update/on_respawn/on_special_star/on_custom_overlap`. |
| `World1Scene` | `scenes/worlds/World1.tscn` (`world1.gd`) | Sólo datos + puerta del castillo. |
| `BossScene` | `scenes/bosses/World1Boss.tscn` (`boss_arena.gd`) | Puerta, combate, estrella especial, portal. |
| `PauseScene` | `scenes/menus/Pause.tscn` (`pause_menu.gd`) | `CanvasLayer` con `process_mode = ALWAYS` + `SceneTree.paused`. |
| `VictoryScene` | `scenes/menus/Victory.tscn` (`victory.gd`) | |
| `GameHUD` | `scenes/ui/HUD.tscn` (`hud.gd`) | `CanvasLayer` + `Control`/`Panel`/`TextureRect`; escucha `GameState.changed`. |
| `registry` de Phaser | autoload `GameState` | Mismo nombre de claves (`hp`, `stars`, `weapon`, `checkpoint`…). |
| `Player` (Arcade Sprite) | `scenes/player/Player.tscn` (`CharacterBody2D`, `player.gd`) | Origen en los pies como `setOrigin(0.5,1)`. `move_and_slide`, gravedad semi-implícita como Arcade. |
| `PlayerAnimator` | `scripts/entities/player_animator.gd` | `AnimatedSprite2D`; `Anim.play` reproduce la semántica `ignoreIfPlaying`. |
| `InputController` + `VirtualPad` | `scripts/systems/input_controller.gd` + acciones del `InputMap` | Los botones táctiles (`TouchScreenButton`) emiten las mismas acciones. |
| `StateMachine` | `scripts/core/state_machine.gd` | Estados como métodos `_enter_X/_update_X/_exit_X`. |
| `scene.time.delayedCall` | `scripts/core/timers.gd` | Sobre el reloj del nivel (pausable y cancelable). |
| `Enemy` | `scripts/entities/enemy.gd` (`CharacterBody2D` + `Area2D` Hitbox) | Mismos estados y tiempos. |
| `ScratchMonster` / `SpitMonster` / `FleaMonster` | `scenes/enemies/Scratch|Spit|Flea.tscn` (`scripts/ai/*.gd`) | |
| `EnemySpawner` | `scripts/systems/enemy_spawner.gd` | Activación/desactivación por distancia a la cámara. |
| `Projectile` + pool | `scenes/weapons/Projectile.tscn` (`CharacterBody2D` + `Area2D`) | Un único código de colisiones; límite de 24/48 activos como el pool. |
| `WeaponManager` | `scripts/weapons/weapon_manager.gd` | |
| `Nubarron` | `scenes/bosses/Nubarron.tscn` (`Area2D`, `nubarron.gd`) | Movimiento por velocidad propia (sin colisión con el escenario, como en Phaser). `setTintFill` → `resources/effects/flash.gdshader`. |
| `LevelBuilder` | `scripts/levels/level_builder.gd` | `TileMapLayer` + `TileSet` con el mismo autotiling. |
| Nubes / puentes (`createCloud`, `buildBridge`) | `CloudPlatform` / `RainbowBridge` (`StaticBody2D`, colisión unidireccional) | |
| `MovingPlatform` | `MovingPlatform` (`AnimatableBody2D`, `sync_to_physics`) | Godot transporta a la protagonista como el arrastre de Arcade. |
| `CrumblePlatform`, `BouncePad`, `Hazard`, `WindZone` | `scripts/objects/*.gd` (`StaticBody2D` / `Area2D`) | |
| `Star`, `WeaponPickup`, `Portal`, `Checkpoint`, `Sign` | `scripts/objects/star.gd`, `weapon_pickup.gd`, `portal.gd`, `checkpoint.gd`, `sign_post.gd` | |
| `CheckpointManager` | `scripts/systems/checkpoint_manager.gd` | |
| `ParallaxBackground` | `scripts/levels/parallax_background.gd` (`Parallax2D`) | `scroll_scale` = `scrollFactor`. |
| `EffectsManager` + emisores | `scripts/systems/effects.gd` + `particle_burst.gd` | Partículas nítidas con la misma semántica que Phaser. |
| Cámara (`startFollow`, deadzone, lerp, shake, fade) | `scripts/systems/camera_rig.gd` (`Camera2D`) + autoload `Fader` | Algoritmo de seguimiento de Phaser portado tal cual. |
| `AudioManager` + `SynthSounds` + `audioConfig` | autoload `AudioManager` + `scripts/core/synth.gd` + `audio_config.gd` | Mismos sonidos sintetizados, renderizados a `AudioStreamWAV`. |
| `SaveManager` (localStorage) | autoload `SaveManager` (`user://save.json`) | Carga segura con valores por defecto. |
| `PixelFont` (RetroFont) | `scripts/ui/pixel_font.gd` + `pixel_text.gd` | Mismos glifos y contorno. |
| `CloudButton` + `MenuList` | `scripts/ui/cloud_button.gd` (`BaseButton`) + `menu_list.gd` | |
| `TouchControls` | `scripts/ui/touch_controls.gd` (`TouchScreenButton`) | |
| `data/worlds.js` | `scripts/levels/world_registry.gd` | Registro de 8 mundos. |
| `tools/prepare_assets.py` | (se reutiliza su salida) + `godot/tools/convert_phaser.mjs` + `godot/tools/build_resources.gd` | |

## 3. Etapas

1. Auditoría y equivalencias (este documento).
2. Proyecto Godot nativo (`godot/project.godot`, autoloads, capas, acciones).
3. Conversión de atlas y datos (`convert_phaser.mjs` → `build_resources.gd`).
4. Protagonista y física.
5. Datos del mundo y TileSet.
6. Armas.
7. Enemigos.
8. Obstáculos y checkpoints.
9. Nubarrón.
10. HUD, menús, audio y guardado.
11. Validación (headless, pruebas automáticas, piloto automático, capturas).
12. Documentación (`MIGRATION_REPORT.md`, `README_GODOT.md`).

## 4. Decisiones de diseño

- **Coordenadas idénticas**: el origen de cada nodo coincide con el origen del sprite en Phaser (pies para la protagonista, enemigos, decorado y cojines; centro para el jefe y proyectiles). Así todas las fórmulas de posición de Phaser se trasladan sin conversión.
- **Reloj de juego propio** (`Level.now`, ms): avanza en cada paso de física y se detiene en pausa; todos los tiempos (invulnerabilidad, enfriamientos, ataques del jefe) lo usan.
- **Solapamientos**: un único sensor `Area2D` en la protagonista despacha estrellas, armas, checkpoints, cojines, peligros, corrientes, enemigos, proyectiles, puerta, portal y jefe al nivel, igual que los `overlap` de `LevelScene.setupCollisions`.
- **Datos generados, no copiados**: los JSON y `.tres` se regeneran con dos comandos a partir del proyecto Phaser.
