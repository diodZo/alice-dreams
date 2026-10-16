import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';

/**
 * Obstáculo con patrón predecible: una burbuja con pinchos que sube y baja (o va
 * de lado a lado) siempre al mismo ritmo.  Daña al tocarla.
 */
export class Hazard extends Phaser.Physics.Arcade.Image {
  constructor(scene, def, atlas) {
    super(scene, def.x * TILE + TILE / 2, def.y * TILE + TILE / 2, atlas, def.frame || 'spiky_bubble');
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setDepth(DEPTH.ENEMY);
    this.body.setAllowGravity(false);
    this.body.moves = false; // el cuerpo sigue al tween
    const r = Math.min(this.width, this.height) * 0.36;
    this.body.setCircle(r, this.width / 2 - r, this.height / 2 - r);
    scene.tweens.add({
      targets: this,
      x: this.x + (def.dx || 0) * TILE,
      y: this.y + (def.dy || 0) * TILE,
      duration: def.duration || 1500,
      delay: def.delay || 0,
      ease: 'Sine.easeInOut',
      yoyo: true,
      repeat: -1,
    });
    scene.tweens.add({ targets: this, angle: { from: -8, to: 8 }, duration: 600, yoyo: true, repeat: -1 });
  }
}

/** Corriente de aire ascendente: empuja suavemente hacia arriba dentro de su zona. */
export class WindZone extends Phaser.GameObjects.Zone {
  constructor(scene, def) {
    super(scene, def.x * TILE, def.y * TILE, def.w * TILE, def.h * TILE);
    this.setOrigin(0, 0);
    scene.add.existing(this);
    scene.physics.add.existing(this, true);
    this.force = def.force || 1400;
    this.maxUp = def.maxUp || 180;
    this.emitter = scene.add.particles(0, 0, 'px', {
      x: { min: this.x, max: this.x + this.width },
      y: this.y + this.height,
      speedY: { min: -170, max: -110 },
      speedX: { min: -6, max: 6 },
      lifespan: (this.height / 140) * 1000,
      scaleY: { start: 3, end: 1 },
      alpha: { start: 0.55, end: 0 },
      frequency: 45,
      tint: [0xfff7ff, 0xc8e8ff],
    });
    this.emitter.setDepth(DEPTH.DECOR_BACK);
    this.lastSoundAt = 0;
  }

  apply(player, delta) {
    const body = player.body;
    const dt = delta / 1000;
    body.setVelocityY(Math.max(body.velocity.y - this.force * dt, -this.maxUp));
    player.jumping = false; // el corte de salto variable no frena la corriente
    const now = this.scene.time.now;
    if (now - this.lastSoundAt > 900) {
      this.lastSoundAt = now;
      this.scene.audio.play('wind');
    }
  }
}
