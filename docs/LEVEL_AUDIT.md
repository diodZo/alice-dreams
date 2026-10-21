# Auditoría de niveles — Alice Dreams (Godot)

> Evaluación individual de los 8 mundos (nivel + arena del jefe). Complementa a [`GAME_DESIGN_DOCUMENT.md`](GAME_DESIGN_DOCUMENT.md); las propuestas citadas (IMP-xxx) están en [`LEVEL_IMPROVEMENTS.md`](LEVEL_IMPROVEMENTS.md).
>
> **Numeración:** se usa el número de mundo que ve el jugador. El Mundo 5 usa los archivos `world6` y el Mundo 6 los archivos `world5`.

---

## 1. Metodología y límites

### 1.1. Qué se hizo

| Fuente de evidencia | Qué aporta | Limitación |
|---|---|---|
| **Datos de nivel** (`godot/data/**/world*.json`) analizados con scripts | Posiciones de enemigos, fosos, checkpoints, objetos y estrellas por sección | No dice cómo se siente jugarlo |
| **Código** (`scripts/ai`, `scripts/entities`, `scripts/objects`, `scripts/levels`) | Comportamiento real de enemigos, jefes y obstáculos | Estático |
| **Suite automática** (`tests/Tests.tscn`) | 131 pruebas / 1 488 comprobaciones en verde: cada mecánica, enemigo y jefe funciona como está programado | Valida corrección, no diversión ni equilibrio |
| **Piloto automático** (`tests/Autopilot.tscn`), 2 modos × 8 mundos, 12 000 fotogramas (200 s de juego) | Dónde se cae o recibe golpes un jugador que **sólo corre, salta y dispara** (no esquiva) | No es un humano. Sus fallos marcan **puntos de riesgo**, no prueban dificultad real |
| **Capturas renderizadas** (`tests/Capture.tscn`, OpenGL, Intel UHD 730), una por mundo + menú | Composición, legibilidad, coherencia visual | Una sola imagen por mundo |

**No se jugó ningún nivel a mano.** Las puntuaciones de *Jugabilidad* (que incluye disfrute) y *Rendimiento* (no se midieron FPS con render) se dejan como **N/E (no evaluable)**. El resto son evaluaciones **estáticas limitadas**, con su nivel de confianza.

### 1.2. Escala

1-3 deficiente · 4-5 mejorable · 6-7 correcto · 8-9 bueno · 10 excelente. Confianza: **A** (varias fuentes coinciden), **M** (una fuente sólida), **B** (inferencia de una captura o de datos indirectos).

### 1.3. Resultados del piloto automático (esta auditoría)

Comando: `Godot_v4.7.2-stable_win64.exe --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn -- world=N max_frames=12000 hits [godmode]`.

| Mundo | Sin invulnerabilidad | Con invulnerabilidad (`godmode`, las caídas sí cuentan) | Punto(s) de fallo concentrado (tesela) |
|---|---|---|---|
| 1 | **No llega** (mejor tesela 268, 28 golpes/caídas) | Llega, 109 s, **49 caídas** | 248 (nube móvil sobre foso, god); 207-238 (golpes, real) |
| 2 | **No llega** (mejor 261, 116) | Llega, 111 s, **48 caídas** | 248 (libro móvil sobre río), 140 (puente dibujado) |
| 3 | **No llega** (mejor 445, 94) | Llega, 91 s, 0 caídas | 119 y 144-149 (fosos junto a cuerdas, tras golpe del Ovillo) |
| 4 | **Llega**, 94 s, 5 golpes | Llega, 73 s, 0 | — (golpes dispersos) |
| 5 | **No llega** (mejor 564, 18) | **No llega** en 200 s (16 caídas); con 30 000 fotogramas llega en **313 s, 49 caídas** | 564 (cruce en tren de la sección E) |
| 6 | **Llega**, 77 s, 3 golpes | Llega, 77 s, 0 | — |
| 7 | **No llega** (mejor 382, 21) | Llega, 86 s, 0 | 277, 349 (golpes de enemigos, no caídas) |
| 8 | **No llega** (mejor 140, 91) | **No llega** (mejor 140, 99 caídas). Repetido: 66 caídas en 8 000 fotogramas, **determinista** | 139-140 (plataformas colgantes de la sección B) |

