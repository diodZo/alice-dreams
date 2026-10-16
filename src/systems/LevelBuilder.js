import { DEPTH, TILE } from '../config/gameConfig.js';
import { createCloud, MovingPlatform, CrumblePlatform, BouncePad } from '../entities/Platforms.js';
import { Hazard, WindZone } from '../entities/Hazards.js';
import { Star, WeaponPickup } from '../entities/Collectibles.js';
import { Sign } from '../entities/Sign.js';
import { PlaceholderFactory } from './PlaceholderFactory.js';

/**
 * Convierte los datos de un mundo (data/worldN.js) en objetos de Phaser:
 * tilemap de terreno con autotiling, plataformas, obstáculos, coleccionables
 * y decoración.  No contiene reglas de juego: las colisiones las define LevelScene.
 */
export class LevelBuilder {
  constructor(scene, data, manifest) {
    this.scene = scene;
    this.data = data;
    this.manifest = manifest;
    this.cols = data.widthTiles;
    this.rows = data.heightTiles;
  }

  build({ touchMode = false, collectedStars = [] } = {}) {
    const d = this.data;
    const out = {};
    out.terrain = this.buildTerrain();
    out.oneWay = this.scene.add.group();
    out.movers = [];
    out.crumbles = [];

    const atlas = d.objectsAtlas;
    this.checkFrames(atlas);

    for (const c of d.clouds) createCloud(this.scene, out.oneWay, c, atlas);
    for (const b of d.bridges) this.buildBridge(b, out.oneWay, atlas);
    for (const m of d.movers) {
      const p = new MovingPlatform(this.scene, m, atlas);
      out.movers.push(p);
      out.oneWay.add(p);
    }
    for (const c of d.crumbles) {
      const p = new CrumblePlatform(this.scene, c, atlas);
      out.crumbles.push(p);
      out.oneWay.add(p);
    }
    out.pads = d.pads.map((p) => new BouncePad(this.scene, p, atlas));
    out.hazards = d.hazards.map((h) => new Hazard(this.scene, h, atlas));
    out.winds = d.winds.map((w) => new WindZone(this.scene, w));

    out.stars = [];
    d.stars.forEach((s, i) => {
      const id = `${d.key}:s${i}`;
      if (collectedStars.includes(id)) return;
      out.stars.push(new Star(this.scene, s.x * TILE + TILE / 2, s.y * TILE + TILE / 2, { id }));
    });
    out.starsTotal = d.stars.length;
    out.pickups = d.pickups.map((p) => new WeaponPickup(this.scene, p));
    out.signs = d.signs.map((s) => new Sign(this.scene, s, atlas, touchMode));
    out.decor = d.decor.map((dec) => this.buildDecor(dec, atlas));
    return out;
  }

  /** Avisa (sin ocultarlo) si el atlas no contiene algún fotograma usado por los datos. */
  checkFrames(atlas) {
    const d = this.data;
    const frames = new Set([
      ...d.clouds.map((c) => c.frame),
      ...d.movers.map((m) => m.frame),
      ...d.hazards.map((h) => h.frame),
      ...d.decor.map((x) => x.frame),
      'cloud_puff',
      'jump_pad',
      'signpost',
      'flag',
      'rainbow_mid',
      'rainbow_cap_l',
      'rainbow_cap_r',
    ]);
    const tex = this.scene.textures.get(atlas);
    for (const f of frames) if (f && !tex.has(f)) PlaceholderFactory.mark(`${atlas}:${f}`);
  }

