# Informe de implementación — Mundo 7

## El Valle de Caramelo

El Mundo 7 se implementó como una extensión nativa del motor Godot existente, en la rama `feature/world-7`, creada sobre `feature/world-carousel` (la versión más reciente con el Mundo 6, el carrusel del menú y la numeración de los Mundos 5 y 6 según la ilustración). Alice, las tres armas, HUD, cámara, checkpoints, guardado, proyectiles, carrusel de mundos y arena de jefe son los mismos sistemas de los Mundos 1-6. No hay un controlador nuevo de Alice: el caramelo y el chocolate son dos superficies más de `PaintSurface` (fricción y velocidad) y las correas usan la velocidad de plataforma de Godot.

## Etapa 1 — Auditoría

- Se partió del pipeline del Mundo 6 (`tools/world6/`), del motor común `Level` / `LevelBuilder` / `BossArena`, del registro `WorldRegistry` + `Router` y del carrusel del menú (`WorldCarousel` / `WorldData`).
- Línea base antes de tocar nada: 1013 comprobaciones automáticas correctas, 0 fallidas.
- Las cuatro referencias están en `imagenes/` con los nombres `word_7.png`, `tilesets_world_7.png`, `enemies_world_7.png` y `jefemundo7.png` (sin el sufijo `(1)` del encargo; se usaron esos nombres reales).
- La estructura sugerida (`godot/assets/world7/...`) se adaptó a la convención real del repositorio: originales en `imagenes/`, recursos generados en `godot/resources/world7/`, datos en `godot/data/world7/`, herramientas en `tools/world7/`, enemigos en `scenes/enemies/world7/`, jefe en `scenes/bosses/DonChupeton.tscn`.
- El registro tenía reservado el Mundo 7 ("El Bosque de Caramelos", sin escena); ahora es "El Valle de Caramelo" y está implementado. La isla del carrusel conserva su rótulo de la ilustración ("Bosque de Caramelos"). El Mundo 8 sigue reservado.
- Requisito de herramientas: el pipeline necesita SciPy (`python -m pip install --user scipy`), que no estaba instalado en este equipo.

## Etapa 2 — Recursos oficiales

Las cuatro referencias se procesan con `tools/world7/prepare_world7_assets.py` (copia adaptada del pipeline del Mundo 6). Las cajas de cada sprite están en `tools/world7/world7_sources.json` (editables a mano) y `tools/world7/detect_world7.py` genera hojas de diagnóstico con las cajas detectadas por paneles.

