# Mundo 2 — El Reino de los Crayones Encantados

**Rama:** `feature/world-2` (desde `main`, con el Mundo 1 en Godot ya funcionando) · **Motor:** Godot 4.7.2

El Mundo 2 está completo y jugable: cinco secciones (9.000 px), los tres enemigos, puentes de reglas, superficies de pintura, obstáculos, crayones mágicos, dos checkpoints y la batalla contra **Garabato, el Rey de los Crayones**, con victoria, guardado y desbloqueo del Mundo 3. Se reutiliza el motor existente sin reconstruirlo y sin tocar a Alice.

## 1. Auditoría: sistemas reutilizados

| Sistema existente | Uso en el Mundo 2 | Cambio necesario |
|---|---|---|
| `Level` (motor común), `LevelBuilder`, `TileMapLayer` | Construye el Mundo 2 desde `data/world2/world2.json` | Listas de datos nuevas opcionales (`rulers`, `paints`, `rollers`, `bouncers`, `drips`, `rivers`, `magicCrayons`), TileSet por clave, fotogramas sustituibles (`frames`) |
| `Player` / `PlayerAnimator` | La misma Alice, mismas animaciones y controles | Dos multiplicadores de superficie con valor neutro 1 (velocidad y fricción) y la velocidad de aterrizaje, para la pintura |
| `Enemy` (máquina de estados, burbuja, pintura, pisotón) | Base de los tres enemigos nuevos: son compatibles con las tres armas sin tocar sus daños | Ninguno |
| `Projectile` + `WeaponManager` | Proyectiles de enemigos y jefe | Texturas de cualquier atlas (antes sólo `fx`) |
| `EnemySpawner`, `CheckpointManager`, `Star`, `CloudPlatform`, `MovingPlatform`, `CrumblePlatform`, `Hazard`, `SignPost`, `Checkpoint` | Igual que en el Mundo 1, con gráficos del Mundo 2 | Parámetros opcionales: fotograma de bandera/cartel/estrella y altura de la superficie pisable |
| Arena del jefe (`boss_arena.gd`) | Arena del Gran Lienzo | Jefe, textos, música y mundo guardado salen de los datos (valores por defecto = Mundo 1). Encuadre opcional jugadora + jefe |
| `ParallaxBackground2` | Fondo del Mundo 2 | Fondo descrito por datos (`background`) |
| HUD, menús, pausa, victoria, `SaveManager`, `AudioManager`, `WorldRegistry`, `Router` | Todo compartido | Nombre del jefe en la barra, casillas de crayones mágicos, selección de mundo en el menú, victoria por mundo, crayones mágicos en el guardado, música nueva |

Regresión: el Mundo 1 conserva su comportamiento. Sus pruebas siguen pasando y su piloto automático sigue llegando al castillo.

## 2. Recursos: extracción verificable

Pipeline reproducible (Python + Pillow + NumPy + SciPy):

```bat
python tools/world2/prepare_world2_assets.py --debug   REM recortes -> godot/resources/world2, godot/data/world2
godot --headless --path godot --import
godot --headless --path godot --script res://tools/build_resources.gd   REM SpriteFrames, TileSet, EnemyDef
```

- **Configuración editable**: `tools/world2/world2_sources.json`. Contiene la caja de cada fotograma u objeto, la escala, el modo de fondo, el número de colores, las animaciones con su fps y bucle, y las correcciones manuales con su motivo (`reviewed`).
- **Detección de regiones**: componentes conectados con alfa ≥ 240 dentro de cada panel. Así se descartan títulos, etiquetas, marcos y el halo de color.
- **Fondo**: en la hoja de teselas sólo se elimina el fondo crema conectado con el borde del recorte. Los blancos, rosas y azules interiores no se tocan.
- **Efectos**: la isla principal se separa de los efectos sueltos (polvo, estrellitas, gotas).
- **Reducción**: alfa premultiplicado, alfa binario, paleta por personaje y refuerzo de contorno. Son las mismas funciones que el pipeline del Mundo 1.
- **Normalización**: celda común por personaje, alineada por los pies. El punto de apoyo es idéntico en todos los fotogramas y lo comprueba una prueba.
- **Manifiesto**: `godot/data/world2/world2_asset_manifest.json`, con 167 recursos. Cada uno registra archivo de origen, caja, recorte real, animación, índice, duración, offset, origen, estado y notas.
  - **0 pendientes.**
  - Los 23 recortes que tocan su caja se revisaron a mano en `tools/out/world2/debug_*.png`, y su motivo queda anotado: chorros de pintura separados como efecto, estrellitas excluidas, crayones de una fila unida, etc.

