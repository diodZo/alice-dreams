import Phaser from 'phaser';
import { registerPixelFont } from '../ui/PixelFont.js';
import { AudioManager } from '../systems/AudioManager.js';

/** Prepara lo mínimo para la pantalla de carga: fuente pixel y manifest de recursos. */
export class BootScene extends Phaser.Scene {
  constructor() {
    super('Boot');
  }

  preload() {
    this.load.json('manifest', 'assets/manifest.json');
  }

  create() {
    registerPixelFont(this);
    AudioManager.get(this.game);
    // Los navegadores sólo permiten audio tras un gesto: se reanuda en la primera interacción.
    const unlock = () => AudioManager.get(this.game).ensureContext();
    this.input.on('pointerdown', unlock);
    this.input.keyboard.on('keydown', unlock);
    window.addEventListener('pointerdown', unlock, { once: true });
    window.addEventListener('keydown', unlock, { once: true });
    this.scene.start('Preload');
  }
}
