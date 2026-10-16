import Phaser from 'phaser';
import { DEPTH } from '../config/gameConfig.js';
import { StateMachine } from '../systems/StateMachine.js';

export const ENEMY_STATE = {
  IDLE: 'IDLE',
  PATROL: 'PATROL',
  ALERT: 'ALERT',
  ATTACK: 'ATTACK',
  HURT: 'HURT',
  DEFEATED: 'DEFEATED',
  TRAPPED: 'TRAPPED',
};

const S = ENEMY_STATE;

/**
 * Base de los monstruos de peluche.  Gestiona vida, daño, atrapado en burbuja,
 * pintura, patrulla y percepción.  Cada subclase define su comportamiento de
 * alerta y su ataque mediante los métodos alertUpdate() y attack().
 */
export class Enemy extends Phaser.Physics.Arcade.Sprite {
  /**
   * @param def   datos del tipo (key, hp, speed, body, detectRange...)
   * @param spawn datos de aparición del nivel ({ id, x, y, patrol:[minX,maxX] })
   */
  constructor(scene, x, y, def, spawn) {
    super(scene, x, y, def.key, 'idle_0');
    this.def = def;
    this.spawn = spawn;
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setOrigin(0.5, 1);
    this.setDepth(DEPTH.ENEMY);
    const fw = this.frame.realWidth;
    const fh = this.frame.realHeight;
    this.body.setSize(def.body.width, def.body.height);
    this.body.setOffset((fw - def.body.width) / 2, fh - def.body.height - 1);
    this.body.setMaxVelocityY(420);

    this.hp = def.hp;
    this.facing = spawn.facing || -1;
    this.patrolMin = (spawn.patrol?.[0] ?? x - 48);
    this.patrolMax = (spawn.patrol?.[1] ?? x + 48);
    this.attackReadyAt = 0;
    this.paintedUntil = 0;
    this.lostSightAt = 0;
    this.bubble = null;
    this.alertIcon = null;
    this.timers = [];

    this.fsm = new StateMachine(this, this.buildStates(), S.IDLE);
  }

  get player() {
    return this.scene.player;
  }

  get isAlive() {
    return !this.fsm.is(S.DEFEATED);
  }

  get isTrapped() {
    return this.fsm.is(S.TRAPPED);
  }

  /** Puede dañar a la protagonista por contacto. */
  get isHarmful() {
    return this.isAlive && !this.isTrapped && !this.fsm.is(S.HURT);
  }

  get speedFactor() {
    return this.scene.time.now < this.paintedUntil ? 0.55 : 1;
  }

  anim(name, ignoreIfPlaying = true) {
    this.anims.play(`${this.def.key}_${name}`, ignoreIfPlaying);
  }

  /** Programa una acción ligada al enemigo (se cancela si cambia a herido/derrotado). */
  after(ms, fn) {
    const ev = this.scene.time.delayedCall(ms, () => {
      this.timers = this.timers.filter((t) => t !== ev);
      if (this.active) fn();
    });
    this.timers.push(ev);
    return ev;
  }

  clearTimers() {
    this.timers.forEach((t) => t.remove(false));
    this.timers = [];
  }

  distanceToPlayer() {
    const p = this.player;
    return { dx: p.x - this.x, dy: p.y - this.y, dist: Math.abs(p.x - this.x) };
  }

  canSeePlayer(range = this.def.detectRange) {
    const p = this.player;
    if (!p || p.dead) return false;
    const { dx, dy } = this.distanceToPlayer();
    return Math.abs(dx) < range && Math.abs(dy) < this.def.detectHeight;
  }

  facePlayer() {
    this.facing = this.player.x < this.x ? -1 : 1;
    this.setFlipX(this.facing < 0);
  }

  /** ¿Hay suelo delante? (evita caer por los bordes al patrullar o perseguir) */
  groundAhead(dir) {
    const layer = this.scene.level?.terrain;
    if (!layer) return true;
    const x = this.x + dir * (this.def.body.width / 2 + 4);
    const tile = layer.getTileAtWorldXY(x, this.y + 4, true);
    return !!(tile && tile.index !== -1);
  }

  walk(dir, speed) {
    if (!this.groundAhead(dir) || (dir < 0 && this.body.blocked.left) || (dir > 0 && this.body.blocked.right)) {
      this.body.setVelocityX(0);
      return false;
    }
    this.facing = dir;
    this.setFlipX(dir < 0);
    this.body.setVelocityX(dir * speed * this.speedFactor);
    return true;
  }

