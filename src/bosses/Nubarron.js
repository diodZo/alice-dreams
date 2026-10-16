import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';
import { StateMachine } from '../systems/StateMachine.js';
import { spawnProjectile } from '../weapons/Projectile.js';

/**
 * NUBARRÓN — jefe del Mundo 1.
 *
 * Fases según la vida restante:
 *  1 (100-65 %): vaivén lento, ráfagas de viento y bolitas de nube.
 *  2 (65-30 %):  más rápido, lluvia de nubecitas con aviso, invoca plataformas.
 *  3 (30-0 %):   cambia de color, movimientos rápidos, ráfaga triple, alterna ataques.
 * Tras cada ataque baja y descansa: es la ventana clara para golpearle.
 * Los ataques siempre tienen aviso y huecos para esquivarlos.
 */
const PHASES = {
  1: { speed: 38, interval: 1500, rest: 1300, pattern: ['WIND', 'SHOOT', 'SHOOT', 'WIND'] },
  2: { speed: 62, interval: 1250, rest: 1300, pattern: ['RAIN', 'SHOOT', 'SUMMON', 'WIND', 'RAIN', 'SHOOT'] },
  3: { speed: 90, interval: 950, rest: 1500, pattern: ['DASH', 'TRIPLE', 'RAIN', 'DASH', 'WIND', 'TRIPLE', 'SHOOT'] },
};
const PHASE3_TINT = 0xcdb8ff;

export class Nubarron extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, cfg) {
    super(scene, cfg.homeX * TILE, -80, 'nubarron', 'idle_0');
    this.cfg = cfg;
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setDepth(DEPTH.ENEMY + 2);
    this.body.setAllowGravity(false);
    this.body.setImmovable(true);
    // hitbox justa: el cuerpo de la nube sin los adornos
    this.body.setSize(60, 46);
    this.body.setOffset((this.frame.realWidth - 60) / 2, (this.frame.realHeight - 46) / 2 + 4);

    this.maxHp = 40;
    this.hp = this.maxHp;
    this.phase = 1;
    this.patternIndex = 0;
    this.homeY = cfg.homeY;
    this.minX = cfg.minX * TILE + 40;
    this.maxX = cfg.maxX * TILE - 40;
    this.floorY = cfg.floorY;
    this.dir = -1;
    this.invulnerable = true;
    this.timers = [];
    this.bobT = 0;
    this.targetY = this.homeY;

