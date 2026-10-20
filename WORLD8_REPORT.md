# Informe de implementación — Mundo 8

## El Castillo de las Pesadillas (el final de Alice Dreams)

El Mundo 8 se implementó como una extensión nativa del motor Godot existente, en la rama `feature/world-8-final`, creada sobre `main` después de fusionar `feature/world-7` (la versión más reciente con el Mundo 7). Alice, las tres armas, HUD, cámara, checkpoints, guardado, proyectiles, carrusel y arena de jefe son los mismos sistemas de los Mundos 1-7. Es el final de la historia: completar el Mundo 8 no desbloquea ningún mundo más.

## Etapa 1 — Auditoría

- Base: pipeline del Mundo 7 (`tools/world7/`), motor común `Level` / `LevelBuilder` / `BossArena`, registro `WorldRegistry` + `Router`, carrusel `WorldCarousel` / `WorldData`, `SaveManager`, `AudioManager` + `Synth`.
- Las cuatro referencias están en `imagenes/`: `word_8.png`, `tilesets_world_8.png`, `enemies_world_8.png` y `jefemundo8.png` (no estaban versionadas; se añaden con este trabajo).
- Estado inicial: la caché de clases de Godot (`godot/.godot/`, no versionada) estaba desactualizada tras fusionar el Mundo 7, y `CheckAll` / `Tests` no compilaban (clases `ConveyorBelt`, `GomilitoMini`... "no encontradas"). Se resolvió reimportando el proyecto (`--import`); no era un fallo del código. Línea base tras reimportar: 1240 correctas y 4 fallidas, todas en `test_w7_progression`, que comprobaba precisamente que el Mundo 8 todavía no existía (actualizada).
- La estructura sugerida se adaptó a la convención real: originales en `imagenes/`, recursos generados en `godot/resources/world8/`, datos en `godot/data/world8/`, herramientas en `tools/world8/`, enemigos en `scenes/enemies/world8/`, jefe en `scenes/bosses/ReyPesadelo.tscn`, cinemáticas en `scenes/cinematics/` y `scripts/cinematics/`.
- El registro tenía reservado el Mundo 8 ("El Castillo de los Sueños", sin escena). Ahora es "El Castillo de las Pesadillas" y está implementado; la isla del carrusel conserva el rótulo de la ilustración ("Castillo de los Sueños"), como se hizo con el Mundo 7.
- Aviso sobre las referencias: el panel "FINAL" de `jefemundo8.png` muestra a otra niña (rubia, vestido azul). No se usa: Alice es siempre la protagonista oficial del proyecto (`resources/player`).

## Etapa 2 — Recursos gráficos

`tools/world8/prepare_world8_assets.py` (pipeline del Mundo 7 adaptado) con las cajas de `tools/world8/world8_sources.json` (editables a mano) y `tools/world8/detect_world8.py` para el diagnóstico de paneles. Los originales nunca se modifican; filtro nearest; alfa binario; paleta común por personaje.