### Fotogramas reales encontrados (comprobados en las imágenes)

| Personaje | Animaciones | Diferencia con las etiquetas de la hoja |
|---|---|---|
| Borrador saltarín (celda 52×24) | idle 4, mover 4, salto 2, ataque 3, daño 2, derrotado **2** | La etiqueta dice 3 en «derrotado», pero hay 2 dibujos del borrador; el resto es polvo (efecto `eraser_dust`) |
| Crayón guerrero (66×36) | idle 4, caminar 4, carga 3, ataque 3, daño 2, derrotado 2 | — |
| Pincel travieso (58×30) | idle 4, mover 4, disparo **3**, daño 2, derrotado **1** | La hoja dice 4 y 2: hay 3 pinceles disparando (las gotas sueltas son proyectiles) y 1 pincel tumbado (el charco es efecto) |
| Garabato (152×80) | reposo 3, desplazamiento 6, disparo 4, remolino 4, remolino de crayones 4, aturdido 2, daño 1, derrota 2 = **26** | La hoja no tiene etiquetas: se clasificó por filas y por expresión (ojos en espiral = aturdido, ojos en X = derrota) |

Efectos extraídos: salpicadura grande, gota de pintura, gota pequeña, polvo de borrador, estela de crayón, salpicadura arcoíris, espiral y cinco crayones voladores.
Objetos: 55, entre ellos libros, nubes, crayones, cuaderno, lápiz, reglas (tramo, poste, extremo y bisagra), pintura azul/amarilla/rosa, decorado, peligros, estrella, crayones mágicos, bandera, carteles y portal.
Fondo: castillo lejano, arcoíris, nubes, estrellas colgantes, garabatos y hojas de cuaderno.
Teselas 16×16: terreno de hierba y tierra, más 9 bloques (A, B, C, estrella, corazón, color y tres de cuaderno).

## 3. Escenario y capas

| Capa | Contenido | Origen |
|---|---|---|
| 1 | Cielo azul (degradado con los colores muestreados de `word_2.png`), brillos | Generado con la paleta de la referencia |
| 2 | Castillo de fantasía lejano, arcoíris | `tilesets_world_2.png` (fondo) |
| 3 | Nubes sonrientes, hojas de cuaderno, garabatos, estrellas colgantes, bancos de nubes | `tilesets_world_2.png` + nubes generadas con la paleta |
| 4 | Terreno (TileMapLayer con colisión), reglas, libros, cuadernos, nubes, crayones, bloques ABC | `tilesets_world_2.png` |
| 5 | Decorado de primer plano (flores) | `tilesets_world_2.png` |
| 6 | Alice, enemigos, obstáculos, proyectiles | hojas oficiales |
| 7 | HUD | existente |

`word_2.png` se usa como referencia de composición y de paleta, **no** como mapa estático. Ninguna capa se recorta de ella: la ilustración no permite separar capas limpias (los elementos se solapan). Esas capas se construyeron con los recursos equivalentes de la hoja de teselas.

## 4. Diseño del nivel (`tools/world2/world2_level.py`)

474 × 25 teselas (7.584 px) más la arena de 60 teselas, que representa 7.584–9.000 px.

| Sección | Píxeles | Contenido |
|---|---|---|
| A · Escritorio gigante | 0–1.500 | Libros, crayones y bloques ABC; primer Borrador; puente de reglas recto; regla inclinada hasta un escritorio flotante; plataformas de crayones |
| B · Jardín de crayones | 1.500–3.300 | Crayones guerreros; pintura azul resbaladiza; puente dibujado temporal; ruta alta de nubes con el **crayón rojo**; **checkpoint 1**; molinillo que dibuja un puente; puente articulado |
| C · Río de pintura | 3.300–5.200 | Río de pintura; cuaderno móvil; isla de pintura amarilla elástica que lleva a la ruta alta con el **crayón azul**; libro móvil; hojas de cuaderno que se deshacen; Pinceles traviesos; rutas opcionales con estrellas |
| D · Fábrica de dibujos | 5.200–7.300 | Pintura rosa; lápices rodantes; borradores que rebotan; goteos de pintura; los tres enemigos combinados; puente dibujado que los Borradores pueden borrar; **checkpoint 2**; escalera ABC y torre con el **crayón amarillo** |
| E · El Gran Lienzo | 7.300–9.000 | Aproximación y entrada; arena de Garabato |

