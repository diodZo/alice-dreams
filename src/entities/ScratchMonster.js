import { Enemy, ENEMY_STATE as S } from './Enemy.js';
import { ENEMY_DEFS } from './enemyDefs.js';
import { spawnProjectile } from '../weapons/Projectile.js';

/** Arañitas: persigue a la protagonista y ataca con un arañazo de corto alcance. */
export class ScratchMonster extends Enemy {
  constructor(scene, x, y, spawn) {
    super(scene, x, y, ENEMY_DEFS.scratch, spawn);
  }

  alertUpdate(time) {
    const { dx, dist } = this.distanceToPlayer();
    if (dist <= this.def.attackRange && time >= this.attackReadyAt) {
      this.fsm.set(S.ATTACK);
      return;
    }
    if (time < this.attackReadyAt - this.def.attackCooldown + 300) {
      this.anim('idle');
      return;
    }
    if (dist > this.def.attackRange - 6 && this.walk(Math.sign(dx), this.def.speed)) this.anim('walk');
    else {
      this.body.setVelocityX(0);
      this.facePlayer();
      this.anim('idle');
    }
  }

  attack() {
    this.anim('attack', false);
    this.telegraph(300);
    this.after(300, () => {
      spawnProjectile(this.scene.enemyProjectiles, {
        x: this.x + this.facing * 14,
        y: this.y - 11,
        vx: this.facing * 70,
        vy: 0,
        texture: 'fx',
        frame: 'slash',
        lifespan: 170,
        body: 14,
        owner: 'enemy',
        kind: 'slash',
        damage: 1,
      });
    });
    this.after(700, () => this.fsm.set(S.ALERT));
  }
}