- Novedades del pipeline: opción `navy` (la hoja del jefe no trae alfa y sus ondas y humo encierran el fondo azul noche: se elimina también el azul noche no conectado con el borde) y opción `bluer_keep` + `open` (el fondo rosado de la hoja de enemigos tiene halos brillantes: un píxel parecido al fondo sólo es fondo si no es más azulado que él, lo que conserva el blanco azulado del Fantasmita; la apertura morfológica quita hilos de halo).
- Fantasmita Farol: 20 cuadros (idle 5, float 6, attack 4, hurt 3, defeat 2).
- Murcibola de Trapo: 18 cuadros (idle 4, fly 5, dive_attack 4, hurt 3, defeat 2).
- Bloquito Sombra: 20 cuadros (idle 5, walk 4, jump 2, charge 3, attack 1 —choque final—, hurt 3, defeat 2).
- Rey Pesadelo: 27 cuadros (idle 4, move 4, spit 4, claw 2, fart 3, fury 3, hurt 2, stunned 1, defeated 4), sólo de `jefemundo8.png`. Proyectiles separados de los cuerpos con `only`.
- Gato morado: de la misma hoja (panel "Gato morado tierno" y último cuadro de la transformación): idle 2, blink 1, sit 1, walk 2, purr 2, sleep 1. La hoja no trae cuadros de caminar: `walk` reutiliza dos posturas y el juego añade un balanceo (documentado como `reused`).
- Efectos: estrellita del Fantasmita, farol y espíritu, bola y estela del escupitajo, media luna y tajo del garrazo, nube ralentizadora con calaveritas caricaturescas, onda y estallido del grito, sombras, piedrecitas y corazón del gato.
- Teselas: materiales "lavender" (roca violeta de "tiles superiores" con su cobertura lavanda) y "castle" (piedra del castillo de "tiles centrales" con la misma cobertura); bordes, base colgante y rampas generados; bloques tenebroso, de luna y de corazón.
- Objetos: plataformas de nube, de piedra (luna, corazón, estrella), colgantes, puentes de cuerda entre bastones de caramelo, setas fantasma, plataformas pequeñas, pinchos de caramelo, charcos y bruma de sombras, bloques tenebrosos, plataformas fantasma (visible y contorno), estrellas colgantes, ganchos de luna y estrella, árboles retorcidos, calabazas, velas, faroles, vallas, gárgolas, ventanales, estandartes, estrellas, fragmentos de luna, corazones de sueño, llave, orbe, bandera, carteles, portal y cofre.
- Fondo: capa lejana con el cielo nocturno, la luna creciente, el castillo, las islas y las cascadas recortados de `word_8.png`; islas y puentes, cascadas, fantasmas y siluetas de la hoja de teselas; cielo y bancos de nubes generados con colores muestreados de `word_8.png`.
- Dibujados por código (no aparecen en las referencias), con la paleta del Mundo 8: el trono del salón y la habitación de Alice con su colcha (`tools/world8/generate_world8_extras.py`). Alice nunca se dibuja: la cinemática usa sus fotogramas oficiales.
- Manifiesto: `godot/data/world8/world8_asset_manifest.json`, 202 recursos, ninguno pendiente.
- Limitación conocida: los bordes de algunos sprites de la hoja de enemigos (halos del fondo pastel) quedan algo ruidosos a la resolución lógica. Se ven bien en el juego, pero admiten retoque manual de cajas en `world8_sources.json`.

## Etapa 3 — Escenario

`tools/world8/world8_level.py` genera `world8.json` y `world8_boss.json` y comprueba al escribirlos: suelo libre bajo cada enemigo de suelo, checkpoint, obstáculo, cartel, farol, cofre, estrella que cae y sombra; coleccionables fuera del terreno; ningún hueco obligatorio de más de 5 teselas sin plataforma; checkpoints en B, D y E.

- Recorrido: 12.000 px (10.000 de nivel + 2.000 del salón del trono), el nivel más grande del juego.
- A — El Bosque de los Susurros (0-1.800): árboles retorcidos, calabazas, faroles; primera plataforma fantasma (ciclo largo, para aprender), Fantasmitas y Bloquitos, ruta alta con plataformas fantasma al primer fragmento de luna.
- B — Los Puentes de la Luna (1.800-3.800): tres plataformas colgantes sincronizadas, estrellas que caen, plataformas que desaparecen, puente de cuerda, primer Murcibola, primer checkpoint.
- C — El Jardín de las Sombras (3.800-5.900): setas fantasma elásticas, charcos y bruma de sombras, enemigos combinados, ruta secreta con el orbe especial.
- D — Las Torres Encantadas (5.900-8.000): escalones y torres de piedra, plataforma móvil entre torres, ganchos oscilantes, plataformas que desaparecen, segundo checkpoint, ruta con plataformas fantasma a la llave del castillo.
- E — El Corazón del Castillo (8.000-10.000): pasillos de piedra del castillo, faroles mágicos que revelan puentes ocultos, los tres recuerdos, el cofre, tercer checkpoint y la gran puerta.
- F — El Trono de las Pesadillas (10.000-12.000): salón con ventanales, estandartes, gárgolas y trono; la arena del jefe con plataformas laterales y la puerta que se cierra.
- 282 estrellas + 22 en el salón, 24 enemigos (9 Fantasmitas, 8 Bloquitos, 7 Murcibolas), 6 corazones de sueño, 3 fragmentos de luna, llave, orbe, 3 recuerdos y cofre.

