import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';
import { setBodyRect } from './Platforms.js';

/** Bandera de punto de control.  La lógica de reaparición está en CheckpointManager. */
export class Checkpoint extends Phaser.Physics.Arcade.Image {
  constructor(scene, def, atlas, index) {
    super(scene, def.x * TILE + TILE / 2, def.y * TILE + 3, atlas, 'flag');
    scene.add.existing(this);
    scene.physics.add.existing(this, true);
    this.index = index;
    this.respawn = { x: this.x, y: def.y * TILE };
    this.setOrigin(0.5, 1).setDepth(DEPTH.DECOR_BACK + 1);
    setBodyRect(this, 18, 44, (this.width - 18) / 2, this.height - 44);
    this.activated = false;
    this.setTint(0x8b86b8);
  }

  activate(silent = false) {
    if (this.activated) return false;
    this.activated = true;
    this.clearTint();
    if (!silent) {
      this.scene.tweens.add({ targets: this, scaleY: 1.15, duration: 120, yoyo: true, ease: 'Back.easeOut' });
      this.scene.effects.sparkle(this.x, this.y - 30, 16);
    }
    return true;
  }
}
