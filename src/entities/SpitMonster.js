import { Enemy, ENEMY_STATE as S } from './Enemy.js';
import { ENEMY_DEFS } from './enemyDefs.js';
import { spawnProjectile } from '../weapons/Projectile.js';

/** Escupitín: mantiene la distancia y escupe gotas de baba esquivables. */
export class SpitMonster extends Enemy {
  constructor(scene, x, y, spawn) {
    super(scene, x, y, ENEMY_DEFS.spit, spawn);
  }

  alertUpdate(time) {
    const { dx, dist } = this.distanceToPlayer();
    const [near, far] = this.def.keepDistance;
    let moving = false;
    if (dist < near) moving = this.walk(-Math.sign(dx), this.def.speed);
    else if (dist > far) moving = this.walk(Math.sign(dx), this.def.speed);
    if (moving) {
      this.anim('walk');
      this.setFlipX(dx < 0); // retrocede mirando a la protagonista
    } else {
      this.body.setVelocityX(0);
      this.facePlayer();
      this.anim('idle');
    }
    if (time >= this.attackReadyAt && dist < this.def.detectRange && this.canSeePlayer()) {
      this.fsm.set(S.ATTACK);
    }
  }

  attack() {
    // aviso: se infla y destella antes de escupir
    this.setFrame('attack_0');
    this.anims.stop();
    this.telegraph(550);
    this.scene.tweens.add({ targets: this, scaleY: 1.12, scaleX: 0.92, duration: 270, yoyo: true });
    this.after(550, () => {
      this.anim('attack', false);
      this.facePlayer();
      spawnProjectile(this.scene.enemyProjectiles, {
        x: this.x + this.facing * 12,
        y: this.y - 12,
        vx: this.facing * 125,
        vy: -50,
        gravity: 170,
        texture: 'fx',
        frame: 'spit_blob',
        lifespan: 2200,
        body: 7,
        owner: 'enemy',
        kind: 'spit',
        damage: 1,
        rotate: true,
      });
    });
    this.after(1050, () => this.fsm.set(S.ALERT));
  }
}