- Recorte sin fondo: en la hoja del jefe (que trae alfa), alfa ≥ 240, que descarta el halo rojo semitransparente; en las demás, fondo pastel conectado al borde del recorte. Los rótulos y los retratos grandes de presentación quedan fuera de las cajas. Reducción con alfa binario, paleta común por personaje y refuerzo del contorno; filtro nearest en todo el proyecto.
- Novedades del pipeline: escala propia por cuadro (`scale` en la caja: los cuadros de daño y derrota están dibujados más grandes en la hoja) y modo `sky`, que descarta el cielo en degradado azul de `word_7.png` para extraer el castillo de dulces.
- `only` separa lo que se toca: los caramelos que dispara Cuppy, la estela de caramelos de la Piruleta, los chorros de glaseado y la boca del jefe (el chorro se convierte en proyectil del juego), y las gelatinas, gomitas y piezas de los paneles compartidos.
- Cuppy Dulzón: 14 cuadros (reposo 3, rodar 3, salto 2, ataque 2 —preparación con la piruleta en alto y disparo—, daño 2, derrota 1).
- Gomilito Saltarín: 12 cuadros (reposo 2, salto 2, saltitos 2, ataque 2, división 2, daño 1, derrota 1) y cuatro gomitas pequeñas de colores (rosa, azul, amarilla y verde) para la división.
- Piruleta Voladora: 7 cuadros (reposo 1, vuelo 2, ataque 1, disparo 1, daño 1, derrota 1).
- Don Chupetón: 26 cuadros (reposo 4, movimiento 6, ataque de caramelos 3, ataque de glaseado 3, giro 4, daño 3, aturdido 1, derrota 2). Los nombres siguen los cuadros disponibles: `idle`, `move`, `candy_attack`, `frosting_attack`, `spin_attack`, `hurt`, `stunned`, `defeated`.
- Cuadros reutilizados (marcados `reused` en el manifiesto): Gomilito `walk` 1 = `idle` 0 y `attack` = `jump`; Piruleta `fly` 0 = `idle` 0; Don Chupetón `hurt` 2 = cuadro de daño de la fila de derrota.
- Teselas: material "frosting" (tierra de chocolate de "tiles centrales" con la cobertura de glaseado rosa de "tiles superiores") y "caramel" (con caramelo dorado), en bloques de 32×32; bordes, base colgante y rampas de 45° generados por el script; bloques sueltos de galleta y de premio.
- Objetos: plataformas de galleta, caramelo (bastones), nube de crema (malvavisco), gelatina, especiales (cupcake, chocolate con caramelo), puentes de pastel y de cuerda, láminas de caramelo, plataformas con pinchos, piruletas giratorias, correa de chocolate, bloques de galleta y de premio, chorros de caramelo y de chocolate, gelatinas que caen, lanzadores de caramelos, postes de bastón, gomas elásticas, confites, superficies de caramelo y de chocolate; árboles de algodón de azúcar, dulces gigantes, pastelillos, setas, arbustos, vallas, cascadas; estrellas, caramelos especiales, cereza dorada, trozo de pastel, corazón, portal, checkpoint y carteles.
- Efectos y proyectiles: caramelos de Cuppy, de la Piruleta y del jefe, caramelos envueltos, gotas y chorro de glaseado, piruleta lanzada, bola del lanzador, estrella y corazón.
- Fondo (seis capas): cielo pastel y bancos de nubes rosadas y lilas generados con colores muestreados de `word_7.png`; castillo de dulces sobre su colina recortado de `word_7.png`; dulces gigantes, árboles de algodón, setas, colinas de gomitas y cascadas de chocolate de las hojas de teselas.
- Manifiesto: `godot/data/world7/world7_asset_manifest.json` (171 recursos, ninguno pendiente; el único que tocaba el borde de su caja, una gota de glaseado, está revisado a mano y anotado).
- Discrepancia en las referencias: `tilesets_world_7.png` incluye un panel "5. Enemigos del Mundo 7" con otros personajes y nombres (Pastelito Travieso, Gomita Saltarina, Bombón Alado). No se usa: los enemigos oficiales son los de `enemies_world_7.png` (Cuppy Dulzón, Gomilito Saltarín, Piruleta Voladora).

## Etapa 3 — Terreno y nivel

`tools/world7/world7_level.py` genera `world7.json` y `world7_boss.json`.

- Recorrido total: 11.504 px (10.496 px de nivel y 1.008 px de arena), cinco secciones en 0, 2.000, 4.200, 6.500 y 9.000 px.
- A — Jardines de Algodón de Azúcar: árboles rosados, piruletas, setas y vallas; plataformas de galleta y malvavisco; la primera gelatina elástica sobre un hueco; goma elástica hacia una cornisa (caramelo especial 1); bloques de premio; los dos primeros Gomilitos.
- B — Los Puentes de Caramelo: puente de pastel, bastón móvil horizontal, caramelo resbaladizo, cascadas de chocolate, cuatro Cuppy Dulzón, primer checkpoint, corazón y bastón que sube a la cereza dorada.
- C — El Río de Chocolate: ríos de chocolate al fondo de los huecos, chocolate pegajoso en cuatro tramos, chorro de chocolate, malvaviscos sobre el río, gelatinas elásticas opcionales, goma elástica hacia una ruta alta de malvaviscos (caramelo especial 2) y cuatro Piruletas Voladoras.
- D — La Fábrica de Caramelos: correas de chocolate (a favor y en contra), lanzadores, piruletas giratorias (de giro completo y de péndulo), plataforma con pinchos, gelatinas que desaparecen, estante de galletas (caramelo especial 3), tobogán de caramelo dorado con rampas, segundo checkpoint y los tres enemigos juntos.
- E — El Castillo del Gran Pastel: pasteles, fresas, cupcakes y piruletas; gelatina, puente de pastel, isla alta (trozo de pastel), plataformas de chocolate, pinchos, lanzador, los tres enemigos y la puerta a la arena.
- 298 estrellas, 20 enemigos (8 Cuppy, 6 Gomilitos, 6 Piruletas) con activación por proximidad, 2 checkpoints, 20 carteles, 4 corazones, 7 bloques de premio, 3 caramelos especiales, cereza dorada y trozo de pastel.
- Colisiones reales del TileSet: cuadradas para el terreno y triangulares para las rampas. Ninguna colisión sale de la ilustración: el escenario completo nunca se usa como imagen con colisiones.
- El generador comprueba al escribir los datos que cada enemigo de suelo, checkpoint, obstáculo, cartel y goma tiene suelo libre, que ningún coleccionable queda dentro del terreno y que ningún hueco obligatorio supera 5 teselas sin plataforma.

