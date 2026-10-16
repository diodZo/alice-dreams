# Guardiana de los Sueños

Plataformas 2D con combate lateral (HTML5 + Phaser 3 + Vite).
**Mundo 1: El Reino de las Nubes de Algodón**: un nivel completo y jugable con cinco secciones, tres armas, tres enemigos, obstáculos, checkpoints y la batalla contra Nubarrón.

---

## 1. Requisitos

| Herramienta | Versión probada | Para qué |
|---|---|---|
| Node.js | 22.x (vale 18 o superior) | ejecutar Vite |
| npm | 10.x | dependencias |
| Python + Pillow + NumPy | 3.12 / 11.x / 2.x | **sólo** para regenerar los recursos gráficos |

Dependencias del proyecto: `phaser@3.80.1` y, en desarrollo, `vite@5.4.10`. No hay más.

## 2. Instalación y ejecución

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # genera dist/ (estático, se puede servir desde cualquier hosting)
npm run preview    # sirve dist/ para comprobar la build
```

Los recursos ya procesados están en `public/assets/`, así que no hace falta Python para jugar.

### Parámetros de URL

| Parámetro | Efecto |
|---|---|
| `?touch=1` | muestra los botones táctiles en escritorio |
| `?debug=1` | dibuja las hitboxes de Arcade Physics y expone `window.__GAME__` |
| `?test=1` | expone `window.__GAME__` sin dibujar hitboxes (pruebas automáticas) |
| `?renderer=canvas` | fuerza el renderizador Canvas (sin tintes: ver "Limitaciones") |

## 3. Controles

| Acción | Teclado | Táctil |
|---|---|---|
| Moverse | A / D o ← / → | botones `◀` `▶` |
| Saltar (mantener = más alto) | Espacio | A |
| Correr | Shift (mantener) | RUN |
| Disparar | J (el lanzaburbujas admite mantener pulsado) | B |
| Apuntar hacia arriba | W / ↑ + J | `▲` + B |
| Cambiar de arma | K | ARMA |
| Pausa | Esc o P | II |
| Menús | ↑ ↓ + Enter / Espacio / J, o ratón/táctil | táctil |

Pisar a un monstruo le quita 1 punto de vida. Un monstruo atrapado en una burbuja se convierte en estrella al tocarlo o al volver a dispararle.

Los botones táctiles aparecen solos en dispositivos táctiles (o con `?touch=1`).

## 4. Preparación de recursos (pipeline)

Las hojas de `imagenes/` son ilustraciones de referencia, **no** spritesheets técnicos: los dibujos no están en una cuadrícula uniforme y tienen fondo (blanco, paneles grises o un halo semitransparente). Los originales nunca se modifican.

```bash
pip install pillow numpy
npm run assets                          # = python tools/prepare_assets.py
python tools/prepare_assets.py --debug  # además: tools/out/debug_*.png con hojas de comprobación
```

Qué hace `tools/prepare_assets.py` con cada fotograma (las cajas de origen están en `tools/asset_sources.py`):

1. **Separar sprites**: recorta la caja del fotograma (las cajas se obtuvieron etiquetando componentes conectados de cada hoja).
2. **Eliminar el fondo**: rellena desde el borde del recorte los píxeles "parecidos al fondo". Los blancos interiores (ojos, brillos) se conservan porque no tocan el borde. En la hoja del jefe se usa su alfa y se recorta el halo magenta.
3. **Separar efectos**: conserva la isla de píxeles principal y descarta las pequeñas (estrellitas, burbujas, salpicaduras). Los efectos y proyectiles se extraen aparte (`fx`).
4. **Quitar la sombra de suelo** (gris azulado) de la franja inferior y volver a rellenar el fondo que quedaba encerrado entre los pies.
5. **Reducir a resolución lógica** con promedio de alfa premultiplicado, alfa binario (sin bordes difuminados), paleta común por personaje y refuerzo del contorno.
6. **Normalizar dimensiones y origen**: todos los fotogramas de un personaje comparten celda y se alinean por los pies (por el centro en el jefe). Así el origen `(0.5, 1)` es estable entre animaciones.
7. **Empaquetar** en atlas JSON (formato hash de Phaser) y escribir `public/assets/manifest.json` con las animaciones.
8. **Hitboxes**: no salen de los gráficos. Se definen en código (`config/tuning.js`, `entities/enemyDefs.js`, `bosses/Nubarron.js`).

El tileset de terreno (16×16) se construye con texturas recortadas de la hoja de teselas; los bordes laterales y la base redondeada los genera el script.
El informe `public/assets/ASSETS_REPORT.md` lista qué se extrajo y qué se generó.

### Qué se extrajo, qué se generó y qué es provisional

| Recurso | Estado |
|---|---|
| Protagonista: idle 4, caminar 6, saltar 2, daño 2, victoria 3, lanzaburbujas 4, lanzapintura 4, tirachinas 4 | extraído de `Player.png` |
| Protagonista: correr 6 | **mismos fotogramas que caminar**, a más velocidad (la hoja sólo trae "walk/run") |
| Protagonista: caer 2 | **fotogramas de salto reutilizados** (la hoja no trae caída) |
| Arañitas, Escupitín, Pulgoso (idle, caminar, ataque, daño, derrota) | extraídos de `enemies.png`; el ataque de Escupitín repite una pose (la hoja sólo tiene 3 distintas) |
| Nubarrón (26 fotogramas: reposo, vuelo, soplido, disparo, tormenta, daño, derrota) | extraído de `boss_worl_1.png` |
| Burbuja, salpicadura, bolita, iconos de arma, arañazo, gota, pulga, ráfaga, bolita de nube | extraídos |
| Nubes, puentes arcoíris, bloques, cojín, burbujas con pinchos, árboles, vallas, flores, piruletas, molinillos, bandera, cartel, cascadas, huevos, islas, luna, castillo | extraídos de la hoja de teselas |
| Cielo, bancos de nubes de fondo, portal, corazones del HUD, gota de pintura y partículas | **generados por código** (no existen en las referencias) |
| Fuente pixel art | dibujada en código (`ui/PixelFont.js`), con tildes, ñ y ¡¿ |
| **Todos los sonidos y la música** | **PROVISIONALES**: sintetizados con WebAudio (`systems/SynthSounds.js`). No hay archivos de audio |

Si un recurso no se puede cargar, `PlaceholderFactory` lo sustituye por un cuadro a cuadros magenta/negro, lo registra en la consola y el menú muestra un aviso. Si falta `manifest.json`, el juego muestra un error explícito ("Ejecuta: npm run assets").

### Sustituir los sonidos provisionales

1. Copia el archivo a `public/assets/audio/` (por ejemplo `jump.ogg`).
2. En `src/config/audioConfig.js`, asígnalo al evento: `jump: 'assets/audio/jump.ogg'`.

`PreloadScene` lo carga y `AudioManager` lo usa en lugar del sintetizado. Lo mismo para la música (`MUSIC_FILES`).
Música y efectos se pueden silenciar por separado desde el menú principal o el de pausa; la preferencia se guarda.

## 5. Arquitectura

```
src/
  main.js                    arranque de Phaser
  config/
    gameConfig.js            resolución 480x270, física, escenas, profundidades
    tuning.js                ajustes de movimiento y cámara
    audioConfig.js           evento de sonido -> archivo (vacío = provisional)
  scenes/
    BootScene.js             fuente pixel + manifest
    PreloadScene.js          carga por manifest, marcadores provisionales, animaciones
    MenuScene.js             título, opciones, progreso guardado
    LevelScene.js            MOTOR COMÚN: colisiones, cámara, reaparición, pausa, HUD
    World1Scene.js           Mundo 1 (A-E) hasta la puerta del castillo
    BossScene.js             arena: puerta, Nubarrón, estrella especial, portal
    PauseScene.js            pausa superpuesta
    VictoryScene.js          resultados
  entities/
    Player.js                física y vida de la protagonista
    PlayerAnimator.js        selección de animaciones (separada de la física)
    Enemy.js                 base con máquina de estados
    ScratchMonster.js / SpitMonster.js / FleaMonster.js
    enemyDefs.js             datos de enemigos (vida, alcance, hitbox)
    Platforms.js             nubes unidireccionales, móviles, de vapor, cojín
    Hazards.js               burbujas con pinchos, corrientes de aire
    Collectibles.js          estrellas, objetos de arma, portal
    Checkpoint.js, Sign.js
  bosses/Nubarron.js         jefe con 3 fases
  weapons/
    weaponDefs.js            las tres armas como datos
    WeaponManager.js         inventario, cambio y disparo
    Projectile.js            proyectil genérico con pool (jugadora, enemigos y jefe)
  systems/
    AnimationManager.js      animaciones desde manifest.json
    AudioManager.js          audio desacoplado (archivo o sintetizado)
    SynthSounds.js           sonidos y música provisionales
    SaveManager.js           progreso y ajustes en localStorage
    CheckpointManager.js     activación y punto de reaparición
    EnemySpawner.js          aparición por cercanía, máximo 6 activos
    LevelBuilder.js          datos -> tilemap con autotiling + objetos
    ParallaxBackground.js    fondo multicapa
    EffectsManager.js        partículas y efectos
    InputController.js       teclado + botones virtuales -> acciones
    PlaceholderFactory.js    marcadores provisionales identificables
    StateMachine.js
  ui/
    GameHUD.js               escena del HUD (corazones, arma, estrellas, progreso, jefe)
    TouchControls.js, CloudButton.js, PixelFont.js
  data/
    world1.js                mapa y objetos del Mundo 1 (sólo datos)
    worlds.js                registro de los 8 mundos y estado de partida nueva
