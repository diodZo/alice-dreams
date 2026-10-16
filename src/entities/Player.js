import Phaser from 'phaser';
import { PLAYER_TUNING as T } from '../config/tuning.js';
import { DEPTH } from '../config/gameConfig.js';
import { PlayerAnimator } from './PlayerAnimator.js';

/**
 * Protagonista: movimiento, salto y vida.
 * - La física (aceleración, coyote time, jump buffer, salto variable) vive aquí.
 * - La elección de animaciones vive en PlayerAnimator.
 * - El disparo lo gestiona WeaponManager, que el nivel actualiza aparte.
 */
export class Player extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y, controls) {
    super(scene, x, y, 'player', 'idle_0');
    this.controls = controls;
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setOrigin(0.5, 1);
    this.setDepth(DEPTH.PLAYER);

    const fw = this.frame.realWidth;
    const fh = this.frame.realHeight;
    this.body.setSize(T.body.width, T.body.height);
    this.body.setOffset((fw - T.body.width) / 2, fh - T.body.height - T.body.footPadding);
    this.body.setCollideWorldBounds(true);

    this.maxHp = T.maxHp;
    this.hp = T.maxHp;
    this.facing = 1;
    this.lastGroundedAt = -9999;
    this.lastJumpPressAt = -9999;
    this.jumping = false;
    this.invulnerableUntil = 0;
    this.stunnedUntil = 0;
    this.attackUntil = 0;
    this.attackAnim = null;
    this.pushX = 0;
    this.frozen = false;
    this.dead = false;
    this.celebrating = false;
    this.ridingPlatform = null;

    this.animator = new PlayerAnimator(this);
  }

  get grounded() {
    return this.body.blocked.down || this.body.touching.down;
  }

  get isInvulnerable() {
    return this.scene.time.now < this.invulnerableUntil || this.dead;
  }

  update(time, delta) {
    if (this.dead) return;
    const dt = delta / 1000;
    const c = this.controls.state;
    const body = this.body;

    if (this.grounded) {
      this.lastGroundedAt = time;
      if (body.velocity.y >= 0) this.jumping = false;
    }

    const canControl = !this.frozen && !this.celebrating && time >= this.stunnedUntil;

    // --- horizontal: aceleración y desaceleración ---
    const axis = canControl ? this.controls.axis : 0;
    const target = axis * (c.run ? T.runSpeed : T.walkSpeed);
    const vx = body.velocity.x;
    let rate;
    if (this.grounded) rate = axis !== 0 && Math.sign(axis) === Math.sign(vx || axis) ? T.groundAccel : T.groundDecel;
    else rate = axis !== 0 ? T.airAccel : T.airDecel;
    let next = Phaser.Math.Linear(vx, target, 1);
    if (Math.abs(target - vx) > rate * dt) next = vx + Math.sign(target - vx) * rate * dt;
    // empuje externo (viento del jefe, retroceso del tirachinas)
    if (this.pushX !== 0) {
      next += this.pushX * dt;
      this.pushX *= Math.pow(0.02, dt);
      if (Math.abs(this.pushX) < 5) this.pushX = 0;
    }
    if (time >= this.stunnedUntil || this.grounded) body.setVelocityX(next);
    if (axis !== 0 && canControl && time >= this.attackUntil) this.facing = axis;
    this.setFlipX(this.facing < 0);

    // --- salto: buffer + coyote time + altura variable ---
    if (canControl && c.jumpPressed) this.lastJumpPressAt = time;
    const buffered = time - this.lastJumpPressAt <= T.jumpBuffer;
    const coyote = time - this.lastGroundedAt <= T.coyoteTime;
    if (canControl && buffered && coyote && !this.jumping) {
      body.setVelocityY(T.jumpVelocity);
      this.jumping = true;
      this.lastJumpPressAt = -9999;
      this.lastGroundedAt = -9999;
      this.scene.audio.play('jump');
      this.scene.effects?.dust(this.x, this.y);
    }
    if (this.jumping && !c.jumpHeld && body.velocity.y < T.jumpCutVelocity) {
      body.setVelocityY(T.jumpCutVelocity);
    }

    // velocidad máxima de caída (la subida no se limita: rebotes y cojines la superan)
    if (body.velocity.y > T.maxFallSpeed) body.setVelocityY(T.maxFallSpeed);

    // parpadeo durante la invulnerabilidad
    if (time < this.invulnerableUntil) this.setAlpha(Math.floor(time / 70) % 2 ? 0.35 : 1);
    else this.setAlpha(1);

    this.animator.update(time);
  }

  /** Impulso hacia arriba al pisar a un enemigo o una plataforma elástica. */
  bounce(velocity) {
    this.body.setVelocityY(velocity);
    // un rebote no es un salto: no se le aplica el corte de salto variable
    this.jumping = false;
    this.lastGroundedAt = -9999;
  }

  /** Marca la pose de ataque del arma actual (la llama WeaponManager). */
  playAttack(weaponId, recoil = 0) {
    this.attackUntil = this.scene.time.now + T.attackPoseTime;
    this.attackAnim = weaponId;
    this.animator.restartAttack();
    if (recoil) this.pushX -= this.facing * recoil;
  }

  push(vx) {
    this.pushX += vx;
  }

  /** Recibe daño. Devuelve true si el golpe se aplicó. */
  hurt(fromX, amount = 1) {
    if (this.isInvulnerable || this.celebrating) return false;
    const now = this.scene.time.now;
    this.hp = Math.max(0, this.hp - amount);
    this.invulnerableUntil = now + T.invulnerableTime;
    this.stunnedUntil = now + T.hurtStunTime;
    const dir = fromX !== undefined && fromX > this.x ? -1 : 1;
    this.body.setVelocity(dir * T.hurtKnockback.x, T.hurtKnockback.y);
    this.jumping = false;
    this.scene.audio.play('hurt');
    this.scene.cameras.main.shake(120, 0.004);
    this.scene.events.emit('player-hp', this.hp);
    if (this.hp <= 0) this.faint();
    return true;
  }

  faint() {
    this.dead = true;
    this.body.setVelocity(0, -120);
    this.anims.play('player_hurt', true);
    this.scene.events.emit('player-fainted');
  }

  heal(full = true) {
    this.hp = full ? this.maxHp : Math.min(this.maxHp, this.hp + 1);
    this.scene.events.emit('player-hp', this.hp);
  }

  respawnAt(x, y) {
    this.dead = false;
    this.pushX = 0;
    this.setPosition(x, y);
    this.body.reset(x, y);
    this.body.setVelocity(0, 0);
    this.invulnerableUntil = this.scene.time.now + T.invulnerableTime;
    this.stunnedUntil = 0;
    this.setAlpha(1);
    this.setVisible(true);
  }

  celebrate() {
    this.celebrating = true;
    this.body.setVelocityX(0);
    this.anims.play('player_victory', true);
  }

  /** Punto de salida de los proyectiles (la mano de la protagonista). */
  muzzle() {
    return { x: this.x + this.facing * 15, y: this.y - 17 };
  }
}
