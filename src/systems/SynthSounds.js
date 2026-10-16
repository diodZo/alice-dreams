/**
 * SONIDOS PROVISIONALES sintetizados con WebAudio.
 * No hay archivos de audio en el proyecto todavía; estas funciones generan efectos
 * y música chiptune sencillos para que cada evento tenga respuesta sonora.
 * Se sustituyen asignando archivos en config/audioConfig.js.
 */

const NOTE_INDEX = { C: 0, 'C#': 1, D: 2, 'D#': 3, E: 4, F: 5, 'F#': 6, G: 7, 'G#': 8, A: 9, 'A#': 10, B: 11 };

export function noteToFreq(note) {
  const m = /^([A-G]#?)(\d)$/.exec(note);
  if (!m) return 0;
  const midi = 12 * (Number(m[2]) + 1) + NOTE_INDEX[m[1]];
  return 440 * Math.pow(2, (midi - 69) / 12);
}

function tone(ctx, out, { type = 'square', from, to = from, start = 0, dur = 0.1, vol = 0.2, attack = 0.005 }) {
  const t0 = ctx.currentTime + start;
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(from, t0);
  if (to !== from) osc.frequency.exponentialRampToValueAtTime(Math.max(20, to), t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(vol, t0 + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(out);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

let noiseBuffer = null;
function noise(ctx, out, { start = 0, dur = 0.15, vol = 0.15, filter = 1200, q = 1 }) {
  if (!noiseBuffer || noiseBuffer.sampleRate !== ctx.sampleRate) {
    noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 0.5, ctx.sampleRate);
    const d = noiseBuffer.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const t0 = ctx.currentTime + start;
  const src = ctx.createBufferSource();
  src.buffer = noiseBuffer;
  const f = ctx.createBiquadFilter();
  f.type = 'bandpass';
  f.frequency.value = filter;
  f.Q.value = q;
  const g = ctx.createGain();
  g.gain.setValueAtTime(vol, t0);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(f).connect(g).connect(out);
  src.start(t0);
  src.stop(t0 + dur + 0.02);
}

const arp = (ctx, out, notes, step, type = 'square', vol = 0.12, dur = 0.12) =>
  notes.forEach((n, i) => tone(ctx, out, { type, from: noteToFreq(n), start: i * step, dur, vol }));

export const SYNTH_SFX = {
  jump: (c, o) => tone(c, o, { type: 'square', from: 280, to: 620, dur: 0.13, vol: 0.09 }),
  shoot_bubble: (c, o) => {
    tone(c, o, { type: 'sine', from: 700, to: 1300, dur: 0.1, vol: 0.12 });
    tone(c, o, { type: 'sine', from: 1300, to: 1700, start: 0.04, dur: 0.06, vol: 0.06 });
  },
  shoot_paint: (c, o) => {
    noise(c, o, { dur: 0.12, vol: 0.12, filter: 1800, q: 2 });
    tone(c, o, { type: 'triangle', from: 520, to: 260, dur: 0.1, vol: 0.12 });
  },
  shoot_sling: (c, o) => {
    tone(c, o, { type: 'square', from: 180, to: 90, dur: 0.12, vol: 0.1 });
    noise(c, o, { start: 0.02, dur: 0.08, vol: 0.07, filter: 3000 });
  },
  weapon_switch: (c, o) => arp(c, o, ['E5', 'B5'], 0.05, 'square', 0.07, 0.06),
  star: (c, o) => arp(c, o, ['C6', 'E6', 'G6'], 0.045, 'square', 0.07, 0.08),
  pickup: (c, o) => arp(c, o, ['C5', 'E5', 'G5', 'C6', 'E6'], 0.06, 'square', 0.08, 0.1),
  hurt: (c, o) => {
    tone(c, o, { type: 'square', from: 440, to: 140, dur: 0.25, vol: 0.12 });
    noise(c, o, { dur: 0.1, vol: 0.08, filter: 800 });
  },
  checkpoint: (c, o) => arp(c, o, ['G4', 'C5', 'E5', 'G5', 'C6'], 0.07, 'triangle', 0.16, 0.16),
  boss_appear: (c, o) => {
    tone(c, o, { type: 'sawtooth', from: 110, to: 55, dur: 0.9, vol: 0.12, attack: 0.1 });
    noise(c, o, { dur: 0.9, vol: 0.1, filter: 300 });
    arp(c, o, ['A4', 'F4', 'D4', 'A3'], 0.12, 'square', 0.08, 0.14);
  },
  victory: (c, o) => {
    arp(c, o, ['C5', 'E5', 'G5', 'C6', 'G5', 'C6', 'E6'], 0.11, 'square', 0.09, 0.14);
    arp(c, o, ['C4', 'G4', 'C5'], 0.25, 'triangle', 0.14, 0.3);
  },
  enemy_hit: (c, o) => tone(c, o, { type: 'square', from: 600, to: 300, dur: 0.07, vol: 0.08 }),
  enemy_defeat: (c, o) => {
    noise(c, o, { dur: 0.2, vol: 0.1, filter: 1500 });
    arp(c, o, ['G5', 'E5', 'C5'], 0.05, 'triangle', 0.1, 0.08);
  },
  bubble_trap: (c, o) => tone(c, o, { type: 'sine', from: 400, to: 900, dur: 0.25, vol: 0.12 }),
  bubble_pop: (c, o) => {
    tone(c, o, { type: 'sine', from: 1200, to: 300, dur: 0.06, vol: 0.14 });
    noise(c, o, { dur: 0.05, vol: 0.06, filter: 4000 });
  },
  bounce: (c, o) => tone(c, o, { type: 'sine', from: 160, to: 640, dur: 0.22, vol: 0.16 }),
  wind: (c, o) => noise(c, o, { dur: 0.6, vol: 0.08, filter: 600, q: 0.7 }),
  boss_hit: (c, o) => tone(c, o, { type: 'square', from: 300, to: 180, dur: 0.06, vol: 0.07 }),
  ui_move: (c, o) => tone(c, o, { type: 'square', from: 660, dur: 0.04, vol: 0.05 }),
  ui_select: (c, o) => arp(c, o, ['C5', 'G5'], 0.05, 'square', 0.08, 0.07),
  pause: (c, o) => arp(c, o, ['G5', 'C5'], 0.06, 'square', 0.06, 0.07),
  no_weapon: (c, o) => tone(c, o, { type: 'square', from: 200, to: 180, dur: 0.08, vol: 0.06 }),
  portal: (c, o) => {
    tone(c, o, { type: 'sine', from: 300, to: 1200, dur: 0.7, vol: 0.12, attack: 0.05 });
    arp(c, o, ['C6', 'G6', 'E6', 'C7'], 0.09, 'triangle', 0.06, 0.12);
  },
};

/**
 * Pistas de música provisionales. Cada compás: 8 corcheas.
 * Token = nota que empieza, "-" = mantener, "." = silencio.
 */
export const SYNTH_MUSIC = {
  menu: {
    bpm: 96,
    lead: { type: 'triangle', vol: 0.07 },
    bass: { type: 'sine', vol: 0.08 },
    melody: 'E5 - G5 - C6 - B5 - | A5 - G5 - E5 - - - | F5 - A5 - G5 - E5 - | D5 - - - . . . . | E5 - G5 - C6 - D6 - | E6 - D6 - C6 - A5 - | B5 - G5 - A5 - B5 - | C6 - - - . . . .',
    bassline: 'C3 . G3 . E3 . G3 . | A2 . E3 . C3 . E3 . | F2 . C3 . A2 . C3 . | G2 . D3 . B2 . D3 . | C3 . G3 . E3 . G3 . | A2 . E3 . C3 . E3 . | G2 . D3 . B2 . D3 . | C3 . G3 . C3 . . .',
  },
  world1: {
    bpm: 126,
    lead: { type: 'square', vol: 0.045 },
    bass: { type: 'triangle', vol: 0.1 },
    melody: 'C5 . E5 . G5 - E5 . | A5 . G5 . E5 - C5 . | D5 . F5 . A5 - G5 . | E5 - - . D5 - - . | C5 . E5 . G5 - C6 . | B5 . A5 . G5 - E5 . | F5 . A5 . G5 . D5 . | C5 - - - . . . . | E5 . E5 . F5 . G5 . | G5 . F5 . E5 . D5 . | C5 . C5 . D5 . E5 . | E5 - D5 . D5 - - . | E5 . E5 . F5 . G5 . | G5 . F5 . E5 . D5 . | C5 . C5 . D5 . E5 . | D5 - C5 . C5 - - .',
    bassline: 'C3 . G2 . C3 . G2 . | F2 . C3 . F2 . C3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . B2 . | C3 . G2 . C3 . G2 . | A2 . E3 . A2 . E3 . | F2 . C3 . G2 . D3 . | C3 . G2 . C3 . . . | C3 . G2 . C3 . G2 . | G2 . D3 . G2 . D3 . | A2 . E3 . A2 . E3 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . G2 . | G2 . D3 . G2 . D3 . | A2 . E3 . F2 . C3 . | G2 . D3 . C3 . . .',
  },
  boss: {
    bpm: 150,
    lead: { type: 'square', vol: 0.05 },
    bass: { type: 'sawtooth', vol: 0.05 },
    melody: 'A4 . C5 . E5 . A5 . | G5 . E5 . C5 . E5 . | F5 . A5 . C6 . A5 . | G5 - - . E5 - - . | A4 . C5 . E5 . A5 . | B5 . A5 . G5 . E5 . | F5 . E5 . D5 . B4 . | A4 - - - . . . .',
    bassline: 'A2 A2 . A2 E3 . A2 . | C3 C3 . C3 G3 . C3 . | F2 F2 . F2 C3 . F2 . | G2 G2 . G2 D3 . G2 . | A2 A2 . A2 E3 . A2 . | E2 E2 . E2 B2 . E2 . | D3 D3 . D3 A2 . D3 . | E2 E2 . E2 G#2 . E2 .',
  },
};

export function parseTrack(str) {
  return str
    .replace(/\|/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

export function scheduleNote(ctx, out, voice, freq, time, dur) {
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = voice.type;
  osc.frequency.setValueAtTime(freq, time);
  g.gain.setValueAtTime(0.0001, time);
  g.gain.exponentialRampToValueAtTime(voice.vol, time + 0.01);
  g.gain.setValueAtTime(voice.vol, time + Math.max(0.02, dur - 0.04));
  g.gain.exponentialRampToValueAtTime(0.0001, time + dur);
  osc.connect(g).connect(out);
  osc.start(time);
  osc.stop(time + dur + 0.02);
}
