import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';
import { WEAPONS } from '../weapons/weaponDefs.js';

/** Estrella coleccionable (del mapa o surgida de un monstruo atrapado). */
export class Star extends Phaser.Physics.Arcade.Image {
  constructor(scene, x, y, { id = null, bonus = false, special = false } = {}) {
    super(scene, x, y, 'fx', 'star_gold');
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.id = id;
    this.bonus = bonus;
    this.special = special;
    this.setDepth(DEPTH.PICKUP);
    this.setScale(special ? 1.5 : 0.8);
    this.body.setAllowGravity(false);
    this.body.setCircle(this.width * 0.35, this.width * 0.15, this.height * 0.15);
    if (bonus) {
      // sale despedida hacia arriba y cae al suelo
      this.body.setAllowGravity(true);
      this.body.setVelocity(Phaser.Math.Between(-40, 40), -180);
      this.body.setBounce(0.4);
      this.collectableAt = scene.time.now + 350;
    } else {
      this.body.moves = false;
      scene.tweens.add({ targets: this, y: y - 2, duration: 700 + Math.random() * 300, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
      this.collectableAt = 0;
    }
    if (special) {
      this.glow = scene.add.image(x, y, 'glow').setScale(3).setTint(0xffe082).setDepth(DEPTH.PICKUP - 1);
      scene.tweens.add({ targets: this.glow, alpha: 0.4, duration: 500, yoyo: true, repeat: -1 });
      scene.tweens.add({ targets: this, angle: 360, duration: 3000, repeat: -1 });
    }
  }

  preUpdate(time, delta) {
    if (this.glow) this.glow.setPosition(this.x, this.y);
  }

  collect() {
    if (!this.active || this.scene.time.now < this.collectableAt) return false;
    const scene = this.scene;
    scene.effects.sparkle(this.x, this.y, this.special ? 30 : 8);
    scene.audio.play(this.special ? 'pickup' : 'star');
    this.glow?.destroy();
    this.destroy();
    return true;
  }
}

/** Objeto que desbloquea un arma. */
export class WeaponPickup extends Phaser.Physics.Arcade.Image {
  constructor(scene, def) {
    const w = WEAPONS[def.weapon];
    super(scene, def.x * TILE + TILE / 2, def.y * TILE - 14, 'fx', w.icon);
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.weaponId = def.weapon;
    this.setDepth(DEPTH.PICKUP);
    this.body.setAllowGravity(false);
    this.body.moves = false;
    this.halo = scene.add.image(this.x, this.y, 'fx', 'bubble').setDepth(DEPTH.PICKUP - 1).setAlpha(0.6).setScale(1.7);
    this.glow = scene.add.image(this.x, this.y, 'glow').setDepth(DEPTH.PICKUP - 2).setScale(2.2).setTint(0xffe082);
    scene.tweens.add({ targets: [this, this.halo, this.glow], y: this.y - 4, duration: 800, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    scene.tweens.add({ targets: this.glow, alpha: 0.35, duration: 600, yoyo: true, repeat: -1 });
  }

  collect() {
    this.scene.effects.sparkle(this.x, this.y, 20);
    this.scene.effects.bubblePop(this.x, this.y);
    this.halo.destroy();
    this.glow.destroy();
    this.destroy();
  }
}

/** Portal al siguiente mundo (aparece al derrotar al jefe). */
export class Portal extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y) {
    super(scene, x, y, 'fx', 'portal_0');
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setOrigin(0.5, 1).setDepth(DEPTH.PICKUP);
    this.body.setAllowGravity(false);
    this.body.moves = false;
    this.body.setSize(20, 34);
    this.play('portal_spin');
    this.glow = scene.add.image(x, y - 20, 'glow').setScale(4).setTint(0xb9a7f4).setDepth(DEPTH.PICKUP - 1);
    scene.tweens.add({ targets: this.glow, alpha: 0.4, scale: 4.6, duration: 700, yoyo: true, repeat: -1 });
    this.setScale(0);
    scene.tweens.add({ targets: this, scale: 1, duration: 600, ease: 'Back.easeOut' });
    this.used = false;
  }
}