    this.fsm = new StateMachine(this, this.buildStates());
  }

  get player() {
    return this.scene.player;
  }

  get isDefeated() {
    return this.fsm.is('DEFEATED');
  }

  get phaseData() {
    return PHASES[this.phase];
  }

  anim(name, ignore = true) {
    const key = this.phase === 3 && (name === 'idle' || name === 'move') ? 'nubarron_storm' : `nubarron_${name}`;
    this.anims.play(key, ignore);
  }

  after(ms, fn) {
    const ev = this.scene.time.delayedCall(ms, () => {
      this.timers = this.timers.filter((t) => t !== ev);
      if (this.active && !this.isDefeated) fn();
    });
    this.timers.push(ev);
  }

  clearTimers() {
    this.timers.forEach((t) => t.remove(false));
    this.timers = [];
  }

  /** Entrada en escena (la llama BossScene al cerrar la puerta). */
  intro() {
    this.fsm.set('INTRO');
  }

  facePlayer() {
    this.setFlipX(this.player.x < this.x);
  }

  /** Vaivén horizontal + balanceo vertical suave hacia targetY. */
  drift(delta, speedMul = 1) {
    const sp = this.phaseData.speed * speedMul;
    if (this.x <= this.minX) this.dir = 1;
    else if (this.x >= this.maxX) this.dir = -1;
    this.bobT += delta;
    const y = this.targetY + Math.sin(this.bobT / 400) * 5;
    this.body.setVelocity(this.dir * sp, (y - this.y) * 4);
  }

  hover(delta) {
    this.bobT += delta;
    const y = this.targetY + Math.sin(this.bobT / 400) * 4;
    this.body.setVelocity(0, (y - this.y) * 5);
  }

  buildStates() {
    return {
      INTRO: {
        enter() {
          this.anim('idle');
          this.scene.tweens.add({
            targets: this,
            y: this.homeY,
            duration: 1600,
            ease: 'Sine.easeOut',
            onComplete: () => {
              this.invulnerable = false;
              this.fsm.set('IDLE');
            },
          });
        },
      },
      IDLE: {
        enter() {
          this.targetY = this.homeY;
          this.anim('move');
        },
        update(time, delta) {
          this.drift(delta);
          this.setFlipX(this.dir < 0);
          if (this.fsm.elapsed > this.phaseData.interval) {
            const p = this.phaseData.pattern;
            const next = p[this.patternIndex % p.length];
            this.patternIndex++;
            this.fsm.set(next);
          }
        },
      },
      REST: {
        // ventana de vulnerabilidad: baja, se queda quieto y brilla
        enter() {
          this.targetY = this.homeY + 34;
          this.anim('idle');
          this.restGlow = this.scene.add.image(this.x, this.y, 'glow').setScale(5).setTint(0xffe082).setAlpha(0.5).setDepth(this.depth - 1);
          this.scene.tweens.add({ targets: this.restGlow, alpha: 0.15, duration: 300, yoyo: true, repeat: -1 });
        },
        update(time, delta) {
          this.hover(delta);
          this.restGlow?.setPosition(this.x, this.y);
          if (this.fsm.elapsed > this.phaseData.rest) this.fsm.set('IDLE');
        },
        exit() {
          this.restGlow?.destroy();
          this.restGlow = null;
        },
      },
      WIND: {
        enter() {
          this.facePlayer();
          this.targetY = this.homeY + 10;
          this.anim('blow', false);
          this.anims.pause(this.anims.currentAnim.frames[1]);
          this.warn(700);
          this.after(700, () => {
            this.anims.resume();
            const dir = this.flipX ? -1 : 1;
            this.scene.audio.play('wind');
            // ráfaga baja: se esquiva saltando. Empuja, no daña.
            spawnProjectile(this.scene.enemyProjectiles, {
              x: this.x + dir * 40,
              y: this.floorY - 12,
              vx: dir * 150,
              vy: 0,
              texture: 'fx',
              frame: 'wind',
              lifespan: 4500,
              body: 18,
              owner: 'boss',
              kind: 'wind',
              damage: 0,
              alpha: 0.9,
            });
            this.scene.effects.poof(this.x + dir * 30, this.y, 10);
          });
          this.after(1500, () => this.fsm.set('REST'));
        },
        update(time, delta) {
          this.hover(delta);
        },
      },
      SHOOT: {
        enter() {
          this.facePlayer();
          this.anim('shoot', false);
          this.warn(500);
          const shots = this.phase === 1 ? 2 : 3;
          for (let i = 0; i < shots; i++) this.after(500 + i * 320, () => this.fireBall(0));
          this.after(500 + shots * 320 + 400, () => this.fsm.set('REST'));
        },
        update(time, delta) {
          this.hover(delta);
        },
      },
      TRIPLE: {
        enter() {
          this.facePlayer();
          this.anim('shoot', false);
          this.warn(650);
          for (let v = 0; v < 3; v++) {
            this.after(650 + v * 420, () => {
              this.facePlayer();
              [-0.32, 0, 0.32].forEach((a) => this.fireBall(a, 105));
            });
          }
          this.after(650 + 3 * 420 + 400, () => this.fsm.set('REST'));
        },
        update(time, delta) {
          this.hover(delta);
        },
      },
      RAIN: {
        enter() {
          this.anim('storm');
          this.targetY = this.homeY - 20;
          // posiciones con huecos amplios entre gotas: siempre hay sitio seguro
          const count = this.phase === 3 ? 5 : 4;
          const span = this.maxX + 40 - (this.minX - 40);
          const gap = span / count;
          const offset = Phaser.Math.Between(10, Math.floor(gap) - 30);
          const xs = Array.from({ length: count }, (_, i) => this.minX - 40 + offset + i * gap);
          const markers = xs.map((x) => {
            const m = this.scene.add.image(x, this.floorY - 2, 'fx', 'cloudball').setScale(0.9, 0.3).setTint(0x3455a4).setAlpha(0.6).setDepth(DEPTH.FX);
            this.scene.tweens.add({ targets: m, alpha: 0.15, duration: 120, yoyo: true, repeat: -1 });
            return m;
          });
          this.after(1000, () => {
            markers.forEach((m) => m.destroy());
            xs.forEach((x, i) =>
              this.after(i * 60, () =>
                spawnProjectile(this.scene.enemyProjectiles, {
                  x,
                  y: -10,
                  vx: 0,
                  vy: 170,
                  gravity: 260,
                  texture: 'fx',
                  frame: 'cloudball',
                  scale: 0.75,
                  lifespan: 2500,
                  body: 12,
                  owner: 'boss',
                  kind: 'rain',
                  damage: 1,
                }),
              ),
            );
          });
          this.after(2100, () => this.fsm.set('REST'));
          this.cleanupMarkers = () => markers.forEach((m) => m.active && m.destroy());
        },
        update(time, delta) {
          this.hover(delta);
        },
        exit() {
          this.cleanupMarkers?.();
        },
      },
      SUMMON: {
        enter() {
          this.anim('blow', false);
          this.warn(500);
          const spots = [
            { x: Phaser.Math.Between(this.minX, this.minX + 120), y: this.floorY - 52 },
            { x: Phaser.Math.Between(this.maxX - 120, this.maxX), y: this.floorY - 52 },
          ];
          spots.forEach((s) => this.scene.effects.sparkle(s.x, s.y, 12));
          this.after(500, () => spots.forEach((s) => this.scene.addTemporaryPlatform(s.x, s.y, 5500)));
          this.after(1200, () => this.fsm.set('REST'));
        },
        update(time, delta) {
          this.hover(delta);
        },
      },
      DASH: {
        // movimiento rápido de un lado a otro de la arena por encima de la jugadora
        enter() {
          this.anim('storm');
          this.warn(600);
          const toLeft = this.x > (this.minX + this.maxX) / 2;
          const tx = toLeft ? this.minX : this.maxX;
          this.after(600, () => {
            this.body.setVelocity(0, 0);
            this.scene.audio.play('wind');
            this.scene.tweens.add({
              targets: this,
              x: tx,
              y: this.homeY - 16,
              duration: 520,
              ease: 'Cubic.easeInOut',
              onUpdate: () => {
                if (Math.random() < 0.5) this.ghost();
              },
            });
          });
          this.after(1300, () => this.fsm.set('REST'));
        },
        update() {
          // el tween controla la posición
          this.body.setVelocity(0, 0);
        },
      },
      PHASE_CHANGE: {
        enter() {
          this.invulnerable = true;
          this.clearTimers();
          this.body.setVelocity(0, 0);
          this.anim('hurt', false);
          this.scene.cameras.main.shake(400, 0.006);
          this.scene.audio.play('boss_appear');
          if (this.phase === 3) {
            this.scene.cameras.main.flash(250, 205, 184, 255);
            this.setTint(PHASE3_TINT);
          }
          this.scene.game.events.emit('hud-toast', this.phase === 2 ? '¡Nubarrón se enfada!' : '¡Nubarrón desata la tormenta!');
          this.after(1200, () => {
            this.invulnerable = false;
            this.fsm.set('IDLE');
          });
        },
        update(time, delta) {
          this.hover(delta);
        },
      },
      DEFEATED: {
        enter() {
          this.clearTimers();
          this.invulnerable = true;
          this.body.setVelocity(0, 0);
          this.body.enable = false;
          this.clearTint();
          this.anim('defeated', false);
          const s = this.scene;
          s.audio.play('enemy_defeat');
          s.effects.confetti(this.x, this.y, 80);
          const sparkles = s.time.addEvent({ delay: 180, repeat: 10, callback: () => s.effects.sparkle(this.x + Phaser.Math.Between(-30, 30), this.y + Phaser.Math.Between(-20, 20), 8) });
          // gira suavemente y se transforma en una nubecita sonriente
          s.tweens.add({
            targets: this,
            angle: 720,
            y: this.floorY - 70,
            duration: 1800,
            ease: 'Sine.easeInOut',
            onComplete: () => {
              sparkles.remove();
              s.effects.poof(this.x, this.y, 20);
              s.effects.confetti(this.x, this.y, 60);
              this.anims.stop();
              this.setFrame('idle_1'); // expresión sonriente con los ojos cerrados
              this.setAngle(0);
              s.tweens.add({ targets: this, scale: 0.45, duration: 400, ease: 'Back.easeIn' });
              s.tweens.add({ targets: this, y: this.y - 6, duration: 900, yoyo: true, repeat: -1, ease: 'Sine.easeInOut', delay: 400 });
              s.events.emit('boss-defeated', this.x, this.y);
            },
          });
        },
      },
    };
  }

  /** Aviso visual previo a cada ataque. */
  warn(ms) {
    const s = this.scene;
    const ring = s.add.image(this.x, this.y, 'glow').setTint(0xffe082).setScale(2).setAlpha(0.9).setDepth(this.depth + 1);
    s.tweens.add({ targets: ring, scale: 6, alpha: 0, duration: ms, onComplete: () => ring.destroy() });
    const mark = s.add.bitmapText(this.x, this.y - 44, 'pixel', '!').setOrigin(0.5).setTint(0xffe082).setScale(2).setDepth(DEPTH.UI_WORLD);
    s.tweens.add({ targets: mark, y: mark.y - 6, alpha: 0, duration: ms, onComplete: () => mark.destroy() });
  }

  ghost() {
    const g = this.scene.add.image(this.x, this.y, this.texture.key, this.frame.name).setAlpha(0.35).setTint(PHASE3_TINT).setDepth(this.depth - 1).setFlipX(this.flipX);
    this.scene.tweens.add({ targets: g, alpha: 0, duration: 260, onComplete: () => g.destroy() });
  }

  fireBall(angleOffset = 0, speed = 120) {
    const dirX = this.flipX ? -1 : 1;
    const sx = this.x + dirX * 34;
    const sy = this.y + 8;
    const base = Math.atan2(this.player.y - 16 - sy, this.player.x - sx);
    const a = base + angleOffset;
    spawnProjectile(this.scene.enemyProjectiles, {
      x: sx,
      y: sy,
      vx: Math.cos(a) * speed,
      vy: Math.sin(a) * speed,
      texture: 'fx',
      frame: 'cloudball',
      scale: 0.7,
      lifespan: 4000,
      body: 11,
      owner: 'boss',
      kind: 'cloudball',
      damage: 1,
    });
    this.scene.audio.play('shoot_bubble');
  }

  /** Impacto de un arma de la protagonista. */
  hitBy(projectile) {
    if (this.isDefeated) return true;
    if (this.invulnerable) {
      this.scene.effects.sparkle(projectile.x, projectile.y, 3);
      return true;
    }
    const dmg = projectile.weapon?.bossDamage ?? 1;
    this.hp = Math.max(0, this.hp - dmg);
    this.scene.audio.play('boss_hit');
    if (projectile.weapon?.effect === 'paint') this.scene.effects.paintSplat(projectile.x, projectile.y, projectile.paintColor);
    else this.scene.effects.impact(projectile.x, projectile.y, 0xffffff);
    this.setTintFill(0xffffff);
    this.scene.time.delayedCall(60, () => {
      if (!this.active || this.isDefeated) return;
      if (this.phase === 3) this.setTint(PHASE3_TINT);
      else this.clearTint();
    });
    this.scene.registry.set('bossHp', this.hp);

    const ratio = this.hp / this.maxHp;
    if (this.hp <= 0) {
      this.fsm.set('DEFEATED');
    } else if (this.phase === 1 && ratio <= 0.65) {
      this.phase = 2;
      this.fsm.set('PHASE_CHANGE');
    } else if (this.phase === 2 && ratio <= 0.3) {
      this.phase = 3;
      this.fsm.set('PHASE_CHANGE');
    }
    return true;
  }

  preUpdate(time, delta) {
    super.preUpdate(time, delta);
    if (this.fsm.current) this.fsm.update(time, delta);
  }

  destroy(fromScene) {
    this.clearTimers?.();
    super.destroy(fromScene);
  }
}