Lectura:
- Los fallos **sin invulnerabilidad** se deben sobre todo a que el piloto no esquiva; no son una medida de dificultad (los informes `WORLD7_REPORT.md` y `WORLD8_REPORT.md` ya lo advierten).
- Los fallos **con invulnerabilidad** sólo pueden ser caídas: señalan obstáculos de *timing* que un jugador automático no resuelve. Aparecen en 1, 2, 5 y 8.
- **Discrepancia:** `WORLD8_REPORT.md` afirma que el piloto con invulnerabilidad recorría el Mundo 8 completo en 78 s. Hoy no pasa de la tesela 140. Es una posible regresión o un cambio no documentado del piloto (IMP-037).
- Todas las ejecuciones del piloto terminan con un aviso del motor al salir (*41-43 ObjectDB instances leaked*, *19 resources still in use*). La suite de pruebas no lo produce: parece propio de la salida del piloto, no del juego.
- La captura del menú (`scene=Menu`) generó la imagen y después el proceso terminó con *access violation* (código −1073741819) al cerrarse. `WORLD8_REPORT.md` describe un fallo similar con los créditos. No se reprodujo en el juego normal (no se ejecutó con ventana fuera de la herramienta de captura).

### 1.4. Datos estructurales comparados

| Mundo | Ancho | Fosos | Enemigos | Densidad /1000 px | Checkpoints (tesela) | Mayor tramo sin checkpoint | Carteles | Coleccionables | Corazones |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 7 600 | 10 | 13 | 1,7 | 138, 367 | 3 664 px | 13 | — (3 armas) | 0 |
| 2 | 7 584 | 13 | 14 | 1,8 | 146, 357 | 3 376 px | 11 | 3 crayones | 0 |
| 3 | 9 040 | 12 | 18 | 2,0 | 109, 322 | 3 776 px | 7 | 6 | 0 |
| 4 | 9 040 | 5 | 22 | 2,4 | 173, 352 | 3 296 px | 12 | 6 | 0 |
| 5 | 10 080 | 12 | 20 | 2,0 | 118, 398 | **4 480 px** | 18 | 3 billetes | 0 |
| 6 | 9 552 | 16 | 30 | **3,1** | 163, 419 | 4 096 px | 13 | 6 | 0 |
| 7 | 10 496 | 14 | 20 | 1,9 | 205, 468 | 4 208 px | 20 | 5 | 4 |
| 8 | 10 000 | 12 | 24 | 2,4 | 150, 425, 610 | 4 400 px | 20 | 8 | 6 |

### 1.5. Puntuaciones globales

| Criterio | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 |
|---|---|---|---|---|---|---|---|---|
| Diseño visual | 6 (B) | 7 (B) | 6 (B) | 7 (B) | 7 (B) | 6 (B) | 7 (B) | 8 (B) |
| Jugabilidad | N/E | N/E | N/E | N/E | N/E | N/E | N/E | N/E |
| Dificultad (equilibrio y curva) | 6 (M) | 4 (A) | 4 (A) | 8 (M) | 4 (A) | 6 (M) | 6 (M) | 3 (A) |
| Enemigos | 6 (M) | 7 (M) | 6 (M) | 6 (M) | 7 (M) | 7 (M) | 8 (M) | 8 (M) |
| Obstáculos | 6 (A) | 7 (A) | 6 (A) | 8 (M) | 7 (A) | 8 (M) | 8 (M) | 7 (A) |
| Exploración | 4 (M) | 6 (M) | 7 (M) | 7 (M) | 6 (M) | 7 (M) | 8 (M) | 9 (M) |
| Ritmo | 6 (B) | 5 (M) | 6 (B) | 7 (B) | 5 (M) | 4 (M) | 6 (B) | 6 (B) |
| Originalidad | 6 (M) | 8 (M) | 7 (M) | 8 (M) | 9 (M) | 8 (M) | 7 (M) | 8 (M) |
| Rendimiento | N/E | N/E | N/E | N/E | N/E | N/E | N/E | N/E |
| Accesibilidad | 7 (M) | 6 (B) | 6 (B) | 7 (B) | 5 (M) | 5 (B) | 5 (M) | 5 (M) |
| **Media de los evaluados** | **5,9** | **6,3** | **6,0** | **7,3** | **6,3** | **6,4** | **6,9** | **6,8** |
| **Prioridad de intervención** | Media‑alta | Alta | Alta | Baja | Alta | Media | Media | **Alta** |

