/**
 * MUNDO 1 — El Reino de las Nubes de Algodón.
 *
 * Sólo datos: el motor (LevelBuilder + LevelScene) los interpreta.  Para crear otro
 * mundo basta con escribir otro archivo con la misma forma.
 *
 * Unidades: x, y, w, h en TESELAS de 16 px salvo que se indique "px".
 *  - Para objetos apoyados en el suelo, `y` es la fila de la superficie (los pies
 *    quedan en y*16).
 *  - El mundo jugable mide 475 x 25 teselas (7.600 x 400 px); los últimos 400 px
 *    hasta los 8.000 del recorrido son la arena del jefe (BossScene).
 */

const ROWS = 25;
/** Suelo que llega hasta el fondo del mundo. */
const g = (x, w, top = 20) => ({ x, y: top, w, h: ROWS - top });
/** Fila de estrellas. */
const row = (x, y, n, step = 1) => Array.from({ length: n }, (_, i) => ({ x: x + i * step, y }));
/** Arco de estrellas sobre un hueco. */
const arc = (x, y, n, height = 2) =>
  Array.from({ length: n }, (_, i) => ({
    x: x + i,
    y: y - Math.round(Math.sin((Math.PI * i) / (n - 1)) * height),
  }));

export const WORLD1 = {
  id: 1,
  key: 'world1',
  name: 'El Reino de las Nubes de Algodón',
  widthTiles: 475,
  heightTiles: ROWS,
  music: 'world1',
  tileset: 'world1_tiles',
  objectsAtlas: 'world1_objects',
  backgroundAtlas: 'world1_bg',
  progress: { total: 8000, offset: 0, scale: 1 },
  playerStart: { x: 3, y: 20 },
  nextScene: 'Boss',

  sections: [
    { id: 'A', name: 'Bienvenida', from: 0 },
    { id: 'B', name: 'Jardines de algodón', from: 1200 },
    { id: 'C', name: 'Puentes del arcoíris', from: 2800 },
    { id: 'D', name: 'Cascadas de sueños', from: 4500 },
    { id: 'E', name: 'Castillo de Nubarrón', from: 6500 },
  ],

  terrain: [
    // A — Bienvenida
    g(0, 30),
    g(18, 6, 18),
    g(33, 22),
    // A/B
    g(58, 40),
    f(88, 17, 6, 8),
    // B — Jardines de algodón (puente arcoíris 98-104)
    g(104, 56),
    f(109, 17, 4, 3),
    g(163, 19, 19),
    // C — Puentes del arcoíris (plataforma móvil 182-200, puente 212-226)
    g(200, 12, 19),
    g(226, 19, 19),
    g(256, 30, 19),
    // D — Cascadas de sueños (nubes que se deshacen 286-306, corriente 320-332)
    g(306, 14, 19),
    g(332, 9, 13),
    g(341, 29, 19),
    g(377, 18, 16),
    // D/E — llegada al castillo
    g(395, 80, 19),
  ],

  blocks: [
    { x: 13, y: 19, type: 'block_stripe_yellow' },
    { x: 44, y: 17, type: 'block_star' },
    { x: 45, y: 17, type: 'block_star' },
    { x: 46, y: 17, type: 'block_star' },
    { x: 70, y: 17, type: 'block_pink' },
    { x: 71, y: 17, type: 'block_blue' },
    { x: 72, y: 17, type: 'block_pink' },
    { x: 232, y: 18, type: 'block_swirl_pink' },
    { x: 232, y: 17, type: 'block_swirl_pink' },
    { x: 233, y: 18, type: 'block_swirl_blue' },
    { x: 418, y: 18, type: 'block_swirl_purple' },
    { x: 419, y: 18, type: 'block_swirl_purple' },
    { x: 419, y: 17, type: 'block_swirl_purple' },
    { x: 446, y: 15, type: 'block_heart' },
    { x: 447, y: 15, type: 'block_star' },
    { x: 448, y: 15, type: 'block_heart' },
  ],

  // Nubes con colisión unidireccional (se atraviesan desde abajo). x = centro, y = superficie.
  clouds: [
    { x: 38, y: 16, frame: 'cloud_small' },
    { x: 85, y: 18, frame: 'cloud_small' },
    { x: 119, y: 17, frame: 'cloud_small' },
    { x: 124, y: 14, frame: 'cloud_med' },
    { x: 131, y: 11, frame: 'cloud_long' },
    { x: 180, y: 16, frame: 'cloud_small' },
    { x: 262, y: 16, frame: 'cloud_small' },
    { x: 364, y: 9, frame: 'cloud_long' },
    // nube elástica sobre el hueco 370-377
    { x: 374, y: 21, frame: 'cloud_face', bouncy: -540 },
  ],

  bridges: [
    { x: 98, y: 20, w: 6 },
    { x: 183, y: 13, w: 13 },
    { x: 212, y: 19, w: 14 },
    { x: 265, y: 13, w: 9 },
  ],

  movers: [
    { x: 184, y: 19, frame: 'cloud_face_small', dx: 13, dy: 0, duration: 3400 },
    { x: 247, y: 19, frame: 'cloud_face_small', dx: 7, dy: 0, duration: 2600 },
  ],

  crumbles: [
    { x: 289, y: 18 },
    { x: 294, y: 17 },
    { x: 299, y: 18 },
    { x: 303, y: 17 },
  ],

  pads: [{ x: 360, y: 19, power: -600 }],

  winds: [{ x: 321, y: 5, w: 10, h: 20, force: 1500, maxUp: 190 }],

  hazards: [
    { x: 216, y: 14, frame: 'spiky_bubble', dy: 4, duration: 1500, delay: 0 },
    { x: 222, y: 14, frame: 'spiky_bubble', dy: 4, duration: 1500, delay: 750 },
  ],

  stars: [
    // A
    ...row(6, 19, 5),
    ...arc(30, 18, 4),
    ...row(37, 14, 3),
    ...row(44, 16, 3),
    ...arc(55, 18, 4),
    ...row(64, 19, 4),
    ...row(70, 16, 3),
    // B
    ...row(78, 17, 2),
    ...row(89, 16, 4),
    ...row(98, 18, 6),
    ...row(129, 10, 5),
    ...row(147, 19, 4),
    ...arc(160, 18, 4),
    // C
    ...row(185, 12, 10),
    ...row(201, 18, 3),
    ...row(213, 17, 3),
    ...row(223, 17, 3),
    ...row(237, 18, 3),
    ...row(266, 12, 8),
    ...row(277, 18, 3),
    // D
    ...arc(288, 16, 16, 2),
    ...row(310, 18, 3),
    ...row(323, 9, 3),
    ...row(325, 7, 3),
    ...row(362, 8, 6),
    ...arc(370, 18, 7, 3),
    ...row(382, 15, 4),
    // E
    ...row(400, 18, 4),
    ...row(446, 14, 3),
    ...row(452, 18, 5),
  ],

  enemies: [
    { type: 'scratch', x: 50, y: 20, patrol: [47, 54] },
    { type: 'scratch', x: 91, y: 17, patrol: [89, 93] },
    { type: 'scratch', x: 116, y: 20, patrol: [112, 124] },
    { type: 'scratch', x: 152, y: 20, patrol: [144, 158] },
    { type: 'spit', x: 209, y: 19, patrol: [204, 211] },
    { type: 'spit', x: 241, y: 19, patrol: [236, 244] },
    { type: 'spit', x: 270, y: 19, patrol: [262, 276] },
    { type: 'flea', x: 316, y: 19, patrol: [311, 319] },
    { type: 'flea', x: 353, y: 19, patrol: [346, 358] },
    { type: 'flea', x: 393, y: 16, patrol: [389, 394] },
    { type: 'scratch', x: 412, y: 19, patrol: [407, 416] },
    { type: 'spit', x: 428, y: 19, patrol: [422, 433] },
    { type: 'flea', x: 440, y: 19, patrol: [436, 444] },
  ],

  // IMP-001: uno por sección (o a <= 320 px de su entrada) y ningún tramo > 2.500 px; el de la
  // tesela 229 queda antes de la nube móvil sobre el foso 245-255
  // IMP-011: corazones recogibles (una vida si falta alguna)
  hearts: [
    { x: 262, y: 18, atlas: 'fx', frame: 'heart_full', scale: 1.5 },
    { x: 335, y: 12, atlas: 'fx', frame: 'heart_full', scale: 1.5 },
    { x: 422, y: 18, atlas: 'fx', frame: 'heart_full', scale: 1.5 },
  ],

  checkpoints: [
    { x: 138, y: 20 },
    { x: 229, y: 19 },
    { x: 367, y: 19 },
    { x: 401, y: 19 },
  ],

  pickups: [
    { x: 78, y: 20, weapon: 'bubble' },
    { x: 177, y: 19, weapon: 'paint' },
    { x: 283, y: 19, weapon: 'sling' },
  ],

  signs: [
    { x: 5, y: 20, text: 'A / D o flechas: caminar', touch: 'Botones [ ]: caminar' },
    { x: 11, y: 20, text: 'ESPACIO: saltar. Mantén pulsado para saltar más alto', touch: 'Botón A: saltar. Mantén pulsado para saltar más alto' },
    { x: 26, y: 20, text: 'Mantén SHIFT para correr y saltar más lejos', touch: 'Mantén CORRER para ir más rápido y saltar más lejos' },
    { x: 41, y: 20, text: 'Salta sobre los monstruos para aturdirlos' },
    { x: 61, y: 20, text: 'Las estrellas son tesoros del sueño: ¡recógelas!' },
    { x: 75, y: 20, text: '¡Lanzaburbujas! J: disparar. Atrapa monstruos y tócalos para volverlos estrellas', touch: '¡Lanzaburbujas! Botón B: disparar. Atrapa monstruos y tócalos para volverlos estrellas' },
    { x: 135, y: 20, text: 'Las banderas guardan tu avance' },
    { x: 174, y: 19, text: '¡Lanzapintura! K: cambiar de arma. W o flecha arriba + J: disparar hacia arriba', touch: '¡Lanzapintura! Botón ARMA: cambiar de arma. ^ + B: disparar hacia arriba' },
    { x: 281, y: 19, text: '¡Tirachinas! Disparo fuerte en arco. Las nubes de vapor se deshacen: ¡no te pares!' },
    { x: 317, y: 19, text: 'Las corrientes de aire te elevan: ¡déjate llevar!' },
    { x: 357, y: 19, text: 'Salta en el cojín de burbujas para llegar muy alto' },
    { x: 369, y: 19, text: 'La nube elástica te hará rebotar' },
    { x: 457, y: 19, text: 'Castillo de Nubarrón. ¡Prepárate!' },
  ],

  decor: [
    // A
    { x: 2, y: 20, frame: 'tree_big' },
    { x: 8, y: 20, frame: 'flowers_a' },
    { x: 16, y: 20, frame: 'bush_a' },
    { x: 21, y: 18, frame: 'fence_long' },
    { x: 28, y: 20, frame: 'lollipop_pink', sway: true },
    { x: 35, y: 20, frame: 'bush_eggs' },
    { x: 48, y: 20, frame: 'tree_small' },
    { x: 53, y: 20, frame: 'flowers_b', front: true },
    { x: 59, y: 20, frame: 'pinwheel_big', sway: true },
    { x: 66, y: 20, frame: 'tree_med' },
    // B
    { x: 81, y: 20, frame: 'tree_big' },
    { x: 86, y: 20, frame: 'bush_b', front: true },
    { x: 91, y: 17, frame: 'tree_small' },
    { x: 106, y: 20, frame: 'fence_med' },
    { x: 113, y: 20, frame: 'tree_big' },
    { x: 121, y: 20, frame: 'flowers_a', front: true },
    { x: 127, y: 20, frame: 'tree_med' },
    { x: 140, y: 20, frame: 'lollipops', sway: true },
    { x: 145, y: 20, frame: 'bush_c' },
    { x: 155, y: 20, frame: 'tree_big' },
    { x: 167, y: 19, frame: 'tree_small' },
    // C
    { x: 171, y: 19, frame: 'pinwheel_small', sway: true },
    { x: 203, y: 19, frame: 'lollipop_pink', sway: true },
    { x: 208, y: 19, frame: 'egg_pink' },
    { x: 229, y: 19, frame: 'egg_mound' },
    { x: 243, y: 19, frame: 'pinwheel_big', sway: true },
    { x: 259, y: 19, frame: 'egg_blue' },
    { x: 273, y: 19, frame: 'lollipops', sway: true },
    { x: 280, y: 19, frame: 'crystals' },
    // D
    { x: 287, y: 24, frame: 'waterfall_big', shimmer: true },
    { x: 300, y: 25, frame: 'waterfall_a', shimmer: true },
    { x: 308, y: 19, frame: 'bush_eggs' },
    { x: 313, y: 19, frame: 'egg_purple' },
    { x: 334, y: 13, frame: 'pinwheel_small', sway: true },
    { x: 339, y: 13, frame: 'flowers_b' },
    { x: 345, y: 19, frame: 'egg_rainbow' },
    { x: 349, y: 19, frame: 'waterfall_b', shimmer: true, back: true },
    { x: 380, y: 16, frame: 'tree_med' },
    { x: 392, y: 16, frame: 'egg_green' },
    // E
    { x: 398, y: 19, frame: 'fence_long' },
    { x: 404, y: 19, frame: 'lollipop_pink', sway: true },
    { x: 424, y: 19, frame: 'egg_yellow' },
    { x: 434, y: 19, frame: 'pinwheel_big', sway: true },
    { x: 443, y: 19, frame: 'crystals' },
    { x: 451, y: 19, frame: 'fence_med' },
    { x: 461, y: 19, frame: 'lollipops', sway: true },
  ],

  // Entrada al castillo: al tocarla empieza la batalla (BossScene).
  door: { x: 468, y: 19 },
};

