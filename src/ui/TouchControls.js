import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';
import { VirtualPad } from '../systems/InputController.js';
import { pixelText } from './PixelFont.js';

/**
 * Botones virtuales para pantallas táctiles.  Escriben en VirtualPad, que
 * InputController lee igual que el teclado.  Cada botón admite su propio dedo
 * (multitáctil), así se puede correr, saltar y disparar a la vez.
 */
export class TouchControls {
  constructor(scene) {
    this.scene = scene;
    this.pad = VirtualPad.get(scene.game);
    this.buttons = [];
    const H = GAME_HEIGHT;
    const W = GAME_WIDTH;
    const r = 17;
    this.make(30, H - 30, r, '[', 'left', true);
    this.make(76, H - 30, r, ']', 'right', true);
    this.make(53, H - 70, 13, '^', 'up', true);
    this.make(W - 34, H - 34, r + 2, 'A', 'jump', true);
    this.make(W - 80, H - 26, r, 'B', 'fire', true);
    this.make(W - 72, H - 70, 14, 'ARMA', 'switch', false);
    this.make(W - 116, H - 22, 14, 'RUN', 'run', true);
    this.make(W - 18, 52, 11, 'II', 'pause', false);
  }

  make(x, y, radius, label, action, holdable, textScale = 1) {
    const s = this.scene;
    const circle = s.add.circle(x, y, radius, 0xfff7ff, 0.35).setStrokeStyle(2, 0x3455a4, 0.7).setScrollFactor(0).setDepth(100);
    const text = pixelText(s, x, y, label, { origin: 0.5, tint: 0x3455a4, scale: textScale }).setDepth(101).setAlpha(0.85);
    circle.setInteractive(new Phaser.Geom.Circle(radius, radius, radius + 6), Phaser.Geom.Circle.Contains);
    const down = () => {
      this.pad.press(action);
      circle.setFillStyle(0xffe082, 0.6);
    };
    const up = () => {
      if (holdable) this.pad.release(action);
      circle.setFillStyle(0xfff7ff, 0.35);
    };
    circle.on('pointerdown', down);
    circle.on('pointerup', up);
    circle.on('pointerout', up);
    this.buttons.push(circle, text);
  }

  destroy() {
    this.pad.releaseAll();
    this.buttons.forEach((b) => b.destroy());
  }
}