  // ------------------------------------------------------------------ terreno
  buildTerrain() {
    const d = this.data;
    const ts = this.manifest.tileset;
    const grid = Array.from({ length: this.rows }, () => new Array(this.cols).fill(0));
    for (const r of d.terrain) {
      for (let y = r.y; y < Math.min(this.rows, r.y + r.h); y++) {
        for (let x = Math.max(0, r.x); x < Math.min(this.cols, r.x + r.w); x++) grid[y][x] = 1;
      }
    }
    const map = this.scene.make.tilemap({ tileWidth: TILE, tileHeight: TILE, width: this.cols, height: this.rows });
    const tileset = map.addTilesetImage(d.tileset, d.tileset, TILE, TILE, 0, 0);
    const layer = map.createBlankLayer('terrain', tileset, 0, 0);
    layer.setDepth(DEPTH.TERRAIN);

    // el fondo del mundo cuenta como sólido (el terreno no muestra borde inferior)
    const solidBelow = (x, y) => y >= this.rows || grid[y][x] === 1;

    for (let y = 0; y < this.rows; y++) {
      for (let x = 0; x < this.cols; x++) {
        if (!grid[y][x]) continue;
        const up = y > 0 && grid[y - 1][x] === 1;
        const down = solidBelow(x, y + 1);
        // en los extremos del mapa el terreno continúa (sin borde lateral visible)
        const left = x === 0 ? true : grid[y][x - 1] === 1;
        const right = x === this.cols - 1 ? true : grid[y][x + 1] === 1;
        let set;
        if (!up && !down) set = ts.terrain.plat;
        else if (!up) set = ts.terrain.top;
        else if (!down) set = ts.terrain.bottom;
        else set = ts.terrain.fill;
        let v;
        if (!left && !right) v = 0;
        else if (!left) v = 1;
        else if (!right) v = 3;
        else v = 2;
        map.putTileAt(set[v], x, y, false, layer);
      }
    }
    for (const b of d.blocks) {
      const idx = ts.blocks[b.type];
      if (idx === undefined) {
        PlaceholderFactory.mark(`tileset:${b.type}`);
        continue;
      }
      map.putTileAt(idx, b.x, b.y, false, layer);
    }
    layer.setCollisionByExclusion([-1]);
    this.map = map;
    this.layer = layer;
    this.grid = grid;
    return layer;
  }

  /** Coloca (o quita) un bloque sólido en tiempo de juego (p. ej. la puerta del jefe). */
  setBlock(x, y, type) {
    const idx = type ? this.manifest.tileset.blocks[type] : -1;
    if (idx === -1) this.map.removeTileAt(x, y, true, true, this.layer);
    else {
      const t = this.map.putTileAt(idx, x, y, true, this.layer);
      t.setCollision(true);
    }
  }

  // ------------------------------------------------------------------ puentes
  buildBridge(b, group, atlas) {
    const scene = this.scene;
    const x0 = b.x * TILE;
    const w = b.w * TILE;
    const surface = b.y * TILE;
    const mid = scene.textures.getFrame(atlas, 'rainbow_mid');
    const h = mid ? mid.realHeight : 16;
    scene.add.tileSprite(x0 + w / 2, surface - 2, w, h, atlas, 'rainbow_mid').setOrigin(0.5, 0).setDepth(DEPTH.PLATFORM);
    scene.add.image(x0, surface - 4, atlas, 'rainbow_cap_l').setOrigin(0.6, 0).setDepth(DEPTH.PLATFORM + 1);
    scene.add.image(x0 + w, surface - 4, atlas, 'rainbow_cap_r').setOrigin(0.4, 0).setDepth(DEPTH.PLATFORM + 1);
    // cuerpo invisible unidireccional a lo largo de todo el puente
    const zone = scene.add.zone(x0 + w / 2, surface + 4, w, 8);
    scene.physics.add.existing(zone, true);
    zone.body.checkCollision.down = false;
    zone.body.checkCollision.left = false;
    zone.body.checkCollision.right = false;
    zone.oneWay = true;
    group.add(zone);
  }

  // ------------------------------------------------------------------ decoración
  buildDecor(dec, atlas) {
    const scene = this.scene;
    const img = scene.add.image(dec.x * TILE + TILE / 2, dec.y * TILE + 1, atlas, dec.frame).setOrigin(0.5, 1);
    img.setDepth(dec.front ? DEPTH.DECOR_FRONT : dec.back ? DEPTH.DECOR_BACK - 1 : DEPTH.DECOR_BACK);
    if (dec.sway) {
      img.setOrigin(0.5, 1);
      scene.tweens.add({
        targets: img,
        angle: { from: -2.5, to: 2.5 },
        duration: 1400 + Math.random() * 600,
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      });
    }
    if (dec.shimmer) {
      img.setAlpha(0.9);
      scene.tweens.add({ targets: img, alpha: 0.7, duration: 500, yoyo: true, repeat: -1 });
      const mist = scene.add.particles(img.x, img.y - 4, 'px', {
        x: { min: -img.width / 3, max: img.width / 3 },
        speedY: { min: -30, max: -10 },
        speedX: { min: -12, max: 12 },
        lifespan: 700,
        scale: { start: 1.5, end: 0 },
        alpha: { start: 0.8, end: 0 },
        frequency: 90,
        tint: [0xffffff, 0xc8f0ff],
      });
      mist.setDepth(img.depth + 0.1);
    }
    return img;
  }
}
