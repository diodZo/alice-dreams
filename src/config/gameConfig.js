import Phaser from 'phaser';
import { BootScene } from '../scenes/BootScene.js';
import { PreloadScene } from '../scenes/PreloadScene.js';
import { MenuScene } from '../scenes/MenuScene.js';
import { World1Scene } from '../scenes/World1Scene.js';
import { BossScene } from '../scenes/BossScene.js';
import { VictoryScene } from '../scenes/VictoryScene.js';
import { PauseScene } from '../scenes/PauseScene.js';
import { GameHUD } from '../ui/GameHUD.js';

/** Resolución lógica: todo el juego se dibuja a 480x270 y se escala sin suavizado. */
export const GAME_WIDTH = 480;
export const GAME_HEIGHT = 270;
export const TILE = 16;
export const GRAVITY = 900;

const params = new URLSearchParams(window.location.search);
export const DEBUG = params.has('debug');
/** Fuerza los botones táctiles en escritorio (útil para probarlos): ?touch=1 */
export const FORCE_TOUCH = params.get('touch') === '1';
/** Fuerza el renderizador Canvas (equipos sin WebGL o pruebas automáticas): ?renderer=canvas */
const RENDERER = params.get('renderer') === 'canvas' ? Phaser.CANVAS : Phaser.AUTO;

/** Profundidades de dibujo compartidas por todas las escenas de nivel. */
export const DEPTH = {
  BG: -100,
  DECOR_BACK: 2,
  TERRAIN: 10,
  PLATFORM: 12,
  PICKUP: 15,
  ENEMY: 20,
  PLAYER: 25,
  PROJECTILE: 30,
  DECOR_FRONT: 35,
  FX: 40,
  UI_WORLD: 50,
};

export function createGameConfig() {
  return {
    type: RENDERER,
    parent: 'game',
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: '#78C5F8',
    pixelArt: true,
    roundPixels: true,
    antialias: false,
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
    },
    physics: {
      default: 'arcade',
      arcade: {
        gravity: { y: GRAVITY },
        debug: DEBUG,
        tileBias: 24,
      },
    },
    input: {
      activePointers: 4,
    },
    render: {
      pixelArt: true,
      roundPixels: true,
    },
    scene: [BootScene, PreloadScene, MenuScene, World1Scene, BossScene, VictoryScene, PauseScene, GameHUD],
  };
}