> Rendimiento: las ejecuciones *headless* y las capturas no mostraron errores ni bloqueos, y el diseño limita enemigos (6 activos) y proyectiles (24/48). Sin medición de FPS con render no se puntúa.

---

## 2. Patrones transversales detectados

1. **Checkpoints escasos y a veces detrás del obstáculo.** Dos por nivel (B y D), ninguno en las arenas. En tres casos el checkpoint está **justo después** del obstáculo que más caídas provoca: Mundo 2 tesela 146 tras el puente dibujado 132-140; Mundo 8 tesela 150 tras las plataformas colgantes 128-143; Mundo 1 tesela 138 lejos del móvil de la 247. → IMP-001, IMP-010, IMP-037.
2. **La caída devuelve al checkpoint**, no al borde del foso. Con tramos de 3 300-4 500 px, cada error cuesta 20-30 s de recorrido (≈ a 150 px/s).
3. **Sin vidas ni *game over*** (coherente con el público): el único coste del error es repetir recorrido. Esto hace de la distribución de checkpoints la principal palanca de dificultad.
4. **Retroceso al recibir daño** (150 px/s + 350 ms sin control, `tuning.json`) cerca de fosos convierte un golpe en una caída (Mundo 3). → IMP-027.
5. **El Lanzaburbujas neutraliza a cualquier enemigo en dos impactos**, por lo que la vida de los enemigos apenas importa desde el Mundo 2 (las tres armas desde el inicio). → IMP-006.
6. **Agresividad decreciente:** enfriamientos de ataque de 900-1 700 ms en el Mundo 1 frente a 2 200-2 600 ms en el Mundo 8. → IMP-007.
7. **Jefes dañables durante sus ataques:** la ventana REST es descanso, no requisito. → IMP-005.
8. **Primer cartel recortado** en el borde izquierdo (Mundos 5, 7 y 8 verificados en captura). → IMP-036.
9. **Último tramo pobre** en los Mundos 1 (E sin mecánicas) y 2 (E de ~160 px). → IMP-025, IMP-026.
10. **Sólo los Mundos 7 y 8 tienen corazones.** → IMP-011.

---

## 3. Mundo 1 — El Reino de las Nubes de Algodón

**Escena:** `godot/scenes/worlds/World1.tscn` · **Datos:** `godot/data/worlds/world1.json` (generado desde `src/data/world1.js`) · **Arena:** `World1Boss.tscn` + `world1_boss.json` · **Jefe:** `scenes/bosses/Nubarron.tscn`, `scripts/entities/nubarron.gd`.

1. **Resumen.** Nivel tutorial de 7 600 px en cinco secciones. Enseña movimiento, salto, carrera, pisotón y las tres armas (recogidas en teselas 78, 177 y 283), con 13 carteles. Es el único mundo con progresión de armas.
2. **Características implementadas.** Nubes atravesables y elásticas, puentes, 2 plataformas móviles, 4 nubes de vapor que se deshacen, cojín de burbujas, corriente de aire, 2 peligros; Arañitas ×5, Escupitín ×4, Pulgoso ×4; 138 estrellas.
3. **Fortalezas.** Introducción gradual: cada mecánica tiene un cartel justo antes (p. ej. tesela 317 “Las corrientes de aire te elevan”, 357 cojín, 369 nube elástica). Música real (`mundo_1.mp3`, `jefe_mundo_1.mp3`). Primer enemigo aislado (tesela 50) antes de los grupos.
4. **Problemas identificados.**
   - Foso de 11 teselas (245-255) cruzable sólo con una nube móvil (`movers` x 247): 49 caídas del piloto invulnerable; cada una devuelve a la tesela 138. [A]
   - La sección E (teselas 406-475) no tiene ningún objeto de mecánica: 3 enemigos y 8 estrellas antes del castillo. [M]
   - El suelo es un único patrón azul repetido en grandes superficies (captura); `WORLD2_REPORT.md` ya anota que la textura de 16×16 “se repite de forma visible”. [B]
