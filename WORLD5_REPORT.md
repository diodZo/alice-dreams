# Informe de implementación — Mundo 5

## Sueños Cósmicos — Islas en el Cielo

El Mundo 5 se implementó como una extensión nativa del motor Godot existente, en la rama `feature/world-5` (creada sobre el trabajo del Mundo 4). Alice, las tres armas, HUD, cámara, checkpoints, guardado, proyectiles, mapa de mundos y arena de jefe son los mismos sistemas de los Mundos 1-4. No hay un controlador nuevo de Alice: el tobogán arcoíris es un estado más de `Player` (`slide_speed`) con valor neutro (0) fuera de los toboganes, como la natación del Mundo 4.

## Etapa 1 — Auditoría

- Se partió del pipeline del Mundo 4 (`tools/world4/`), del motor común `Level` / `LevelBuilder` / `BossArena` y del registro `WorldRegistry` + `Router`.
- Línea base antes de tocar nada: 587 comprobaciones automáticas correctas, 0 fallidas.
- La estructura sugerida (`godot/assets/world5/...`, `scenes/enemies/world5`...) se adaptó a la convención real del repositorio: originales en `imagenes/`, recursos generados en `godot/resources/world5/`, datos en `godot/data/world5/`, herramientas en `tools/world5/`, enemigos en `scenes/enemies/world5/`, jefe en `scenes/bosses/LunaEstelar.tscn`.
- El registro tenía reservado el Mundo 5 como "El Reino de los Juguetes"; se renombró a "Sueños Cósmicos — Islas en el Cielo". El Mundo 6 sigue reservado.

## Etapa 2 — Recursos oficiales

Las cuatro referencias de `imagenes/` (`word_5.png`, `tilesets_world_5.png`, `enemies_world_5.png`, `jefemundo5.png`) se procesan con `tools/world5/prepare_world5_assets.py`. Las cajas de cada sprite están en `tools/world5/world5_sources.json` (editables a mano) y `tools/world5/detect_world5.py` genera hojas de diagnóstico con las cajas detectadas.

- Recorte sin fondo: en la hoja del jefe, alfa ≥ 240 (descarta el halo magenta semitransparente y conserva el aura cósmica); en las demás, fondo pastel conectado al borde. Descarte de rótulos y marcos, reducción con alfa binario y paleta común por personaje. Filtro nearest en todo el proyecto.
- `only` separa dibujos que se tocan: las estelas de estrellas de los disparos del jefe, la media luna de energía del giro lunar y el rayo estelar del Cohetito (se convierten en proyectiles del juego, así el pivote no se desplaza).
- Pivote estable por personaje, por la mancha de color del cuerpo: estrella amarilla (Estrellita), roca oscura (Meteorito, ignora su estela), casco blanco (Cohetito, ignora la llama) y luna amarillo pálido (Luna Estelar, ignora estrellas y nubes). También admite una x fijada a mano por fotograma (`pivot`).
- Estrellita Fugaz: 16 fotogramas (reposo 4, vuelo 4, disparo 2, daño 2, derrota 4). Meteorito Travieso: 17 (reposo 4, rodar 4, embestida 3, daño 2, derrota 4). Cohetito Centinela: 16 (reposo 4, vuelo 4, disparo 2, daño 2, derrota 4). Luna Estelar: 26 (reposo 4, movimiento 6, disparo 4, giro 4, fase cósmica 4, daño 2, derrota 2).
- Teselas: material "cosmic" en bloques de 32×32 a partir de la tesela "suelo superior" (nube, roca y estrella) y de una franja de roca sin estrellas apilada; bordes laterales, base colgante y rampas de 45° generados por el script. Bloques sueltos de estrella y de planeta.
- Objetos (todas las categorías de la hoja de teselas): plataformas de nube, de estrella (sólida y con muelle), de luna creciente, colgante, de cohete y de observatorio; toboganes; islotes colgantes; meteoritos; cohetes móviles; estrellas que caen (4 fotogramas); nubes explosivas; plataforma de lanzamiento; cascadas de luz (2 fotogramas); nubes; observatorios, telescopios, torres, vallas, farolas, estrellas colgantes, globo, esfera armilar y cúpulas; estrellas, fichas de luna, estrella especial, bandera, cartel, portal y mini cohete.
- Efectos: miniestrellas, estelas, cometa, guijarros, estallidos, anillos, rayos estelares, nube de humo, media luna de energía, nubes de la derrota y chispas.
- Fondo: la luna sonriente y el castillo celeste se extraen de `word_5.png` sin el cielo nocturno (y sin las plataformas pintadas de la parte baja); planetas, islas distantes, estelas y niebla salen de la sección "fondos / parallax" de la hoja de teselas. El cielo y los bancos de nubes usan colores muestreados de `word_5.png`.
- Único recurso generado sin recorte directo: la banda del tobogán arcoíris (8×12 px), con los colores muestreados en una columna de los "segmentos de tobogán arcoíris" de la hoja.
- Manifiesto: `godot/data/world5/world5_asset_manifest.json` (192 recursos, ninguno pendiente de revisión; los dos que tocaban el borde de su caja están revisados a mano y anotados).

