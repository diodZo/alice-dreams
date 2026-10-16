# Informe de migración Phaser 3 → Godot 4

**Rama:** `godot-migration` · **Motor:** Godot 4.7.2 estable (GDScript 2.0, renderizador Compatibility) · **Entrada:** `godot/project.godot`

## 1. Resumen

El Mundo 1 completo se ha migrado a escenas y scripts nativos de Godot: protagonista, tres armas, tres monstruos, todas las plataformas y obstáculos, checkpoints, coleccionables, HUD, menús, pausa, audio, guardado, la arena y Nubarrón con sus tres fases, la estrella especial, el portal y la pantalla de victoria. Se usan los sprites originales de `public/assets/` sin redibujar nada, y los mapas, valores y tiempos se generan directamente desde el código Phaser (no se copiaron a mano).

El proyecto Phaser no se ha tocado: `git diff` sobre `src/ public/ imagenes/ tools/ index.html package.json README.md` está vacío. Todo lo nuevo está en `godot/` y en `MIGRATION_PLAN.md`, `MIGRATION_REPORT.md` y `README_GODOT.md`.

## 2. Cómo se verificó

| Verificación | Herramienta | Resultado |
|---|---|---|
| Importación del proyecto en el editor (headless) | `godot --headless --path godot --import` | Sin errores |
| Compilación de todos los scripts y carga/instanciación de todas las escenas y recursos | `tests/CheckAll.tscn` | **0 fallos** |
| Pruebas automáticas de datos, física, armas, enemigos, jefe y guardado | `tests/Tests.tscn` | **125 comprobaciones correctas, 0 fallidas** |
| Recorrido completo del Mundo 1 con los controles normales (sin teletransportes) | `tests/Autopilot.tscn -- godmode` | **Llega a la puerta del castillo** desde el inicio en 6.577 fotogramas (110 s de juego), cruzando las dos nubes móviles, las nubes de vapor, la corriente de aire, el cojín y la nube elástica |
| Tramos por separado | `Autopilot -- godmode start=283` / `start=367` / `start=395` | Llegan a la puerta sin caídas (D completa, D final + E, E) |
| Prueba de humo larga (3.000 fotogramas disparando y saltando, con capturas) | `tests/Capture.tscn` | Sin errores de ejecución |
| Revisión visual | Capturas reales con la GPU (menú, secciones A-E, puentes, cascadas, castillo, arena en fases 1 y 3, pausa, victoria, botones táctiles) | Sprites originales sin recortes ni desplazamientos, píxeles nítidos, capas de fondo correctas |
| Exportación a Windows | `--export-release "Windows Desktop"` | `AliceDreams.exe` generado; arranca sin errores y carga los datos |

`godmode` sólo desactiva el daño de enemigos y peligros (las caídas al vacío sí cuentan) para comprobar que **el recorrido es físicamente posible** con la física migrada. Sin `godmode` el piloto, que no sabe combatir, cae ante los Escupitines de la sección C; el combate se verifica en las pruebas unitarias.

### Detalle de las 125 comprobaciones (`tests/run_tests.gd`)

- **Datos**: 475×25 teselas, 8.000 px, 5 secciones, 16 terrenos, 138 estrellas, 13 enemigos, 2 checkpoints, 3 armas, plataformas y obstáculos; arena 40×17; valores de las tres armas, de los monstruos y de la protagonista idénticos a Phaser.
- **Recursos**: 11 animaciones de la protagonista (caminar 6 fotogramas, correr a 15 fps), celda 42×44, **26 fotogramas de Nubarrón**, animaciones de los tres monstruos, TileSet, ningún recurso provisional.
- **Protagonista**: se apoya en el suelo, caminar 95 px/s, correr 150 px/s, desaceleración, salto completo de 61,5 px (335²/1.800), salto variable, **coyote time** (salta a 50 ms del borde y no a 150 ms), **jump buffer**, nube unidireccional atravesada desde abajo y pisada desde arriba.
- **Plataformas**: la móvil transporta a la protagonista, la de vapor se deshace a los 560 ms y reaparece, cojín (−600), nube elástica (−540), corriente de aire (−190 px/s), burbuja con pinchos (daño + invulnerabilidad).
- **Checkpoints y caídas**: activación, caída al vacío (−1 corazón), reaparición en la bandera.
- **Coleccionables**: estrellas del mapa recordadas, recogida del arma y selección automática.
- **Armas**: velocidades (185/255 px/s), cambio con K, parábola del tirachinas, tiempo de recarga, disparo hacia arriba; burbuja atrapa → tocar = estrella extra que se recoge; pintura (1 daño, marca y ralentiza ×0,55); tirachinas (2 daño); pisotón.
- **Enemigos**: Arañitas detecta (IDLE/PATROL → ALERT), se acerca y araña (hace daño); Escupitín escupe gotas; Pulgoso retrocede y lanza pulgas en parábola; aparición al acercarse la cámara y retirada al alejarse.
- **Nubarrón**: el combate empieza al cruzar la puerta, la puerta se cierra, barra de 40 PV, vulnerable tras la entrada, pasa por las fases 2 y 3, usa WIND, SHOOT, REST, PHASE_CHANGE y ataques de fase 2/3, es derrotado, suelta la estrella especial, se abre el portal, la protagonista lo cruza y celebra, y el Mundo 1 queda guardado como completado.
- **Guardado**: mejor marca conservada al recargar, desbloqueo del Mundo 2, archivo dañado → valores por defecto.
- **Menús y pausa**: navegación con flechas, Enter y ratón; la pausa detiene el reloj del juego; Esc reanuda sin volver a pausar.