5. **Mecánicas desaprovechadas.** La corriente de aire y el cojín aparecen una sola vez (sección D) y no se combinan después.
6. **Dificultad.** La sección C concentra el primer obstáculo de *timing* sin checkpoint cercano. Sin invulnerabilidad, el piloto acumula golpes en las teselas 207-238 (Escupitines con disparo a distancia en la sección C).
7. **Mejora visual.** Variar la fila superior del terreno (flores, tréboles de nube) cada pocas teselas para romper la repetición.
8. **Nuevos obstáculos.** Tramo final que combine corriente + nube de vapor (IMP-025).
9. **Variación de enemigos.** Un Pulgoso sobre plataforma alta que obligue a disparar hacia arriba (la mecánica de apuntar arriba se enseña en la tesela 174 pero no se exige).
10. **Ritmo.** A tranquila, B-D bien escalonadas, E plana. Añadir el reto final y un checkpoint en C.
11. **Jefe: Nubarrón (40 PV).** Tres fases (65 %/30 %) con viento, bolitas, lluvia con aviso, invocación de nubes temporales y embestida; descanso brillante tras cada ataque. Bien telegrafiado [M]. Se le puede dañar mientras ataca: con disparo continuo cae en ≈8-9 s de impactos acertados. Arena de 40 teselas (una pantalla y poco más) sin `frameBoth`.
12. **Prioridad de intervención: Media‑alta** (IMP-001, IMP-010, IMP-025).

---

## 4. Mundo 2 — El Reino de los Crayones Encantados

**Escena:** `World2.tscn` · **Datos:** `godot/data/world2/world2.json` (`tools/world2/world2_level.py`) · **Jefe:** `Garabato.tscn`, `scripts/entities/garabato.gd`.

1. **Resumen.** 7 584 px. Mundo de pinturas con tres superficies de color, reglas-puente y ríos de pintura; se empieza con las tres armas.
2. **Características.** 7 reglas (algunas inclinadas, algunas dibujadas con ciclo), 6 superficies de pintura, 4 ríos, 3 lápices rodantes, 3 borradores rebotantes, 3 goteos, 2 plataformas móviles, 4 que se deshacen, molinillo; Borrador ×4, Crayón ×5, Pincel ×5; 3 crayones mágicos; 152 estrellas.
3. **Fortalezas.** Mecánicas propias y coherentes con el tema (pintura azul resbala, amarilla rebota, rosa frena). El Borrador **interactúa con el escenario** (borra puentes dibujados, `eraser_monster.gd`): el mejor ejemplo de enemigo ligado al mundo de todo el juego.
4. **Problemas.**
   - Puente dibujado (teselas 132-140, ciclo 2 600/1 600 ms) **antes** del checkpoint de la tesela 146: 32 caídas del piloto (con y sin invulnerabilidad) y cada una vuelve al inicio. [A]
   - Libro móvil sobre el río en la tesela ~244: 80 caídas del piloto sin invulnerabilidad. [A]
   - La sección E dura ≈160 px (tesela 456 → puerta 466). [M]
   - `mundo_2.mp3` / `jefe_mundo_2.mp3` existen pero no suenan (IMP-008). [A]
5. **Mecánicas desaprovechadas.** La pintura rosa (pegajosa) sólo aparece en D; los crayones mágicos no tienen efecto jugable más allá del recuento.
6. **Dificultad.** Salto de exigencia respecto al Mundo 1: dos obstáculos de *timing* sobre fosos en B y C sin red.
7. **Mejora visual.** El fondo es muy detallado y luminoso; el borde superior del terreno y los ríos compiten con él (captura). Oscurecer ligeramente la capa lejana del parallax.
8. **Nuevos obstáculos.** Superficie que cambia de color al dispararle con el Lanzapintura (usa la mecánica del arma en el entorno).
9. **Variación de enemigos.** Un Pincel que pinte el suelo de rosa (frena a Alice) en lugar de dispararle.
10. **Ritmo.** D muy cargada (6 enemigos + lápices, borradores, goteos); E vacía. Repartir.
11. **Jefe: Garabato (48 PV).** Siete ataques en tres fases, cada uno con “!” y destello; pintura en el suelo en la fase 3. Arena de 60 teselas con encuadre doble (`frameBoth`). [M]
12. **Prioridad: Alta** (IMP-010, IMP-008, IMP-026).

---

## 5. Mundo 3 — El Reino de los Peluches Dormilones

