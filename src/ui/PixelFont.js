import Phaser from 'phaser';

/**
 * Fuente pixel art propia (glifos de 5x7 + 2 filas para tildes) con contorno oscuro.
 * Se dibuja en un canvas al arrancar y se registra como fuente bitmap "pixel",
 * de modo que no depende de tipografías externas ni de la red.
 */
const G = {
  A: ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  B: ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
  C: ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
  D: ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
  E: ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  F: ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
  G: ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.####'],
  H: ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  I: ['..#..', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  J: ['..###', '...#.', '...#.', '...#.', '#..#.', '#..#.', '.##..'],
  K: ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
  L: ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
  M: ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
  N: ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
  O: ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  P: ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
  Q: ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
  R: ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
  S: ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
  T: ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  U: ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  V: ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
  W: ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
  X: ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
  Y: ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
  Z: ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
  0: ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
  1: ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  2: ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  3: ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
  4: ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
  5: ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  6: ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'],
  7: ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  8: ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  9: ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'],
  ' ': ['.....', '.....', '.....', '.....', '.....', '.....', '.....'],
  '.': ['.....', '.....', '.....', '.....', '.....', '.....', '..#..'],
  ',': ['.....', '.....', '.....', '.....', '.....', '..#..', '.#...'],
  '!': ['..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'],
  '¡': ['..#..', '.....', '..#..', '..#..', '..#..', '..#..', '..#..'],
  '?': ['.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..'],
  '¿': ['..#..', '.....', '..#..', '.#...', '#....', '#...#', '.###.'],
  ':': ['.....', '..#..', '.....', '.....', '.....', '..#..', '.....'],
  ';': ['.....', '..#..', '.....', '.....', '..#..', '.#...', '.....'],
  '-': ['.....', '.....', '.....', '.###.', '.....', '.....', '.....'],
  '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
  '/': ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'],
  "'": ['..#..', '..#..', '.....', '.....', '.....', '.....', '.....'],
  '"': ['.#.#.', '.#.#.', '.....', '.....', '.....', '.....', '.....'],
  '(': ['...#.', '..#..', '.#...', '.#...', '.#...', '..#..', '...#.'],
  ')': ['.#...', '..#..', '...#.', '...#.', '...#.', '..#..', '.#...'],
  '%': ['##..#', '##.#.', '...#.', '..#..', '.#...', '.#.##', '#..##'],
  '<': ['...#.', '..#..', '.#...', '#....', '.#...', '..#..', '...#.'],
  '>': ['.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'],
  '=': ['.....', '.....', '#####', '.....', '#####', '.....', '.....'],
  _: ['.....', '.....', '.....', '.....', '.....', '.....', '#####'],
  // símbolos: * estrella, ^ flecha arriba, @ corazón, [ y ] flechas izquierda/derecha
  '*': ['..#..', '..#..', '#####', '.###.', '.###.', '.#.#.', '#...#'],
  '^': ['..#..', '.###.', '#.#.#', '..#..', '..#..', '..#..', '..#..'],
  '@': ['.....', '##.##', '#####', '#####', '.###.', '..#..', '.....'],
  '[': ['.....', '..#..', '.##..', '#####', '.##..', '..#..', '.....'],
  ']': ['.....', '..#..', '..##.', '#####', '..##.', '..#..', '.....'],
};

const ACCENTS = {
  Á: ['A', ['...#.', '..#..']],
  É: ['E', ['...#.', '..#..']],
  Í: ['I', ['...#.', '..#..']],
  Ó: ['O', ['...#.', '..#..']],
  Ú: ['U', ['...#.', '..#..']],
  Ñ: ['N', ['.##.#', '#.##.']],
  Ü: ['U', ['.....', '.#.#.']],
};

const CELL_W = 7;
const CELL_H = 11;
const PER_ROW = 16;
export const FONT_KEY = 'pixel';

export function registerPixelFont(scene) {
  if (scene.cache.bitmapFont.exists(FONT_KEY)) return;
  const chars = Object.keys(G).concat(Object.keys(ACCENTS));
  const rows = Math.ceil(chars.length / PER_ROW);
  const tex = scene.textures.createCanvas('pixelfont', PER_ROW * CELL_W, rows * CELL_H);
  const ctx = tex.getContext();

  chars.forEach((ch, i) => {
    const ox = (i % PER_ROW) * CELL_W;
    const oy = Math.floor(i / PER_ROW) * CELL_H;
    let glyph;
    if (ACCENTS[ch]) {
      const [base, top] = ACCENTS[ch];
      glyph = top.concat(G[base]);
    } else {
      glyph = ['.....', '.....'].concat(G[ch]);
    }
    const on = (x, y) => y >= 0 && y < 9 && x >= 0 && x < 5 && glyph[y][x] === '#';
    // contorno
    ctx.fillStyle = '#2A2350';
    for (let y = -1; y <= 9; y++) {
      for (let x = -1; x <= 5; x++) {
        if (on(x, y)) continue;
        if (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1)) {
          ctx.fillRect(ox + 1 + x, oy + 1 + y, 1, 1);
        }
      }
    }
    ctx.fillStyle = '#FFFFFF';
    for (let y = 0; y < 9; y++) {
      for (let x = 0; x < 5; x++) {
        if (on(x, y)) ctx.fillRect(ox + 1 + x, oy + 1 + y, 1, 1);
      }
    }
  });
  tex.refresh();

  const data = Phaser.GameObjects.RetroFont.Parse(scene, {
    image: 'pixelfont',
    width: CELL_W,
    height: CELL_H,
    chars: chars.join(''),
    charsPerRow: PER_ROW,
    spacing: { x: 0, y: 0 },
    offset: { x: 0, y: 0 },
    lineSpacing: 1,
  });
  scene.cache.bitmapFont.add(FONT_KEY, data);
}

