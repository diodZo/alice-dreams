import Phaser from 'phaser';
import { Enemy, ENEMY_STATE as S } from './Enemy.js';
import { ENEMY_DEFS } from './enemyDefs.js';
import { spawnProjectile } from '../weapons/Projectile.js';

const FLEA_GRAVITY = 520;
const FLIGHT_TIME = 0.95;

/** Pulgoso: retrocede si la protagonista se acerca y lanza pulgas en parábola. */
export class FleaMonster extends Enemy {
  constructor(scene, x, y, spawn) {
    super(scene, x, y, ENEMY_DEFS.flea, spawn);
  }

  alertUpdate(time) {
    const { dx, dist } = this.distanceToPlayer();
    if (dist < this.def.retreatDistance && this.walk(-Math.sign(dx), this.def.speed)) {
      this.anim('walk');
      this.setFlipX(dx < 0);
    } else {
      this.body.setVelocityX(0);
      this.facePlayer();
      this.anim('idle');
    }
    if (time >= this.attackReadyAt && this.canSeePlayer()) this.fsm.set(S.ATTACK);
  }

  attack() {
    this.setFrame('attack_0');
    this.anims.stop();
    this.telegraph(500);
    this.after(500, () => {
      this.anim('attack', false);
      this.facePlayer();
      const sx = this.x + this.facing * 10;
      const sy = this.y - 16;
      const p = this.player;
      // trayectoria parabólica hacia donde está la protagonista (alcance limitado)
      const dx = Phaser.Math.Clamp(p.x - sx, -190, 190);
      const dy = p.y - 12 - sy;
      const t = FLIGHT_TIME;
      spawnProjectile(this.scene.enemyProjectiles, {
        x: sx,
        y: sy,
        vx: dx / t,
        vy: (dy - 0.5 * FLEA_GRAVITY * t * t) / t,
        gravity: FLEA_GRAVITY,
        texture: 'fx',
        frame: 'flea_bug',
        lifespan: 2600,
        body: 8,
        owner: 'enemy',
        kind: 'flea',
        damage: 1,
        bounces: 1,
        bounceVelocity: 150,
      });
    });
    this.after(950, () => this.fsm.set(S.ALERT));
  }
}
