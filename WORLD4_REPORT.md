# Informe de implementación — Mundo 4

## Reino de las Burbujas

El Mundo 4 se implementó como una extensión nativa del motor Godot existente, en la rama `feature/world-4`. Alice, las tres armas, HUD, cámara, checkpoints, guardado, proyectiles, mapa de mundos y arena de jefe son los mismos sistemas de los Mundos 1-3. No hay un controlador nuevo de Alice: la natación es un estado más de `Player` con valores neutros fuera del agua.

## Etapa 1 — Auditoría

- Se partió del pipeline del Mundo 3 (`tools/world3/`), del motor común `Level` / `LevelBuilder` / `BossArena` y del registro `WorldRegistry` + `Router`.
- Línea base antes de tocar nada: 412 comprobaciones automáticas correctas, 0 fallidas.
- La estructura sugerida (`godot/assets/world4/...`, `scenes/enemies/world4`...) se adaptó a la convención real del repositorio: originales en `imagenes/`, recursos generados en `godot/resources/world4/`, datos en `godot/data/world4/`, herramientas en `tools/world4/`.

## Etapa 2 — Recursos oficiales

Las cuatro referencias de `imagenes/` (`word_4.png`, `tilesets_world_4.png`, `enemies_world_4.png`, `jefemundo4.png`) se procesan con `tools/world4/prepare_world4_assets.py`. Las cajas de cada sprite están en `tools/world4/world4_sources.json` (editables a mano) y `tools/world4/detect_world4.py` genera hojas de diagnóstico con las cajas detectadas.

- Recorte sin fondo (alfa en la hoja del jefe; fondo pastel conectado al borde en las demás), descarte de etiquetas y marcos, reducción con alfa binario y paleta común por personaje. Filtro nearest en todo el proyecto (sin suavizado).
- `only` (rectángulos o polígonos) separa dibujos que se tocan: los cepillos solapados, las flechas de los rodillos y los chorros de burbujas del jefe, que se cortan en el pico para que el pivote no se desplace.
- Pivote estable por personaje: pies (cangrejito), centro del dibujo (pez, pompa) o centro del cuerpo amarillo (Rey Patoburbuja, ignora olas y remolinos).
- Pez Burbuja: 10 fotogramas. Cangrejito Esponja: 9. Pompa Traviesa: 9. Rey Patoburbuja: 27 (reposo 4, desplazamiento 6, escupir 4, ola 4, remolino 4, daño 2, derrota 3).
- Teselas: dos materiales (esponja y azulejo) en bloques de 32×32 a partir del bloque base y el bloque con espuma; bordes laterales, base y rampas de 45° generados por el script. Bloques sueltos de esponja, cristal y azulejo.
- Objetos, efectos y fondo: plataformas de burbuja, espuma, barquito, esponja y azulejo; agua (superficie y submarina, 3 fotogramas cada una), columnas de burbujas, burbujas de salto, salpicaduras, géiser (5 fotogramas), jabones, rodillos, espuma resbaladiza, coleccionables, decoración y la franja alta de `word_4.png` como capa lejana.
- Único recurso generado sin recorte directo: el remolino del jefe (la hoja no lo trae suelto), pintado con los azules y blancos del agua de `jefemundo4.png`. El cielo y los bancos de espuma usan colores muestreados de `word_4.png`.
- Manifiesto: `godot/data/world4/world4_asset_manifest.json` (151 recursos, ninguno pendiente de revisión).

## Etapa 3 — Mapa

`tools/world4/world4_level.py` genera `world4.json` y `world4_boss.json`.

- Recorrido total: 10.000 px (9.040 px de nivel y 960 px de arena), cinco secciones en 0, 1.800, 3.600, 5.600 y 7.900 px.
- A — Las bañeras de espuma: azulejos, esponja, rampa, primeras plataformas de burbuja, agua poco honda y el primer Pez Burbuja.
- B — Los jardines del jabón: espuma resbaladiza, dos géiseres, jabón móvil, jabón deslizante, foso de plataformas de esponja, primer Cangrejito y primer checkpoint.
- C — El canal de los patitos: canal con dos barquitos, patitos, isla con columna de burbujas hacia una ruta alta opcional, ascensor de burbuja, burbujas frágiles y las primeras Pompas.
- D — Las cataratas de burbujas: columna gigante sobre el vacío, rodillos de esponja, tramo submarino de 9 teselas con géiser sumergido, los tres enemigos y segundo checkpoint.
- E — El trono de Patoburbuja: gran bañera real con espuma, burbuja de salto y la entrada (portal) a la arena.
- 197 estrellas, 22 enemigos con activación por proximidad, 2 checkpoints.
- Colisiones reales del TileSet: cuadradas para el terreno y triangulares para las rampas. Ninguna colisión sale de la ilustración.
- Parallax en capas: cielo y burbujas lejanas, ciudad acuática con el gran pato, cascadas a media distancia, burbujas grandes, terreno, decoración delantera (pequeña y baja para no tapar a Alice), personajes y HUD.

## Etapa 4 — Enemigos

Escenas en `godot/scenes/enemies/world4/`, comportamiento en `godot/scripts/ai/` sobre la clase `Enemy` existente (vida, burbuja, pintura, patrulla, aviso "!").

