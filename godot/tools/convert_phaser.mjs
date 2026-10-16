/**
 * Conversión Phaser -> Godot (paso 1 de 2).  Reproducible y sin dependencias:
 *
 *     node godot/tools/convert_phaser.mjs
 *
 * 1. Lee public/assets/manifest.json y los atlas JSON de Phaser (formato hash).
 *    Copia cada PNG a godot/resources/** (los originales no se tocan) y escribe
 *    godot/data/atlases.json con la región de cada fotograma y godot/data/characters.json
 *    con las animaciones (fotogramas, velocidad y repetición) del manifest.
 * 2. Evalúa los módulos de datos del juego Phaser (src/data, src/weapons, src/entities,
 *    src/config) con el propio Node y los vuelca a JSON en godot/data/.  Así los
 *    mapas, armas, enemigos y ajustes de Godot son exactamente los mismos valores
 *    que usa la versión Phaser (no se copian a mano).
 *
 * El paso 2 (SpriteFrames, TileSet y recursos de armas/enemigos) lo hace Godot:
 *     godot --headless --path godot --import
 *     godot --headless --path godot --script res://tools/build_resources.gd
 */
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GODOT = path.resolve(HERE, '..');
const ROOT = path.resolve(GODOT, '..');
const PUBLIC = path.join(ROOT, 'public');
const DATA_OUT = path.join(GODOT, 'data');

/** Destino de cada textura dentro del proyecto Godot (por clave del manifest). */
const TEXTURE_DEST = {
  player: 'resources/player/player.png',
  scratch: 'resources/enemies/scratch.png',
  spit: 'resources/enemies/spit.png',
  flea: 'resources/enemies/flea.png',
  nubarron: 'resources/bosses/nubarron.png',
  fx: 'resources/effects/fx.png',
  world1_objects: 'resources/tilesets/world1/world1_objects.png',
  world1_bg: 'resources/backgrounds/world1/world1_bg.png',
  world1_tiles: 'resources/tilesets/world1/world1_tiles.png',
  sky: 'resources/backgrounds/world1/sky.png',
  clouds_far: 'resources/backgrounds/world1/clouds_far.png',
  clouds_near: 'resources/backgrounds/world1/clouds_near.png',
};

const log = (...a) => console.log('[convert]', ...a);

async function readJson(file) {
  return JSON.parse(await fs.readFile(file, 'utf8'));
}

async function writeJson(file, obj) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, JSON.stringify(obj, null, 1) + '\n', 'utf8');
  log('escrito', path.relative(ROOT, file));
}

async function copyTexture(key, srcRel) {
  const dest = TEXTURE_DEST[key];
  if (!dest) throw new Error(`No hay destino Godot para la textura "${key}"`);
  const src = path.join(PUBLIC, srcRel);
  const out = path.join(GODOT, dest);
  await fs.mkdir(path.dirname(out), { recursive: true });
  await fs.copyFile(src, out);
  return 'res://' + dest;
}

/**
 * Convierte un atlas hash de Phaser en { texture, size, frames: { nombre: [x,y,w,h, ox,oy, sw,sh] } }.
 * ox/oy/sw/sh conservan el recorte (spriteSourceSize/sourceSize) por si un atlas futuro
 * viene recortado; en los actuales todos son trimmed=false (ox=oy=0, sw=w, sh=h).
 */
async function convertAtlas(key, pngRel, jsonRel) {
  const atlas = await readJson(path.join(PUBLIC, jsonRel));
  const texture = await copyTexture(key, pngRel);
  const frames = {};
  for (const [name, f] of Object.entries(atlas.frames)) {
    if (f.rotated) throw new Error(`${key}:${name} está rotado; no soportado`);
    const r = f.frame;
    const ss = f.spriteSourceSize || { x: 0, y: 0 };
    const src = f.sourceSize || { w: r.w, h: r.h };
    frames[name] = [r.x, r.y, r.w, r.h, ss.x, ss.y, src.w, src.h];
  }
  return { texture, size: [atlas.meta.size.w, atlas.meta.size.h], frames };
}

