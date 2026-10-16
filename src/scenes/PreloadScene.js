import Phaser from 'phaser';
import { GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';
import { SFX_FILES, MUSIC_FILES } from '../config/audioConfig.js';
import { pixelText } from '../ui/PixelFont.js';
import { AnimationManager } from '../systems/AnimationManager.js';
import { PlaceholderFactory } from '../systems/PlaceholderFactory.js';

/** Carga todos los recursos declarados en assets/manifest.json con barra de progreso. */
export class PreloadScene extends Phaser.Scene {
  constructor() {
    super('Preload');
  }

  preload() {
    const manifest = this.cache.json.get('manifest');
    this.cameras.main.setBackgroundColor('#3455A4');
    const cx = GAME_WIDTH / 2;
    pixelText(this, cx, 100, 'Guardiana de los Sueños', { origin: 0.5, scale: 2, tint: 0xffe082 });
    pixelText(this, cx, 128, 'Cargando el sueño...', { origin: 0.5, tint: 0xfff7ff });
    this.add.rectangle(cx, 150, 202, 10, 0x2a2350).setStrokeStyle(1, 0xfff7ff);
    const bar = this.add.rectangle(cx - 100, 150, 0, 6, 0xf7a8d8).setOrigin(0, 0.5);
    this.load.on('progress', (p) => (bar.width = 200 * p));

    if (!manifest) {
      this.manifestMissing = true;
      return;
    }

    this.failed = [];
    this.load.on('loaderror', (file) => this.failed.push(file.key));

    for (const [key, c] of Object.entries(manifest.characters)) this.load.atlas(key, c.png, c.json);
    for (const a of manifest.atlases) this.load.atlas(a.key, a.png, a.json);
    for (const img of manifest.images) this.load.image(img.key, img.png);
    if (manifest.tileset) this.load.image(manifest.tileset.key, manifest.tileset.png);

    for (const [event, path] of Object.entries(SFX_FILES)) if (path) this.load.audio(`sfx_${event}`, path);
    for (const [track, path] of Object.entries(MUSIC_FILES)) if (path) this.load.audio(`music_${track}`, path);
  }

  create() {
    if (this.manifestMissing) {
      // Error explícito: sin manifest no hay recursos que cargar.
      console.error('[Preload] Falta public/assets/manifest.json. Ejecuta: npm run assets');
      pixelText(this, GAME_WIDTH / 2, 190, 'Faltan los recursos.\nEjecuta: npm run assets', {
        origin: 0.5,
        tint: 0xff8080,
        align: 'center',
      });
      return;
    }
    const manifest = this.cache.json.get('manifest');
    this.createPlaceholders(manifest);
    this.createRuntimeTextures();
    AnimationManager.createAll(this, manifest);
    this.registry.set('manifest', manifest);
    this.scene.start('Menu');
  }

  /** Sustituye cada recurso que no se pudo cargar por un marcador provisional visible. */
  createPlaceholders(manifest) {
    for (const [key, c] of Object.entries(manifest.characters)) {
      if (!this.textures.exists(key) || this.failed.includes(key)) {
        const names = [...new Set(Object.values(c.anims).flatMap((a) => a.frames))];
        PlaceholderFactory.makeAtlas(this, key, names, c.frameWidth, c.frameHeight);
      }
    }
    for (const img of manifest.images) {
      if (!this.textures.exists(img.key)) {
        PlaceholderFactory.makeTexture(this, img.key, 64, 64);
        PlaceholderFactory.mark(img.key);
      }
    }
    const ts = manifest.tileset;
    if (ts && !this.textures.exists(ts.key)) {
      PlaceholderFactory.makeTexture(this, ts.key, 128, 64);
      PlaceholderFactory.mark(ts.key);
    }
    for (const a of manifest.atlases) {
      if (!this.textures.exists(a.key)) {
        PlaceholderFactory.makeTexture(this, a.key, 16, 16);
        PlaceholderFactory.mark(a.key);
      }
    }
  }

  /** Texturas mínimas generadas en tiempo de ejecución (partículas y gotas de pintura). */
  createRuntimeTextures() {
    const g = this.make.graphics({ x: 0, y: 0 }, false);
    g.fillStyle(0xffffff, 1).fillRect(0, 0, 2, 2);
    g.generateTexture('px', 2, 2);
    g.clear();
    g.fillStyle(0xffffff, 1).fillRect(0, 0, 3, 2);
    g.generateTexture('confetti', 3, 2);
    g.clear();
    // gota de pintura: círculo de 7px con contorno (se tiñe al disparar)
    g.fillStyle(0x2a2350, 1).fillCircle(4, 4, 4);
    g.fillStyle(0xffffff, 1).fillCircle(4, 4, 3);
    g.fillStyle(0xffffff, 1).fillRect(5, 1, 3, 3);
    g.generateTexture('paint_blob', 9, 9);
    g.clear();
    // brillo circular suave para efectos de energía
    for (let r = 10; r > 0; r -= 2) {
      g.fillStyle(0xffffff, 0.12).fillCircle(10, 10, r);
    }
    g.generateTexture('glow', 20, 20);
    g.destroy();
  }
}
