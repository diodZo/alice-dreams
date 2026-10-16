import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';
import { pixelText } from '../ui/PixelFont.js';
import { CloudButton, MenuList } from '../ui/CloudButton.js';
import { AudioManager } from '../systems/AudioManager.js';
import { SaveManager } from '../systems/SaveManager.js';
import { PlaceholderFactory } from '../systems/PlaceholderFactory.js';
import { WORLD1 } from '../data/world1.js';
import { newRunState } from '../data/worlds.js';

/** Pantalla de título. */
export class MenuScene extends Phaser.Scene {
  constructor() {
    super('Menu');
  }

  create() {
    // Phaser reutiliza la instancia de la escena: el estado se reinicia en cada create()
    this.starting = false;
    this.resetArmed = false;
    this.audio = AudioManager.get(this.game);
    this.audio.playMusic('menu');
    const W = GAME_WIDTH;
    const H = GAME_HEIGHT;

    this.add.image(0, 0, 'sky').setOrigin(0);
    this.add.image(W / 2 + 120, 120, 'world1_bg', 'castle').setAlpha(0.9);
    this.add.image(70, 92, 'world1_bg', 'island_big').setScale(0.8);
    const far = this.textures.get('clouds_far').getSourceImage();
    this.cloudsFar = this.add.tileSprite(0, H - far.height + 10, W, far.height, 'clouds_far').setOrigin(0);
    const near = this.textures.get('clouds_near').getSourceImage();
    this.cloudsNear = this.add.tileSprite(0, H - near.height + 24, W, near.height, 'clouds_near').setOrigin(0);

    const title = pixelText(this, W / 2, 26, 'Guardiana de los Sueños', { origin: 0.5, scale: 2, tint: 0xffe082 });
    this.tweens.add({ targets: title, y: 29, duration: 1200, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    pixelText(this, W / 2, 50, `Mundo 1: ${WORLD1.name}`, { origin: 0.5, tint: 0xfff7ff });

    // personajes
    this.add.sprite(60, H - 8, 'player', 'idle_0').setOrigin(0.5, 1).setScale(2).play('player_idle');
    this.add.sprite(W - 120, H - 6, 'scratch').setOrigin(0.5, 1).play('scratch_idle');
    this.add.sprite(W - 86, H - 6, 'spit').setOrigin(0.5, 1).play('spit_idle').setFlipX(true);
    this.add.sprite(W - 52, H - 6, 'flea').setOrigin(0.5, 1).play('flea_idle').setFlipX(true);
    const boss = this.add.sprite(W - 80, 92, 'nubarron').setScale(0.6).play('nubarron_idle').setFlipX(true);
    this.tweens.add({ targets: boss, y: 98, duration: 1500, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });

    // progreso guardado
    const w1 = SaveManager.getWorld(1);
    if (w1?.completed) {
      pixelText(this, W / 2, 62, `* Mundo 1 completado - Mejor marca: ${w1.bestStars} estrellas *`, { origin: 0.5, tint: 0xffe082 });
    }

    const cx = W / 2;
    this.buttons = [
      new CloudButton(this, cx, 88, 'Jugar', () => this.startGame()),
      new CloudButton(this, cx, 114, this.musicLabel(), (b) => {
        this.audio.setMusicEnabled(!this.audio.musicOn);
        b.setLabel(this.musicLabel());
        this.audio.play('ui_select');
      }),
      new CloudButton(this, cx, 140, this.sfxLabel(), (b) => {
        this.audio.setSfxEnabled(!this.audio.sfxOn);
        b.setLabel(this.sfxLabel());
        this.audio.play('ui_select');
      }),
      new CloudButton(this, cx, 166, 'Borrar progreso', (b) => this.confirmReset(b)),
    ];
    this.menu = new MenuList(this, this.buttons, this.audio);

    pixelText(
      this,
      W / 2,
      198,
      'A/D: mover - ESPACIO: saltar - SHIFT: correr\nJ: disparar - K: arma - W+J: arriba - ESC: pausa',
      { origin: 0.5, tint: 0xfff7ff, align: 'center' },
    );

    if (PlaceholderFactory.used.size > 0) {
      pixelText(this, 4, H - 12, `Aviso: ${PlaceholderFactory.used.size} recurso(s) provisional(es). Ver consola.`, { tint: 0xff8080 });
    }
    if (!SaveManager.isStorageAvailable()) {
      pixelText(this, 4, 4, 'Aviso: el navegador no permite guardar el progreso', { tint: 0xff8080 });
    }
    this.cameras.main.fadeIn(400, 52, 85, 164);
  }

  musicLabel() {
    return `Música: ${this.audio.musicOn ? 'Sí' : 'No'}`;
  }

  sfxLabel() {
    return `Efectos: ${this.audio.sfxOn ? 'Sí' : 'No'}`;
  }

  confirmReset(btn) {
    if (!this.resetArmed) {
      this.resetArmed = true;
      btn.setLabel('¿Seguro? Pulsa otra vez');
      this.audio.play('ui_move');
      this.time.delayedCall(3000, () => {
        if (!btn.active) return;
        this.resetArmed = false;
        btn.setLabel('Borrar progreso');
      });
      return;
    }
    SaveManager.resetProgress();
    this.audio.play('ui_select');
    this.scene.restart();
  }

  startGame() {
    if (this.starting) return;
    this.starting = true;
    this.audio.play('ui_select');
    const run = newRunState(WORLD1);
    for (const [k, v] of Object.entries(run)) this.registry.set(k, v);
    const cam = this.cameras.main;
    cam.fadeOut(400, 52, 85, 164);
    cam.once('camerafadeoutcomplete', () => this.scene.start('World1', { introBanner: true }));
  }

  update(time, delta) {
    this.cloudsFar.tilePositionX += delta * 0.006;
    this.cloudsNear.tilePositionX += delta * 0.014;
  }
}