## Etapa 4 — Enemigos

Los tres derivan de `Enemy`: funcionan con las tres armas (burbuja, pintura y tirachinas) y se pueden pisar. Hitbox propia más pequeña que el dibujo.

- Fantasmita Farol (`scripts/ai/fantasmita.gd`): flota por su ruta; al ver a Alice se coloca a una altura cómoda, levanta el farol (aviso 750 ms), lanza una estrellita lenta y retrocede. Su luz revela un rato los puentes ocultos cercanos. Derrota: partículas, el farol cae y su espíritu sube.
- Murcibola de Trapo (`murcibola.gd`): patrulla el aire; se coloca a un lado de Alice (nunca justo encima), se encoge (aviso 700 ms con "!"), se lanza en picada al punto fijado al avisar y vuelve a su zona de descanso.
- Bloquito Sombra (`bloquito_sombra.gd`): camina (salta escalones de una tesela), avisa, levanta una barrera de sombra que detiene los disparos, embiste y al chocar queda quieto y sin barrera: el momento de atacar.

## Etapa 5 — Obstáculos y mecánicas

| Mecánica | Implementación |
|---|---|
| Plataformas fantasma | `GhostPlatform`: ciclo VISIBLE → WARNING (parpadeo y brillo lunar) → INVISIBLE (contorno tenue, sin colisión) → REAPPEAR sobre el reloj del nivel; las de un mismo hueco van desfasadas y nunca desaparecen a la vez. |
| Setas fantasma | `CloudPlatform` con rebote. |
| Charcos y bruma de sombras | `ShadowZone`: franja baja (se salta); el nivel aplica un golpe como mucho cada 1,1 s y respeta la invulnerabilidad. |
| Estrellas que caen | `FallingStar` (Mundo 5) con fotogramas de datos: durante el aviso cuelga de su cadena y titila, el suelo marca el impacto. |
| Plataformas colgantes | `SwingPlatform` (Mundo 3) con cadena; sincronizadas, transportan a Alice. |
| Faroles mágicos | `MagicLantern` (tocar o disparar) emite `lit`; el builder lo conecta a sus `HiddenBridge` por id. |
| Ganchos en cadena | `ChainHook`: péndulo determinista; sólo daña el gancho. |
| Plataformas que desaparecen | `CrumblePlatform` con plataformas pequeñas. |
| Cofre | `TreasureChest`: se abre con la llave: estrellas y vida llena. |
| Recuerdos | `DreamCollectible` "memory"; el nivel muestra 2 s una visión con motivos de los mundos anteriores (Alice sigue al mando). |

## Etapa 6 — Rey Pesadelo

`scripts/entities/rey_pesadelo.gd` + `scenes/bosses/ReyPesadelo.tscn`, en `scripts/levels/world8_boss_arena.gd` (extiende la arena común). 80 HP. Estados explícitos: INTRO, IDLE, MOVE, TELEGRAPH, SPIT, CLAW, SLOW_CLOUD, FURY_SCREAM, HURT, STUNNED, DEFEATED, TRANSFORMING y CAT. Contacto dañino sólo en la parte baja del cuerpo (las plataformas laterales son seguras) y un área mayor para recibir disparos. Lejos de Alice se acerca deprisa: nunca ataca fuera de la vista.