## Etapa 3 — Mapa

`tools/world5/world5_level.py` genera `world5.json` y `world5_boss.json`.

- Recorrido total: 10.496 px (9.552 px de nivel y 944 px de arena), cinco secciones en 0, 2.000, 4.000, 6.200 y 8.500 px.
- A — El observatorio de las nubes: observatorio y telescopio de salida, nubes, estrella sólida, trampolín de estrella hacia una nube alta (ficha de luna 1), rampa y las primeras Estrellitas Fugaces.
- B — El camino de la luna: lunas crecientes en curva, luna móvil, primer Cohetito, primer checkpoint, cascada de luz que sube a un acantilado, luna en órbita (ficha de luna 2), plataforma colgante y Cohetito con patrulla vertical.
- C — Los jardines planetarios: cohete sobre el vacío, dos toboganes arcoíris, grupo de tres Estrellitas, plataforma de lanzamiento a una ruta alta opcional con la estrella especial, trampolín, Cohetitos y cohete ascensor.
- D — La lluvia de meteoros: rampas, Meteoritos, estrellas que caen, nubes explosivas, segundo checkpoint, islas partidas flotantes con trampolín a la ficha de luna 3, cohete entre islas, pendiente y luna en órbita con el mini cohete dorado.
- E — El trono de la Luna: gran isla con el palacio lunar (torres, observatorios y telescopio), cascada de luz a una isla alta (fragmento de constelación) y el portal a la arena.
- 240 estrellas, 30 enemigos (13 Estrellitas, 9 Meteoritos, 8 Cohetitos) con activación por proximidad, 2 checkpoints, 13 carteles.
- Colisiones reales del TileSet: cuadradas para el terreno y triangulares para las rampas. Ninguna colisión sale de la ilustración.
- Capas: 1 cielo estrellado (fijo), 2 planetas y constelaciones lejanas, 3 luna con castillo e islas distantes, planetas cercanos y niebla, 4 terreno y plataformas, 5 decoración delantera (sólo piezas pequeñas y bajas), 6 Alice, enemigos, proyectiles y jefe, 7 HUD. Las cascadas decorativas van tenues y detrás del terreno.

## Etapa 4 — Enemigos

Escenas en `godot/scenes/enemies/world5/`, comportamiento en `godot/scripts/ai/` sobre la clase `Enemy` existente (vida, burbuja, pintura, patrulla, aviso "!").

- Estrellita Fugaz (2 HP): vuela rápido por su ruta con una onda regular dejando una estela de chispas; en grupo, cada una lleva un desfase de onda. Se encoge y brilla como aviso y lanza una miniestrella lenta dirigida.
- Meteorito Travieso (3 HP): rueda por el suelo y cuesta abajo en las pendientes (más deprisa). Al ver a Alice a su altura tiembla (aviso) y embiste en línea recta; frena en los bordes y contra los muros. Al ser derrotado se parte en fragmentos (sólo efecto).
- Cohetito Centinela (3 HP): patrulla en horizontal o en vertical (`axis: "v"`); al detectar a Alice se detiene, enciende el motor como aviso y dispara un rayo estelar recto.
- Los tres responden a las tres armas: burbuja (atrapa y convierte en estrella), pintura y tirachinas.