async function convertAssets() {
  const manifest = await readJson(path.join(PUBLIC, 'assets', 'manifest.json'));
  const atlases = {};
  const characters = {};
  for (const [key, c] of Object.entries(manifest.characters)) {
    atlases[key] = await convertAtlas(key, path.join('', c.png), c.json);
    const anims = {};
    for (const [name, a] of Object.entries(c.anims)) {
      const missing = a.frames.filter((f) => !atlases[key].frames[f]);
      if (missing.length) throw new Error(`${key}_${name}: faltan fotogramas ${missing.join(', ')}`);
      anims[name] = { frames: a.frames, fps: a.frameRate, loop: a.repeat === -1, derived: !!a.derived };
    }
    characters[key] = { frameWidth: c.frameWidth, frameHeight: c.frameHeight, anims };
  }
  for (const a of manifest.atlases) atlases[a.key] = await convertAtlas(a.key, a.png, a.json);
  const images = {};
  for (const img of manifest.images) images[img.key] = await copyTexture(img.key, img.png);
  const ts = manifest.tileset;
  const tileset = {
    key: ts.key,
    texture: await copyTexture(ts.key, ts.png),
    tileSize: ts.tileSize,
    terrain: ts.terrain,
    blocks: ts.blocks,
  };
  // Animación del portal: Phaser la crea en AnimationManager (portal_0..5 a 10 fps, en bucle).
  const portalFrames = [0, 1, 2, 3, 4, 5].map((i) => `portal_${i}`).filter((f) => atlases.fx.frames[f]);
  characters.fx_portal = {
    atlas: 'fx',
    frameWidth: 40,
    frameHeight: 40,
    anims: { spin: { frames: portalFrames, fps: 10, loop: true, derived: false } },
  };
  await writeJson(path.join(DATA_OUT, 'atlases.json'), { atlases, images, tileset });
  await writeJson(path.join(DATA_OUT, 'characters.json'), characters);
}

async function importModule(rel) {
  return import(pathToFileURL(path.join(ROOT, rel)).href);
}

async function convertData() {
  const { WORLD1 } = await importModule('src/data/world1.js');
  const { WEAPONS, WEAPON_ORDER, PAINT_COLORS, FOAM_COLORS } = await importModule('src/weapons/weaponDefs.js');
  const { ENEMY_DEFS } = await importModule('src/entities/enemyDefs.js');
  const { PLAYER_TUNING, CAMERA_TUNING } = await importModule('src/config/tuning.js');

  // world1.js define el jefe en WORLD1.boss: se separa en dos archivos (nivel y arena)
  const { boss, ...level } = WORLD1;
  await writeJson(path.join(DATA_OUT, 'worlds', 'world1.json'), level);
  await writeJson(path.join(DATA_OUT, 'worlds', 'world1_boss.json'), boss);
  await writeJson(path.join(DATA_OUT, 'weapons', 'weapons.json'), {
    order: WEAPON_ORDER,
    paintColors: PAINT_COLORS,
    foamColors: FOAM_COLORS,
    weapons: WEAPONS,
  });
  await writeJson(path.join(DATA_OUT, 'enemies', 'enemies.json'), ENEMY_DEFS);
  await writeJson(path.join(DATA_OUT, 'tuning.json'), {
    // gameConfig.js (no se importa: depende de Phaser) — valores copiados de allí
    game: { width: 480, height: 270, tile: 16, gravity: 900 },
    player: PLAYER_TUNING,
    camera: CAMERA_TUNING,
  });
  log(
    `Mundo 1: ${level.widthTiles}x${level.heightTiles} teselas, ${level.terrain.length} terrenos, ` +
      `${level.stars.length} estrellas, ${level.enemies.length} enemigos, ${level.checkpoints.length} checkpoints; ` +
      `arena ${boss.widthTiles}x${boss.heightTiles}`,
  );
}

await convertAssets();
// conserva el informe que identifica recursos originales, reutilizados y generados
await fs.copyFile(path.join(PUBLIC, 'assets', 'ASSETS_REPORT.md'), path.join(GODOT, 'resources', 'ASSETS_REPORT.md'));
log('copiado resources/ASSETS_REPORT.md');
await convertData();
log('listo');