**Escena:** `World3.tscn` · **Datos:** `godot/data/world3/world3.json` (`tools/world3/world3_level.py`) · **Jefe:** `ReySieston.tscn`, `scripts/entities/rey_sieston.gd`.

1. **Resumen.** 9 040 px. Juguetes, lana y almohadas; mecánica de sueño que ralentiza.
2. **Características.** 4 cuerdas columpio, 5 plataformas móviles, 3 que se deshacen, 5 almohadas elásticas, 4 ovillos rodantes, 4 nubes de sueño, botón mágico que activa un ascensor; Peluche ×7, Ovillo ×5, Almohada ×6; 3 lunas + 3 botones dorados.
3. **Fortalezas.** La somnolencia ralentiza sin quitar el control (`player.gd`: ×0,72), castigo suave y temático. El botón mágico crea una pequeña “llave‑puerta” espacial. Buena exploración (6 coleccionables repartidos de A a E).
4. **Problemas.**
   - Ovillo (`wool`, embiste) patrullando la plataforma entre dos cuerdas sobre fosos (teselas 117-146): el piloto sin invulnerabilidad cayó 81 veces en las teselas 119 y 144-149; con invulnerabilidad, 0. El golpe + retroceso lanza al foso. [A] → IMP-027.
   - El terreno (bloque azul acolchado con remate rosa) se parece mucho al del Mundo 1 (capturas). [B]
   - Sólo 7 carteles: la cuerda se explica con un cartel en la tesela 106, justo antes de la primera. [M]
5. **Mecánicas desaprovechadas.** El botón mágico aparece una vez (sección D).
6. **Dificultad.** La sección B (cuerdas) es exigente para la primera aparición de la mecánica. C concentra 6 enemigos.
7. **Mejora visual.** Diferenciar el remate del terreno (IMP-038).
8. **Nuevos obstáculos.** Segundo botón mágico que active una plataforma temporal en la sección E.
9. **Variación de enemigos.** Peluche saltarín en lugar del Ovillo junto a fosos; Ovillo en suelo continuo largo, donde su embestida se puede saltar.
10. **Ritmo.** A-B ligeras en enemigos, C-D densas; E con 3 enemigos y 1 almohada: correcto.
11. **Jefe: Rey Siestón (50 PV).** Siete ataques, tres fases, descanso con brillo dorado. Su script (190 líneas) está escrito en un estilo compacto con varias sentencias por línea, distinto al resto, lo que dificulta su mantenimiento (R13). [M]
12. **Prioridad: Alta** (IMP-027, IMP-001).

---

## 6. Mundo 4 — Reino de las Burbujas

**Escena:** `World4.tscn` · **Datos:** `godot/data/world4/world4.json` (`tools/world4/world4_level.py`) · **Jefe:** `ReyPatoburbuja.tscn`, `scripts/entities/rey_patoburbuja.gd`.

1. **Resumen.** 9 040 px; añade el agua con natación como mecánica principal.
2. **Características.** 5 zonas de agua, 3 géiseres, 4 columnas de burbujas, 4 rodillos de esponja, 2 jabones, espuma resbaladiza, 2 rampas, 7 plataformas móviles; Pez Burbuja ×9, Cangrejito ×7, Pompa ×6; 6 coleccionables (3 conchas principales).
3. **Fortalezas.** El mejor resultado del piloto: **completa el nivel sin invulnerabilidad con 5 golpes y ninguna caída repetida**. Sólo 5 fosos; el agua sirve de red. La natación tiene salida fácil a la superficie (ajustes documentados en `WORLD4_REPORT.md`).
4. **Problemas.**
   - Los enemigos no dependen del agua (el Pez Burbuja “nada (o flota)” también en tierra). [M] → IMP-028.
   - El suelo vuelve a ser azul con remate blanco. [B]
5. **Mecánicas desaprovechadas.** Los jabones (2) y la espuma resbaladiza aparecen poco.
6. **Dificultad.** Equilibrada según el piloto; la sección C (7 enemigos) es la más exigente.
7. **Mejora visual.** Contraste entre agua y terreno correcto en la captura; reforzar la línea de superficie del agua.
8. **Nuevos obstáculos.** Corriente submarina horizontal (reutilizando `wind_zone.gd` dentro del agua).
9. **Variación de enemigos.** Pez que salta fuera del agua como aviso antes de disparar.
10. **Ritmo.** El más regular del juego (3-7 enemigos por sección, mecánicas repartidas).
11. **Jefe: Rey Patoburbuja (50 PV).** Ocho ataques; fase 3 con combo encadenado. Mismo PV que el Rey Siestón: la curva de jefes no sube entre 3 y 4. [M]
12. **Prioridad: Baja** (IMP-028, IMP-038).