## 3. Funcionalidades verificadas

| Funcionalidad | Estado | Evidencia |
|---|---|---|
| Arranque, carga de recursos, menú | Verificado | CheckAll, ejecución headless, captura del menú |
| Sprites originales (protagonista, monstruos, jefe, objetos, fondos) | Verificado | `SpriteFrames` generados desde los atlas; capturas |
| Movimiento, carrera, salto variable, coyote time, jump buffer | Verificado | Pruebas de física |
| Colisiones (terreno, unidireccionales, límites del mundo) | Verificado | Pruebas + piloto automático |
| Cámara (zona muerta, suavizado, anticipación, límites, sacudidas) | Verificado visualmente | Capturas en todas las secciones y en la arena |
| Las tres armas | Verificado | Pruebas de armas |
| Los tres enemigos | Verificado | Pruebas de IA |
| Plataformas móviles, de vapor, cojín, elástica, corriente, pinchos | Verificado | Pruebas + piloto |
| Checkpoints y reaparición | Verificado | Pruebas |
| Coleccionables y estrella extra | Verificado | Pruebas |
| HUD (corazones, arma, estrellas, progreso, sección, barra del jefe, avisos) | Verificado visualmente | Capturas |
| Menús (principal, pausa, victoria), ratón/teclado | Verificado | Capturas + pruebas de navegación y de pausa |
| Nubarrón: 3 fases, avisos, descansos, derrota, estrella, portal, victoria | Verificado | Prueba del jefe + capturas de fases 1 y 3 |
| Guardado y carga | Verificado | Prueba de guardado |
| Recorrido completo del Mundo 1 | Verificado (sin daño de enemigos) | Piloto automático |
| Exportación a Windows | Verificado | `AliceDreams.exe` |

## 4. Pendiente o no verificable aquí

| Punto | Situación |
|---|---|
| **Partida manual completa por una persona** (sensación de control, comparación lado a lado con Phaser) | No realizada: no puedo jugar con teclado. Toda la validación es automática y por capturas. Se recomienda que el propietario juegue el Mundo 1 completo. |
| Combate contra Nubarrón con disparos apuntados por el jugador | La prueba hace llegar los impactos directamente al jefe para recorrer las fases; la puntería real (disparos de tirachinas en parábola, burbujas hacia arriba) no la ha probado una persona. |
| Controles táctiles en un dispositivo táctil real | Sólo verificados visualmente (`-- --touch`). Usan `TouchScreenButton`, que en Godot es multitáctil. |
| Escucha del audio | Los sonidos se generan sin errores con los mismos parámetros que Phaser, pero nadie los ha escuchado en esta sesión. Los osciladores no están limitados en banda (como los de WebAudio sí lo están): el timbre puede sonar algo más áspero. |
| Selector visual de mundos | Phaser tampoco lo tiene (sólo "Jugar"). Está el registro de los 8 mundos (`world_registry.gd`) y el guardado de mundo desbloqueado, listo para un selector cuando existan más mundos. |
| Mundos 2 a 8 | Fuera de alcance por petición. Arquitectura preparada (sección 5 de `README_GODOT.md`). |

## 5. Diferencias de implementación (y por qué)