- Escupitajo oscuro: se detiene, abre la boca, chispas, proyectil con estela hacia Alice (ángulo limitado); desaparece contra el terreno.
- Garrazo de ráfaga: levanta el brazo, marca el suelo, tajo y media luna que recorre el suelo (velocidad, daño, vida y escala configurables en `CLAW_WAVE`); se salta. Dobles en las fases 2 y 3.
- Pedo ralentizador: se gira con cara traviesa y suelta una nube con calaveritas que avanza despacio; sin daño, ralentiza velocidad y aceleración 3 s, sin acumularse (como mucho 4 s), no bloquea salto ni disparos; sonido 8-bit cómico.
- Grito de furia: aviso de 1,5 s (la música baja, brillan los ojos, destellos suaves), temblor leve, tres pares de ondas por el suelo hacia los dos lados (se saltan o se esperan en las plataformas), empuje pequeño al recibir el golpe. Sin destellos intensos.
- Fases: 1 (100-65 %) escupitajo y garrazo; 2 (65-30 %) garrazos dobles, escupitajos dobles, nube, desplazamientos rápidos, el cielo se oscurece, estrellas cambian de color y caen estrellas con aviso; 3 (30-0 %) grito, garrazos, escupitajos seguidos, nubes y combinación garrazo + escupitajo, música de furia.
- Equidad: cada ataque termina en STUNNED (ventana de contraataque, más larga tras los especiales) y el grito nunca empieza mientras Alice está ralentizada.

## Etapa 7 — Derrota y transformación

DEFEATED cancela los ataques pendientes, desactiva las hitboxes, elimina proyectiles y nubes, bloquea nuevos disparos, baja la música poco a poco y deja al monstruo agotado. TRANSFORMING instancia `scenes/cinematics/NightmareTransformation.tscn`: una animación de `AnimationPlayer` construida en código (partículas moradas, los ojos dejan de brillar, encoge, las garras desaparecen entre nubes, fundido del monstruo y aparición del gato con los cuadros oficiales). CAT deja en la arena el gato morado (`PurpleCat`): parpadea, se acerca despacio, se sienta a esperar; al tocarlo ronronea y sale un corazón. El HUD se oculta poco a poco y Alice ya no puede disparar.

## Etapa 8 — Cinemática final y créditos

- Escena 1 (en la arena): el castillo recupera la luz (el cielo pasa a lavanda, chispas, fantasmas sonrientes, música suave).
- Escena 2: Alice brilla, estrellas giran a su alrededor y todo se funde.
- Escenas 3-5 (`scenes/cinematics/AliceAwakening.tscn`): la habitación al amanecer; Alice duerme, se incorpora, mira a los lados y sonríe; un maullido; el gato duerme a los pies de la cama, abre los ojos y mueve la cola; Alice sonríe sorprendida; "Los sueños más grandes comienzan con un poquito de valentía.", "Gracias por jugar, Alice." y "FIN" con la tipografía pixel. Se puede saltar.
- Créditos (`scenes/cinematics/Credits.tscn`, datos en `godot/data/world8/credits.json`): desplazamiento suave, Alice Dreams, Guardiana de los Sueños, agradecimiento especial a Alice, música y recursos, estrellas, corazones, el gato morado y Alice saludando; botón para volver al menú.
- No se inventan nombres: la sección "Desarrollo" está vacía y no se muestra hasta que el propietario la rellene.

## Etapa 9 — Música, guardado y menú