152 estrellas en el nivel y 10 en la arena, 14 enemigos (4 Borradores, 5 Crayones y 5 Pinceles), 7 puentes de reglas y 6 superficies de pintura.

## 5. Mecánicas (objetos reutilizables en `scripts/objects/`)

| Mecánica | Implementación |
|---|---|
| Puentes de reglas: rectos, inclinados, articulados, activables y temporales | `RulerBridge`: colisión unidireccional que gira con cada tramo; las rampas se suben caminando. `drawn` (los Borradores lo borran 3,2 s), `cycle` (aparece y desaparece y parpadea antes de irse), `switch` (lo dibuja `BridgeSwitch`) |
| Pintura azul / amarilla / rosa | `PaintSurface`: fricción ×0,22, rebote −470 (−555 con salto mantenido) y velocidad ×0,5. El efecto se aplica sólo mientras se pisa y se restaura al salir. Garabato las crea temporalmente |
| Lápices rodantes | `RollingPencil` |
| Borradores que rebotan | `BouncingEraser` (obstáculo, distinto del enemigo) |
| Pintura que gotea | `PaintDrip`: se estira 400 ms antes de soltar la gota |
| Salpicaduras | `Hazard` existente con gráficos de pintura |
| Plataformas temporales | `CrumblePlatform` existente con hojas de cuaderno |
| Ríos de pintura | Decorado animado; caer sigue siendo caer al vacío |
| Crayones mágicos rojo, azul y amarillo | `MagicCrayon`: aparecen en el HUD, en la pantalla de victoria y en el guardado |

## 6. Enemigos

| Enemigo | Comportamiento |
|---|---|
| Borrador saltarín (`eraser_monster.gd`) | Patrulla y se aplasta como aviso (450 ms). Salta hacia Alice con una parábola calculada y, al caer, embiste deslizándose. Al aterrizar borra los puentes dibujados cercanos |
| Crayón guerrero (`crayon_monster.gd`) | Camina, detecta y carga con aviso (520 ms). Embiste a 210 px/s con estela de crayón y se recupera antes de repetir |
| Pincel travieso (`brush_monster.gd`) | Mantiene 80–160 px de distancia y se aparta si Alice se acerca. Dispara pintura rosa alternando dos disparos sueltos y una ráfaga de tres |

Los tres extienden `Enemy`. Burbuja, pintura, tirachinas y pisotón funcionan con ellos sin cambiar daños ni propiedades globales.

## 7. Garabato (`scripts/entities/garabato.gd`, `scenes/bosses/Garabato.tscn`)

48 puntos de vida; Nubarrón tiene 40. Camina por el suelo de la arena.

| Fase | Ataques |
|---|---|
| 1 · Lluvia de colores (100–65 %) | Disparos de pintura arcoíris en parábola (fotogramas de disparo) y salpicadura rasante que se salta; vaivén lento |
| 2 · Remolino de crayones (65–30 %) | Remolinos a dos alturas, uno de ellos ondulado (fotogramas de remolino); crayones orbitando mientras avanza más rápido (fotogramas de remolino de crayones) |
| 3 · El Gran Garabato (30–0 %) | Lluvia de crayones con marcas y huecos seguros; remolinos grandes en abanico y ráfaga; charcos temporales de pintura rosa y azul en el suelo; combina los ataques anteriores |