---

## 7. Mundo 5 — El Reino del Tren de Juguete (archivos `world6`)

**Escena:** `World6.tscn` · **Datos:** `godot/data/world6/world6.json` (`tools/world6/world6_level.py`) · **Script:** `scripts/levels/world6.gd` · **Jefe:** `Locomostro.tscn`, `scripts/entities/locomostro.gd`.

1. **Resumen.** 10 080 px. Trenes de juguete con vías, estaciones, desvíos y campanas; el mundo más original en mecánicas.
2. **Características.** 7 líneas de tren (con ramales y paradas), 2 palancas, 3 campanas, 5 plataformas con hélice, 2 arcos arcoíris, 4 bloques que caen con aviso, 3 ruedas, 2 barreras de estrella, 1 tren peligroso de túnel con señal, 6 bloques de estrella; Bloquecito ×9, Payasito ×7, Vagoncito ×4; 3 billetes dorados.
3. **Fortalezas.** Sistema de trenes propio (`train_line.gd`, 339 líneas) con cámara adaptada al viaje (`world6.gd → update_camera`). Avisos claros (señal roja + silbato antes del tren de túnel; bloques que tiemblan antes de caer). El Vagoncito alterna tres ataques en orden fijo: predecible y aprendible.
4. **Problemas.**
   - **Cruce en tren de la sección E** (foso 560-583, tren 553→591): el piloto no lo supera en 200 s ni con invulnerabilidad; con más tiempo lo consigue tras 49 caídas (313 s). Checkpoint previo a 2 650 px. [A] → IMP-029.
   - Mayor tramo sin checkpoint del juego: 4 480 px (teselas 118→398). [A]
   - El primer cartel se recorta por la izquierda (captura). [A] → IMP-036.
   - 18 carteles. [M]
5. **Mecánicas desaprovechadas.** Las palancas de desvío (2) apenas cambian la ruta; los ramales podrían llevar a zonas secretas.
6. **Dificultad.** Muy dependiente de la sincronía con los trenes; sin checkpoints intermedios un fallo en E es caro.
7. **Mejora visual.** Captura: buena lectura de los trenes sobre el fondo; suelo azul de nube similar a otros mundos.
8. **Nuevos obstáculos.** Un desvío que lleve a una ruta alternativa con billete dorado (refuerza exploración).
9. **Variación de enemigos.** Payasito en un andén durante el viaje (IMP-035).
10. **Ritmo.** C es mayormente espera en tren (59 estrellas, 3 enemigos); D muy densa (7 enemigos + bloques que caen + ruedas). → IMP-035.
11. **Jefe: Locomostro (60 PV).** Embestidas por ruta fija con descanso aturdido, bloques con sombra previa, humo que sólo empuja; “nada es inevitable” según su cabecera. Más PV que el jefe del mundo siguiente (IMP-004). [M]
12. **Prioridad: Alta** (IMP-029, IMP-001, IMP-036).

---

## 8. Mundo 6 — Sueños Cósmicos, Islas en el Cielo (archivos `world5`)

**Escena:** `World5.tscn` · **Datos:** `godot/data/world5/world5.json` (`tools/world5/world5_level.py`) · **Script:** `scripts/levels/world5.gd` · **Jefa:** `LunaEstelar.tscn`, `scripts/entities/luna_estelar.gd`.

1. **Resumen.** 9 552 px. Islas flotantes, lunas, cohetes y lluvia de meteoros.
2. **Características.** Estrellas sólidas y trampolín, lunas fijas/móviles/en órbita (2 órbitas), 2 toboganes arcoíris, 3 cohetes, 2 cascadas de luz, 6 estrellas que caen con aviso, 5 nubes explosivas; Estrellita ×13, Cohetito ×8, Meteorito ×9; 6 coleccionables.
3. **Fortalezas.** Gran variedad de mecánicas de movimiento (tobogán con control parcial, cascadas que elevan). El piloto lo completa sin invulnerabilidad con 3 golpes (77 s).
4. **Problemas.**
   - Sección D con 12 enemigos, 6 estrellas que caen y 5 nubes explosivas: el pico de densidad del juego. [M] → IMP-030.
   - Las nubes explosivas aparecen por primera vez en esa sección cargada. [M]
   - Estrellas recogibles poco distinguibles de la decoración estelar (captura). [B] → IMP-039.
   - Tras el cambio de numeración, es el mundo más denso y su jefa tiene menos PV que el jefe anterior. [A] → IMP-004.
