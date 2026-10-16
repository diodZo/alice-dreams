import Phaser from 'phaser';
import { DEPTH } from '../config/gameConfig.js';

/**
 * Proyectil genérico reutilizable (armas de la protagonista, enemigos y jefe).
 * Se usa desde grupos con pool: group.get() + fire(config).
 *
 * config: { x, y, vx, vy, gravity, texture, frame, lifespan, damage, owner,
 *           kind, body, scale, alpha, tint, spin, wobble, bounces, rotate, data }
 */
export class Projectile extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y) {
    super(scene, x, y, 'px');
    this.cfg = null;
  }

  fire(cfg) {
    this.cfg = cfg;
    this.setTexture(cfg.texture, cfg.frame);
    this.setActive(true).setVisible(true);
    this.setDepth(DEPTH.PROJECTILE);
    this.setScale(cfg.scale || 1);
    this.setAlpha(cfg.alpha ?? 1);
    this.setAngle(0);
    this.setFlipX(cfg.vx < 0);
    if (cfg.tint !== undefined) this.setTint(cfg.tint);
    else this.clearTint();
    this.body.enable = true;
    this.body.reset(cfg.x, cfg.y);
    const size = cfg.body || Math.min(this.width, this.height);
    this.body.setSize(size / (cfg.scale || 1), size / (cfg.scale || 1), true);
    this.body.setAllowGravity(!!cfg.gravity);
    this.body.setGravityY(cfg.gravity ? cfg.gravity - this.scene.physics.world.gravity.y : 0);
    this.body.setVelocity(cfg.vx, cfg.vy || 0);
    this.body.setBounce(cfg.bounces ? 0.6 : 0);
    this.owner = cfg.owner;
    this.kind = cfg.kind;
    this.damage = cfg.damage ?? 1;
    this.bouncesLeft = cfg.bounces || 0;
    this.bornAt = this.scene.time.now;
    this.dieAt = this.bornAt + (cfg.lifespan || 1500);
    this.baseVy = cfg.vy || 0;
    this.hitTargets = new Set();
    return this;
  }

  preUpdate(time, delta) {
    super.preUpdate(time, delta);
    if (!this.active || !this.cfg) return;
    const cfg = this.cfg;
    if (time >= this.dieAt) {
      this.expire();
      return;
    }
    if (cfg.spin) this.angle += (cfg.spin * delta) / 1000 * Math.sign(this.body.velocity.x || 1);
    if (cfg.wobble) this.body.velocity.y = this.baseVy + Math.sin((time - this.bornAt) / 90) * cfg.wobble * 10;
    if (cfg.rotate) this.rotation = Math.atan2(this.body.velocity.y, this.body.velocity.x);
    // fuera del mundo
    const wb = this.scene.physics.world.bounds;
    if (this.y > wb.bottom + 32 || this.x < wb.x - 64 || this.x > wb.right + 64) this.kill();
  }

  /** Choque con el escenario. Devuelve true si el proyectil desaparece. */
  hitWorld() {
    if (this.bouncesLeft > 0 && this.body.blocked.down) {
      this.bouncesLeft--;
      this.body.setVelocityY(-Math.abs(this.cfg.bounceVelocity || 140));
      return false;
    }
    this.expire();
    return true;
  }

  /** Fin natural (tiempo o impacto): avisa a la escena para el efecto visual. */
  expire() {
    if (!this.active) return;
    this.scene.events.emit('projectile-expired', this);
    this.kill();
  }

  kill() {
    this.setActive(false).setVisible(false);
    this.body.stop();
    this.body.enable = false;
    this.cfg = null;
  }
}

/** Crea un grupo-pool de proyectiles. */
export function createProjectileGroup(scene, max = 30) {
  return scene.physics.add.group({
    classType: Projectile,
    maxSize: max,
    runChildUpdate: false,
    allowGravity: false,
  });
}

/** Obtiene un proyectil libre del pool y lo dispara (null si el pool está lleno). */
export function spawnProjectile(group, cfg) {
  const p = group.get(cfg.x, cfg.y);
  if (!p) return null;
  return p.fire(cfg);
}