## Etapa 4 — Mecánicas exclusivas

| Mecánica | Implementación |
|---|---|
| Gelatinas elásticas | `CloudPlatform` con `bouncy` (fuerza en los datos): impulso vertical, compresión y recuperación de la forma. |
| Gomas elásticas | `BouncePad` con los dibujos de goma. |
| Caramelo resbaladizo | `PaintSurface` color `caramel` (fricción 0,28): frena más tarde, pero frena. |
| Chocolate pegajoso | `PaintSurface` color `choco` (velocidad 0,5): al salir se recupera la velocidad normal. |
| Correas de chocolate | `ConveyorBelt` nuevo: `StaticBody2D` con `constant_linear_velocity`. Godot la aplica como velocidad de plataforma, así no hay deslizamientos erráticos; un brillo recorre las flechas en su sentido. |
| Piruletas giratorias | `SpinningLollipop` nuevo: gira (o se balancea) alrededor de la base del palo; la colisión es un círculo dentro del brazo, sobre la cabeza de caramelo. El palo no hace daño. |
| Lanzadores de caramelos | `CandyLauncher` nuevo: intervalo configurable; avisa 700 ms antes (tiembla, se hincha y brilla) y dispara una bola lenta a altura fija. |
| Chorros de chocolate | `ChocoJet` nuevo: ciclo fijo reposo → aviso (burbujea y brilla 800 ms) → columna que sube; sólo hace daño levantada. |
| Plataformas temporales | `CrumblePlatform` con los dibujos de gelatina: tiemblan al pisarlas, desaparecen y vuelven a aparecer. |
| Plataformas con pinchos | `Hazard` con forma `spikes`: colisión rectangular sólo en la franja de pinchos. |
| Plataformas móviles de bastón dulce | `MovingPlatform` (horizontal y vertical). |
| Bloques de premio | `StarBlock` con el dibujo del bloque "?": sueltan estrellas con cabezazo o disparo. |
| Corazones | `HeartPickup` nuevo: devuelven un corazón (con la vida llena no se gastan). |

## Etapa 5 — Enemigos

Los tres derivan de `Enemy`, así que funcionan con las tres armas sin código extra: la burbuja los atrapa (y un segundo disparo los convierte en estrella), la pintura los ralentiza y el tirachinas les hace daño. También se pueden pisar. Todos tienen hitbox propia más pequeña que el dibujo.

- **Cuppy Dulzón** (`scripts/ai/cuppy.gd`): patrulla rodando; al ver a Alice se acerca a saltitos sin saltar fuera de su plataforma; cerca de ella levanta la piruleta (preparación de 650 ms con destello), dispara un caramelo redondo recto y lento a la altura de sus galletas, se recupera y repite.
- **Gomilito Saltarín** (`gomilito.gd`): siempre se mueve a saltitos; se agacha (aviso) y salta en plancha hacia Alice. Al bajar su vida a `splitAt` (2 por defecto) se divide en dos gomitas pequeñas (`gomilito_mini.gd`), con menos vida (1) y velocidad configurable (`miniSpeed`). Las gomitas no se dividen y nunca hay más de 6 a la vez en el nivel.
- **Piruleta Voladora** (`piruleta.gd`): flota con una onda suave y patrulla en horizontal; al ver a Alice sube o baja a una altura cómoda por encima de ella (dentro de su franja `fly`) y mantiene distancia; se inclina (aviso de 700 ms) y lanza tres caramelitos lentos en abanico con huecos entre ellos.

## Etapa 6 — Don Chupetón

`scripts/entities/don_chupeton.gd` + `scenes/bosses/DonChupeton.tscn`, en la arena común (`World7Boss.tscn`). 65 HP. Misma interfaz que los jefes anteriores. Cada ataque empieza con aviso ("!", destello y pose previa) y termina en un descanso vulnerable. Nada es inevitable: caramelos lentos y con huecos, piruletas y remolinos que ruedan por el suelo (se saltan), gotas de glaseado que marcan antes dónde caen y un giro que se esquiva desde las nubes de crema. Su cuerpo queda por debajo de esas nubes.