- Todos los ataques tienen aviso (anillo y «!») y, tras cada uno, una ventana de descanso para contraatacar.
- Cada cambio de fase es invulnerable 1,2 s, con sacudida de cámara y mensaje.
- **Derrota**: aturdido (ojos en espiral) → daño → derrota (ojos en X). Los crayones saltan de la caja y caen alrededor, aparecen confeti y estrellas de colores, y el mensaje «¡Los colores mágicos vuelven al lienzo!». Después **se transforma en amigo** (ver abajo) y, sólo entonces, aparecen la estrella especial y el portal al Mundo 3.
- **Transformación en amigo** (hoja nueva `imagenes/jefemundo2.png`; la antigua, de la que salen los sprites de combate, queda como `jefemundo2old.png`): al terminar la animación de derrota y tras un instante con los ojos en X, Garabato cambia a la hoja `garabato_friend` (transformación 6, amigo en reposo 4, caminar 6, celebrar 6; celda 116×78 alineada por los pies, sin cambio de tamaño ni de posición) y se transforma con destellos. Ya amigo, celebra con corazones, camina hasta Alice y la espera a su lado, y vuelve a celebrar cuando ella entra en el portal. Sin colisión: ni hace daño ni recibe disparos. Estados `TRANSFORMING` y `FRIEND` en la misma máquina de estados; cada paso empieza con `animation_finished`. La hoja nueva no tiene transparencia útil y sus fotogramas se tocan: el modo `panel` de `prepare_world2_assets.py` quita el fondo de cada panel y la sombra del suelo, corta por la columna con menos dibujo y separa los trozos del vecino (`split_px`). Pruebas `test_w2_boss_friend` y `test_w2_sprites`.
- Al cruzar el portal se guarda el Mundo 2 como completado, con estrellas, estrella especial, tiempo y crayones; se desbloquea el Mundo 3 y se muestra la pantalla de victoria propia del mundo.
- La cámara encuadra a la vez a Alice y al jefe, porque la arena mide dos pantallas.

## 8. Música

Integrada en el sistema actual, igual que la del Mundo 1:
- Hay tres pistas **sintetizadas provisionales** de estilo NES (pulso y triángulo): `world2` (Do mayor, 138 bpm), `garabato` (Mi menor, 160 bpm) y `world2_victory` (fanfarria).
- Si se copian `world2_theme.ogg`, `garabato_boss.ogg` o `world2_victory.ogg` a `godot/resources/audio/`, se usan en su lugar (`AudioConfig.OPTIONAL_MUSIC`).
- Si no existen, no se intenta cargarlos: no hay referencias rotas ni avisos.

## 9. Validación realizada

| Comprobación | Resultado |
|---|---|
| Carga de todos los scripts, escenas y recursos (`tests/CheckAll.tscn`) | 0 fallos |
| Pruebas automáticas, Mundo 1 + Mundo 2 (`tests/Tests.tscn`) | **321 comprobaciones correctas, 0 fallidas** |
| Integridad de los PNG, número de fotogramas, celda común, línea de apoyo idéntica y ausencia de recortes en cada fotograma | Correcto (dentro de las pruebas) |
| Recorrido completo del Mundo 2 con los controles normales (`Autopilot -- world=2 godmode`) | **Llega a la puerta del Gran Lienzo** desde el inicio (111 s de juego) |
| Regresión del Mundo 1: pruebas + piloto (`world=1`) | Pasan / llega al castillo |
| Revisión visual con capturas reales (GPU) | Secciones A, B, D, E, menú, victoria, combate en fases 1 y 3 y secuencia de derrota |
| Exportación a Windows | `AliceDreams.exe` generado y arranca sin errores |

`godmode` desactiva sólo el daño de enemigos y peligros (las caídas cuentan): comprueba que el recorrido es físicamente posible. El combate se comprueba en las pruebas unitarias.

## 10. Pendiente o no verificable aquí

- **No he jugado el Mundo 2 a mano.** La dificultad, el ritmo y la sensación de las superficies de pintura los tiene que valorar una persona.
- En la prueba del jefe, los golpes se aplican directamente en cada descanso; acertar con disparos apuntados no lo ha probado una persona.
- Faltan capturas de las secciones C (río) y el detalle de B: las vi en el recorrido del piloto pero no las capturé.
- Las pistas de música son provisionales y no las he escuchado. Faltan los archivos `.ogg` definitivos.
- La textura de tierra 16×16 se repite de forma visible en superficies grandes (igual que en el Mundo 1).
- Las animaciones de **salto** y **caída** del Pincel y del Crayón no existen en la hoja: usan `idle`/`walk` mientras están en el aire.