/**
 * Crea un texto pixel art. El texto se pasa a mayúsculas (la fuente sólo tiene mayúsculas).
 * opts: { scale, tint, origin, align, depth, scrollFactor, maxWidth }
 */
export function pixelText(scene, x, y, text, opts = {}) {
  // sin tamaño explícito: se usa el nativo de la fuente (escala entera, píxeles nítidos)
  const t = scene.add.bitmapText(x, y, FONT_KEY, formatText(text, opts.maxWidth, opts.scale || 1));
  t.setLetterSpacing(-1);
  t.setScale(opts.scale || 1);
  const o = opts.origin ?? 0;
  if (Array.isArray(o)) t.setOrigin(o[0], o[1]);
  else t.setOrigin(o);
  if (opts.align === 'center') t.setCenterAlign();
  if (opts.tint !== undefined) t.setTint(opts.tint);
  if (opts.depth !== undefined) t.setDepth(opts.depth);
  if (opts.scrollFactor !== undefined) t.setScrollFactor(opts.scrollFactor);
  t.setText = wrapSetText(t, opts);
  return t;
}

function wrapSetText(t, opts) {
  const original = Phaser.GameObjects.BitmapText.prototype.setText;
  return function setText(value) {
    return original.call(t, formatText(value, opts.maxWidth, opts.scale || 1));
  };
}

/** Pasa a mayúsculas y, si se indica ancho máximo (px de pantalla), parte en líneas. */
export function formatText(text, maxWidth, scale = 1) {
  const upper = String(text).toUpperCase();
  if (!maxWidth) return upper;
  const charW = (CELL_W - 1) * scale;
  const maxChars = Math.max(4, Math.floor(maxWidth / charW));
  return upper
    .split('\n')
    .map((line) => {
      const words = line.split(' ');
      const out = [];
      let cur = '';
      for (const w of words) {
        if ((cur + (cur ? ' ' : '') + w).length > maxChars) {
          if (cur) out.push(cur);
          cur = w;
        } else {
          cur += (cur ? ' ' : '') + w;
        }
      }
      if (cur) out.push(cur);
      return out.join('\n');
    })
    .join('\n');
}