- **Física**: Arcade Physics se sustituye por `CharacterBody2D`/`move_and_slide`. Se conservan el orden de integración (gravedad semi-implícita a 60 Hz), los valores y las hitboxes; la altura de salto resultante coincide (61,5 px). La colisión unidireccional usa la de Godot (`one_way_collision`, margen 5 px, el mismo margen que el `oneWayCheck` de Phaser).
- **Plataformas móviles**: `AnimatableBody2D` con `sync_to_physics` en lugar de un cuerpo con velocidad; Godot transporta al jugador igual que el rozamiento de Arcade.
- **Proyectiles**: un `CharacterBody2D` (choque con terreno, rebote de las pulgas) con un `Area2D` para impactos. El límite de proyectiles activos (24/48) reproduce el tamaño de los pools de Phaser.
- **Partículas**: un emisor propio (`particle_burst.gd`) reproduce los parámetros de los emisores de Phaser (velocidad, ángulo, vida, escala, alfa, gravedad, tintes) dibujando rectángulos nítidos; la apariencia es equivalente, no idéntica píxel a píxel.
- **Fuente**: la misma fuente pixel 5×7 con contorno, dibujada en una imagen al arrancar.
- **Cámara**: se portó el algoritmo de seguimiento de Phaser (zona muerta 40×60 centrada en la vista, lerp 0,12, desplazamiento de 16 px, anticipación de 36 px, límites, sacudida). El "encuadre especial" del jefe es el de Phaser: la arena es un escenario propio de 640×272 px y la cámara queda limitada a él.
- **Escalado**: viewport de 480×270 escalado con proporción fija y filtro *nearest* (equivalente a `Scale.FIT` + `pixelArt`). Ventana inicial de 1440×810 (×3).
- **Audio**: los mismos eventos y partituras sintetizados se renderizan a `AudioStreamWAV`; la música se genera en segundo plano durante la pantalla de carga.

## 6. Problemas encontrados y corregidos durante la migración

- `weakref()` y valores de diccionario sin tipo rompían la compilación de `level.gd` (inferencia sobre Variant tratada como error): se tiparon explícitamente.
- Temporizadores con lambdas que capturaban nodos ya liberados (estrella extra recogida antes de desvanecerse, nubes temporales del jefe): ahora usan referencias débiles.
- La pulsación de Esc que cierra la pausa podía volver a abrirla en el mismo fotograma: se ignora la pausa durante el fotograma de reanudación.
- La generación de música en segundo plano se interrumpe al cerrar el juego (evita accesos a un nodo liberado).
- Las herramientas de prueba no deben persistir ajustes: el piloto desactivaba los efectos guardándolo en el progreso real; ahora sólo lo desactiva en memoria y las pruebas usan un archivo de guardado propio que borran al terminar.

## 7. Herramientas de conversión

| Herramienta | Qué hace |
|---|---|
| `godot/tools/convert_phaser.mjs` | Lee `manifest.json` y los atlas Phaser, copia los PNG originales, escribe las regiones de cada fotograma (conservando recortes si los hubiera) y las animaciones; evalúa `world1.js`, `weaponDefs.js`, `enemyDefs.js` y `tuning.js` y los vuelca a JSON; copia `ASSETS_REPORT.md`. |
| `godot/tools/build_resources.gd` | Crea `SpriteFrames` (un `AtlasTexture` por fotograma), el `TileSet` con colisión y los `WeaponDef`/`EnemyDef` `.tres`. |

Ambas son reproducibles: volver a ejecutarlas produce los mismos archivos.

## 8. Recursos: originales, reutilizados y provisionales

Sin cambios respecto a Phaser (detalle en `godot/resources/ASSETS_REPORT.md` y en la sección 4 del `README.md` original):

- **Originales extraídos**: protagonista (idle 4, caminar 6, saltar 2, daño 2, victoria 3, lanzaburbujas 4, lanzapintura 4, tirachinas 4), los tres monstruos, los 26 fotogramas de Nubarrón, proyectiles e iconos, objetos y decorado del mundo.
- **Reutilizados (provisionales)**: *correr* usa los fotogramas de caminar a 15 fps; *caer* usa los de salto; el ataque de Escupitín repite una pose.
- **Generados por código**: cielo, bancos de nubes, portal, corazones del HUD (pipeline de Phaser); gota de pintura, brillo, partículas y confeti (en Godot, igual que en Phaser).
- **Audio**: todo provisional y sintetizado.
