import { WORLD1 } from './world1.js';

/**
 * Registro de mundos.  Los ocho mundos comparten el mismo motor (LevelScene);
 * cada uno sólo necesita su archivo de datos y su escena ligera.
 * De momento sólo el Mundo 1 está implementado; el resto queda reservado.
 */
export const WORLDS = [
  { id: 1, name: WORLD1.name, scene: 'World1', data: WORLD1, implemented: true },
  { id: 2, name: 'Mundo 2', scene: null, implemented: false },
  { id: 3, name: 'Mundo 3', scene: null, implemented: false },
  { id: 4, name: 'Mundo 4', scene: null, implemented: false },
  { id: 5, name: 'Mundo 5', scene: null, implemented: false },
  { id: 6, name: 'Mundo 6', scene: null, implemented: false },
  { id: 7, name: 'Mundo 7', scene: null, implemented: false },
  { id: 8, name: 'Mundo 8', scene: null, implemented: false },
];

/** Estado inicial de una partida nueva en el mundo indicado. */
export function newRunState(world = WORLD1) {
  return {
    stars: 0,
    starsTotal: world.stars.length + (world.boss ? world.boss.stars.length : 0),
    collectedStars: [],
    defeatedEnemies: [],
    weaponsOwned: [],
    weapon: null,
    checkpoint: null,
    hp: 3,
    playTime: 0,
    progress: 0,
    specialStar: false,
    bossVisible: false,
  };
}
