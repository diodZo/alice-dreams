import Phaser from 'phaser';
import { DEPTH, TILE } from '../config/gameConfig.js';
import { pixelText } from '../ui/PixelFont.js';

/** Cartel con instrucción contextual: muestra un bocadillo al acercarse. */
export class Sign extends Phaser.GameObjects.Image {
  constructor(scene, def, atlas, touchMode) {
    super(scene, def.x * TILE + TILE / 2, def.y * TILE + 2, atlas, 'signpost');
    scene.add.existing(this);
    this.setOrigin(0.5, 1).setDepth(DEPTH.DECOR_BACK + 1);
    const text = touchMode && def.touch ? def.touch : def.text;

    const label = pixelText(scene, 0, 0, text, { origin: 0.5, tint: 0x3455a4, maxWidth: 170 });
    const w = Math.ceil(label.width) + 12;
    const h = Math.ceil(label.height) + 10;
    const bg = scene.add.graphics();
    bg.fillStyle(0x2a2350, 1).fillRoundedRect(-w / 2 - 1, -h / 2 - 1, w + 2, h + 2, 5);
    bg.fillStyle(0xfff7ff, 1).fillRoundedRect(-w / 2, -h / 2, w, h, 4);
    bg.fillStyle(0xfff7ff, 1).fillTriangle(-4, h / 2 - 1, 4, h / 2 - 1, 0, h / 2 + 5);
    this.bubble = scene.add.container(this.x, this.y - this.height - h / 2 - 8, [bg, label]);
    this.bubble.setDepth(DEPTH.PLAYER - 1).setAlpha(0);
    // que el bocadillo no se salga por arriba
    if (this.bubble.y - h / 2 < 4) this.bubble.y = h / 2 + 4;
    this.visibleBubble = false;
  }

  distanceTo(player) {
    return Math.abs(player.y - this.y) < 64 ? Math.abs(player.x - this.x) : Infinity;
  }

  /** Muestra el bocadillo sólo si este es el cartel activo (el más cercano). */
  updateProximity(active) {
    const near = active;
    if (near === this.visibleBubble) return;
    this.visibleBubble = near;
    this.scene.tweens.killTweensOf(this.bubble);
    this.scene.tweens.add({ targets: this.bubble, alpha: near ? 1 : 0, duration: 180 });
  }
}
