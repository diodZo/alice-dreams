import Phaser from 'phaser';
import { pixelText } from './PixelFont.js';

/** Genera (una vez por tamaño) la textura de un botón con forma de nube. */
function cloudTexture(scene, w, h, key) {
  if (scene.textures.exists(key)) return key;
  const g = scene.make.graphics({ x: 0, y: 0 }, false);
  const draw = (color, inset) => {
    g.fillStyle(color, 1);
    const r = (h - inset * 2) / 2;
    g.fillRoundedRect(inset + 2, inset + 2, w - inset * 2 - 4, h - inset * 2 - 4, Math.max(2, r - 2));
    const bumps = Math.max(2, Math.floor(w / 18));
    for (let i = 0; i < bumps; i++) {
      const cx = 8 + ((w - 16) * (i + 0.5)) / bumps;
      g.fillCircle(cx, inset + 5, Math.max(2, 6 - inset));
    }
  };
  draw(0x3455a4, 0);
  draw(0xfff7ff, 1);
  g.fillStyle(0xf7a8d8, 1);
  g.fillRect(4, h - 6, w - 8, 2);
  g.generateTexture(key, w, h);
  g.destroy();
  return key;
}

/**
 * Botón de nube con texto pixel art. Se puede activar con ratón/táctil o, a través
 * de MenuList, con el teclado.
 */
export class CloudButton extends Phaser.GameObjects.Container {
  constructor(scene, x, y, label, onClick, opts = {}) {
    super(scene, x, y);
    const w = opts.width || 140;
    const h = opts.height || 22;
    const key = cloudTexture(scene, w, h, `cloudbtn_${w}x${h}`);
    this.bg = scene.add.image(0, 0, key);
    this.label = pixelText(scene, 0, 0, label, { origin: 0.5, tint: 0x3455a4 });
    this.add([this.bg, this.label]);
    this.setSize(w, h);
    this.onClick = onClick;
    this.selected = false;
    this.setInteractive({ useHandCursor: true });
    this.on('pointerover', () => this.emit('hover', this));
    this.on('pointerdown', () => this.activate());
    scene.add.existing(this);
    if (opts.scrollFactor !== undefined) this.setScrollFactor(opts.scrollFactor);
  }

  setLabel(text) {
    this.label.setText(text);
    return this;
  }

  setSelected(sel) {
    this.selected = sel;
    this.bg.setTint(sel ? 0xffe082 : 0xffffff);
    this.label.setTint(sel ? 0xb04a8a : 0x3455a4);
    this.setScale(sel ? 1.06 : 1);
    return this;
  }

  activate() {
    if (!this.visible || !this.input?.enabled) return;
    this.scene.tweens.add({ targets: this, scale: 0.94, duration: 60, yoyo: true });
    if (this.onClick) this.onClick(this);
  }
}

/** Navegación con teclado (flechas/W/S + Enter/Espacio/J) sobre una lista de botones. */
export class MenuList {
  constructor(scene, buttons, audio) {
    this.scene = scene;
    this.buttons = buttons;
    this.audio = audio;
    this.index = 0;
    buttons.forEach((b, i) =>
      b.on('hover', () => {
        this.select(i);
      }),
    );
    const kb = scene.input.keyboard;
    this.keys = kb.addKeys('UP,DOWN,W,S,ENTER,SPACE,J');
    this.onKey = (event) => {
      const code = event.code;
      if (code === 'ArrowUp' || code === 'KeyW') this.move(-1);
      else if (code === 'ArrowDown' || code === 'KeyS') this.move(1);
      else if (code === 'Enter' || code === 'Space' || code === 'KeyJ') this.buttons[this.index]?.activate();
    };
    kb.on('keydown', this.onKey);
    scene.events.once('shutdown', () => kb.off('keydown', this.onKey));
    this.select(0, true);
  }

  move(d) {
    const n = this.buttons.length;
    let i = this.index;
    for (let k = 0; k < n; k++) {
      i = (i + d + n) % n;
      if (this.buttons[i].visible) break;
    }
    this.select(i);
  }

  select(i, silent) {
    if (i !== this.index && !silent) this.audio?.play('ui_move');
    this.index = i;
    this.buttons.forEach((b, k) => b.setSelected(k === i));
  }
}