- Audio: seis pistas integradas en el sistema actual (`world8`, `rey_pesadelo`, `rey_pesadelo_fury`, `transformation`, `alice_awakening`, `alice_credits`) con versiones chiptune provisionales sintetizadas. Si se copian `world8_theme.ogg`, `rey_pesadelo_boss.ogg`, `rey_pesadelo_fury.ogg`, `transformation_theme.ogg`, `alice_awakening.ogg` y `alice_credits.ogg` a `godot/resources/audio/`, se usan en su lugar; si faltan, no hay errores de carga. Catorce efectos nuevos (fantasma, picada, embestida, magia, recuerdo, escupitajo, garrazo, pedo cómico, grito, maullido, ronroneo...).
- Guardado: al abrazar al gato se guardan estrellas, tesoros, tiempo y Mundo 8 completado, y se registra la victoria final (`adventureCompleted`). Campos nuevos con valores por defecto: los guardados anteriores se cargan igual. `unlockedWorld` sigue siendo 8.
- Menú: "Ver el final" aparece al terminar la aventura (cinemática y créditos). Todos los mundos desbloqueados se pueden repetir. La victoria del Mundo 7 ofrece "Ir al Mundo 8".
- Cambios compartidos (neutros para los demás mundos): ralentización en `Player`, interruptor de combate en `InputController`, fundido de música en `AudioManager`, fotogramas configurables en `FallingStar`, color de cuerda en `SwingPlatform`, objetos nuevos en `LevelBuilder`.

## Etapa 10 — Pruebas

- CheckAll (todos los scripts compilan y todas las escenas y recursos cargan): 0 fallos.
- Suite automática headless completa: 131 pruebas, 1488 comprobaciones correctas, 0 fallidas, sin errores de script. Incluye 17 pruebas nuevas del Mundo 8: datos y referencias, sprites, carga del nivel y colisiones, plataformas fantasma (ciclo y nunca dos a la vez), daño de sombras con intervalo, ganchos, plataformas colgantes y estrellas que caen, faroles y puentes ocultos, cofre y recuerdos, los tres enemigos, armas contra enemigos, ralentización (y su restauración), estados y umbrales de vida del jefe, sus cuatro ataques (aviso, ventana de contraataque, el grito nunca sobre la ralentización, ondas más bajas que un salto), cancelación de ataques en la derrota, combate completo con transformación, gato y guardado del final, cinemática y créditos, y progresión (sin Mundo 9, compatibilidad con guardados anteriores, "Ver el final").
- Piloto automático (`res://tests/Autopilot.tscn -- world=8 godmode`): recorre el Mundo 8 de principio a fin en 78 s de juego, sin caídas, y llega a la gran puerta. Ajustes hechos a raíz de esta prueba: hueco inicial más corto y sin el bloque del borde, escalones sólidos hasta la segunda torre (en lugar de un ascensor junto al muro), escalera de plataformas que desaparecen al bajar de la tercera torre, plataformas colgantes sincronizadas (se cruzaban) y huecos más cortos en las secciones B y C. El piloto ya no se apoya en plataformas fantasma (cambio en `tests/autopilot.gd`).
- Sin invulnerabilidad el piloto no pasa de la sección B (sólo corre y dispara, nunca esquiva), igual que en el Mundo 7: no mide la dificultad real.
- Regresión de mundos con código compartido modificado: el piloto completa el Mundo 3 (plataformas colgantes) y el Mundo 6 (estrellas que caen) sin caídas.
- Revisión visual con capturas (`res://tests/Capture.tscn`) de las secciones, el salón del trono, el combate, la transformación, la habitación de Alice y los créditos.

## Pendiente y problemas conocidos

- Las pruebas automáticas y el piloto no sustituyen una partida real: falta una revisión jugada (ritmo, dificultad del jefe para una niña de 7 años, legibilidad de los avisos y del final).
- Música y efectos son provisionales (sintetizados); faltan los `.ogg` definitivos.
- Créditos de desarrollo: hay que añadir los nombres confirmados en `godot/data/world8/credits.json`.
- Bordes algo ruidosos en algunos sprites de enemigos (ver Etapa 2).
- En una de seis capturas de los créditos Godot terminó con un fallo de segmento al cerrar la ventana de captura; no se reprodujo en otros cinco intentos ni durante la escena.