5. **Mecánicas desaprovechadas.** Las lunas en órbita (2) y los cohetes ascensor tienen pocas apariciones.
6. **Dificultad.** Baja para el piloto; posible saturación visual para una persona (no verificado).
7. **Mejora visual.** Reducir estrellas decorativas amarillas en primer plano o cambiar su tono.
8. **Nuevos obstáculos.** Gravedad reducida en una isla (reutilizar `WATER_GRAVITY` sin natación) — sólo si se valida en IMP-034.
9. **Variación de enemigos.** Separar los grupos de Estrellitas (teselas 292-298 y 317-320) para que cada grupo se lea.
10. **Ritmo.** A-C crecientes, D pico, E tranquila (3 enemigos). Mover carga de D a C.
11. **Jefa: Luna Estelar (50 PV).** Nueve ataques (el repertorio más amplio), fase 3 con anillo de energía y lluvia con huecos marcados. [M]
12. **Prioridad: Media** (IMP-030, IMP-004, IMP-039).

---

## 9. Mundo 7 — El Valle de Caramelo

**Escena:** `World7.tscn` · **Datos:** `godot/data/world7/world7.json` (`tools/world7/world7_level.py`) · **Script:** `scripts/levels/world7.gd` · **Jefe:** `DonChupeton.tscn`, `scripts/entities/don_chupeton.gd`.

1. **Resumen.** 10 496 px. Golosinas: gelatinas, chocolate, correas y una fábrica.
2. **Características.** 28 nubes (gelatinas), 9 superficies (caramelo resbaladizo, chocolate pegajoso), 3 ríos, 4 correas (una invertida), 4 piruletas giratorias, 4 lanzadores, 3 chorros de chocolate, 5 plataformas que se deshacen, 7 bloques de premio, tobogán, **4 corazones**; Gomilito ×6, Cuppy ×8, Piruleta ×6; 5 coleccionables; 298 estrellas.
3. **Fortalezas.** Mejor exploración de la primera mitad del juego (premios, corazones, rutas altas con cereza). El Gomilito se divide en gomitas (`gomilito_mini`): variación real de comportamiento. Con invulnerabilidad, el piloto lo recorre sin caídas (86 s).
4. **Problemas.**
   - 20 carteles; algunos repiten mecánicas de mundos anteriores. [M] → IMP-031.
   - Primer cartel recortado (captura). [A] → IMP-036.
   - Sección D muy cargada de mecánicas a la vez (4 correas, 3 piruletas, 3 lanzadores, 2 chorros, 4 plataformas que se deshacen). [M]
   - Las gelatinas elásticas son la nube elástica del Mundo 1 con otro dibujo (`world7.gd` lo indica): reutilización correcta, pero poco nueva. [M]
5. **Mecánicas desaprovechadas.** La correa invertida aparece una vez.
6. **Dificultad.** Sin invulnerabilidad el piloto se queda en la tesela 382 por golpes (teselas 277 y 349, junto a las Piruletas Voladoras de las teselas 280 y 353, en el río de chocolate y el inicio de la fábrica); no hay caídas repetidas.
7. **Mejora visual.** Captura con buena paleta propia (marrón/rosa); la mejor diferenciación de suelo junto al Mundo 8.
8. **Nuevos obstáculos.** Chocolate que se endurece por ciclos (plataforma temporal) en el río.
9. **Variación de enemigos.** Cuppy que deja glaseado en el suelo (frena) al rodar.
10. **Ritmo.** D saturada; E con 4 enemigos y lanzadores: final exigente pero coherente.
11. **Jefe: Don Chupetón (65 PV).** Nueve ataques; el giro se esquiva subiendo a las nubes de crema; glaseado con marca previa. [M]
12. **Prioridad: Media** (IMP-031, IMP-036, IMP-001).

---