- Fase 1, Lluvia de caramelos (100-65 %): tres caramelos pequeños hacia Alice, piruleta horizontal, avance lento y descansos largos.
- Fase 2, Tormenta de glaseado (65-30 %): chorro de glaseado por el suelo con dos gotas marcadas, abanico de cinco caramelos, remolinos de piruletas y cambios de sentido.
- Fase 3, El gran remolino dulce (30-0 %): giro de caramelo multicolor que recorre la arena soltando caramelos envueltos, ráfagas de glaseado hacia los dos lados, proyectiles múltiples y combinación de giro y glaseado.
- Derrota: deja de atacar, sus piruletas dejan de girar poco a poco, pone cara de sorpresa, el glaseado cae suavemente, aparecen estrellas y confeti y queda convertido en un pastelito dormido ("Z z z"). Entrega la estrella especial y se abre el portal al Mundo 8.

## Etapa 7 — Progreso, HUD y audio

- `WorldRegistry`: Mundo 7 implementado (escena `World7`, arena `Boss7`, textos de victoria); el Mundo 6 ahora anuncia "Portal al Mundo 7: abierto". `Router`: `World7` y `Boss7`.
- Al completar el Mundo 6 se desbloquea el 7; al completar el 7 se guardan estrellas, estrella especial, tiempo y coleccionables, y se desbloquea el 8. El Mundo 8 no tiene escena: la victoria ofrece "Jugar otra vez" y nunca se intenta abrir una escena inexistente.
- Carrusel: el Mundo 7 aparece jugable. Un mundo desbloqueado sin escena (el 8 al completar el 7) se muestra ahora sin candado, como "Desbloqueado: próximamente", y no se puede entrar.
- HUD: estrellas, vida, armas, barra de progreso con las cinco secciones y los tres caramelos especiales. La pantalla de victoria cuenta los cinco tesoros.
- Audio: música chiptune estilo NES sintetizada para `world7`, `don_chupeton` y `world7_victory` (melodía de onda cuadrada con arpegios y bajo triangular rítmico) y seis efectos nuevos (lanzador, chocolate, gelatina, glaseado, giro y división). Si se copian `world7_theme.ogg`, `don_chupeton_boss.ogg` y `world7_victory.ogg` a `godot/resources/audio/`, se usan en su lugar; si faltan, no hay errores de carga.

## Etapa 8 — Pruebas

- CheckAll (carga de todos los scripts y escenas): 0 fallos.
- Pruebas automáticas headless: 13 nuevas del Mundo 7 (datos, sprites, carga del nivel, rebote, superficies, correas, obstáculos, gelatinas y corazón, enemigos, armas contra enemigos, jefe, victoria completa y progresión) y las de los Mundos 1-6 adaptadas a que el 7 ya existe. Resultado de la suite completa: 114 pruebas, 1244 comprobaciones correctas, 0 fallidas, sin errores de script.
- Piloto automático (`res://tests/Autopilot.tscn -- world=7 godmode`): recorre el Mundo 7 de principio a fin en 86 s de juego, sin caídas, y llega a la puerta del jefe. Ajustes hechos a raíz de esta prueba: llegada del bastón móvil de la sección B a su misma altura (con rampa), malvaviscos firmes en lugar de gelatinas en los huecos obligatorios del río (las gelatinas quedan como ayuda opcional), plataformas que recogen las caídas desde la ruta alta y retirada de un bastón móvil redundante.
- Revisión visual con capturas (`res://tests/Capture.tscn`) de las cinco secciones, la Fábrica y la arena durante el combate.

## Pendiente y problemas conocidos

- Las pruebas headless y el piloto automático no sustituyen una partida real: falta una revisión jugada (ritmo, dificultad para una niña de 7 años, legibilidad de los avisos).
- Sin invulnerabilidad el piloto automático no completa el nivel: sólo corre y dispara, nunca esquiva. No es una medida de dificultad, pero conviene confirmar el balance jugando.
- Música y efectos son provisionales (sintetizados); faltan los `.ogg` definitivos.
- El panel de enemigos de `tilesets_world_7.png` (otros nombres y diseños) no se usa; si debía usarse, hay que aclarar cuál es el oficial.
- El Mundo 8 queda desbloqueado pero sin escena.