## Etapa 5 — Mecánicas espaciales

- Plataformas de estrella: sólidas (unidireccionales) y trampolines suaves (estrella con muelle); la plataforma de lanzamiento lanza mucho más alto. Se distinguen a simple vista por el muelle y los anillos.
- Lunas crecientes: estáticas en curva, móvil (`MovingPlatform`) y en órbita elíptica (`OrbitPlatform`, ruta curva).
- Toboganes arcoíris (`RainbowSlide`): rampa unidireccional; mientras se pisa, Alice se desliza a ~190 px/s y las flechas aceleran o frenan un poco sin pararla ni hacerla subir.
- Cohetes móviles (`RocketPlatform`): patrullan de lado a lado (miran hacia donde avanzan) o hacen de ascensor, con llama encendida y trayectoria suavizada estable.
- Estrellas que caen (`FallingStar`): ciclo fijo aviso (1 s: destello creciente en el suelo y la estrella titila arriba) → caída (sólo daña mientras cae) → impacto. Apartarse una tesela basta.
- Nubes explosivas (`ExplosiveCloud`): al tocarlas se hinchan y destellan 0,65 s y estallan en luz y nube (un corazón si Alice sigue cerca); un disparo de cualquier arma las hace estallar al momento. Se vuelven a formar a los 3,2 s.
- Cascadas de luz (`LightFall`): las que funcionan son corrientes ascendentes a plena luz, con chispas doradas que suben y una estrella en la base; las decorativas son tenues, están al fondo y no empujan.
- Ajustes de diseño tras el piloto automático: ningún enemigo ni obstáculo que empuje está en una isla estrecha junto al vacío ni puede disparar a Alice mientras va en un cohete sobre el vacío (el retroceso del golpe la tiraba); la isla tras el primer cohete empieza donde acaba su recorrido y el hueco de la estrella sólida se redujo a 3 teselas.

## Etapa 6 — Luna Estelar

Escena `godot/scenes/bosses/LunaEstelar.tscn` con la misma interfaz que los jefes anteriores, en la arena común `BossArena`.

- 50 HP; fases al 65 % y al 30 %, con un instante invulnerable de transición. Flota sobre el suelo con cuatro estrellitas que orbitan siempre a su alrededor (más rápido en cada fase).
- Fase 1, Destellos nocturnos: estrellitas dirigidas, movimiento lateral suave y embestidas estelares breves con estela de cometa.
- Fase 2, Órbita celestial: giro lunar con medias lunas de energía a ras de suelo, seis estrellas en órbita que después salen disparadas hacia fuera, ondas cósmicas por el suelo y más movilidad.
- Fase 3, Tormenta de constelaciones: aura cósmica con anillo de doce estrellas y hueco seguro, lluvia de estrellas con columnas marcadas y tres libres, giro con dos anillos de energía alternados y abanicos de cinco estrellas.
- Todos los ataques tienen anticipación ("!", destello y pose previa) y terminan en un descanso vulnerable.
- Derrota sin violencia: pierde energía, sus estrellas giran cada vez más lento, la expresión se suaviza, se recuesta entre nubes, destellos y partículas, queda dormida ("Z z z") y entrega la estrella dorada; después se abre el portal.

## Etapa 7 — HUD, progresión, música y guardado