  showAlert() {
    if (this.alertIcon) this.alertIcon.destroy();
    this.alertIcon = this.scene.add
      .bitmapText(this.x, this.y - this.def.body.height - 8, 'pixel', '!')
      .setOrigin(0.5)
      .setTint(0xffe082)
      .setDepth(DEPTH.UI_WORLD);
    this.scene.tweens.add({
      targets: this.alertIcon,
      y: this.alertIcon.y - 4,
      duration: 160,
      yoyo: true,
      onComplete: () => {
        this.alertIcon?.destroy();
        this.alertIcon = null;
      },
    });
  }

  /** Aviso visual antes de atacar (destello). */
  telegraph(ms) {
    let n = 0;
    const blink = this.scene.time.addEvent({
      delay: ms / 6,
      repeat: 5,
      callback: () => {
        if (!this.active) return;
        if (n++ % 2 === 0) this.setTint(0xfff3a0);
        else this.applyTint();
      },
    });
    this.timers.push(blink);
    const flash = this.scene.add.image(this.x, this.y - this.def.body.height / 2, 'glow').setDepth(DEPTH.FX).setTint(0xffe082).setAlpha(0.9);
    this.scene.tweens.add({ targets: flash, scale: 2, alpha: 0, duration: ms, onComplete: () => flash.destroy() });
  }

  applyTint() {
    if (this.scene.time.now < this.paintedUntil && this.paintColor) this.setTint(this.paintColor);
    else this.clearTint();
  }

  buildStates() {
    return {
      [S.IDLE]: {
        enter() {
          this.body.setVelocityX(0);
          this.anim('idle');
        },
        update() {
          if (this.canSeePlayer()) this.fsm.set(S.ALERT);
          else if (this.fsm.elapsed > 900) this.fsm.set(S.PATROL);
        },
      },
      [S.PATROL]: {
        enter() {
          this.anim('walk');
        },
        update() {
          if (this.canSeePlayer()) {
            this.fsm.set(S.ALERT);
            return;
          }
          if (this.x <= this.patrolMin) this.facing = 1;
          else if (this.x >= this.patrolMax) this.facing = -1;
          if (!this.walk(this.facing, this.def.speed * 0.6)) {
            this.facing *= -1;
            this.fsm.set(S.IDLE);
          }
          this.anim('walk');
        },
      },
      [S.ALERT]: {
        enter(prev) {
          this.body.setVelocityX(0);
          this.facePlayer();
          if (prev === S.IDLE || prev === S.PATROL) {
            this.showAlert();
            this.attackReadyAt = Math.max(this.attackReadyAt, this.scene.time.now + this.def.reactionTime);
          }
          this.anim('idle');
        },
        update(time) {
          if (!this.canSeePlayer(this.def.detectRange * 1.4)) {
            if (!this.lostSightAt) this.lostSightAt = time;
            if (time - this.lostSightAt > 1400) {
              this.lostSightAt = 0;
              this.fsm.set(S.PATROL);
            }
          } else {
            this.lostSightAt = 0;
          }
          this.alertUpdate(time);
        },
      },
      [S.ATTACK]: {
        enter() {
          this.body.setVelocityX(0);
          this.facePlayer();
          this.attack();
        },
        update() {
          if (this.grounded) this.body.setVelocityX(0);
        },
        exit() {
          this.attackReadyAt = this.scene.time.now + this.def.attackCooldown;
        },
      },
      [S.HURT]: {
        enter(prev, data) {
          this.clearTimers();
          this.anim('hurt', false);
          this.body.setVelocity((data?.dir || -this.facing) * 70, -90);
          this.after(380, () => this.fsm.set(S.ALERT));
        },
      },
      [S.TRAPPED]: {
        enter() {
          this.clearTimers();
          this.anim('hurt', false);
          this.anims.pause();
          this.body.setAllowGravity(false);
          this.body.setVelocity(0, -16);
          this.bubble = this.scene.add
            .image(this.x, this.y - this.def.body.height / 2, 'fx', 'bubble')
            .setDepth(DEPTH.ENEMY + 1)
            .setAlpha(0.8);
          const size = Math.max(this.def.body.width, this.def.body.height) + 12;
          this.bubble.setDisplaySize(size, size);
          this.trapUntil = this.scene.time.now + this.def.trapTime;
          this.scene.audio.play('bubble_trap');
        },
        update(time) {
          this.body.setVelocityX(Math.sin(time / 250) * 8);
          if (this.body.blocked.up) this.body.setVelocityY(0);
          this.bubble.setPosition(this.x, this.y - this.def.body.height / 2);
          const left = this.trapUntil - time;
          if (left < 900) this.bubble.setAlpha(Math.floor(time / 90) % 2 ? 0.3 : 0.8);
          if (left <= 0) {
            // se escapa: la burbuja revienta y vuelve a la carga
            this.scene.effects.bubblePop(this.bubble.x, this.bubble.y);
            this.scene.audio.play('bubble_pop');
            this.fsm.set(S.ALERT);
          }
        },
        exit() {
          this.anims.resume();
          this.body.setAllowGravity(true);
          this.bubble?.destroy();
          this.bubble = null;
        },
      },
      [S.DEFEATED]: {
        enter(prev, data) {
          this.clearTimers();
          this.body.setVelocity(0, 0);
          this.body.enable = false;
          this.clearTint();
          if (data?.toStar) {
            this.setVisible(false);
            this.scene.effects.bubblePop(this.x, this.y - this.def.body.height / 2);
            this.finish();
            return;
          }
          this.anim('defeated', false);
          this.scene.audio.play('enemy_defeat');
          this.scene.effects.sparkle(this.x, this.y - 10, 12);
          this.scene.tweens.add({
            targets: this,
            alpha: 0,
            delay: 700,
            duration: 400,
            onComplete: () => {
              this.scene.effects.poof(this.x, this.y - 6);
              this.finish();
            },
          });
        },
      },
    };
  }