/** Fragmento flotante con base redondeada (no llega al fondo del mundo). */
function f(x, y, w, h) {
  return { x, y, w, h };
}

/** Arena del jefe (BossScene).  Representa los píxeles 7.600-8.000 del recorrido. */
WORLD1.boss = {
  key: 'world1_boss',
  widthTiles: 40,
  heightTiles: 17,
  music: 'world1',
  bossMusic: 'boss',
  tileset: 'world1_tiles',
  objectsAtlas: 'world1_objects',
  backgroundAtlas: 'world1_bg',
  progress: { total: 8000, offset: 7600, scale: 400 / 640 },
  playerStart: { x: 2, y: 14 },
  sections: [{ id: 'E', name: 'Castillo de Nubarrón', from: 6500 }],
  terrain: [{ x: 0, y: 14, w: 40, h: 3 }],
  blocks: [],
  clouds: [
    { x: 11, y: 10, frame: 'cloud_med' },
    { x: 29, y: 10, frame: 'cloud_med' },
  ],
  bridges: [],
  movers: [],
  crumbles: [],
  pads: [],
  winds: [],
  hazards: [],
  stars: [...row(14, 13, 3), ...row(24, 13, 3)],
  enemies: [],
  checkpoints: [],
  pickups: [],
  signs: [],
  decor: [
    { x: 1, y: 14, frame: 'lollipops', sway: true },
    { x: 38, y: 14, frame: 'pinwheel_big', sway: true },
    { x: 20, y: 14, frame: 'flowers_a', front: true },
  ],
  // Puerta que se cierra a la espalda de la protagonista al empezar el combate
  gate: { x: 5, rows: [10, 11, 12, 13], tile: 'block_swirl_purple' },
  triggerX: 9,
  boss: { homeX: 28, homeY: 150, minX: 8, maxX: 38, floorY: 224 },
  portal: { x: 37, y: 14 },
};