## 10. Mundo 8 — El Castillo de las Pesadillas (final)

**Escena:** `World8.tscn` · **Datos:** `godot/data/world8/world8.json` (`tools/world8/world8_level.py`) · **Scripts:** `scripts/levels/world8.gd`, `scripts/levels/world8_boss_arena.gd` · **Jefe:** `ReyPesadelo.tscn`, `scripts/entities/rey_pesadelo.gd` · **Final:** `scenes/cinematics/*.tscn`.

1. **Resumen.** 10 000 px en cinco secciones + el Trono (F) en una arena de 125 teselas. Cierra la historia.
2. **Características.** 5 plataformas fantasma con aviso, 3 plataformas colgantes, 5 estrellas que caen, 6 plataformas que se caen, setas elásticas, 5 zonas de sombra (daño por intervalo), 4 ganchos, 2 faroles que revelan 3 puentes ocultos, llave + cofre, 3 recuerdos con visión de los mundos anteriores, 6 corazones; Fantasmita ×9, Bloquito Sombra ×8, Murcibola ×7; 3 checkpoints.
3. **Fortalezas.** El mundo más rico en exploración (8 coleccionables con funciones distintas). Los recuerdos (`world8.gd → MEMORIES`) conectan con los mundos anteriores usando sus sprites. Enemigos con aviso claro (farol levantado, encogerse antes de la picada) y el Bloquito Sombra exige cambiar de táctica (barrera). Final completo y emotivo (transformación, abrazo, despertar, créditos).
4. **Problemas.**
   - **Bloqueo del piloto en la sección B**: plataformas colgantes sobre el foso 128-143, con pinchos antes y el primer checkpoint **después** (tesela 150). 99 caídas con invulnerabilidad; reproducible. Contradice `WORLD8_REPORT.md`. [A] → IMP-037.
   - Primer cartel recortado (captura). [A]
   - 20 carteles. [M]
   - La arena recarga entera si Alice cae: en el jefe más largo (80 PV) obliga a repetir fases. [M] → IMP-032.
   - Paleta nocturna con fondo muy iluminado: los enemigos violetas pueden perder contraste (captura). [B]
5. **Mecánicas desaprovechadas.** Los ganchos (4) se concentran en D; los faroles (2) sólo en E.
6. **Dificultad.** El salto de exigencia más brusco del juego ocurre al principio (sección B), no al final.
7. **Mejora visual.** Contorno claro de 1 px en enemigos violetas o aclarar la capa media del parallax.
8. **Nuevos obstáculos.** Farol que hay que mantener encendido disparándole (usa el Lanzapintura).
9. **Variación de enemigos.** Fantasmita que sólo es visible a la luz de un farol, en la sección E.
10. **Ritmo.** A y B empiezan fuerte; C con 7 enemigos y sombras; D-E con exploración. Suavizar B.
11. **Jefe: Rey Pesadelo (80 PV).** Máquina de estados explícita (INTRO → IDLE → MOVE → TELEGRAPH → ataque → STUNNED), cuatro ataques más combo, la nube ralentizadora nunca se combina con el grito; fase 2 oscurece el cielo y añade estrellas con aviso; música de furia en fase 3; derrota → transformación en gato. El combate mejor estructurado del juego [M]. Recibe daño fuera de STUNNED (IMP-005).
12. **Prioridad: Alta** (IMP-037, IMP-001, IMP-032, IMP-036).

---

## 11. Coherencia entre mundos

| Aspecto | Observación | Propuesta |
|---|---|---|
| Identidad por mundo | Cada mundo tiene enemigos, jefe y mecánicas propias: no hay mundos “recoloreados”. Lo más reutilizado es la nube elástica (gelatina en el 7, seta en el 8) y los bloques de premio (5 y 7) | Mantener |
| Terreno | 5 de 8 mundos con suelo azul de bloques | IMP-038 |
| Curva de jefes (PV) | 40 → 48 → 50 → 50 → **60 → 50** → 65 → 80 | IMP-004 |
| Curva de densidad | 1,7 → 1,8 → 2,0 → 2,4 → 2,0 → **3,1** → 1,9 → 2,4 | IMP-004, IMP-030 |
| Agresividad enemiga | Decrece | IMP-007 |
| Mundo con mejor equilibrio observado | Mundo 4 | Usar como referencia de ritmo |
