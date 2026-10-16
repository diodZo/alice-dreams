import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';

/**
 * Ajusta el tamaño y desplazamiento del cuerpo.  En cuerpos estáticos hay que
 * sincronizar primero con el objeto (updateFromGameObject restablece el tamaño
 * al de la imagen) y después aplicar tamaño y desplazamiento.
 */
export function setBodyRect(obj, width, height, offsetX, offsetY) {
  const body = obj.body;
  if (body.physicsType === Phaser.Physics.Arcade.STATIC_BODY) {
    body.updateFromGameObject();
    body.setSize(width, height, false);
    body.setOffset(offsetX, offsetY);
  } else {
    body.setSize(width, height, false);
    body.setOffset(offsetX, offsetY);
  }
}

/**
 * Configura el cuerpo de una plataforma de nube: sólo la franja superior colisiona
 * y únicamente desde arriba (colisión unidireccional).
 */
export function setupCloudBody(img, surfaceY) {
  const w = img.width;
  const inset = Math.min(6, Math.floor(w * 0.12));
  // la superficie visual de la nube está unos píxeles por debajo del borde superior
  const top = 3;
  img.y = surfaceY - top;
  setBodyRect(img, w - inset * 2, 10, inset, top);
  img.body.checkCollision.down = false;
  img.body.checkCollision.left = false;
  img.body.checkCollision.right = false;
}

/** Nube estática unidireccional (opcionalmente elástica). */
export function createCloud(scene, group, def, atlas) {
  const img = scene.physics.add.staticImage(def.x * TILE, 0, atlas, def.frame).setOrigin(0.5, 0);
  img.setDepth(DEPTH.PLATFORM);
  setupCloudBody(img, def.y * TILE);
  img.oneWay = true;
  if (def.bouncy) {
    img.bouncy = def.bouncy;
    img.setTint(0xffe6f6);
  }
  // pequeño movimiento ambiental (sólo visual: el cuerpo estático no se mueve)
  group.add(img);
  return img;
}

/** Plataforma de nube que se desplaza siguiendo un vaivén y transporta a la jugadora. */
export class MovingPlatform extends Phaser.Physics.Arcade.Image {
  constructor(scene, def, atlas) {
    super(scene, def.x * TILE, def.y * TILE, atlas, def.frame);
    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setOrigin(0.5, 0).setDepth(DEPTH.PLATFORM);
    this.body.setAllowGravity(false);
    this.body.setImmovable(true);
    this.body.pushable = false;
    setupCloudBody(this, def.y * TILE);
    this.start = { x: this.x, y: this.y };
    this.delta = { x: (def.dx || 0) * TILE, y: (def.dy || 0) * TILE };
    this.duration = def.duration || 3000;
    this.phase = (def.delay || 0) / this.duration;
    this.oneWay = true;
    this.elapsed = 0;
  }

  /** Posición del vaivén suavizado en el instante t (0..1 ida, 1..2 vuelta). */
  targetAt(ms) {
    const t = ((ms / this.duration + this.phase) % 2 + 2) % 2;
    const k = t < 1 ? t : 2 - t;
    const e = 0.5 - 0.5 * Math.cos(Math.PI * k);
    return { x: this.start.x + this.delta.x * e, y: this.start.y + this.delta.y * e };
  }

  update(time, delta) {
    this.elapsed += delta;
    const dt = Math.max(delta, 1) / 1000;
    const target = this.targetAt(this.elapsed + delta);
    // se mueve por velocidad (no teletransporte) para que Arcade arrastre a quien va encima
    this.body.setVelocity((target.x - this.x) / dt, (target.y - this.y) / dt);
  }
}

/** Nube de vapor: se deshace poco después de pisarla y reaparece al rato. */
export class CrumblePlatform extends Phaser.Physics.Arcade.Image {
  constructor(scene, def, atlas) {
    super(scene, def.x * TILE, def.y * TILE, atlas, def.frame || 'cloud_puff');
    scene.add.existing(this);
    scene.physics.add.existing(this, true);
    this.setOrigin(0.5, 0).setDepth(DEPTH.PLATFORM);
    this.setTint(0xe9f3ff);
    setupCloudBody(this, def.y * TILE);
    this.surfaceY = def.y * TILE;
    this.baseX = this.x;
    this.oneWay = true;
    this.crumbling = false;
  }

  stepOn() {
    if (this.crumbling) return;
    this.crumbling = true;
    const scene = this.scene;
    scene.tweens.add({ targets: this, x: this.baseX + 1.5, duration: 45, yoyo: true, repeat: 6 });
    this.setTint(0xffffff);
    scene.time.delayedCall(560, () => {
      if (!this.active) return;
      this.body.enable = false;
      scene.effects.poof(this.x, this.y + 6, 10);
      scene.tweens.add({ targets: this, alpha: 0, scaleY: 0.4, duration: 220 });
      scene.time.delayedCall(2600, () => this.restore());
    });
  }

  restore() {
    if (!this.active) return;
    this.x = this.baseX;
    this.scene.tweens.add({
      targets: this,
      alpha: 1,
      scaleY: 1,
      duration: 300,
      onComplete: () => {
        this.body.enable = true;
        setupCloudBody(this, this.surfaceY);
        this.crumbling = false;
      },
    });
  }
}

/** Cojín de burbujas que lanza a la jugadora hacia arriba. */
export class BouncePad extends Phaser.Physics.Arcade.Image {
  constructor(scene, def, atlas) {
    super(scene, def.x * TILE + TILE / 2, def.y * TILE, atlas, 'jump_pad');
    scene.add.existing(this);
    scene.physics.add.existing(this, true);
    this.setOrigin(0.5, 1).setDepth(DEPTH.PLATFORM);
    setBodyRect(this, this.width - 4, 8, 2, this.height - 8);
    this.power = def.power || -520;
    this.readyAt = 0;
  }

  trigger(player) {
    const now = this.scene.time.now;
    if (now < this.readyAt) return;
    this.readyAt = now + 200;
    player.bounce(this.power);
    this.scene.audio.play('bounce');
    this.scene.tweens.add({ targets: this, scaleY: 0.6, scaleX: 1.25, duration: 70, yoyo: true });
    this.scene.effects.sparkle(this.x, this.y - 8, 6);
  }
}
