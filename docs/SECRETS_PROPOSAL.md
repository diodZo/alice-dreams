# Propuesta — Rutas secretas con recompensa (IMP-018)

> Pendiente de aprobación del autor. No hay nada implementado. Criterio de aceptación de [`LEVEL_IMPROVEMENTS.md`](LEVEL_IMPROVEMENTS.md#imp-018): cada mundo tiene ≥1 secreto señalado por una pista visual (no por cartel); el extra se desbloquea y se guarda.

## 1. Idea

Un **fragmento de sueño** escondido en cada mundo (8 en total), en una ruta alta u oculta de las secciones C o D. Al reunir los 8 se desbloquea un **extra en el menú: la Galería de jefes**, con los ocho jefes en su forma tierna (sprites que ya existen) y una frase de cada uno.

Por qué así:

- **Recompensa tangible y visible** desde el menú, no sólo una estrella más.
- **Reutiliza lo que hay:** el fragmento es un coleccionable del sueño más (`dreamCollectibles`, `kind: "fragment"`), así que ya se recoge, se guarda al completar el mundo, sale en el HUD y en la página del Diario de Sueños («secretos»). Los Mundos 3-8 ya tienen rutas altas: sólo se añade el fragmento.
- **Sin carteles:** la pista es visual (ver §3).

## 2. Dónde (una por mundo)

| Mundo | Sección | Lugar propuesto | Qué hay ya |
|---|---|---|---|
| 1 | D | Plataforma alta de las teselas 332-340 (fila 13), tesela ≈338 | La corriente de aire de la tesela 321 sube hasta allí; corazón en la 335 |
| 2 | C | Ruta alta del crayón azul, tesela ≈256 (fila 8) | Crayón mágico azul (tesela 252) |
| 3 | C | Secreto tras la almohada (nube móvil 303, fila 12), tesela ≈308 | Ruta secreta ya diseñada |
| 4 | C | Ruta alta del canal (corriente 255, nube 269), tesela ≈272 | Concha 2 (tesela 264) |
| 5 | D | Ruta alta del billete 3 (plataforma vertical 431), tesela ≈446 | Billete dorado 3 (tesela 442) |
| 6 | C | Ruta alta de la estrella especial, tesela ≈322 | Estrella especial (tesela 319) |
| 7 | D | Estante de galletas (ruta alta), tesela ≈476 | Caramelo 3 (tesela 471) |
| 8 | C | Ruta secreta de la seta violeta, tesela ≈333 | Orbe especial (tesela 328) |

Las posiciones exactas se comprobarían con el piloto automático y una captura de cada una (alcanzable, no dentro del terreno, sin peligro de caída sin red).

## 3. Pista visual (sin carteles)

- El fragmento **brilla y late** (como la estrella especial) y se ve desde el camino principal.
- Un **rastro de tres destellos** pequeños que parpadean marca por dónde se sube (la corriente, la seta o la plataforma que lleva a la ruta).
- Al recogerlo: el aviso de coleccionable que ya existe («¡Fragmento de sueño 1 de 8!»).

## 4. El extra: Galería de jefes

- Botón «Galería» al final del menú principal, visible sólo con los 8 fragmentos (como «Ver el final», que aparece al terminar la aventura).
- Una pantalla con los 8 jefes en su forma tierna (`bossFrames` de `WorldRegistry`), su nombre y una línea («Nubarrón volvió a ser una nube feliz»). Navegable con teclado, mando y táctil, y Esc para volver.
- El desbloqueo se calcula del guardado (fragmentos de los mundos completados), sin campo nuevo obligatorio: los guardados antiguos cargan igual.

## 5. Efectos secundarios

- Los Mundos 1 y 2 pasan a tener coleccionables del sueño: la victoria mostrará «Tesoros del sueño: X de 1» en ellos.
- Los recuentos de coleccionables de los Mundos 3-8 suben en 1 (pruebas `test_wN_data` a actualizar).
- El fragmento sólo cuenta si se completa el mundo (igual que los demás coleccionables).

## 6. Decisiones para el autor

1. ¿Te vale la **Galería de jefes** como extra, u otra cosa (p. ej. un traje de Alice, que necesitaría sprites nuevos)?
2. ¿Un fragmento por mundo (8) o uno por sección C **y** D (16)?
3. ¿Las ubicaciones de §2 te parecen bien, o prefieres otras en algún mundo?
4. ¿Los fragmentos deben verse en el Diario de Sueños como «secreto encontrado»?
