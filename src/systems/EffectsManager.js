import { DEPTH } from '../config/gameConfig.js';
import { PAINT_COLORS } from '../weapons/weaponDefs.js';

/**
 * Efectos visuales reutilizables (partículas y destellos).  Sólo dibuja:
 * no conoce reglas de juego ni colisiones.
 */
export class EffectsManager {
  constructor(scene) {
    this.scene = scene;
    const mk = (texture, cfg) => {
      const e = scene.add.particles(0, 0, texture, { emitting: false, ...cfg });
      e.setDepth(DEPTH.FX);
      return e;
    };
    this.sparkles = mk('px', {
      speed: { min: 30, max: 90 },
      lifespan: { min: 300, max: 600 },
      scale: { start: 1, end: 0 },
      gravityY: 60,
      tint: [0xffe082, 0xfff7ff, 0xf7a8d8],
    });
    this.splat = mk('px', {
      speed: { min: 40, max: 120 },
      lifespan: { min: 250, max: 450 },
      scale: { start: 1.5, end: 0.5 },
      gravityY: 300,
    });
    this.puffs = mk('px', {
      speed: { min: 10, max: 45 },
      lifespan: { min: 300, max: 500 },
      scale: { start: 2.5, end: 0 },
      alpha: { start: 0.9, end: 0 },
      tint: [0xfff7ff, 0xe8e0ff],
    });
    this.confettiEmitter = mk('confetti', {
      speed: { min: 60, max: 180 },
      angle: { min: 200, max: 340 },
      lifespan: { min: 1200, max: 2000 },
      gravityY: 160,
      rotate: { min: 0, max: 360 },
      tint: [...PAINT_COLORS, 0xffffff],
    });
    this.trailEmitter = mk('px', {
      speed: 0,
      lifespan: 220,
      scale: { start: 1, end: 0 },
      alpha: { start: 0.8, end: 0 },
      frequency: 30,
    });
  }

  sparkle(x, y, count = 10) {
    this.sparkles.explode(count, x, y);
  }

  paintSplat(x, y, color) {
    this.splat.setParticleTint(color);
    this.splat.explode(10, x, y);
    const s = this.scene.add.image(x, y, 'fx', 'paint_splash').setTint(color).setDepth(DEPTH.FX).setScale(0.6);
    s.setAngle(Math.random() * 360);
    this.scene.tweens.add({ targets: s, scale: 1, alpha: 0, duration: 280, onComplete: () => s.destroy() });
  }

  poof(x, y, count = 8) {
    this.puffs.explode(count, x, y);
  }

  dust(x, y) {
    this.puffs.explode(4, x, y - 2);
  }

  bubblePop(x, y) {
    this.sparkles.explode(6, x, y);
    const ring = this.scene.add.circle(x, y, 6).setStrokeStyle(1, 0xc8f0ff).setDepth(DEPTH.FX);
    this.scene.tweens.add({ targets: ring, scale: 2.4, alpha: 0, duration: 220, onComplete: () => ring.destroy() });
  }

  impact(x, y, color = 0xffffff) {
    this.splat.setParticleTint(color);
    this.splat.explode(6, x, y);
  }

  confetti(x, y, count = 60) {
    this.confettiEmitter.explode(count, x, y);
  }

  /** Estela de pintura que sigue al proyectil mientras está activo. */
  paintTrail(proj, color) {
    const e = this.scene.add.particles(0, 0, 'px', {
      speed: 0,
      lifespan: 200,
      scale: { start: 1, end: 0 },
      alpha: { start: 0.8, end: 0 },
      frequency: 25,
      tint: color,
      follow: proj,
    });
    e.setDepth(DEPTH.PROJECTILE - 1);
    const stop = () => {
      e.stop();
      this.scene.time.delayedCall(260, () => e.destroy());
    };
    const check = this.scene.time.addEvent({
      delay: 50,
      loop: true,
      callback: () => {
        if (!proj.active || proj.kind !== 'paint') {
          check.remove();
          stop();
        }
      },
    });
  }

  /** Texto flotante corto (p. ej. "+1"). */
  floatText(x, y, text, color = 0xffe082) {
    const t = this.scene.add.bitmapText(x, y, 'pixel', String(text).toUpperCase()).setOrigin(0.5).setTint(color).setDepth(DEPTH.FX);
    t.setLetterSpacing(-1);
    this.scene.tweens.add({ targets: t, y: y - 18, alpha: 0, duration: 700, onComplete: () => t.destroy() });
  }
}