- Pez Burbuja (2 HP): nada en horizontal sin caer, rodeado de burbujitas; infla las mejillas como aviso y lanza una burbuja lenta.
- Cangrejito Esponja (3 HP): vigila el suelo, avanza a pasitos (anda, espera, anda) y, ya cerca, levanta la pinza y da un pinzazo corto con estela de espuma.
- Pompa Traviesa (2 HP): flota y se acerca despacio; se hincha como aviso y estalla en un abanico de 6 burbujitas lentas, después se aparta y se vuelve a formar.
- Los tres responden a las tres armas: burbuja (atrapa y convierte en estrella), pintura y tirachinas.

## Etapa 5 — Mecánicas del agua y obstáculos

- Agua (`WaterZone`): menos gravedad, caída lenta, brazadas con el botón de salto y salto fuera del agua al asomar (también a toques). Salpicadura al zambullirse y burbujas que suben. El agua no hace daño y toda balsa tiene salida.
- Géiser de burbujas (`BubbleGeyser`): ciclo fijo burbujea → avisa (vibra y suena) → estalla. Impulsa a Alice, lanza a los monstruos de suelo y desvía los proyectiles enemigos.
- Columnas de burbujas (`BubbleColumn`): corriente ascendente constante con la animación oficial.
- Plataformas de burbuja: estáticas, oscilantes, móviles y frágiles (revientan 0,5 s después de pisarlas, con temblor de aviso, y se vuelven a inflar).
- Espuma resbaladiza: menos fricción mientras se pisa; Alice sigue al mando.
- Jabones móviles: plataformas que se deslizan y un jabón deslizante que hace de obstáculo.
- Rodillos de esponja (`SpongeRoller`): van y vienen con pausa en cada extremo; empujan sin quitar vida.

## Etapa 6 — Rey Patoburbuja

Escena `godot/scenes/bosses/ReyPatoburbuja.tscn` con la misma interfaz que los jefes anteriores, en la arena común `BossArena`.

- 50 HP; fases al 65 % y al 30 %, con un instante invulnerable de transición.
- Fase 1, Burbujas reales: burbujas en línea recta, golpes de agua suaves, flota despacio.
- Fase 2, Oleaje juguetón: burbujas grandes en arco, olas pequeñas, remolinos pequeños, más movilidad.
- Fase 3, Tormenta de espuma: remolino amplio que cruza la arena, lluvia de burbujas con huecos marcados y ataques encadenados.
- Todos los ataques tienen anticipación ("!", destello y pose previa) y terminan en un descanso vulnerable.
- Derrota sin violencia: se marea, la corona se ladea, flota despacio, se hunde un poco entre la espuma, salen estrellas y burbujas, queda dormido y entrega la estrella dorada; después se abre el portal.

## Etapa 7 — HUD, progresión, música y guardado

- Registrado en `WorldRegistry` (implementado) y `Router` (`World4`, `Boss4`). Se abre desde el mapa de mundos al completar el Mundo 3.
- Coleccionables: estrellas normales y seis tesoros. Las 3 conchas token principales salen en el HUD y dan una estrella extra al reunirlas; además hay una estrella marina mágica, una burbuja arcoíris y un patito real. El HUD y el motor leen el tipo principal de los datos de cada mundo (el Mundo 3 sigue con sus lunas).
- Al cruzar el portal se guardan estrellas, estrella dorada, tiempo y tesoros, y se desbloquea el Mundo 5. Como el Mundo 5 aún no existe, la pantalla de victoria ofrece "Jugar otra vez" y "Menú principal" e indica "Portal al Mundo 5: preparado (próximamente)"; no se intenta cargar ninguna escena inexistente.
- Música chiptune provisional sintetizada para `world4`, `patoburbuja` y `world4_victory`, y efectos nuevos de brazada y chapuzón. Si se copian `world4_theme.ogg`, `rey_patoburbuja_boss.ogg` o `world4_victory.ogg` en `godot/resources/audio/`, se usan automáticamente; si no existen, no hay errores.

## Etapa 8 — Validación

- Importación de Godot 4.7.2 y generación de SpriteFrames, TileSet y EnemyDef: 0 errores.
- `CheckAll` (todos los scripts, escenas y recursos): 0 fallos.
- Pruebas automáticas: 587 comprobaciones correctas, 0 fallidas (las 412 previas de los Mundos 1-3 siguen intactas; 175 nuevas del Mundo 4: datos, sprites, autotiling, rampas, agua, géiseres, columnas, obstáculos, enemigos, armas, las tres fases del jefe, derrota, portal, guardado y progresión).
- Piloto automático con los controles normales: los Mundos 1, 2, 3 y 4 llegan a la puerta del jefe; el Mundo 4 también sin invulnerabilidad (3 golpes recibidos).
- Revisión visual con render OpenGL real: salida, balsa, géiser, canal, cascada, tramo submarino, trono, arena del jefe y pantalla de victoria.

Ajustes que salieron de esta etapa: el salto fuera del agua ya no se corta al soltar el botón (a toques no se podía salir); al asomar del agua se concede el mismo margen de salto que al dejar el suelo; el primer géiser y el ascensor de burbuja se pegaron a su muro (se podía quedar justo al lado sin activarlos); las cascadas con bloques salieron del primer plano porque se confundían con terreno; la decoración submarina se dibuja delante del agua.

Las pruebas y el piloto confirman que el recorrido y el combate se pueden completar, pero no sustituyen una sesión manual de juego con teclado o mando.

## Regeneración

```powershell
python tools/world4/prepare_world4_assets.py --debug
python tools/world4/world4_level.py
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tools/build_resources.gd
```

El proyecto se abre desde `godot/project.godot`.