  get grounded() {
    return this.body.blocked.down || this.body.touching.down;
  }

  preUpdate(time, delta) {
    super.preUpdate(time, delta);
    if (!this.active) return;
    this.fsm.update(time, delta);
    if (this.paintedUntil && time >= this.paintedUntil) {
      this.paintedUntil = 0;
      this.applyTint();
    }
    if (this.y > this.scene.physics.world.bounds.bottom + 40) this.finish();
  }

  /** Impacto de un proyectil de la protagonista. Devuelve true si lo consume. */
  hitBy(projectile) {
    if (!this.isAlive) return false;
    const w = projectile.weapon;
    if (this.isTrapped) {
      // un segundo disparo sobre la burbuja la revienta y el monstruo se vuelve estrella
      this.convertToStar();
      return true;
    }
    if (w.effect === 'trap') {
      this.fsm.set(S.TRAPPED);
      return true;
    }
    if (w.effect === 'paint') {
      this.paintedUntil = this.scene.time.now + 2500;
      this.paintColor = projectile.paintColor;
      this.scene.effects.paintSplat(projectile.x, projectile.y, projectile.paintColor);
    } else {
      this.scene.effects.impact(projectile.x, projectile.y, projectile.tintTopLeft);
    }
    this.takeDamage(w.damage, Math.sign(projectile.body.velocity.x) || 1);
    return true;
  }

  stomp() {
    if (!this.isAlive || this.isTrapped) return;
    this.takeDamage(1, this.player.x < this.x ? 1 : -1);
  }

  takeDamage(amount, dir) {
    this.hp -= amount;
    this.scene.audio.play('enemy_hit');
    this.scene.tweens.add({ targets: this, scaleX: 1.15, scaleY: 0.85, duration: 70, yoyo: true });
    if (this.hp <= 0) this.fsm.set(S.DEFEATED);
    else this.fsm.set(S.HURT, { dir });
    this.applyTint();
  }

  convertToStar() {
    const x = this.x;
    const y = this.y - this.def.body.height / 2;
    this.scene.audio.play('bubble_pop');
    this.fsm.set(S.DEFEATED, { toStar: true });
    this.scene.events.emit('spawn-star', x, y, true);
  }

  finish() {
    if (this.finished) return;
    this.finished = true;
    this.clearTimers();
    this.alertIcon?.destroy();
    this.scene.events.emit('enemy-finished', this);
    this.destroy();
  }

  /** Retirada por el gestor de apariciones (fuera de cámara). */
  despawn() {
    this.clearTimers();
    this.alertIcon?.destroy();
    this.bubble?.destroy();
    this.destroy();
  }

  // --- a implementar por cada monstruo ---
  alertUpdate() {}

  attack() {
    this.after(300, () => this.fsm.set(S.ALERT));
  }
}
