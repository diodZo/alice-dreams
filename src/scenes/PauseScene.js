import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';
import { pixelText } from '../ui/PixelFont.js';
import { CloudButton, MenuList } from '../ui/CloudButton.js';
import { AudioManager } from '../systems/AudioManager.js';
import { VirtualPad } from '../systems/InputController.js';

/** Menú de pausa superpuesto a la escena de juego (que queda en pausa). */
export class PauseScene extends Phaser.Scene {
  constructor() {
    super('Pause');
  }

  init(data) {
    this.from = data.from;
  }

  create() {
    this.audio = AudioManager.get(this.game);
    const W = GAME_WIDTH;
    const H = GAME_HEIGHT;
    this.add.rectangle(0, 0, W, H, 0x2a2350, 0.6).setOrigin(0);
    pixelText(this, W / 2, 50, 'Pausa', { origin: 0.5, scale: 2, tint: 0xffe082 });

    const cx = W / 2;
    const buttons = [
      new CloudButton(this, cx, 86, 'Continuar', () => this.resumeGame(), { width: 170 }),
      new CloudButton(this, cx, 112, this.musicLabel(), (b) => {
        this.audio.setMusicEnabled(!this.audio.musicOn);
        b.setLabel(this.musicLabel());
      }, { width: 170 }),
      new CloudButton(this, cx, 138, this.sfxLabel(), (b) => {
        this.audio.setSfxEnabled(!this.audio.sfxOn);
        b.setLabel(this.sfxLabel());
        this.audio.play('ui_select');
      }, { width: 170 }),
      new CloudButton(this, cx, 164, 'Volver al checkpoint', () => this.restartLevel(), { width: 170 }),
      new CloudButton(this, cx, 190, 'Salir al menú', () => this.exitToMenu(), { width: 170 }),
    ];
    new MenuList(this, buttons, this.audio);

    const kb = this.input.keyboard;
    const onKey = (e) => {
      if (e.code === 'Escape' || e.code === 'KeyP') this.resumeGame();
    };
    kb.on('keydown', onKey);
    this.events.once('shutdown', () => kb.off('keydown', onKey));
    // el botón táctil de pausa también reanuda
    this.pad = VirtualPad.get(this.game);
    this.pad.consume('pause');
  }

  update() {
    if (this.pad.consume('pause')) this.resumeGame();
  }

  musicLabel() {
    return `Música: ${this.audio.musicOn ? 'Sí' : 'No'}`;
  }

  sfxLabel() {
    return `Efectos: ${this.audio.sfxOn ? 'Sí' : 'No'}`;
  }

  resumeGame() {
    this.audio.play('pause');
    this.audio.duck(false);
    this.scene.resume(this.from);
    this.scene.stop();
  }

  restartLevel() {
    this.audio.duck(false);
    const level = this.scene.get(this.from);
    this.scene.stop();
    level.restartFromCheckpoint();
  }

  exitToMenu() {
    this.audio.duck(false);
    this.scene.stop(this.from);
    this.scene.stop('HUD');
    this.scene.start('Menu');
  }
}