tools/
  prepare_assets.py          pipeline de recursos
  asset_sources.py           cajas de origen de cada fotograma
public/assets/               recursos generados (player, enemies, bosses, tilesets, backgrounds, fx)
```

Reglas que sigue el código:

- Renderizado, física y reglas están separados: `Player` (física y vida) / `PlayerAnimator` (animación) / `WeaponManager` (disparo) / `LevelScene` (reglas y colisiones) / `GameHUD` (interfaz).
- El HUD es una escena aparte que lee el registro del juego; el nivel no lo dibuja.
- Los niveles son datos. Física, controles y combate no se duplican entre mundos.

### Formato de un mundo (`data/worldN.js`)

Unidades en teselas de 16 px. `y` es la fila de la superficie para objetos apoyados en el suelo.

| Campo | Contenido |
|---|---|
| `widthTiles`, `heightTiles` | tamaño del mundo |
| `playerStart` | posición inicial |
| `sections` | `{ id, name, from }` (px) para los carteles de sección y el indicador de progreso |
| `terrain` | rectángulos sólidos; el autotiling elige bordes, esquinas y base |
| `blocks` | bloques sólidos del tileset |
| `clouds`, `bridges` | plataformas unidireccionales (`bouncy` = nube elástica) |
| `movers`, `crumbles`, `pads`, `winds`, `hazards` | plataformas móviles, temporales, cojines, corrientes y obstáculos |
| `stars`, `pickups`, `checkpoints`, `signs`, `decor` | coleccionables, armas, puntos de control, instrucciones, decorado |
| `enemies` | `{ type, x, y, patrol: [min, max] }` |
| `door` / `boss` / `portal` | salida al jefe, configuración de la arena y portal |

**Añadir un mundo**: crear `data/world2.js` con esta forma y una escena de 10 líneas que extienda `LevelScene` y devuelva esos datos en `getLevelData()` (como `World1Scene`). Después, registrarla en `gameConfig.js` y `data/worlds.js`.

## 6. Diseño del Mundo 1

El recorrido mide 8.000 px: 7.600 de nivel más la arena del jefe, que representa los últimos 400.

| Sección | Píxeles | Contenido |
|---|---|---|
| A · Bienvenida | 0–1.200 | carteles de caminar, saltar y correr; escalón; primeros huecos; bloques de estrella; primer Arañitas (se puede saltar o pisar) |
| B · Jardines de algodón | 1.200–2.800 | **lanzaburbujas**; mesetas; puente arcoíris pequeño; ruta alta opcional con nubes; 3 Arañitas; **checkpoint 1** |
| C · Puentes del arcoíris | 2.800–4.500 | **lanzapintura**; 2 nubes móviles; puente con burbujas de pinchos que suben y bajan; escalera de bloques; 3 Escupitines; rutas de estrellas en puentes altos |
| D · Cascadas de sueños | 4.500–6.500 | **tirachinas**; nubes de vapor que se deshacen y reaparecen; corriente de aire ascendente; cojín de burbujas; nube elástica; 3 Pulgosos; **checkpoint 2** |
| E · Castillo de Nubarrón | 6.500–8.000 | camino de aproximación con los tres tipos de monstruo; fachada del castillo; arena: la puerta se cierra, combate, estrella especial, portal |

Caer al vacío quita un corazón y devuelve al último checkpoint. Con 0 corazones se reaparece con la vida completa (no hay "game over"). Tocar una bandera también recupera la vida.
En la arena, rendirse reinicia el combate.

### Nubarrón

- Vida: 40. Daño por impacto: burbuja 1, pintura 2, tirachinas 3. Se puede derrotar con cualquiera de las tres armas.
- **Fase 1 (100–65 %)**: vaivén lento; ráfaga de viento baja (empuja y se esquiva saltando, no hace daño); 2 bolitas de nube.
- **Fase 2 (65–30 %)**: más rápido; lluvia de nubecitas con marcas de aviso en el suelo y huecos seguros; invoca 2 nubes temporales; 3 bolitas.
- **Fase 3 (30–0 %)**: color lavanda, aspecto de tormenta y estela; desplazamientos rápidos; ráfaga triple en abanico; alterna los ataques anteriores.
- Antes de cada ataque hay un aviso visual (anillo y "!"). Después de cada ataque **descansa**: baja, brilla y se queda quieto, de modo que se le puede golpear desde el suelo.
- Derrota: gira, confeti y estrellas, se convierte en una nubecita sonriente, suelta la estrella dorada especial y se abre el portal. Al cruzarlo se guarda el Mundo 1 como completado.

## 7. Etapas y cómo verificarlas

Cada etapa se comprobó en Chrome (headless, mediante DevTools Protocol) con capturas y lecturas del estado del juego.

| Etapa | Archivos principales | Cómo verificarla a mano |
|---|---|---|
| 1. Base, carga y movimiento | `main.js`, `config/*`, `BootScene`, `PreloadScene`, `Player`, `PlayerAnimator`, `InputController` | `npm run dev`, Jugar. Caminar, correr (Shift) y salto variable; al dejar un borde aún se puede saltar (coyote time); un salto pulsado justo antes de aterrizar se ejecuta (buffer) |
| 2. Tileset, mapa, cámara y parallax | `tools/*`, `LevelBuilder`, `ParallaxBackground`, `data/world1.js` | Terreno con bordes y esquinas; cámara suave con anticipación; capas de fondo a distinta velocidad |
| 3. Armas y efectos | `weapons/*`, `EffectsManager` | Recoger cada arma (x≈1.250, 2.830, 4.530 px); K alterna; J dispara; W+J dispara hacia arriba; estela y salpicadura de pintura; retroceso del tirachinas |
| 4. Enemigos e IA | `Enemy`, `ScratchMonster`, `SpitMonster`, `FleaMonster`, `EnemySpawner` | "!" al detectar; Arañitas persigue y araña; Escupitín guarda distancia y destella antes de escupir; Pulgoso retrocede y lanza pulgas en parábola; burbuja → atrapado → tocar = estrella |
| 5. Obstáculos, coleccionables y checkpoints | `Platforms`, `Hazards`, `Collectibles`, `Checkpoint`, `CheckpointManager`, `Sign` | La bandera cambia de color y avisa; caer al vacío te devuelve a ella; nubes de vapor, corriente de aire, cojín y nube elástica |
| 6. Nubarrón | `bosses/Nubarron.js`, `BossScene` | La puerta se cierra; barra de vida; cambios de fase al 65 % y al 30 %; descansos; derrota y portal |
| 7. Interfaz, sonido, progreso y victoria | `GameHUD`, `TouchControls`, `PauseScene`, `VictoryScene`, `AudioManager`, `SaveManager` | Corazones, arma, estrellas, progreso; pausa con Esc; silenciar música y efectos; la pantalla de victoria y el menú muestran "Mundo 1 completado" |
| 8. Pruebas y correcciones | — | Ver la lista siguiente |

Problemas encontrados en las pruebas y corregidos:

- La fuente se escalaba ×1,57: se usa ahora su tamaño nativo.
- Phaser invertía el orden de los argumentos en algunos solapamientos: se normaliza por tipo.
- Los cuerpos estáticos perdían su tamaño: se sincronizan antes de ajustarlos.
- El salto variable y el límite de velocidad anulaban los rebotes: ahora no se aplican a los rebotes.
- La bandera "iniciando" del menú sobrevivía entre partidas: se reinicia en cada entrada al menú.
- Se ajustaron distancias de nubes móviles y de la nube elástica para que se puedan superar caminando.
- Se retiró un obstáculo injusto sobre las nubes de vapor.

## 8. Limitaciones conocidas

- **Audio provisional**: todos los efectos y la música son sintetizados. El sistema está listo para archivos reales (sección 4).
- **Mundo 2 no existe todavía**: el portal lleva a la pantalla de victoria, que lo indica ("próximamente").
- Con `?renderer=canvas` no hay tintes: no se ven los enemigos pintados, los destellos de aviso ni el color de la fase 3. En WebGL (lo normal en navegadores) sí.
- La fachada del castillo de la sección E es el sprite de fondo ampliado ×1,6, y se ve algo menos nítido que el resto.
- La textura de relleno del terreno se repite de forma visible en superficies grandes.
- Las animaciones de correr y caer reutilizan fotogramas (sección 4).