- Registrado en `WorldRegistry` (implementado) y `Router` (`World5`, `Boss5`). Se abre desde el mapa de mundos al completar el Mundo 4 (la victoria del Mundo 4 ofrece ahora "Ir al Mundo 5").
- Coleccionables: estrellas normales y seis tesoros. Las 3 fichas de luna principales salen en el HUD y dan una estrella extra al reunirlas; además hay una estrella especial, un fragmento de constelación y un mini cohete dorado.
- Al cruzar el portal se guardan estrellas, estrella dorada, tiempo y tesoros, y se desbloquea el Mundo 6. Como el Mundo 6 aún no existe, la pantalla de victoria ofrece "Jugar otra vez" y "Menú principal" e indica "Portal al Mundo 6: preparado (próximamente)"; no se intenta cargar ninguna escena inexistente.
- Música chiptune provisional sintetizada para `world5`, `luna_estelar` y `world5_victory`, y efectos nuevos de estrella que cae, cohete y nube que estalla. Si se copian `world5_theme.ogg`, `luna_estelar_boss.ogg` o `world5_victory.ogg` en `godot/resources/audio/`, se usan automáticamente; si no existen, no hay errores.

## Cambios en sistemas compartidos (todos neutros para los Mundos 1-4)

- `Player`: `slide_speed` (0 = sin tobogán).
- `Level`: los enemigos reciben las opciones extra de sus datos (eje de patrulla, desfase de grupo...); efectos de impacto de los proyectiles nuevos.
- `Projectile`: los disparos de Alice también reaccionan a áreas "shootable" (nubes explosivas).
- `LevelBuilder`: crea los objetos nuevos si los datos los traen; la decoración admite `alpha`, `scale` y `flip`.
- `DreamCollectible`: tipos nuevos y tinte opcional.
- Piloto automático: reconoce plataformas que suben y bajan (espera a que lleguen), salta a salientes hasta dos teselas más altos desde una plataforma móvil y registra dónde se producen los golpes (`hits`).

## Etapa 8 — Validación

- Importación de Godot 4.7.2 y generación de SpriteFrames, TileSet y EnemyDef: 0 errores.
- `CheckAll` (todos los scripts, escenas y recursos): 0 fallos.
- Pruebas automáticas: 770 comprobaciones correctas, 0 fallidas. Las de los Mundos 1-4 siguen pasando; dos se actualizaron porque su comportamiento cambia a propósito (la progresión del Mundo 4 ahora lleva a un Mundo 5 jugable, y en el mapa «Próximamente» se comprueba en el Mundo 6). Las nuevas del Mundo 5 cubren datos, sprites, autotiling y colisiones, rampas, plataformas especiales, toboganes, cascadas de luz, estrellas que caen, nubes explosivas, los tres enemigos, las tres armas, las tres fases del jefe con anticipación y descanso, la derrota completa, el portal, el guardado y la progresión.
- Piloto automático con los controles normales: los Mundos 1-5 llegan a la puerta del jefe. El Mundo 5 sin invulnerabilidad tarda 77 s con 3 golpes y ninguna caída.
- Revisión visual con render real: salida, trampolín, lunas, cascada de luz, cohetes, toboganes, ruta alta, lluvia de meteoros, nubes explosivas, palacio lunar, las tres fases de la arena y la pantalla de victoria.

Ajustes que salieron de esta etapa: la banda del tobogán se veía como una línea de puntos porque `Line2D` no recorta las `AtlasTexture` (ahora usa una textura propia); el Meteorito se paraba en lo alto de las bajadas (ahora reconoce el suelo de una rampa); además los cambios de diseño de la etapa 5.

Pendiente fuera de este trabajo: la ilustración del mapa de mundos (`imagenes/mapa_mundos.png`) tiene pintado «Juguetes» en la isla 5. La barra inferior del mapa ya dice «Mundo 5: Sueños Cósmicos», pero el rótulo pintado sólo se corrige editando la ilustración.

Las pruebas y el piloto confirman que el recorrido y el combate se pueden completar, pero no sustituyen una sesión manual de juego con teclado o mando.

## Regeneración

```powershell
python tools/world5/prepare_world5_assets.py --debug
python tools/world5/world5_level.py
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tools/build_resources.gd
```

El proyecto se abre desde `godot/project.godot`.
