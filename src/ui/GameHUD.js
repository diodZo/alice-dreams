import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT, FORCE_TOUCH } from '../config/gameConfig.js';
import { WEAPONS } from '../weapons/weaponDefs.js';
import { pixelText } from './PixelFont.js';
import { TouchControls } from './TouchControls.js';

/**
 * Interfaz superpuesta (escena aparte, sin cámara que se desplace).
 * Lee el estado del registro del juego y escucha avisos puntuales:
 *  - corazones, arma, estrellas, progreso del nivel, vida del jefe
 *  - "hud-banner" (título grande) y "hud-toast" (aviso corto)
 */
export class GameHUD extends Phaser.Scene {
  constructor() {
    super('HUD');
  }

  create() {
    this.cleanups = [];
    const R = this.registry;

    // --- corazones ---
    this.hearts = [];
    for (let i = 0; i < 5; i++) {
      this.hearts.push(this.add.image(10 + i * 11, 10, 'fx', 'heart_full').setOrigin(0, 0).setVisible(false));
    }

    // --- arma seleccionada ---
    this.weaponBox = this.add.graphics();
    this.weaponBox.fillStyle(0x2a2350, 0.55).fillRoundedRect(8, 22, 26, 22, 4);
    this.weaponBox.lineStyle(1, 0xfff7ff, 0.8).strokeRoundedRect(8, 22, 26, 22, 4);
    this.weaponIcon = this.add.image(21, 33, 'fx', 'icon_bubble').setVisible(false);
    this.weaponName = pixelText(this, 38, 28, '', { tint: 0xfff7ff });
    this.weaponDots = this.add.graphics();

    // --- estrellas ---
    this.starIcon = this.add.image(GAME_WIDTH - 52, 12, 'fx', 'star_gold').setScale(0.7);
    this.starText = pixelText(this, GAME_WIDTH - 42, 7, '0', { tint: 0xffe082 });

    // --- progreso del nivel ---
    const px = GAME_WIDTH / 2 - 80;
    this.progressX = px;
    const pg = this.add.graphics();
    pg.fillStyle(0x2a2350, 0.55).fillRoundedRect(px - 3, 6, 166, 10, 4);
    pg.fillStyle(0xfff7ff, 0.9).fillRect(px, 10, 160, 2);
    this.progressMarks = this.add.graphics();
    this.progressFlag = this.add.image(px + 160, 11, 'fx', 'star_gold').setScale(0.45);
    this.progressMarker = this.add.circle(px, 11, 3, 0xf7a8d8).setStrokeStyle(1, 0x2a2350);
    this.sectionText = pixelText(this, GAME_WIDTH / 2, 19, '', { origin: [0.5, 0], tint: 0xfff7ff, scale: 1 });

    // --- barra del jefe ---
    this.bossGroup = this.add.container(GAME_WIDTH / 2, GAME_HEIGHT - 16);
    const bb = this.add.graphics();
    bb.fillStyle(0x2a2350, 0.75).fillRoundedRect(-102, -6, 204, 12, 5);
    this.bossBar = this.add.rectangle(-100, 0, 200, 6, 0xb9a7f4).setOrigin(0, 0.5);
    const bossLabel = pixelText(this, 0, -16, 'Nubarrón', { origin: 0.5, tint: 0xffe082 });
    this.bossGroup.add([bb, this.bossBar, bossLabel]);
    this.bossGroup.setVisible(false);

    // --- avisos ---
    this.banner = pixelText(this, GAME_WIDTH / 2, 70, '', { origin: 0.5, scale: 2, tint: 0xfff7ff, align: 'center', maxWidth: 440 }).setAlpha(0);
    this.toast = pixelText(this, GAME_WIDTH / 2, 96, '', { origin: 0.5, tint: 0xffe082, align: 'center', maxWidth: 400 }).setAlpha(0);

    // --- controles táctiles ---
    const touch = FORCE_TOUCH || this.sys.game.device.input.touch;
    if (touch) this.touch = new TouchControls(this);

    const onData = (parent, key) => this.refresh(key);
    R.events.on('changedata', onData);
    this.cleanups.push(() => R.events.off('changedata', onData));
    const onBanner = (t) => this.showBanner(t);
    const onToast = (t) => this.showToast(t);
    this.game.events.on('hud-banner', onBanner);
    this.game.events.on('hud-toast', onToast);
    this.cleanups.push(() => this.game.events.off('hud-banner', onBanner));
    this.cleanups.push(() => this.game.events.off('hud-toast', onToast));
    this.events.once('shutdown', () => {
      this.cleanups.forEach((fn) => fn());
      this.touch?.destroy();
    });

    this.refresh();
  }

  refresh(key) {
    const R = this.registry;
    if (!key || key === 'hp' || key === 'maxHp') {
      const hp = R.get('hp') ?? 3;
      const max = R.get('maxHp') ?? 3;
      this.hearts.forEach((h, i) => {
        h.setVisible(i < max);
        h.setFrame(i < hp ? 'heart_full' : 'heart_empty');
      });
      if (key === 'hp') this.tweens.add({ targets: this.hearts, scale: 1.25, duration: 80, yoyo: true });
    }
    if (!key || key === 'weapon' || key === 'weaponsOwned') {
      const id = R.get('weapon');
      const owned = R.get('weaponsOwned') || [];
      if (id && WEAPONS[id]) {
        this.weaponIcon.setFrame(WEAPONS[id].icon).setVisible(true);
        this.weaponName.setText(WEAPONS[id].name);
      } else {
        this.weaponIcon.setVisible(false);
        this.weaponName.setText('Sin arma');
      }
      this.weaponDots.clear();
      owned.forEach((w, i) => {
        this.weaponDots.fillStyle(w === id ? 0xffe082 : 0xfff7ff, w === id ? 1 : 0.5).fillRect(38 + i * 6, 38, 4, 3);
      });
    }
    if (!key || key === 'stars') this.starText.setText(String(R.get('stars') || 0));
    if (!key || key === 'progress') {
      const p = R.get('progress') || 0;
      this.progressMarker.x = this.progressX + p * 160;
    }
    if (!key || key === 'progressMarks') {
      this.progressMarks.clear();
      for (const m of R.get('progressMarks') || []) {
        this.progressMarks.fillStyle(0xb9a7f4, 1).fillRect(this.progressX + m * 160, 8, 1, 6);
      }
    }
    if (!key || key === 'section') this.sectionText.setText(R.get('section') ? `Sección ${R.get('section')}` : '');
    if (!key || key === 'bossVisible' || key === 'bossHp' || key === 'bossMaxHp') {
      const visible = !!R.get('bossVisible');
      this.bossGroup.setVisible(visible);
      const max = R.get('bossMaxHp') || 1;
      const ratio = Phaser.Math.Clamp((R.get('bossHp') ?? max) / max, 0, 1);
      this.bossBar.width = 200 * ratio;
      this.bossBar.fillColor = ratio > 0.65 ? 0xb9a7f4 : ratio > 0.3 ? 0xf7a8d8 : 0xff7a9a;
    }
  }

  showBanner(text) {
    this.tweens.killTweensOf(this.banner);
    this.banner.setText(text).setAlpha(0).setY(64);
    this.tweens.add({ targets: this.banner, alpha: 1, y: 70, duration: 250 });
    this.tweens.add({ targets: this.banner, alpha: 0, delay: 2200, duration: 400 });
  }

  showToast(text) {
    this.tweens.killTweensOf(this.toast);
    this.toast.setText(text).setAlpha(1);
    this.tweens.add({ targets: this.toast, alpha: 0, delay: 1800, duration: 400 });
  }
}
