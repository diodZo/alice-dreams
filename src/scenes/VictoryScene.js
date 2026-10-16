import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';
import { pixelText } from '../ui/PixelFont.js';
import { CloudButton, MenuList } from '../ui/CloudButton.js';
import { AudioManager } from '../systems/AudioManager.js';
import { EffectsManager } from '../systems/EffectsManager.js';
import { WORLD1 } from '../data/world1.js';
import { newRunState } from '../data/worlds.js';

/** Pantalla de victoria del Mundo 1 (el progreso ya se guardó al cruzar el portal). */
export class VictoryScene extends Phaser.Scene {
  constructor() {
    super('Victory');
  }

  init(data) {
    this.stats = data || {};
  }

  create() {
    this.audio = AudioManager.get(this.game);
    this.audio.playMusic('menu');
    const W = GAME_WIDTH;
    const H = GAME_HEIGHT;
    this.add.image(0, 0, 'sky').setOrigin(0);
    const near = this.textures.get('clouds_near').getSourceImage();
    this.clouds = this.add.tileSprite(0, H - near.height + 24, W, near.height, 'clouds_near').setOrigin(0);
    this.effects = new EffectsManager(this);

    pixelText(this, W / 2, 28, '¡Mundo 1 completado!', { origin: 0.5, scale: 2, tint: 0xffe082 });
    pixelText(this, W / 2, 50, 'Nubarrón vuelve a ser una nube feliz', { origin: 0.5, tint: 0xfff7ff });

    this.add.sprite(110, 190, 'player', 'victory_0').setOrigin(0.5, 1).setScale(2).play('player_victory');
    const cloud = this.add.sprite(W - 52, 150, 'nubarron', 'idle_1').setScale(0.5);
    this.tweens.add({ targets: cloud, y: 144, duration: 1000, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });

    const s = this.stats;
    const secs = Math.floor((s.time || 0) / 1000);
    const time = `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}`;
    const lines = [
      `Estrellas: ${s.stars ?? 0} de ${s.total ?? 0}`,
      `Estrella dorada especial: ${s.special ? 'conseguida' : 'no'}`,
      `Tiempo: ${time}`,
      'Portal al Mundo 2: abierto (próximamente)',
    ];
    pixelText(this, W / 2 + 10, 76, lines.join('\n'), { origin: [0.5, 0], tint: 0xfff7ff, align: 'center' });

    const buttons = [
      new CloudButton(this, W / 2 + 10, 150, 'Jugar otra vez', () => this.replay(), { width: 150 }),
      new CloudButton(this, W / 2 + 10, 176, 'Menú principal', () => this.scene.start('Menu'), { width: 150 }),
    ];
    new MenuList(this, buttons, this.audio);

    this.effects.confetti(W / 2, 20, 90);
    this.time.addEvent({ delay: 1600, loop: true, callback: () => this.effects.confetti(Phaser.Math.Between(60, W - 60), 10, 40) });
    this.cameras.main.fadeIn(600, 255, 247, 255);
  }

  replay() {
    const run = newRunState(WORLD1);
    for (const [k, v] of Object.entries(run)) this.registry.set(k, v);
    this.scene.start('World1', { introBanner: true });
  }

  update(time, delta) {
    this.clouds.tilePositionX += delta * 0.012;
  }
}
